import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

@internal
final class ObjectiveCGrammar extends MatcherGrammar {
  const ObjectiveCGrammar();

  @override
  List<Matcher> get matchers => [
    Matcher.include(_preprocessor),
    Matcher.include(_comments),
    Matcher.include(_strings),
    Matcher.include(_atDirectives),
    Matcher.include(_keywords),
    Matcher.include(_literals),
    Matcher.include(_types),
    Matcher.include(_functions),
    Matcher.include(_operators),
    Matcher.include(_identifiers),
  ];

  Matcher _preprocessor() => Matcher.capture(
    r'^(#)(import|include|define|undef|if|ifdef|ifndef|elif|else|endif|'
    r'pragma|error|warning|line)\b(.*)$',
    captures: [
      Tags.punctuation,
      const Tag('name', parent: Tags.preprocessorDirective),
      const Tag('options', parent: Tags.preprocessorDirective),
    ],
    tag: Tags.preprocessorDirective,
  );

  Matcher _comments() => Matcher.options([
    Matcher.regex(r'///.*$', tag: Tags.docComment),
    Matcher.regex(r'//.*$', tag: Tags.lineComment),
    Matcher.verbatim(r'/**/', tag: Tags.docComment),
    Matcher.wrapped(
      begin: Matcher.verbatim(
        '/**',
        tag: const Tag('begin', parent: Tags.docComment),
      ),
      end: Matcher.verbatim(
        '*/',
        tag: const Tag('end', parent: Tags.docComment),
      ),
      content: Matcher.regex(
        r'.+?(?=\*/|$)',
        tag: const Tag('content', parent: Tags.docComment),
      ),
      tag: Tags.docComment,
    ),
    Matcher.verbatim(r'/**/', tag: Tags.blockComment),
    Matcher.wrapped(
      begin: Matcher.verbatim(
        '/*',
        tag: const Tag('begin', parent: Tags.blockComment),
      ),
      end: Matcher.verbatim(
        '*/',
        tag: const Tag('end', parent: Tags.blockComment),
      ),
      content: Matcher.regex(
        r'.+?(?=\*/|$)',
        tag: const Tag('content', parent: Tags.blockComment),
      ),
      tag: Tags.blockComment,
    ),
  ]);

  Matcher _strings() => Matcher.options([
    Matcher.include(_objcString),
    Matcher.include(_cString),
    Matcher.include(_characterLiteral),
  ]);

  Matcher _objcString() => Matcher.wrapped(
    begin: Matcher.regex(
      r'@"',
      tag: const Tag('begin', parent: Tags.doubleQuoteString),
    ),
    end: Matcher.verbatim(
      '"',
      tag: const Tag('end', parent: Tags.doubleQuoteString),
    ),
    content: Matcher.options([
      Matcher.regex(r"""\\[nrtbf"'\\]""", tag: Tags.stringEscape),
      Matcher.regex(r'\\[0-7]{1,3}', tag: Tags.stringEscape),
      Matcher.regex(r'\\x[0-9a-fA-F]{2}', tag: Tags.stringEscape),
      Matcher.regex(r'\\u[0-9a-fA-F]{4}', tag: Tags.stringEscape),
      Matcher.regex(
        r'[^"\\]+',
        tag: Tags.stringContent,
      ),
    ], tag: Tags.stringContent),
    tag: Tags.doubleQuoteString,
  );

