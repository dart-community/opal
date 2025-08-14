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
    Matcher.include(_textBlock),
    Matcher.include(_singleQuotedChar),
    Matcher.include(_doubleQuotedString),
  ]);

  Matcher _textBlock() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '"""',
      tag: const Tag('begin', parent: Tags.stringLiteral),
    ),
    end: Matcher.verbatim(
      '"""',
      tag: const Tag('end', parent: Tags.stringLiteral),
    ),
    content: Matcher.options([
      Matcher.regex(r"""\\[nrtbf"'\\]""", tag: Tags.stringEscape),
      Matcher.regex(r'\\u[0-9a-fA-F]{4}', tag: Tags.stringEscape),
      Matcher.regex(r'\\[0-7]{1,3}', tag: Tags.stringEscape),
      Matcher.regex(
        r'[\s\S]+?',
      ),
    ], tag: Tags.stringContent),
    tag: Tags.stringLiteral,
  );

  Matcher _singleQuotedChar() => Matcher.wrapped(
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
      Matcher.regex(r'\\[0-7]{1,3}', tag: Tags.stringEscape),
      Matcher.regex(
        r"[^'\\]",
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
      Matcher.regex(r'\\[0-7]{1,3}', tag: Tags.stringEscape),
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
    'while',
    'yield',
  ]);

  Matcher _declarationKeywords() => Matcher.keywords([
    'class',
    'enum',
    'extends',
    'implements',
    'import',
    'interface',
    'module',
    'package',
    'record',
  ]);

  Matcher _modifierKeywords() => Matcher.keywords([
    'abstract',
    'const',
    'final',
    'native',
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
  ]);

  Matcher _exceptionKeywords() => Matcher.keywords([
    'catch',
    'finally',
    'throw',
    'throws',
    'try',
  ]);

  Matcher _otherKeywords() => Matcher.keywords([
    'instanceof',
    'new',
    'non-sealed',
    'open',
    'requires',
    'super',
    'this',
    'var',
    'void',
  ]);

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
    Matcher.regex(r'\b0[xX][0-9a-fA-F_]+[lL]?\b', tag: Tags.numberLiteral),
    Matcher.regex(r'\b0[bB][01_]+[lL]?\b', tag: Tags.numberLiteral),
    Matcher.regex(r'\b0[0-7_]+[lL]?\b', tag: Tags.numberLiteral),
    Matcher.regex(
      r'\b\d[\d_]*\.?\d*([eE][+-]?\d[\d_]*)?[fFdDlL]?\b',
      tag: Tags.numberLiteral,
    ),
  ]);

  Matcher _annotations() => Matcher.regex(r'@\w+', tag: Tags.annotation);

  Matcher _types() => Matcher.options([
    Matcher.include(_primitiveTypes),
    Matcher.include(_builtInTypes),
    Matcher.include(_typeIdentifiers),
  ]);

  Matcher _primitiveTypes() => Matcher.keywords([
    'boolean',
    'byte',
    'char',
    'double',
    'float',
    'int',
    'long',
    'short',
  ]);

  Matcher _builtInTypes() => Matcher.builtInTypes([
    'Boolean',
    'Byte',
    'Character',
    'Class',
    'Double',
    'Enum',
    'Exception',
    'Float',
    'Integer',
    'Long',
    'Number',
    'Object',
    'Record',
    'Short',
    'String',
    'StringBuffer',
    'StringBuilder',
    'System',
    'Thread',
    'Throwable',
  ]);

  Matcher _typeIdentifiers() =>
      Matcher.regex(r'\b[A-Z][a-zA-Z0-9_]*\b', tag: Tags.type);

  Matcher _operators() => Matcher.options([
    Matcher.regex(
      r'\+\+|--|<<|>>>|>>|<=|>=|==|!=|&&|\|\||->|::',
      tag: Tags.operator,
    ),
    Matcher.regex(r'[+\-*/%&|^~<>=!?:]', tag: Tags.operator),
    Matcher.regex(r'[{}()\[\],.;]', tag: Tags.punctuation),
  ]);

  Matcher _identifiers() => Matcher.options([
    Matcher.regex(r'\b[a-z][a-zA-Z0-9_]*\b', tag: Tags.identifier),
    Matcher.regex(r'\b[A-Z_][A-Z0-9_]*\b', tag: Tags.specialIdentifier),
  ]);
}
