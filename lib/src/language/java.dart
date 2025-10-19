import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

@internal
final class JavaGrammar extends MatcherGrammar {
  const JavaGrammar();

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
      content: Matcher.options([
        Matcher.regex(
          r'@(param|return|throws|exception|see|since|deprecated|author|'
          r'version|serial|serialField|serialData|link|linkplain|code|'
          r'literal|value|docRoot|inheritDoc)\b',
          tag: Tags.annotation,
        ),
        Matcher.regex(
          r'\{@\w+[^}]*\}',
          tag: Tags.annotation,
        ),
        Matcher.regex(
          r'[^@*]+',
          tag: const Tag('content', parent: Tags.docComment),
        ),
        Matcher.regex(
          r'\*(?!/)',
          tag: const Tag('content', parent: Tags.docComment),
        ),
      ], tag: const Tag('content', parent: Tags.docComment)),
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
    Matcher.include(_textBlock),
    Matcher.include(_characterLiteral),
    Matcher.include(_doubleQuotedString),
  ]);

  Matcher _textBlock() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '"""',
      tag: const Tag('begin', parent: Tags.tripleQuoteString),
    ),
    end: Matcher.verbatim(
      '"""',
      tag: const Tag('end', parent: Tags.tripleQuoteString),
    ),
    content: Matcher.options([
      Matcher.regex(r"""\\[btnfr"'\\]""", tag: Tags.stringEscape),
      Matcher.regex(r'\\u[0-9a-fA-F]{4}', tag: Tags.stringEscape),
      Matcher.regex(r'\\[0-7]{1,3}', tag: Tags.stringEscape),
      Matcher.regex(r'\\s', tag: Tags.stringEscape),
      Matcher.regex(
        r'[\s\S]+?',
        tag: Tags.stringContent,
      ),
    ], tag: Tags.stringContent),
    tag: Tags.tripleQuoteString,
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
      Matcher.regex(r"""\\[btnfr"'\\]""", tag: Tags.stringEscape),
      Matcher.regex(r'\\u[0-9a-fA-F]{4}', tag: Tags.stringEscape),
      Matcher.regex(r'\\[0-7]{1,3}', tag: Tags.stringEscape),
      Matcher.regex(
        r"[^'\\]",
        tag: Tags.stringContent,
      ),
    ], tag: Tags.stringContent),
    tag: Tags.characterLiteral,
  );

  Matcher _doubleQuotedString() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '"',
      tag: const Tag('begin', parent: Tags.doubleQuoteString),
    ),
    end: Matcher.verbatim(
      '"',
      tag: const Tag('end', parent: Tags.doubleQuoteString),
    ),
    content: Matcher.options([
      Matcher.regex(r"""\\[btnfr"'\\]""", tag: Tags.stringEscape),
      Matcher.regex(r'\\u[0-9a-fA-F]{4}', tag: Tags.stringEscape),
      Matcher.regex(r'\\[0-7]{1,3}', tag: Tags.stringEscape),
      Matcher.regex(
        r'[^"\\]+',
        tag: Tags.stringContent,
      ),
    ], tag: Tags.stringContent),
    tag: Tags.doubleQuoteString,
  );

  Matcher _keywords() => Matcher.options([
    Matcher.include(_controlKeywords),
    Matcher.include(_declarationKeywords),
    Matcher.include(_modifierKeywords),
    Matcher.include(_exceptionKeywords),
    Matcher.include(_otherKeywords),
  ]);

  Matcher _controlKeywords() => Matcher.keywords(
    [
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
      'while',
      'yield',
    ],
    baseTag: Tags.controlKeyword,
  );

  Matcher _declarationKeywords() => Matcher.keywords(
    [
      'class',
      'enum',
      'extends',
      'implements',
      'import',
      'interface',
      'module',
      'package',
      'record',
    ],
    baseTag: Tags.declarationKeyword,
  );

  Matcher _modifierKeywords() => Matcher.keywords(
    [
      'abstract',
      'const',
      'final',
      'native',
      'non-sealed',
      'open',
      'permits',
      'private',
      'protected',
      'public',
      'sealed',
      'static',
      'strictfp',
      'synchronized',
      'transient',
      'volatile',
    ],
    baseTag: Tags.modifierKeyword,
  );

  Matcher _exceptionKeywords() => Matcher.keywords(
    [
      'catch',
      'finally',
      'throw',
      'throws',
      'try',
    ],
    baseTag: Tags.controlKeyword,
  );

  Matcher _otherKeywords() => Matcher.keywords(
    [
      'instanceof',
      'new',
      'requires',
      'super',
      'this',
      'var',
      'void',
    ],
    baseTag: Tags.keyword,
  );

  Matcher _literals() => Matcher.options([
    Matcher.include(_booleanLiterals),
    Matcher.include(_nullLiteral),
    Matcher.include(_numberLiterals),
  ]);

  Matcher _booleanLiterals() => Matcher.options([
    Matcher.regex(r'\btrue\b', tag: Tags.trueLiteral),
    Matcher.regex(r'\bfalse\b', tag: Tags.falseLiteral),
  ]);

  Matcher _nullLiteral() => Matcher.regex(r'\bnull\b', tag: Tags.nullLiteral);

  Matcher _numberLiterals() => Matcher.options([
    Matcher.regex(
      r'\b0[xX][0-9a-fA-F_]+[lL]?\b',
      tag: Tags.integerLiteral,
    ),
    Matcher.regex(r'\b0[bB][01_]+[lL]?\b', tag: Tags.integerLiteral),
    Matcher.regex(r'\b0[0-7_]+[lL]?\b', tag: Tags.integerLiteral),
    Matcher.regex(
      r'\b\d[\d_]*\.\d[\d_]*[eE][+-]?\d[\d_]*[fFdD]?\b',
      tag: Tags.floatLiteral,
    ),
    Matcher.regex(
      r'\b\d[\d_]*\.\d[\d_]*[fFdD]?\b',
      tag: Tags.floatLiteral,
    ),
    Matcher.regex(
      r'\b\d[\d_]*[eE][+-]?\d[\d_]*[fFdD]?\b',
      tag: Tags.floatLiteral,
    ),
    Matcher.regex(r'\b\d[\d_]*\.[fFdD]\b', tag: Tags.floatLiteral),
    Matcher.regex(r'\b\d[\d_]*[fFdD]\b', tag: Tags.floatLiteral),
    Matcher.regex(r'\b\d[\d_]*[lL]?\b', tag: Tags.integerLiteral),
  ]);

  Matcher _annotations() => Matcher.regex(
    r'@[a-zA-Z_][a-zA-Z0-9_]*',
    tag: Tags.annotation,
  );

  Matcher _types() => Matcher.options([
    Matcher.include(_primitiveTypes),
    Matcher.include(_builtInTypes),
    Matcher.include(_typeIdentifiers),
  ]);

  Matcher _primitiveTypes() => Matcher.builtInTypes(
    [
      'boolean',
      'byte',
      'char',
      'double',
      'float',
      'int',
      'long',
      'short',
    ],
    tag: Tags.builtInType,
  );

  Matcher _builtInTypes() => Matcher.builtInTypes([
    'Boolean',
    'Byte',
    'Character',
    'Class',
    'Double',
    'Enum',
    'Error',
    'Exception',
    'Float',
    'Integer',
    'Iterable',
    'List',
    'Long',
    'Math',
    'Number',
    'Object',
    'Record',
    'Runnable',
    'RuntimeException',
    'Short',
    'String',
    'StringBuffer',
    'StringBuilder',
    'System',
    'Thread',
    'Throwable',
    'Void',
  ]);

  Matcher _typeIdentifiers() =>
      Matcher.regex(r'\b[A-Z][a-zA-Z0-9_]*\b', tag: Tags.type);

  Matcher _functions() => Matcher.regex(
    r'\b[a-zA-Z_][a-zA-Z0-9_]*(?=\s*\()',
    tag: Tags.function,
  );

  Matcher _operators() => Matcher.options([
    Matcher.regex(
      r'\+\+|--|<<|>>>|>>|<=|>=|==|!=|&&|\|\||->|::',
      tag: Tags.operator,
    ),
    Matcher.regex(r'[+\-*/%&|^~<>=!?:]', tag: Tags.operator),
    Matcher.regex(r'[{}()\[\],.;]', tag: Tags.punctuation),
    Matcher.regex(r'\.', tag: Tags.accessor),
  ]);

  Matcher _identifiers() => Matcher.options([
    Matcher.regex(
      r'\b[A-Z][A-Z0-9_]*\b',
      tag: const Tag('constant', parent: Tags.specialIdentifier),
    ),
    Matcher.regex(r'\b[a-z_][a-zA-Z0-9_]*\b', tag: Tags.identifier),
  ]);
}
