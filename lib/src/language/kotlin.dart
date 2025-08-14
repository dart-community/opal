import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

@internal
final class KotlinGrammar extends MatcherGrammar {
  const KotlinGrammar();

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
    Matcher.include(_rawString),
    Matcher.include(_templateString),
    Matcher.include(_singleQuotedChar),
    Matcher.include(_doubleQuotedString),
  ]);

  Matcher _rawString() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '"""',
      tag: const Tag('begin', parent: Tags.stringLiteral),
    ),
    end: Matcher.verbatim(
      '"""',
      tag: const Tag('end', parent: Tags.stringLiteral),
    ),
    content: Matcher.regex(
      r'[\s\S]*?',
      tag: Tags.stringContent,
    ),
    tag: Tags.stringLiteral,
  );

  Matcher _templateString() => Matcher.wrapped(
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
      Matcher.regex(
        r'[^"\\$]+',
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
    Matcher.include(_functionalKeywords),
    Matcher.include(_coroutineKeywords),
    Matcher.include(_exceptionKeywords),
    Matcher.include(_otherKeywords),
  ]);

  Matcher _controlKeywords() => Matcher.keywords([
    'break',
    'continue',
    'do',
    'else',
    'for',
    'if',
    'return',
    'when',
    'while',
  ]);

  Matcher _declarationKeywords() => Matcher.keywords([
    'class',
    'constructor',
    'enum',
    'fun',
    'import',
    'interface',
    'object',
    'package',
    'typealias',
    'val',
    'var',
  ]);

  Matcher _modifierKeywords() => Matcher.keywords([
    'abstract',
    'actual',
    'annotation',
    'companion',
    'const',
    'crossinline',
    'data',
    'expect',
    'external',
    'final',
    'infix',
    'inline',
    'inner',
    'internal',
    'lateinit',
    'noinline',
    'open',
    'operator',
    'out',
    'override',
    'private',
    'protected',
    'public',
    'reified',
    'sealed',
    'tailrec',
    'value',
    'vararg',
  ]);

  Matcher _functionalKeywords() => Matcher.keywords([
    'by',
    'delegate',
    'field',
    'file',
    'get',
    'init',
    'param',
    'property',
    'receiver',
    'set',
    'setparam',
    'where',
  ]);

  Matcher _coroutineKeywords() => Matcher.keywords([
    'suspend',
  ]);

  Matcher _exceptionKeywords() => Matcher.keywords([
    'catch',
    'finally',
    'throw',
    'try',
  ]);

  Matcher _otherKeywords() => Matcher.keywords([
    'as',
    'in',
    'is',
    'super',
    'this',
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
    Matcher.regex(r'\b0[xX][0-9a-fA-F_]+[uUlL]*\b', tag: Tags.numberLiteral),
    Matcher.regex(r'\b0[bB][01_]+[uUlL]*\b', tag: Tags.numberLiteral),
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
    'Boolean',
    'Byte',
    'Char',
    'Double',
    'Float',
    'Int',
    'Long',
    'Short',
  ]);

  Matcher _builtInTypes() => Matcher.builtInTypes([
    'Any',
    'Array',
    'BooleanArray',
    'ByteArray',
    'CharArray',
    'CharSequence',
    'Comparable',
    'DoubleArray',
    'Enum',
    'FloatArray',
    'IntArray',
    'List',
    'LongArray',
    'Map',
    'Nothing',
    'Number',
    'Pair',
    'Set',
    'ShortArray',
    'String',
    'Throwable',
    'Triple',
    'Unit',
  ]);

  Matcher _typeIdentifiers() =>
      Matcher.regex(r'\b[A-Z][a-zA-Z0-9_]*\b', tag: Tags.type);

  Matcher _operators() => Matcher.options([
    Matcher.regex(
      r'\+\+|--|\.\.|\.\.<|===|!==|<=|>=|==|!=|&&|\|\||->|::|=>|\?:|!!|\?\.|\?\?',
      tag: Tags.operator,
    ),
    Matcher.regex(r'[+\-*/%&|^~<>=!?:]', tag: Tags.operator),
    Matcher.regex(r'[{}()\[\],.;]', tag: Tags.punctuation),
  ]);

  Matcher _identifiers() => Matcher.options([
    Matcher.regex(r'\b[a-z][a-zA-Z0-9_]*\b', tag: Tags.identifier),
    Matcher.regex(r'\b[A-Z_][A-Z0-9_]*\b', tag: Tags.specialIdentifier),
    Matcher.regex(r'`[^`]+`', tag: Tags.identifier),
  ]);
}
