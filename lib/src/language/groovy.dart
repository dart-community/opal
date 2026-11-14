import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

/// Lexical highlighting for Groovy, including Gradle build scripts,
/// Spock specifications, and the contextual keywords added through Groovy 6.
///
/// Favors simple, local rules over full accuracy:
/// names are classified by their casing and the tokens right next to them.
@internal
final class GroovyGrammar extends MatcherGrammar {
  const GroovyGrammar();

  static const String _identifierStart = r'[\p{L}_$]';
  static const String _identifierPart = r'[\p{L}\p{Nd}_$]';
  static const String _identifier = '$_identifierStart$_identifierPart*';
  static const String _rightBoundary = '(?!$_identifierPart)';

  /// A name that can be interpolated without braces, such as in `"$user"`.
  static const String _interpolatedName = r'[\p{L}_][\p{L}\p{Nd}_]*';

  @override
  List<Matcher> get matchers => _matchers;

  static final List<Matcher> _matchers = [
    Matcher.regex(r'\s+', tag: Tags.whitespace),
    // Match strings before names, since the `$` of `$/` can start a name.
    _strings,
    _names,
    _comments,
    _operators,
    _numbers,
    _annotations,
  ];

  /// Whitespace is matched explicitly by [matchers],
  /// so disable the default trailing whitespace rule on [Matcher.options].
  @override
  List<Matcher> get postAppliedMatchers => const [];

  static final Matcher _comments = Matcher.options([
    Matcher.regex(r'^#!.*', tag: Tags.lineComment),
    // Four or more slashes, such as `////`, form a regular line comment.
    Matcher.regex(r'///(?!/).*', tag: Tags.docComment),
    Matcher.regex(r'//.*', tag: Tags.lineComment),
    // Exclude `/**/` and `/***`, which are regular block comments.
    _blockComment(r'/\*\*(?![*/])', Tags.docComment),
    _blockComment(r'/\*', Tags.blockComment),
  ]);

  static Matcher _blockComment(String opener, Tag tag) => Matcher.wrapped(
    begin: Matcher.regex(opener, tag: Tag('begin', parent: tag)),
    end: Matcher.verbatim('*/', tag: Tag('end', parent: tag)),
    content: Matcher.options([
      if (tag == Tags.docComment)
        // A block tag, such as `@param`, or an inline tag, such as `{@link`.
        Matcher.regex(r'(?<=^[\s*]*|\{)@[a-zA-Z]+', tag: Tags.annotation),
      Matcher.regex(r'(?:[^*@]|\*(?!/))+|@', tag: Tag('content', parent: tag)),
    ]),
    tag: tag,
  );

  /// String literals, with longer opening delimiters first.
  static final Matcher _strings = Matcher.options([
    _string(r'$/', Tags.regexpLiteral),
    _string("'''", Tags.tripleQuoteString),
    _string('"""', Tags.tripleQuoteString),
    _string("'", Tags.singleQuoteString),
    _string('"', Tags.doubleQuoteString),
    // A `/` opens a slashy string, such as in `text =~ /\d+/`,
    // rather than dividing, if it doesn't follow an operand
    // and is closed on the same line.
    _string(
      '/',
      Tags.regexpLiteral,
      after:
          '(?<!(?:$_identifierPart|[)\\]}\'"])\\s*/)(?![/*=\\s])'
          r'(?=(?:[^/\\]|\\.)*/)',
    ),
  ]);

  /// A string that starts with [opener], if followed by [after].
  static Matcher _string(String opener, Tag tag, {String after = ''}) {
    final dollarSlashy = opener == r'$/';
    final closer = dollarSlashy ? r'/$' : opener;
    // Slashy strings can span lines, but only single-line ones are matched.
    final multiline = opener.length > 1;
    final interpolated = !opener.startsWith("'");

    return Matcher.wrapped(
      begin: Matcher.regex(
        '${RegExp.escape(opener)}$after',
        tag: Tag('begin', parent: tag),
      ),
      // A single-line string that is never closed ends with its line.
      end: Matcher.regex(
        '${RegExp.escape(closer)}${multiline ? '' : r'|$'}',
        tag: Tag('end', parent: tag),
      ),
      content: Matcher.options([
        Matcher.regex(
          dollarSlashy ? r'\$[$/]' : r'\\(?:u[\da-fA-F]{4}|.)',
          tag: Tags.stringEscape,
        ),
        if (interpolated) ...[
          Matcher.wrapped(
            begin: Matcher.verbatim(
              r'${',
              tag: const Tag('begin', parent: Tags.stringInterpolation),
            ),
            // Recover at the end of the line if a
            // single-line string's interpolation is never closed.
            end: Matcher.regex(
              multiline ? r'\}' : r'\}|$',
              tag: const Tag('end', parent: Tags.stringInterpolation),
            ),
            content: _expression,
            tag: Tags.stringInterpolation,
          ),
          Matcher.regex(
            '\\\$$_interpolatedName(?:\\.$_interpolatedName)*',
            tag: Tags.stringInterpolation,
          ),
        ],
        // Plain text, or a lone delimiter character such as `$`.
        Matcher.regex('[^${closer[0]}\\\\\$]+|.', tag: Tags.stringContent),
      ]),
      tag: tag,
    );
  }

