import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

@internal
final class JSGrammar extends MatcherGrammar {
  const JSGrammar();

  @override
  List<Matcher> get matchers => [
    Matcher.include(_comments),
    Matcher.include(_strings),
    Matcher.include(_keywords),
    Matcher.include(_literals),
    Matcher.include(_operators),
    Matcher.include(_identifiers),
  ];

  Matcher _comments() => Matcher.options([
    Matcher.regex(r'//.*$', tag: Tags.lineComment),
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
    Matcher.include(_templateLiteral),
    Matcher.include(_singleQuotedString),
    Matcher.include(_doubleQuotedString),
  ]);

  Matcher _templateLiteral() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '`',
      tag: const Tag('begin', parent: Tags.stringLiteral),
    ),
    end: Matcher.verbatim(
      '`',
      tag: const Tag('end', parent: Tags.stringLiteral),
    ),
    content: Matcher.options([
      Matcher.regex(r'\$\{[^}]*\}', tag: Tags.stringInterpolation),
      Matcher.regex(r"""\\[nrtbf"'\\]""", tag: Tags.stringEscape),
      Matcher.regex(r'\\u[0-9a-fA-F]{4}', tag: Tags.stringEscape),
      Matcher.regex(r'\\x[0-9a-fA-F]{2}', tag: Tags.stringEscape),
      Matcher.regex(
        r'[^`\\$]+',
      ),
    ], tag: Tags.stringContent),
    tag: Tags.stringLiteral,
  );

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
      Matcher.regex(r"""\\[nrtbf"'\\]""", tag: Tags.stringEscape),
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
    Matcher.include(_asyncKeywords),
    Matcher.include(_exceptionKeywords),
    Matcher.include(_otherKeywords),
  ]);

  Matcher _controlKeywords() => Matcher.keywords([
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
    'while',
  ]);

  Matcher _declarationKeywords() => Matcher.keywords([
    'class',
    'const',
    'export',
    'extends',
    'function',
    'import',
    'let',
    'var',
  ]);

  Matcher _asyncKeywords() => Matcher.keywords([
    'async',
    'await',
  ]);

  Matcher _exceptionKeywords() => Matcher.keywords([
    'catch',
    'finally',
    'throw',
    'try',
  ]);

  Matcher _otherKeywords() => Matcher.keywords([
    'debugger',
    'delete',
    'from',
    'get',
    'in',
    'instanceof',
    'new',
    'of',
    'set',
    'static',
    'super',
    'this',
    'typeof',
    'void',
    'with',
    'yield',
  ]);

  Matcher _literals() => Matcher.options([
    Matcher.include(_booleanLiterals),
    Matcher.include(_nullLiterals),
    Matcher.include(_numberLiterals),
    Matcher.include(_regexLiterals),
  ]);

  Matcher _booleanLiterals() => Matcher.options([
    Matcher.regex(r'\btrue\b', tag: Tags.trueLiteral),
    Matcher.regex(r'\bfalse\b', tag: Tags.falseLiteral),
  ]);

  Matcher _nullLiterals() => Matcher.options([
    Matcher.regex(r'\bnull\b', tag: Tags.nullLiteral),
    Matcher.regex(r'\bundefined\b', tag: Tags.nullLiteral),
  ]);

  Matcher _numberLiterals() => Matcher.options([
    Matcher.regex(r'\b0[xX][0-9a-fA-F_]+n?\b', tag: Tags.numberLiteral),
    Matcher.regex(r'\b0[bB][01_]+n?\b', tag: Tags.numberLiteral),
    Matcher.regex(r'\b0[oO][0-7_]+n?\b', tag: Tags.numberLiteral),
    Matcher.regex(
      r'\b\d[\d_]*\.?\d*([eE][+-]?\d[\d_]*)?n?\b',
      tag: Tags.numberLiteral,
    ),
    Matcher.regex(r'\bNaN\b', tag: Tags.numberLiteral),
    Matcher.regex(r'\bInfinity\b', tag: Tags.numberLiteral),
  ]);

  Matcher _regexLiterals() => Matcher.regex(
    r'/(?:[^/\\\n]|\\.)+/[gimsuvy]*',
    tag: const Tag('regex', parent: Tags.literal),
  );

  Matcher _operators() => Matcher.options([
    Matcher.regex(
      r'\+\+|--|<<|>>>|>>|<=|>=|===|!==|==|!=|&&|\|\||=>|\.\.\.|\.\.|\?\.|::|!!',
      tag: Tags.operator,
    ),
    Matcher.regex(r'[+\-*/%&|^~<>=!?:]', tag: Tags.operator),
    Matcher.regex(r'[{}()\[\],.;]', tag: Tags.punctuation),
  ]);

  Matcher _identifiers() => Matcher.options([
    Matcher.regex(r'\$[a-zA-Z_]\w*', tag: Tags.specialIdentifier),
    Matcher.regex(r'[a-zA-Z_]\w*', tag: Tags.identifier),
  ]);
}
