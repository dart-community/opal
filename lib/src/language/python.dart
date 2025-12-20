import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

@internal
final class PythonGrammar extends MatcherGrammar {
  const PythonGrammar();

  @override
  List<Matcher> get matchers => [
    Matcher.include(_comments),
    Matcher.include(_strings),
    Matcher.include(_keywords),
    Matcher.include(_literals),
    Matcher.include(_decorators),
    Matcher.include(_builtInFunctions),
    Matcher.include(_builtInTypes),
    Matcher.include(_operators),
    Matcher.include(_identifiers),
  ];

  Matcher _comments() => Matcher.regex(r'#.*$', tag: Tags.lineComment);

  Matcher _strings() => Matcher.options([
    Matcher.include(_fTripleDoubleQuotedString),
    Matcher.include(_fTripleSingleQuotedString),
    Matcher.include(_fDoubleQuotedString),
    Matcher.include(_fSingleQuotedString),
    Matcher.include(_tripleDoubleQuotedString),
    Matcher.include(_tripleSingleQuotedString),
    Matcher.include(_doubleQuotedString),
    Matcher.include(_singleQuotedString),
  ]);

  static const _nonFPrefixes = r'(?:[rR]|[uU]|[bB]|[bB][rR]|[rR][bB])?';
  static const _fPrefixes = r'(?:[fF]|[fF][rR]|[rR][fF])';

  Matcher _wrappedString({
    required String beginPattern,
    required String endLiteral,
    required Matcher content,
  }) => Matcher.wrapped(
    begin: Matcher.regex(
      beginPattern,
      tag: const Tag('begin', parent: Tags.stringLiteral),
    ),
    end: Matcher.verbatim(
      endLiteral,
      tag: const Tag('end', parent: Tags.stringLiteral),
    ),
    content: content,
    tag: Tags.stringLiteral,
  );

  Matcher _fTripleDoubleQuotedString() => _wrappedString(
    beginPattern: '$_fPrefixes"""',
    endLiteral: '"""',
    content: _fStringContent(delimiter: '"'),
  );

  Matcher _fTripleSingleQuotedString() => _wrappedString(
    beginPattern: "$_fPrefixes'''",
    endLiteral: "'''",
    content: _fStringContent(delimiter: "'"),
  );

  Matcher _fDoubleQuotedString() => _wrappedString(
    beginPattern: '$_fPrefixes"',
    endLiteral: '"',
    content: _fStringContent(delimiter: '"'),
  );

  Matcher _fSingleQuotedString() => _wrappedString(
    beginPattern: "$_fPrefixes'",
    endLiteral: "'",
    content: _fStringContent(delimiter: "'"),
  );

  Matcher _tripleDoubleQuotedString() => _wrappedString(
    beginPattern: '$_nonFPrefixes"""',
    endLiteral: '"""',
    content: _plainStringContent(delimiter: '"'),
  );

  Matcher _tripleSingleQuotedString() => _wrappedString(
    beginPattern: "$_nonFPrefixes'''",
    endLiteral: "'''",
    content: _plainStringContent(delimiter: "'"),
  );

  Matcher _doubleQuotedString() => _wrappedString(
    beginPattern: '$_nonFPrefixes"',
    endLiteral: '"',
    content: _plainStringContent(delimiter: '"'),
  );

  Matcher _singleQuotedString() => _wrappedString(
    beginPattern: "$_nonFPrefixes'",
    endLiteral: "'",
    content: _plainStringContent(delimiter: "'"),
  );

  Matcher _plainStringContent({required String delimiter}) {
    return Matcher.options([
      Matcher.regex(r"""\\[nrtbf"'\\abfnrtv]""", tag: Tags.stringEscape),
      Matcher.regex(r'\\x[0-9a-fA-F]{2}', tag: Tags.stringEscape),
      Matcher.regex(r'\\u[0-9a-fA-F]{4}', tag: Tags.stringEscape),
      Matcher.regex(r'\\U[0-9a-fA-F]{8}', tag: Tags.stringEscape),
      Matcher.regex(r'\\N\{[^}]+\}', tag: Tags.stringEscape),
      Matcher.regex(r'\\[0-7]{1,3}', tag: Tags.stringEscape),
      Matcher.regex('[^\\\\$delimiter]+', tag: Tags.stringContent),
    ], tag: Tags.stringContent);
  }

  Matcher _fStringContent({required String delimiter}) {
    return Matcher.options([
      Matcher.regex(r'\{[^}]*\}', tag: Tags.stringInterpolation),
      Matcher.regex(r"""\\[nrtbf"'\\abfnrtv]""", tag: Tags.stringEscape),
      Matcher.regex(r'\\x[0-9a-fA-F]{2}', tag: Tags.stringEscape),
      Matcher.regex(r'\\u[0-9a-fA-F]{4}', tag: Tags.stringEscape),
      Matcher.regex(r'\\U[0-9a-fA-F]{8}', tag: Tags.stringEscape),
      Matcher.regex(r'\\N\{[^}]+\}', tag: Tags.stringEscape),
      Matcher.regex(r'\\[0-7]{1,3}', tag: Tags.stringEscape),
      Matcher.regex('[^{}\\\\$delimiter]+', tag: Tags.stringContent),
      Matcher.regex(r'.', tag: Tags.stringContent),
    ], tag: Tags.stringContent);
  }