  /// An expression that balances `{}` blocks so that the `}` of a closure,
  /// such as in `"${names.collect { it.trim() }}"`,
  /// doesn't end an enclosing interpolation.
  static final Matcher _expression = Matcher.include(
    () => Matcher.options([
      Matcher.wrapped(
        begin: Matcher.verbatim('{', tag: Tags.punctuation),
        end: Matcher.verbatim('}', tag: Tags.punctuation),
        content: _expression,
      ),
      ..._matchers,
    ]),
  );

  static const String _digits = r'\d[\d_]*';
  static const String _exponent = '[eE][+-]?$_digits';

  static final Matcher _numbers = Matcher.options([
    Matcher.regex(
      '$_digits(?:\\.$_digits(?:$_exponent)?[fFdDgG]?|$_exponent[fFdDgG]?|'
      '[fFdD])$_rightBoundary',
      tag: Tags.floatLiteral,
    ),
    Matcher.regex(
      '(?:0[xX][\\da-fA-F_]+|0[bB][01_]+|$_digits)[iIlLgG]?$_rightBoundary',
      tag: Tags.integerLiteral,
    ),
    // Consume a malformed number, such as `0x` or `12abc`, as one token
    // so its trailing characters aren't highlighted as an identifier.
    Matcher.regex('\\d$_identifierPart*', tag: Tags.numberLiteral),
  ]);

  static final Matcher _annotations = Matcher.options([
    Matcher.regex(
      '@interface$_rightBoundary',
      tag: const Tag('interface', parent: Tags.declarationKeyword),
    ),
    Matcher.regex('@$_identifier(?:\\.$_identifier)*', tag: Tags.annotation),
  ]);

  static final Matcher _operators = Matcher.options([
    // Require surrounding whitespace or a line boundary to
    // distinguish relational and shift operators,
    // such as in `a < b` or `list << item`, from `List<T>`.
    Matcher.regex(
      r'(?<=^|\s)(?:<<|>>>?|[<>])=?(?=\s|$)',
      tag: Tags.operator,
    ),
    Matcher.regex(
      r'<\.\.<?|\.\.[.<]?|\*\*=?|===|!==|==>|==~|==|!=|=~|<=>|<=|>=|'
      r'&&|\|\||\+\+|--|->|\?[:=]|[-+*/%&|^]=',
      tag: Tags.operator,
    ),
    // Member access, such as `.`, `?.`, `*.`, `.&`, `.@`, or `::`.
    Matcher.regex(r'[?*]?\.[&@]?|::', tag: Tags.accessor),
    Matcher.regex(r'[-+*/%&|^~!=?]', tag: Tags.operator),
    Matcher.regex(r'[:,]', tag: Tags.separator),
    Matcher.regex(r'[{}()\[\]<>;]', tag: Tags.punctuation),
  ]);

  /// Scans a complete identifier once and dispatches on its full text.
  static final Matcher _names = Matcher.options([
    // After a `.`, a lowercase keyword is a member name,
    // such as `in` in `System.in`,
    // whereas `URL` in `java.net.URL` is still a type.
    Matcher.select(
      '(?:(?<!\\.)|(?=\\p{Lu}))(?:non-sealed$_rightBoundary|$_identifier)',
      (match) => _knownNames[match[0]] ?? _ordinaryName,
    ),
    // A member name, or a contextual keyword outside of its context.
    _ordinaryName,
  ]);

  /// Keywords that can follow an operand,
  /// such as `in` in `item in items` or `else` in `if (ok) YES else NO`,
  /// and so don't start a new operand.
  static const String _notInfixKeyword = r'(?!(?:as|else|in|instanceof)\b)';

  /// Lookahead for the start of a declared name or an expression after
  /// a contextual keyword or command name,
  /// such as in `var total`, `val (x, y)`, or `await task`,
  /// unlike in `println var` or `yield()`.
  static const String _beforeOperand =
      '(?=\\s+(?:$_notInfixKeyword$_identifierStart|[\\d(\\[{\'"]))';

