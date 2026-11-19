import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

/// Lexical highlighting for Objective-C.
@internal
final class ObjectiveCGrammar extends MatcherGrammar {
  const ObjectiveCGrammar();

  static const String _identifier = r'[a-zA-Z_]\w*';

  @override
  List<Matcher> get matchers => _matchers;

  static final List<Matcher> _matchers = [
    Matcher.regex(r'\s+', tag: Tags.whitespace),
    // Match the most common tokens first.
    // Besides the `/` that [_operators] leaves to [_comments],
    // none can begin a later token.
    _names,
    Matcher.regex(r'[{}()\[\],;]', tag: Tags.punctuation),
    _operators,
    _preprocessor,
    _comments,
    // Before [_atDirectives], so `@"` begins a string.
    _strings,
    _atDirectives,
    _numbers,
    // After [_numbers], so literals like `.5` stay whole.
    Matcher.verbatim('.', tag: Tags.accessor),
  ];

  /// Whitespace is matched explicitly by [matchers],
  /// so disable the default trailing whitespace rule on [Matcher.options].
  @override
  List<Matcher> get postAppliedMatchers => const [];

  static final Matcher _preprocessor = Matcher.wrapped(
    begin: Matcher.regex(
      r'(?<=^[ \t]*)#[ \t]*\w+',
      tag: const Tag('name', parent: Tags.preprocessorDirective),
    ),
    // A trailing backslash continues the directive onto the next line.
    end: Matcher.regex(r'(?<!\\)$'),
    content: Matcher.options([
      _comments,
      // A string is skipped whole, so the `//` in a value
      // like `@"https://example.com"` doesn't begin a comment.
      Matcher.regex(
        r'(?:"(?:[^"\\]|\\.)*"?|[^"/]|/(?![/*]))+',
        tag: const Tag('options', parent: Tags.preprocessorDirective),
      ),
    ]),
    tag: Tags.preprocessorDirective,
  );

  static final Matcher _comments = Matcher.options([
    // `///` and `//!` begin doc comments, but
    // four or more slashes, such as `////`, form a regular line comment.
    Matcher.regex(r'//(?:/(?!/)|!).*', tag: Tags.docComment),
    Matcher.regex(r'//.*', tag: Tags.lineComment),
    for (final (opener, tag) in const [
      // `/**` and `/*!` begin doc comments, but
      // `/**/` and `/***` are regular block comments.
      (r'/\*(?:\*(?![*/])|!)', Tags.docComment),
      (r'/\*', Tags.blockComment),
    ])
      Matcher.wrapped(
        begin: Matcher.regex(opener, tag: Tag('begin', parent: tag)),
        end: Matcher.verbatim('*/', tag: Tag('end', parent: tag)),
        content: Matcher.regex(
          r'(?:[^*]|\*(?!/))+',
          tag: Tag('content', parent: tag),
        ),
        tag: tag,
      ),
  ]);

  static final Matcher _strings = Matcher.options([
    _quotedString('@?"', '"', Tags.doubleQuoteString),
    _quotedString("'", "'", Tags.characterLiteral),
  ]);

  static Matcher _quotedString(String opener, String quote, Tag tag) =>
      Matcher.wrapped(
        begin: Matcher.regex(opener, tag: Tag('begin', parent: tag)),
        // An unclosed string or character literal ends with its line.
        end: Matcher.regex('$quote|\$', tag: Tag('end', parent: tag)),
        content: Matcher.options([
          Matcher.regex(
            r'\\(?:[0-7]{1,3}|x[0-9a-fA-F]+|u[0-9a-fA-F]{4}|U[0-9a-fA-F]{8}|.)',
            tag: Tags.stringEscape,
          ),
          // A backslash that ends its line has nothing to escape.
          Matcher.regex('[^$quote\\\\]+|\\\\', tag: Tags.stringContent),
        ]),
        tag: tag,
      );

  /// `@` either begins a directive, such as `@interface`, or
  /// boxes what follows it, such as `@42`, `@YES`, `@[...]`, or `@(...)`.
  static final Matcher _atDirectives = Matcher.select(
    '@(?:$_identifier)?',
    (match) => _atKeywords[match[0]] ?? _boxOperator,
  );

  static final Matcher _boxOperator = Matcher.verbatim(
    '@',
    tag: Tags.operator,
  );

  static final Map<String, Matcher> _atKeywords = {
    ..._keywords(prefix: '@', [
      'class',
      'compatibility_alias',
      'dynamic',
      'end',
      'implementation',
      'import',
      'interface',
      'protocol',
      'synthesize',
    ], Tags.declarationKeyword),
    '@property': _property,
    ..._keywords(prefix: '@', [
      'autoreleasepool',
      'catch',
      'finally',
      'synchronized',
      'throw',
      'try',
    ], Tags.controlKeyword),
    ..._keywords(prefix: '@', [
      'optional',
      'package',
      'private',
      'protected',
      'public',
      'required',
    ], Tags.modifierKeyword),
    ..._keywords(prefix: '@', [
      'available',
      'encode',
      'selector',
    ], Tags.keyword),
  };

  /// Attributes such as `copy` are only keywords up to the end of
  /// the attribute list of a `@property`,
  /// so method calls like `[tasks copy]` stay identifiers.
  static final Matcher _property = Matcher.wrapped(
    begin: Matcher.verbatim(
      '@property',
      tag: const Tag('property', parent: Tags.declarationKeyword),
    ),
    // Without an attribute list or its closing `)`, end with the line.
    end: Matcher.regex(r'\)|$', tag: Tags.punctuation),
    content: Matcher.options([
      Matcher.select(
        _identifier,
        (match) => _propertyAttributes[match[0]] ?? _names,
      ),
      ..._matchers,
    ]),
  );

