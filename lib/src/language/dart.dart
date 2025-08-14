import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

@internal
final class DartGrammar extends MatcherGrammar {
  const DartGrammar();

  @override
  List<Matcher> get matchers => [
    Matcher.include(_comments),
    Matcher.include(_strings),
    Matcher.include(_keywords),
    Matcher.include(_literals),
    Matcher.include(_annotations),
    Matcher.include(_types),
    Matcher.include(_functions),
    Matcher.include(_operators),
    Matcher.include(_identifiers),
  ];

  Matcher _comments() => Matcher.options([
    Matcher.regex(r'///.*$', tag: Tags.lineComment),
    Matcher.regex(r'//.*$', tag: Tags.lineComment),
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
        r'.+?(?=\*\/|$)',
        tag: const Tag('content', parent: Tags.blockComment),
      ),
      tag: Tags.blockComment,
    ),
  ]);

  Matcher _strings() => Matcher.options([
    Matcher.include(_rawString),
    Matcher.include(_interpolatedString),
    Matcher.include(_tripleQuotedString),
    Matcher.include(_singleQuotedString),
    Matcher.include(_doubleQuotedString),
  ]);

  Matcher _rawString() => Matcher.options([
    Matcher.regex(r"r'[^']*'", tag: Tags.stringLiteral),
    Matcher.regex(r'r"[^"]*"', tag: Tags.stringLiteral),
    Matcher.regex(r"r'''[\s\S]*?'''", tag: Tags.stringLiteral),
    Matcher.regex(r'r"""[\s\S]*?"""', tag: Tags.stringLiteral),
  ]);

  Matcher _interpolatedString() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '"',
      tag: const Tag('begin', parent: Tags.stringLiteral),
    ),
    end: Matcher.verbatim(
      '"',
      tag: const Tag('end', parent: Tags.stringLiteral),
    ),
    content: Matcher.options([
      Matcher.regex(r'\$\{[^}]*\}', tag: Tags.stringInterpolation),
      Matcher.regex(r'\$\w+', tag: Tags.stringInterpolation),
      Matcher.regex(r"""\\[nrtbf"'\\]""", tag: Tags.stringEscape),
      Matcher.regex(r'\\u[0-9a-fA-F]{4}', tag: Tags.stringEscape),
      Matcher.regex(r'\\x[0-9a-fA-F]{2}', tag: Tags.stringEscape),
      Matcher.regex(
        r'[^"\\$]+',
      ),
    ], tag: Tags.stringContent),
    tag: Tags.stringLiteral,
  );

  Matcher _tripleQuotedString() => Matcher.options([
    Matcher.regex(r"'''[\s\S]*?'''", tag: Tags.stringLiteral),
    Matcher.regex(r'"""[\s\S]*?"""', tag: Tags.stringLiteral),
  ]);

  Matcher _singleQuotedString() => Matcher.wrapped(
    begin: Matcher.verbatim(
      "'",
      tag: const Tag('begin', parent: Tags.stringLiteral),
    ),
    end: Matcher.verbatim(
      "'",
      tag: const Tag('end', parent: Tags.stringLiteral),
    ),
    content: Matcher.options([
      Matcher.regex(r"""\\[nrtbf"'\\]""", tag: Tags.stringEscape),
      Matcher.regex(r'\\u[0-9a-fA-F]{4}', tag: Tags.stringEscape),
      Matcher.regex(r'\\x[0-9a-fA-F]{2}', tag: Tags.stringEscape),
      Matcher.regex(
        r"[^'\\]+",
      ),
    ], tag: Tags.stringContent),
    tag: Tags.stringLiteral,
  );

  Matcher _doubleQuotedString() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '"',
      tag: const Tag('begin', parent: Tags.stringLiteral),
    ),
    end: Matcher.verbatim(
      '"',
      tag: const Tag('end', parent: Tags.stringLiteral),
    ),
    content: Matcher.options([
      Matcher.regex(r"""\\[Match.include("'\\]""", tag: Tags.stringEscape),
      Matcher.regex(r'\\u[0-9a-fA-F]{4}', tag: Tags.stringEscape),
      Matcher.regex(r'\\x[0-9a-fA-F]{2}', tag: Tags.stringEscape),
      Matcher.regex(
        r'[^"\\]+',
      ),
    ], tag: Tags.stringContent),
    tag: Tags.stringLiteral,
  );

  Matcher _keywords() => Matcher.options([
    Matcher.include(_controlKeywords),
    Matcher.include(_declarationKeywords),
    Matcher.include(_modifierKeywords),
    Matcher.include(_asyncKeywords),
    Matcher.include(_exceptionKeywords),
    Matcher.include(_otherKeywords),
  ]);

  Matcher _controlKeywords() => Matcher.keywords([
    'assert',
    'break',
    'case',
    'continue',
    'default',
    'do',
    'else',
    'for',
    'if',
    'return',
    'switch',
    'when',
    'while',
  ]);

  Matcher _declarationKeywords() => Matcher.keywords([
    'as',
    'class',
    'deferred',
    'enum',
    'export',
    'extension',
    'hide',
    'import',
    'library',
    'mixin',
    'part',
    'show',
    'typedef',
    'var',
  ]);

  Matcher _modifierKeywords() => Matcher.keywords([
    'abstract',
    'base',
    'const',
    'covariant',
    'external',
    'factory',
    'final',
    'get',
    'interface',
    'late',
    'operator',
    'required',
    'sealed',
    'set',
    'static',
  ]);

  Matcher _asyncKeywords() => Matcher.keywords([
    'async',
    'await',
    'sync',
    'yield',
  ]);

  Matcher _exceptionKeywords() => Matcher.keywords([
    'try',
    'catch',
    'finally',
    'throw',
    'rethrow',
    'on',
  ]);

  Matcher _otherKeywords() => Matcher.keywords([
    'in',
    'is',
    'new',
    'super',
    'this',
    'with',
  ]);

  Matcher _literals() => Matcher.options([
    Matcher.include(_booleanLiterals),
    Matcher.include(_nullLiteral),
    Matcher.include(_numberLiterals),
    Matcher.include(_symbolLiterals),
  ]);

  Matcher _booleanLiterals() => Matcher.options([
    Matcher.regex(r'\btrue\b', tag: Tags.trueLiteral),
    Matcher.regex(r'\bfalse\b', tag: Tags.falseLiteral),
  ]);

  Matcher _nullLiteral() => Matcher.regex(r'\bnull\b', tag: Tags.nullLiteral);

  Matcher _numberLiterals() => Matcher.options([
    Matcher.regex(r'\b0x[0-9a-fA-F_]+\b', tag: Tags.numberLiteral),
    Matcher.regex(
      r'\b\d[\d_]*\.\d[\d_]*([eE][+-]?\d[\d_]*)?\b',
      tag: Tags.numberLiteral,
    ),
    Matcher.regex(r'\b\d[\d_]*([eE][+-]?\d[\d_]*)?\b', tag: Tags.numberLiteral),
  ]);

  Matcher _symbolLiterals() => Matcher.regex(
    r'#[a-zA-Z_][a-zA-Z0-9_]*(?:\.[a-zA-Z_][a-zA-Z0-9_]*)*',
    tag: const Tag('symbol', parent: Tags.literal),
  );

  Matcher _annotations() => Matcher.regex(r'@\w+', tag: Tags.annotation);

  Matcher _types() => Matcher.options([
    Matcher.include(_builtInTypes),
    Matcher.include(_typeIdentifiers),
  ]);

  Matcher _builtInTypes() => Matcher.builtInTypes([
    'Comparable',
    'DateTime',
    'Duration',
    'Enum',
    'Expando',
    'Function',
    'Future',
    'Iterable',
    'Iterator',
    'List',
    'Map',
    'MapEntry',
    'Never',
    'Null',
    'Object',
    'Record',
    'RegExp',
    'Set',
    'Stream',
    'String',
    'Symbol',
    'Type',
    'Uri',
    'bool',
    'double',
    'dynamic',
    'int',
    'num',
    'void',
  ]);

  Matcher _typeIdentifiers() =>
      Matcher.regex(r'\b[A-Z][a-zA-Z0-9_]*\b', tag: Tags.type);

  Matcher _functions() => Matcher.regex(
    r'\b[a-zA-Z_][a-zA-Z0-9_]*(?=\s*\()',
    tag: Tags.function,
  );

  Matcher _operators() => Matcher.options([
    Matcher.regex(
      r'\+\+|--|<<|>>|<=|>=|==|!=|&&|\|\||=>|\.\.',
      tag: Tags.operator,
    ),
    Matcher.regex(r'[+\-*/%&|^~=!?:]', tag: Tags.operator),
    Matcher.regex(r'[{}()\[\],.;<>]', tag: Tags.punctuation),
  ]);

  Matcher _identifiers() => Matcher.options([
    Matcher.regex(r'\b_[a-zA-Z0-9_]*\b', tag: Tags.specialIdentifier),
    Matcher.regex(r'\b[a-z][a-zA-Z0-9_]*\b', tag: Tags.identifier),
  ]);
}
