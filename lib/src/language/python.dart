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
    // Triple-quoted strings are listed before single-character quotes so that
    // an opening `"""` or `'''` is never mistaken for an empty string.
    ..._stringVariants('"""', '"'),
    ..._stringVariants("'''", "'"),
    ..._stringVariants('"', '"'),
    ..._stringVariants("'", "'"),
  ]);

  /// Builds the supported prefix variants for a [quote] delimiter.
  ///
  /// The variants are ordered from most to least specific prefix so that,
  /// for example, `rf"..."` isn't matched as a raw string followed by content.
  ///
  /// [contentDelimiter] is the single quote character that string content
  /// stops at, which is `"` for both `"` and `"""` (and likewise for `'`).
  List<Matcher> _stringVariants(String quote, String contentDelimiter) => [
    // Raw f-strings (`rf"..."`, `fr"..."`): interpolations, no escapes.
    _string(
      prefixPattern: r'(?:[fF][rR]|[rR][fF])',
      quote: quote,
      content: _fStringContent(contentDelimiter, raw: true),
    ),
    // f-strings (`f"..."`): interpolations and escape sequences.
    _string(
      prefixPattern: r'[fF]',
      quote: quote,
      content: _fStringContent(contentDelimiter),
    ),
    // Raw strings (`r"..."`, `rb"..."`, `br"..."`): literal backslashes.
    _string(
      prefixPattern: r'(?:[rR]|[bB][rR]|[rR][bB])',
      quote: quote,
      content: _stringContent(contentDelimiter, raw: true),
    ),
    // Plain strings, optionally byte or unicode prefixed (`b"..."`, `u"..."`).
    // The prefix is optional, so unprefixed strings match here too.
    _string(
      prefixPattern: r'(?:[uU]|[bB])?',
      quote: quote,
      content: _stringContent(contentDelimiter),
    ),
  ];

  Matcher _string({
    required String prefixPattern,
    required String quote,
    required Matcher content,
  }) => Matcher.wrapped(
    begin: Matcher.regex(
      '$prefixPattern$quote',
      tag: const Tag('begin', parent: Tags.stringLiteral),
    ),
    end: Matcher.verbatim(
      quote,
      tag: const Tag('end', parent: Tags.stringLiteral),
    ),
    content: content,
    tag: Tags.stringLiteral,
  );

  /// The escape sequences recognized inside regular (non-raw) strings.
  List<Matcher> get _escapeSequences => [
    Matcher.regex(r"""\\['"\\abfnrtv]""", tag: Tags.stringEscape),
    Matcher.regex(r'\\[0-7]{1,3}', tag: Tags.stringEscape),
    Matcher.regex(r'\\x[0-9a-fA-F]{2}', tag: Tags.stringEscape),
    Matcher.regex(r'\\u[0-9a-fA-F]{4}', tag: Tags.stringEscape),
    Matcher.regex(r'\\U[0-9a-fA-F]{8}', tag: Tags.stringEscape),
    Matcher.regex(r'\\N\{[^}]+\}', tag: Tags.stringEscape),
  ];

  /// Content for non-f-strings.
  ///
  /// Recognized escape sequences are highlighted unless [raw] is set,
  /// in which case backslashes are literal.
  /// However, a backslash before a quote still
  /// keeps that quote from ending the string.
  Matcher _stringContent(String delimiter, {bool raw = false}) =>
      Matcher.options([
        if (!raw) ..._escapeSequences,
        // An unrecognized escape (or any backslash in a raw string) keeps its
        // backslash so the following character can't terminate the string.
        Matcher.regex(r'\\.'),
        Matcher.regex('[^\\\\$delimiter]+'),
        // A lone delimiter that doesn't close the string is literal content,
        // such as a single `"` inside a `"""` triple-quoted string.
        // The end matcher is always tried first,
        // so this never eats a real terminator.
        Matcher.regex(r'.'),
      ], tag: Tags.stringContent);

  /// Content for f-strings: interpolations and literal (doubled) braces.
  ///
  /// Escape sequences are recognized unless [raw] is set, since raw f-strings
  /// (`rf"..."`) keep backslashes literal just like other raw strings.
  Matcher _fStringContent(String delimiter, {bool raw = false}) =>
      Matcher.options([
        // Doubled braces are literal `{` and `}`, not interpolations.
        Matcher.regex(r'\{\{|\}\}', tag: Tags.stringEscape),
        Matcher.regex(r'\{[^}]*\}', tag: Tags.stringInterpolation),
        if (!raw) ..._escapeSequences,
        Matcher.regex(r'\\.'),
        Matcher.regex('[^{}\\\\$delimiter]+'),
        Matcher.regex(r'.'),
      ], tag: Tags.stringContent);

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
    // Floats with a fractional dot, such as `3.14`, `10.`, and `2.5e-3j`.
    Matcher.regex(
      r'\b\d[\d_]*\.[\d_]*(?:[eE][+-]?\d[\d_]*)?[jJ]?',
      tag: Tags.floatLiteral,
    ),
    // Floats that start with a dot, such as `.5` and `.5j`.
    Matcher.regex(
      r'(?<![\w.])\.\d[\d_]*(?:[eE][+-]?\d[\d_]*)?[jJ]?',
      tag: Tags.floatLiteral,
    ),
    // Floats with an exponent but no dot, such as `1e10` and `2E-3j`.
    Matcher.regex(
      r'\b\d[\d_]*[eE][+-]?\d[\d_]*[jJ]?',
      tag: Tags.floatLiteral,
    ),
    // Imaginary integers, such as `4j`.
    Matcher.regex(r'\b\d[\d_]*[jJ]', tag: Tags.numberLiteral),
    // Decimal integers, such as `42` and `1_000`.
    Matcher.regex(r'\b\d[\d_]*', tag: Tags.integerLiteral),
  ]);

  // Only `@` at the start of a line is a decorator,
  // elsewhere it's the matrix-multiplication operator.
  // The name is optional so the bare `@` of
  // an expression decorator (such as `@(deco())`) is still tagged.
  Matcher _decorators() => Matcher.regex(
    r'(?<=^\s*)@(?:[a-zA-Z_][a-zA-Z0-9_.]*)?',
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