  Matcher _keywords() => Matcher.options([
    Matcher.include(_controlKeywords),
    Matcher.include(_declarationKeywords),
    Matcher.include(_logicalKeywords),
  ]);

  Matcher _controlKeywords() => Matcher.keywords([
    'if',
    'elif',
    'else',
    'for',
    'while',
    'try',
    'except',
    'finally',
    'with',
    'break',
    'continue',
    'return',
    'raise',
    'yield',
    'await',
    'async',
  ], baseTag: Tags.controlKeyword);

  Matcher _declarationKeywords() => Matcher.keywords([
    'def',
    'class',
    'lambda',
    'global',
    'nonlocal',
    'del',
    'import',
    'from',
    'as',
    'pass',
    'assert',
  ], baseTag: Tags.declarationKeyword);

  Matcher _logicalKeywords() => Matcher.keywords([
    'and',
    'or',
    'not',
    'in',
    'is',
  ], baseTag: Tags.keyword);

  Matcher _literals() => Matcher.options([
    Matcher.include(_booleanLiterals),
    Matcher.include(_nullLiteral),
    Matcher.include(_numberLiterals),
  ]);

  Matcher _booleanLiterals() => Matcher.options([
    Matcher.regex(r'\bTrue\b', tag: Tags.trueLiteral),
    Matcher.regex(r'\bFalse\b', tag: Tags.falseLiteral),
  ]);

  Matcher _nullLiteral() => Matcher.regex(r'\bNone\b', tag: Tags.nullLiteral);

  Matcher _numberLiterals() => Matcher.options([
    Matcher.regex(r'\b0[xX][0-9a-fA-F_]+\b', tag: Tags.integerLiteral),
    Matcher.regex(r'\b0[bB][01_]+\b', tag: Tags.integerLiteral),
    Matcher.regex(r'\b0[oO][0-7_]+\b', tag: Tags.integerLiteral),
    Matcher.regex(
      r'\b\d[\d_]*\.[\d_]*([eE][+-]?[\d_]+)?j?\b',
      tag: Tags.floatLiteral,
    ),
    Matcher.regex(
      r'\b\d[\d_]*[eE][+-]?[\d_]+j?\b',
      tag: Tags.floatLiteral,
    ),
    Matcher.regex(r'\b\d[\d_]*j\b', tag: Tags.numberLiteral),
    Matcher.regex(r'\b\d[\d_]*\b', tag: Tags.integerLiteral),
  ]);

  Matcher _decorators() => Matcher.regex(
    r'@\s*[a-zA-Z_][a-zA-Z0-9_.]*',
    tag: Tags.annotation,
  );

  Matcher _builtInTypes() => Matcher.builtInTypes([
    'int',
    'float',
    'complex',
    'str',
    'bytes',
    'bytearray',
    'list',
    'tuple',
    'set',
    'frozenset',
    'dict',
    'bool',
    'object',
    'type',
    'range',
    'slice',
    'memoryview',
    'Exception',
    'BaseException',
    'TypeError',
    'ValueError',
    'KeyError',
    'IndexError',
    'AttributeError',
    'NameError',
    'RuntimeError',
    'StopIteration',
    'GeneratorExit',
    'IOError',
    'OSError',
    'FileNotFoundError',
  ]);

  Matcher _builtInFunctions() => Matcher.options([
    Matcher.regex(
      r'\b(?:print|input|len|range|type|isinstance|issubclass|'
      r'hasattr|getattr|setattr|delattr|'
      r'open|close|read|write|'
      r'abs|round|min|max|sum|pow|divmod|'
      r'sorted|reversed|enumerate|zip|map|filter|reduce|'
      r'all|any|iter|next|'
      r'id|hash|repr|str|int|float|bool|list|dict|set|tuple|'
      r'chr|ord|hex|oct|bin|'
      r'format|vars|dir|help|'
      r'callable|exec|eval|compile|'
      r'globals|locals|'
      r'super|staticmethod|classmethod|property)\b(?=\s*\()',
      tag: Tags.function,
    ),
  ]);

  Matcher _operators() => Matcher.options([
    Matcher.regex(
      r'\*\*=|//=|<<=|>>=|'
      r'\*\*|//|<<|>>|<=|>=|==|!=|:=|->|'
      r'\+=|-=|\*=|/=|%=|&=|\|=|\^=|@=',
      tag: Tags.operator,
    ),
    Matcher.regex(r'[+\-*/%&|^~<>=@]', tag: Tags.operator),
    Matcher.regex(r'[{}()\[\],.:;]', tag: Tags.punctuation),
  ]);

  Matcher _identifiers() => Matcher.options([
    Matcher.regex(r'\bself\b', tag: Tags.specialIdentifier),
    Matcher.regex(r'\bcls\b', tag: Tags.specialIdentifier),
    Matcher.regex(
      r'\b__[a-zA-Z_][a-zA-Z0-9_]*__\b',
      tag: Tags.specialIdentifier,
    ),
    Matcher.regex(r'\b[a-zA-Z_][a-zA-Z0-9_]*\b', tag: Tags.identifier),
  ]);
}