  static final Matcher _ordinaryName = Matcher.options([
    Matcher.regex(
      // A jump target, such as `outer` in `break outer`.
      '(?<=\\b(?:break|continue)\\s+)$_identifier|'
      // A statement label before a loop or at the end of its line,
      // excluding `name: value` entries in maps and named arguments.
      '(?<=^\\s*)$_identifier(?=:\\s*(?:\$|(?:do|for|while)\\b))|'
      // A Spock block label, such as `given:` or `when: "described"`.
      r'(?<=^\s*)(?:and|cleanup|expect|given|setup|then|when|where)'
      r'(?=:(?!:))',
      tag: Tags.label,
    ),
    // An all-caps name is a constant,
    // such as `MAX_SIZE`, unless a type is expected,
    // such as `DTO` in `new DTO()` or `DTO result`.
    Matcher.regex(
      '(?<!\\b(?:as|class|enum|extends|implements|instanceof|interface|new|'
      'record|trait)\\s+)\\p{Lu}[\\p{Lu}\\p{Nd}_]+$_rightBoundary'
      '(?!\\s+$_notInfixKeyword$_identifierStart)',
      tag: const Tag('constant', parent: Tags.specialIdentifier),
    ),
    Matcher.regex('\\p{Lu}$_identifierPart*', tag: Tags.type),
    Matcher.regex(
      // A call with arguments or a trailing closure, such as `tasks { }`.
      '$_identifier(?=\\(|\\s*\\{)|'
      // A method reference, such as `trim` in `text.&trim`.
      '(?<=\\.&|::)$_identifier|'
      // A command call that starts a statement or closure body,
      // such as `println` in `println name` or `id` in `id 'groovy'`.
      '(?<=(?:^|[{;]|->)\\s*(?:$_identifier\\.)*)$_identifier$_beforeOperand',
      tag: Tags.function,
    ),
    Matcher.regex(_identifier, tag: Tags.identifier),
  ]);

  static final Map<String, Matcher> _knownNames = {
    ..._keywords([
      'assert',
      'break',
      'case',
      'catch',
      'continue',
      'default',
      'do',
      'else',
      'finally',
      'for',
      'if',
      'return',
      'switch',
      'throw',
      'throws',
      'try',
      'while',
    ], Tags.controlKeyword),
    ..._keywords([
      'class',
      'def',
      'enum',
      'extends',
      'implements',
      'import',
      'interface',
      'package',
    ], Tags.declarationKeyword),
    ..._keywords([
      'abstract',
      'final',
      'native',
      'non-sealed',
      'permits',
      'private',
      'protected',
      'public',
      'sealed',
      'static',
      'synchronized',
      'transient',
      'volatile',
    ], Tags.modifierKeyword),
    ..._keywords(['as', 'in', 'instanceof', 'new'], Tags.keyword),
    for (final type in _builtInTypes)
      type: Matcher.verbatim(type, tag: Tags.builtInType),
    'this': Matcher.verbatim('this', tag: Tags.specialIdentifier),
    'super': Matcher.verbatim('super', tag: Tags.specialIdentifier),
    'true': Matcher.verbatim('true', tag: Tags.trueLiteral),
    'false': Matcher.verbatim('false', tag: Tags.falseLiteral),
    'null': Matcher.verbatim('null', tag: Tags.nullLiteral),

    // Contextual keywords, which remain valid identifiers elsewhere.
    ..._keywords(
      ['record', 'trait', 'val', 'var'],
      Tags.declarationKeyword,
      after: _beforeOperand,
    ),
    // Also match before a generic method, such as `async <T> T load()`.
    ..._keywords(
      ['async'],
      Tags.modifierKeyword,
      after: '(?:$_beforeOperand|(?=\\s+<))',
    ),
    ..._keywords(
      ['await', 'defer', 'yield'],
      Tags.controlKeyword,
      after: _beforeOperand,
    ),
  };

  /// Primitive types and the most common types that are always available.
  static const List<String> _builtInTypes = [
    'boolean',
    'byte',
    'char',
    'double',
    'float',
    'int',
    'long',
    'short',
    'void',
    'BigDecimal',
    'BigInteger',
    'Boolean',
    'Byte',
    'Character',
    'Class',
    'Closure',
    'Collection',
    'Double',
    'Exception',
    'Float',
    'Integer',
    'Iterable',
    'List',
    'Long',
    'Map',
    'Number',
    'Object',
    'Optional',
    'Set',
    'Short',
    'String',
    'StringBuilder',
    'System',
    'Thread',
    'Throwable',
    'URI',
    'URL',
    'UUID',
    'Void',
  ];

  /// Matches each of [words] with a child tag of [parent],
  /// unconditionally or only before the [after] lookahead.
  static Map<String, Matcher> _keywords(
    List<String> words,
    Tag parent, {
    String after = '',
  }) => {
    for (final word in words)
      word: Matcher.regex('$word$after', tag: Tag(word, parent: parent)),
  };
}
