import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

/// Shared lexical matchers for ECMAScript-based languages.
///
/// Subclasses compose these groups in their preferred order so they can insert
/// language-specific rules before the general identifier fallback.
@internal
abstract base class EcmaScriptGrammar extends MatcherGrammar {
  const EcmaScriptGrammar();

  static const String unicodeEscape =
      r'\\u(?:[0-9a-fA-F]{4}|\{[0-9a-fA-F]{1,6}\})';
  static const String identifierStartCharacter = r'[$_\p{ID_Start}]';
  static const String identifierContinueCharacter =
      r'[$_\u200C\u200D\p{ID_Continue}]';
  static const String identifierStart =
      '(?:$identifierStartCharacter|$unicodeEscape)';
  static const String identifierContinue =
      '(?:$identifierContinueCharacter|$unicodeEscape)';
  static const String identifierPattern =
      '$identifierStart$identifierContinue*';
  static const String identifierLeftBoundary =
      '(?<!$identifierContinueCharacter)';
  static const String identifierRightBoundary = '(?!$identifierContinue)';
  static const String _expressionEndCharacter =
      r'''[$_\u200C\u200D\p{ID_Continue})\]}"'`]''';
  static const String _regularExpressionLiteralPattern =
      r'/(?![/*])(?:\\.|[^/\\[\r\n]|\[(?:\\.|[^\]\\\r\n]|\[(?:\\.|[^\]\\\r\n])*\])*\])+/[dgimsuvy]*';
  static const String _regexPrefixKeywordPattern =
      r'(?:(?:^|[^.#$_\u200C\u200D\p{ID_Continue}])'
      r'(?:case|return|yield)[ \t]*)';
  static const String _recoverableStringLineEndPattern =
      r'(?<=(?:^|[^\\])(?:\\\\)*)$';

  @protected
  Matcher comments() => Matcher.options([
    Matcher.regex(r'^#!.*$', tag: Tags.lineComment),
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

  @protected
  Matcher strings() => Matcher.options([
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
      Matcher.include(_stringEscape),
      Matcher.regex(r'\$(?!\{)'),
      Matcher.regex(r'[^`\\$]+'),
    ], tag: Tags.stringContent),
    tag: Tags.stringLiteral,
  );

  Matcher _singleQuotedString() => Matcher.wrapped(
    begin: Matcher.verbatim(
      "'",
      tag: const Tag('begin', parent: Tags.stringLiteral),
    ),
    end: Matcher.regex(
      "'|$_recoverableStringLineEndPattern",
      tag: const Tag('end', parent: Tags.stringLiteral),
    ),
    content: Matcher.options([
      Matcher.include(_stringEscape),
      Matcher.regex(r"[^'\\]+"),
    ], tag: Tags.stringContent),
    tag: Tags.stringLiteral,
  );

  Matcher _doubleQuotedString() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '"',
      tag: const Tag('begin', parent: Tags.stringLiteral),
    ),
    end: Matcher.regex(
      '"|$_recoverableStringLineEndPattern',
      tag: const Tag('end', parent: Tags.stringLiteral),
    ),
    content: Matcher.options([
      Matcher.include(_stringEscape),
      Matcher.regex(r'[^"\\]+'),
    ], tag: Tags.stringContent),
    tag: Tags.stringLiteral,
  );

  Matcher _stringEscape() => Matcher.regex(
    r'''\\(?:$|[0bfnrtv'"`\\]|x[0-9a-fA-F]{2}|u[0-9a-fA-F]{4}|u\{[0-9a-fA-F]{1,6}\}|[^\r\n])''',
    tag: Tags.stringEscape,
  );

  @protected
  Matcher javascriptKeywords() => Matcher.options([
    Matcher.include(_controlKeywords),
    Matcher.include(_declarationKeywords),
    Matcher.include(_asyncKeywords),
    Matcher.include(_exceptionKeywords),
    Matcher.include(_otherKeywords),
  ]);

  Matcher _controlKeywords() => keywordIdentifiers(
    [
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
    ],
    baseTag: Tags.controlKeyword,
  );

  Matcher _declarationKeywords() => keywordIdentifiers(
    [
      'class',
      'const',
      'enum',
      'export',
      'extends',
      'function',
      'import',
      'let',
      'using',
      'var',
    ],
    baseTag: Tags.declarationKeyword,
  );

  Matcher _asyncKeywords() => Matcher.options([
    keywordIdentifiers(['async'], baseTag: Tags.modifierKeyword),
    keywordIdentifiers(['await', 'yield'], baseTag: Tags.controlKeyword),
  ]);

  Matcher _exceptionKeywords() => keywordIdentifiers(
    ['catch', 'finally', 'throw', 'try'],
    baseTag: Tags.controlKeyword,
  );

  Matcher _otherKeywords() => keywordIdentifiers([
    'as',
    'debugger',
    'delete',
    'from',
    'get',
    'implements',
    'in',
    'instanceof',
    'interface',
    'new',
    'of',
    'package',
    'private',
    'protected',
    'public',
    'set',
    'static',
    'super',
    'this',
    'typeof',
    'void',
    'with',
  ]);

  @protected
  Matcher keywordIdentifiers(
    List<String> keywords, {
    Tag baseTag = Tags.keyword,
  }) => Matcher.options([
    for (final keyword in keywords)
      namedIdentifier(keyword, tag: Tag(keyword, parent: baseTag)),
  ]);

  @protected
  Matcher builtInTypeIdentifiers(List<String> types) => Matcher.regex(
    '$identifierLeftBoundary'
    '(?:${types.map(RegExp.escape).join('|')})'
    '$identifierRightBoundary',
    tag: Tags.builtInType,
  );

  @protected
  Matcher literals() => Matcher.options([
    Matcher.include(_booleanLiterals),
    Matcher.include(_nullLiterals),
    Matcher.include(_numberLiterals),
    Matcher.include(_regexLiterals),
  ]);

  Matcher _booleanLiterals() => Matcher.options([
    namedIdentifier('true', tag: Tags.trueLiteral),
    namedIdentifier('false', tag: Tags.falseLiteral),
  ]);

  Matcher _nullLiterals() => Matcher.options([
    namedIdentifier('null', tag: Tags.nullLiteral),
    namedIdentifier('undefined', tag: Tags.nullLiteral),
  ]);

  Matcher _numberLiterals() => Matcher.options([
    Matcher.regex(
      r'0[xX][0-9a-fA-F](?:_?[0-9a-fA-F])*n?'
      '(?!$identifierStart|[0-9])',
      tag: Tags.numberLiteral,
    ),
    Matcher.regex(
      r'0[bB][01](?:_?[01])*n?'
      '(?!$identifierStart|[0-9])',
      tag: Tags.numberLiteral,
    ),
    Matcher.regex(
      r'0[oO][0-7](?:_?[0-7])*n?'
      '(?!$identifierStart|[0-9])',
      tag: Tags.numberLiteral,
    ),
    Matcher.regex(
      r'(?:0|[1-9](?:_?[0-9])*)n'
      '(?!$identifierStart|[0-9])',
      tag: Tags.numberLiteral,
    ),
    Matcher.regex(
      r'(?:[0-9](?:_?[0-9])*(?:\.(?:[0-9](?:_?[0-9])*)?)?'
      r'|\.[0-9](?:_?[0-9])*)'
      r'(?:[eE][+-]?[0-9](?:_?[0-9])*)?'
      '(?!$identifierStart|[0-9])',
      tag: Tags.numberLiteral,
    ),
    namedIdentifier('NaN', tag: Tags.numberLiteral),
    namedIdentifier('Infinity', tag: Tags.numberLiteral),
  ]);

  Matcher _regexLiterals() => Matcher.options([
    Matcher.regex(
      '(?<=$_regexPrefixKeywordPattern)$_regularExpressionLiteralPattern',
      tag: const Tag('regex', parent: Tags.literal),
    ),
    Matcher.regex(
      '(?<!$_expressionEndCharacter[ \\t]*)'
      '$_regularExpressionLiteralPattern',
      tag: const Tag('regex', parent: Tags.literal),
    ),
  ]);

  @protected
  Matcher privateIdentifiers() => Matcher.regex(
    '#$identifierPattern$identifierRightBoundary',
    tag: Tags.privateIdentifier,
  );

  @protected
  Matcher operators() => Matcher.options([
    Matcher.regex(
      r'>>>=|\*\*=|===|!==|>>>|<<=|>>=|&&=|\|\|=|\?\?=|\.\.\.|=>|'
      r'\+\+|--|\*\*|<<|>>|<=|>=|==|!=|&&|\|\||\?\?|\?\.|'
      r'\+=|-=|\*=|/=|%=|&=|\|=|\^=',
      tag: Tags.operator,
    ),
    Matcher.regex(r'[+\-*/%&|^~<>=!?:]', tag: Tags.operator),
    Matcher.regex(r'[{}()\[\],.;]', tag: Tags.punctuation),
  ]);

  @protected
  Matcher identifiers() => Matcher.options([
    Matcher.regex(
      '$identifierLeftBoundary'
      r'\$'
      '$identifierContinue*'
      '$identifierRightBoundary',
      tag: Tags.specialIdentifier,
    ),
    Matcher.regex(
      '$identifierLeftBoundary$identifierPattern$identifierRightBoundary',
      tag: Tags.identifier,
    ),
  ]);

  @protected
  Matcher namedIdentifier(String name, {required Tag tag}) => Matcher.regex(
    '$identifierLeftBoundary$name$identifierRightBoundary',
    tag: tag,
  );
}