  static final Map<String, Matcher> _propertyAttributes = _keywords([
    'assign',
    'atomic',
    'class',
    'copy',
    'direct',
    'getter',
    'nonatomic',
    'null_resettable',
    'readonly',
    'readwrite',
    'retain',
    'setter',
    'strong',
    'unsafe_unretained',
    'weak',
  ], Tags.modifierKeyword);

  /// Scans a complete identifier once and dispatches on its full text.
  static final Matcher _names = Matcher.select(
    _identifier,
    (match) => _knownNames[match[0]] ?? _ordinaryName,
  );

  static final Matcher _ordinaryName = Matcher.options([
    // A class or protocol name after a declaration directive,
    // so `Person` isn't a function in
    // `@interface Person ()` or `@implementation Person (Helpers)`.
    Matcher.regex(
      '(?<=@(?:class|implementation|interface|protocol)\\s+)$_identifier',
      tag: Tags.type,
    ),
    Matcher.regex('$_identifier(?=\\s*\\()', tag: Tags.function),
    Matcher.regex(
      r'[A-Z][A-Z0-9_]+\b',
      tag: const Tag('constant', parent: Tags.specialIdentifier),
    ),
    Matcher.regex(r'[A-Z]\w*', tag: Tags.type),
    Matcher.regex(
      r'_[a-zA-Z]\w*',
      tag: const Tag('ivar', parent: Tags.property),
    ),
    Matcher.regex(_identifier, tag: Tags.identifier),
  ]);

  static final Map<String, Matcher> _knownNames = {
    ..._keywords([
      'break',
      'case',
      'continue',
      'default',
      'do',
      'else',
      'for',
      'goto',
      'if',
      'return',
      'switch',
      'while',
    ], Tags.controlKeyword),
    ..._keywords([
      'enum',
      'struct',
      'typedef',
      'union',
    ], Tags.declarationKeyword),
    ..._keywords([
      '__autoreleasing',
      '__block',
      '__bridge',
      '__bridge_retained',
      '__bridge_transfer',
      '__kindof',
      '__strong',
      '__unsafe_unretained',
      '__weak',
      '_Nonnull',
      '_Null_unspecified',
      '_Nullable',
      'auto',
      'const',
      'extern',
      'inline',
      'nonnull',
      'null_unspecified',
      'nullable',
      'register',
      'restrict',
      'static',
      'volatile',
    ], Tags.modifierKeyword),
    ..._keywords([
      '__typeof',
      '__typeof__',
      'in',
      'self',
      'sizeof',
      'super',
      'typeof',
      // C11 keywords, which would otherwise be mistaken for ivars.
      '_Alignas',
      '_Alignof',
      '_Atomic',
      '_Bool',
      '_Complex',
      '_Generic',
      '_Imaginary',
      '_Noreturn',
      '_Static_assert',
      '_Thread_local',
    ], Tags.keyword),
    for (final (names, tag) in const [
      (['YES', 'TRUE', 'true'], Tags.trueLiteral),
      (['NO', 'FALSE', 'false'], Tags.falseLiteral),
      (['nil', 'Nil', 'NULL'], Tags.nullLiteral),
      (_builtInTypes, Tags.builtInType),
    ])
      for (final name in names) name: Matcher.verbatim(name, tag: tag),
  };

  static const List<String> _builtInTypes = [
    // C types.
    'char',
    'double',
    'float',
    'int',
    'long',
    'short',
    'signed',
    'unsigned',
    'void',
    // Objective-C types.
    'BOOL',
    'Class',
    'IMP',
    'Protocol',
    'SEL',
    'id',
    'instancetype',
    // Foundation types.
    'CGFloat',
    'NSArray',
    'NSAttributedString',
    'NSData',
    'NSDate',
    'NSDictionary',
    'NSError',
    'NSException',
    'NSInteger',
    'NSMutableArray',
    'NSMutableDictionary',
    'NSMutableSet',
    'NSMutableString',
    'NSNumber',
    'NSObject',
    'NSRange',
    'NSSet',
    'NSString',
    'NSTimeInterval',
    'NSUInteger',
    'NSURL',
    'NSValue',
  ];

  static final Matcher _numbers = Matcher.options([
    Matcher.regex(
      r'(?:\d+\.\d*|\.\d+)(?:[eE][+-]?\d+)?[fFlL]?|\d+[eE][+-]?\d+[fFlL]?',
      tag: Tags.floatLiteral,
    ),
    Matcher.regex(
      r'(?:0[xX][0-9a-fA-F]+|0[bB][01]+|\d+)[uUlL]*',
      tag: Tags.integerLiteral,
    ),
  ]);

  /// A `/` that begins a `//` or `/*` comment is left to [_comments].
  static final Matcher _operators = Matcher.regex(
    r'<<=?|>>=?|\+\+|--|&&|\|\||->|\.\.\.|\?:|/(?![/*])=?|'
    r'[+\-*%&|^<>=!]=?|[~?:]',
    tag: Tags.operator,
  );

  /// Matches each of [words], after [prefix], with a child tag of [parent].
  static Map<String, Matcher> _keywords(
    List<String> words,
    Tag parent, {
    String prefix = '',
  }) => {
    for (final word in words)
      '$prefix$word': Matcher.verbatim(
        '$prefix$word',
        tag: Tag(word, parent: parent),
      ),
  };
}