  Matcher _cString() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '"',
      tag: const Tag('begin', parent: Tags.doubleQuoteString),
    ),
    end: Matcher.verbatim(
      '"',
      tag: const Tag('end', parent: Tags.doubleQuoteString),
    ),
    content: Matcher.options([
      Matcher.regex(r"""\\[nrtbf"'\\]""", tag: Tags.stringEscape),
      Matcher.regex(r'\\[0-7]{1,3}', tag: Tags.stringEscape),
      Matcher.regex(r'\\x[0-9a-fA-F]{2}', tag: Tags.stringEscape),
      Matcher.regex(
        r'[^"\\]+',
        tag: Tags.stringContent,
      ),
    ], tag: Tags.stringContent),
    tag: Tags.doubleQuoteString,
  );

  Matcher _characterLiteral() => Matcher.wrapped(
    begin: Matcher.verbatim(
      "'",
      tag: const Tag('begin', parent: Tags.characterLiteral),
    ),
    end: Matcher.verbatim(
      "'",
      tag: const Tag('end', parent: Tags.characterLiteral),
    ),
    content: Matcher.options([
      Matcher.regex(r"""\\[nrtbf"'\\]""", tag: Tags.stringEscape),
      Matcher.regex(r'\\[0-7]{1,3}', tag: Tags.stringEscape),
      Matcher.regex(r'\\x[0-9a-fA-F]{2}', tag: Tags.stringEscape),
      Matcher.regex(
        r"[^'\\]",
        tag: Tags.stringContent,
      ),
    ], tag: Tags.stringContent),
    tag: Tags.characterLiteral,
  );

  Matcher _atDirectives() => Matcher.options([
    Matcher.keywords(
      [
        '@autoreleasepool',
        '@catch',
        '@class',
        '@dynamic',
        '@encode',
        '@end',
        '@finally',
        '@implementation',
        '@interface',
        '@optional',
        '@package',
        '@private',
        '@property',
        '@protected',
        '@protocol',
        '@public',
        '@required',
        '@selector',
        '@synchronized',
        '@synthesize',
        '@throw',
        '@try',
      ],
      baseTag: Tags.keyword,
    ),
    Matcher.regex(
      r'@(YES|NO|TRUE|FALSE|available)\b',
      tag: Tags.annotation,
    ),
    Matcher.regex(r'@\(', tag: Tags.operator),
    Matcher.regex(r'@\[', tag: Tags.operator),
    Matcher.regex(r'@\{', tag: Tags.operator),
    Matcher.regex(r'@[a-zA-Z_][a-zA-Z0-9_]*', tag: Tags.annotation),
  ]);

  Matcher _keywords() => Matcher.options([
    Matcher.include(_controlKeywords),
    Matcher.include(_declarationKeywords),
    Matcher.include(_modifierKeywords),
    Matcher.include(_typeQualifiers),
    Matcher.include(_otherKeywords),
  ]);

  Matcher _controlKeywords() => Matcher.keywords(
    [
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
    ],
    baseTag: Tags.controlKeyword,
  );

  Matcher _declarationKeywords() => Matcher.keywords(
    [
      'enum',
      'struct',
      'typedef',
      'union',
    ],
    baseTag: Tags.declarationKeyword,
  );

  Matcher _modifierKeywords() => Matcher.keywords(
    [
      'auto',
      'const',
      'extern',
      'inline',
      'register',
      'restrict',
      'static',
      'volatile',
    ],
    baseTag: Tags.modifierKeyword,
  );

  Matcher _typeQualifiers() => Matcher.keywords(
    [
      '__autoreleasing',
      '__block',
      '__bridge',
      '__bridge_retained',
      '__bridge_transfer',
      '__strong',
      '__unsafe_unretained',
      '__weak',
      '_Nonnull',
      '_Null_unspecified',
      '_Nullable',
      'assign',
      'atomic',
      'copy',
      'getter',
      'nonatomic',
      'nonnull',
      'nullable',
      'readwrite',
      'readonly',
      'retain',
      'setter',
      'strong',
      'weak',
    ],
    baseTag: Tags.modifierKeyword,
  );

  Matcher _otherKeywords() => Matcher.keywords(
    [
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
      'in',
      'inout',
      'oneway',
      'out',
      'self',
      'sizeof',
      'super',
      'typeof',
    ],
    baseTag: Tags.keyword,
  );

  Matcher _literals() => Matcher.options([
    Matcher.include(_booleanLiterals),
    Matcher.include(_nilLiterals),
    Matcher.include(_numberLiterals),
  ]);

  Matcher _booleanLiterals() => Matcher.options([
    Matcher.regex(r'\b(YES|TRUE|true)\b', tag: Tags.trueLiteral),
    Matcher.regex(r'\b(NO|FALSE|false)\b', tag: Tags.falseLiteral),
  ]);

  Matcher _nilLiterals() => Matcher.options([
    Matcher.regex(r'\bnil\b', tag: Tags.nullLiteral),
    Matcher.regex(r'\bNil\b', tag: Tags.nullLiteral),
    Matcher.regex(r'\bNULL\b', tag: Tags.nullLiteral),
  ]);

  Matcher _numberLiterals() => Matcher.options([
    Matcher.regex(
      r'\b0[xX][0-9a-fA-F]+[uUlL]*\b',
      tag: Tags.integerLiteral,
    ),
    Matcher.regex(r'\b0[0-7]+[uUlL]*\b', tag: Tags.integerLiteral),
    Matcher.regex(
      r'\b\d+\.?\d*[eE][+-]?\d+[fFlL]?\b',
      tag: Tags.floatLiteral,
    ),
    Matcher.regex(
      r'\b\d+\.\d+[fFlL]?\b',
      tag: Tags.floatLiteral,
    ),
    Matcher.regex(r'\b\d+[fF]\b', tag: Tags.floatLiteral),
    Matcher.regex(r'\b\d+[uUlL]*\b', tag: Tags.integerLiteral),
  ]);

  Matcher _types() => Matcher.options([
    Matcher.include(_cTypes),
    Matcher.include(_objcTypes),
    Matcher.include(_foundationTypes),
    Matcher.include(_typeIdentifiers),
  ]);

  Matcher _cTypes() => Matcher.builtInTypes([
    'char',
    'double',
    'float',
    'int',
    'long',
    'short',
    'signed',
    'unsigned',
    'void',
  ]);

  Matcher _objcTypes() => Matcher.builtInTypes([
    'BOOL',
    'Block',
    'Class',
    'IMP',
    'Protocol',
    'SEL',
    'id',
    'instancetype',
  ]);

  Matcher _foundationTypes() => Matcher.builtInTypes([
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
    'UIColor',
    'UIImage',
    'UIView',
    'UIViewController',
  ]);

  Matcher _typeIdentifiers() =>
      Matcher.regex(r'\b[A-Z][a-zA-Z0-9_]*\b', tag: Tags.type);

  Matcher _functions() => Matcher.regex(
    r'\b[a-zA-Z_][a-zA-Z0-9_]*(?=\s*\()',
    tag: Tags.function,
  );

  Matcher _operators() => Matcher.options([
    Matcher.regex(
      r'\+\+|--|<<|>>|<=|>=|==|!=|&&|\|\||->|\.\.\.',
      tag: Tags.operator,
    ),
    Matcher.regex(r'\^(?![{(])', tag: Tags.operator),
    Matcher.regex(r'[+\-*/%&|~<>=!?:]', tag: Tags.operator),
    Matcher.regex(r'[{}()\[\],;]', tag: Tags.punctuation),
    Matcher.regex(r'\.', tag: Tags.accessor),
  ]);

  Matcher _identifiers() => Matcher.options([
    Matcher.regex(
      r'\b[A-Z][A-Z0-9_]+\b',
      tag: const Tag('constant', parent: Tags.specialIdentifier),
    ),
    Matcher.regex(
      r'\b_[a-zA-Z][a-zA-Z0-9_]*\b',
      tag: const Tag('ivar', parent: Tags.property),
    ),
    Matcher.regex(r'\b[a-z_][a-zA-Z0-9_]*\b', tag: Tags.identifier),
  ]);
}
