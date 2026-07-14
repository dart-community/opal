import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

@internal
final class GoGrammar extends MatcherGrammar {
  const GoGrammar();

  static const String _identifierStart = r'[\p{L}_]';
  static const String _identifierContinue = r'[\p{L}\p{Nd}_]';
  static const String _identifierPattern =
      '$_identifierStart$_identifierContinue*';
  static const String _identifierLeftBoundary = '(?<!$_identifierContinue)';
  static const String _identifierRightBoundary = '(?!$_identifierContinue)';

  @override
  List<Matcher> get matchers => [
    Matcher.include(_comments),
    Matcher.include(_strings),
    Matcher.include(_keywords),
    Matcher.include(_literals),
    Matcher.include(_types),
    Matcher.include(_functions),
    Matcher.include(_operators),
    Matcher.include(_identifiers),
  ];

  Matcher _comments() => Matcher.options([
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
        r'.+?(?=\*/|$)',
        tag: const Tag('content', parent: Tags.blockComment),
      ),
      tag: Tags.blockComment,
    ),
  ]);

  Matcher _strings() => Matcher.options([
    Matcher.include(_rawString),
    Matcher.include(_interpretedString),
    Matcher.include(_runeLiteral),
  ]);

  Matcher _rawString() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '`',
      tag: const Tag('begin', parent: Tags.stringLiteral),
    ),
    end: Matcher.verbatim(
      '`',
      tag: const Tag('end', parent: Tags.stringLiteral),
    ),
    content: Matcher.regex(
      r'[^`]+',
      tag: Tags.stringContent,
    ),
    tag: Tags.stringLiteral,
  );

  Matcher _interpretedString() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '"',
      tag: const Tag('begin', parent: Tags.doubleQuoteString),
    ),
    end: Matcher.regex(
      r'"|$',
      tag: const Tag('end', parent: Tags.doubleQuoteString),
    ),
    content: Matcher.options([
      Matcher.include(_stringEscape),
      Matcher.regex(r'[^"\\]+', tag: Tags.stringContent),
      Matcher.regex(r'\\.', tag: Tags.stringEscape),
    ], tag: Tags.stringContent),
    tag: Tags.doubleQuoteString,
  );

  Matcher _runeLiteral() => Matcher.wrapped(
    begin: Matcher.verbatim(
      "'",
      tag: const Tag('begin', parent: Tags.characterLiteral),
    ),
    end: Matcher.regex(
      r"'|$",
      tag: const Tag('end', parent: Tags.characterLiteral),
    ),
    content: Matcher.options([
      Matcher.include(_stringEscape),
      Matcher.regex(r"[^'\\]+", tag: Tags.stringContent),
      Matcher.regex(r'\\.', tag: Tags.stringEscape),
    ], tag: Tags.stringContent),
    tag: Tags.characterLiteral,
  );

  Matcher _stringEscape() => Matcher.options([
    Matcher.regex(r'''\\[abfnrtv\\'"]''', tag: Tags.stringEscape),
    Matcher.regex(r'\\[0-7]{3}', tag: Tags.stringEscape),
    Matcher.regex(r'\\x[0-9a-fA-F]{2}', tag: Tags.stringEscape),
    Matcher.regex(r'\\u[0-9a-fA-F]{4}', tag: Tags.stringEscape),
    Matcher.regex(r'\\U[0-9a-fA-F]{8}', tag: Tags.stringEscape),
  ]);

  Matcher _keywords() => Matcher.options([
    _keywordIdentifiers(
      [
        'break',
        'case',
        'continue',
        'default',
        'else',
        'fallthrough',
        'for',
        'goto',
        'if',
        'range',
        'return',
        'select',
        'switch',
      ],
      baseTag: Tags.controlKeyword,
    ),
    _keywordIdentifiers(
      ['const', 'func', 'import', 'package', 'type', 'var'],
      baseTag: Tags.declarationKeyword,
    ),
    _keywordIdentifiers(
      ['chan', 'interface', 'map', 'struct'],
      baseTag: Tags.declarationKeyword,
    ),
    _keywordIdentifiers(
      ['defer', 'go'],
      baseTag: Tags.controlKeyword,
    ),
  ]);

  Matcher _literals() => Matcher.options([
    _namedIdentifier('true', tag: Tags.trueLiteral),
    _namedIdentifier('false', tag: Tags.falseLiteral),
    _namedIdentifier('nil', tag: Tags.nullLiteral),
    _namedIdentifier('iota', tag: Tags.integerLiteral),
    Matcher.include(_imaginaryLiterals),
    Matcher.include(_floatLiterals),
    Matcher.include(_integerLiterals),
  ]);

  Matcher _imaginaryLiterals() => Matcher.regex(
    r'(?:0[xX][0-9a-fA-F_]*(?:\.[0-9a-fA-F_]*)?[pP][+-]?[0-9_]+|'
    r'(?:[0-9][0-9_]*\.?[0-9_]*|\.[0-9][0-9_]*)'
    r'(?:[eE][+-]?[0-9_]+)?|'
    r'0[bB][01_]+|0[oO][0-7_]+|0[xX][0-9a-fA-F_]+)i'
    r'\b',
    tag: Tags.numberLiteral,
  );

  Matcher _floatLiterals() => Matcher.options([
    Matcher.regex(
      r'\b0[xX][0-9a-fA-F_]*(?:\.[0-9a-fA-F_]*)?[pP][+-]?[0-9_]+'
      r'\b',
      tag: Tags.floatLiteral,
    ),
    Matcher.regex(
      r'(?:\b[0-9][0-9_]*\.[0-9_]*|\.[0-9][0-9_]*)'
      r'(?:[eE][+-]?[0-9_]+)?'
      r'(?:\b|(?<=\.))',
      tag: Tags.floatLiteral,
    ),
    Matcher.regex(
      r'\b[0-9][0-9_]*[eE][+-]?[0-9_]+'
      r'\b',
      tag: Tags.floatLiteral,
    ),
  ]);

  Matcher _integerLiterals() => Matcher.options([
    Matcher.regex(r'\b0[bB][01_]+\b', tag: Tags.integerLiteral),
    Matcher.regex(r'\b0[oO][0-7_]+\b', tag: Tags.integerLiteral),
    Matcher.regex(r'\b0[xX][0-9a-fA-F_]+\b', tag: Tags.integerLiteral),
    Matcher.regex(r'\b[0-9][0-9_]*\b', tag: Tags.integerLiteral),
  ]);

  Matcher _types() => _namedIdentifiers(
    [
      'any',
      'bool',
      'byte',
      'comparable',
      'complex64',
      'complex128',
      'error',
      'float32',
      'float64',
      'int',
      'int8',
      'int16',
      'int32',
      'int64',
      'rune',
      'string',
      'uint',
      'uint8',
      'uint16',
      'uint32',
      'uint64',
      'uintptr',
    ],
    tag: Tags.builtInType,
  );

  Matcher _functions() => Matcher.regex(
    '$_identifierLeftBoundary$_identifierPattern'
    '$_identifierRightBoundary'
    r'(?=\s*(?:\[(?:[^\[\]]|\[[^\[\]]*\])*\]\s*)?\()',
    tag: Tags.function,
  );

  Matcher _operators() => Matcher.options([
    Matcher.regex(
      r'<<=|>>=|&\^=|\.\.\.|\+\+|--|==|!=|<=|>=|:=|<-|&&|\|\||'
      r'\+=|-=|\*=|/=|%=|&=|\|=|\^=|<<|>>|&\^',
      tag: Tags.operator,
    ),
    Matcher.regex(r'[+\-*/%&|^~<>=!]', tag: Tags.operator),
    Matcher.regex(r'[{}()\[\],;:]', tag: Tags.punctuation),
    Matcher.regex(r'\.', tag: Tags.accessor),
  ]);

  Matcher _identifiers() => Matcher.regex(
    '$_identifierLeftBoundary$_identifierPattern'
    '$_identifierRightBoundary',
    tag: Tags.identifier,
  );

  Matcher _keywordIdentifiers(List<String> names, {required Tag baseTag}) =>
      Matcher.options([
        for (final name in names)
          _namedIdentifier(name, tag: Tag(name, parent: baseTag)),
      ]);

  Matcher _namedIdentifier(String name, {required Tag tag}) => Matcher.regex(
    '$_identifierLeftBoundary${RegExp.escape(name)}'
    '$_identifierRightBoundary',
    tag: tag,
  );

  Matcher _namedIdentifiers(List<String> names, {required Tag tag}) =>
      Matcher.options([
        for (final name in names) _namedIdentifier(name, tag: tag),
      ]);
}
