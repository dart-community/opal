import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

@internal
final class CPlusPlusGrammar extends MatcherGrammar {
  const CPlusPlusGrammar();

  @override
  List<Matcher> get matchers => [
    Matcher.include(_preprocessor),
    Matcher.include(_comments),
    Matcher.include(_strings),
    Matcher.include(_keywords),
    Matcher.include(_literals),
    Matcher.include(_types),
    Matcher.include(_functions),
    Matcher.include(_operators),
    Matcher.include(_identifiers),
  ];

  Matcher _preprocessor() => Matcher.regex(
    r'^\s*#\s*(include|define|undef|if|ifdef|ifndef|elif|else|endif|'
    r'pragma|error|warning|line|import)\b.*$',
    tag: Tags.preprocessor,
  );

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
    Matcher.include(_prefixedString),
    Matcher.include(_cppString),
    Matcher.include(_characterLiteral),
  ]);

  Matcher _rawString() => Matcher.regex(
    r'R"([^(]*)\([\s\S]*?\)\1"',
    tag: Tags.stringLiteral,
  );

  Matcher _prefixedString() => Matcher.options([
    Matcher.regex(
      r'u8"(?:[^"\\]|\\.)*"',
      tag: Tags.stringLiteral,
    ),
    Matcher.regex(
      r'[uUL]"(?:[^"\\]|\\.)*"',
      tag: Tags.stringLiteral,
    ),
    Matcher.regex(
      r"[uUL]'(?:[^'\\]|\\.)*'",
      tag: Tags.characterLiteral,
    ),
  ]);

  Matcher _cppString() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '"',
      tag: const Tag('begin', parent: Tags.doubleQuoteString),
    ),
    end: Matcher.verbatim(
      '"',
      tag: const Tag('end', parent: Tags.doubleQuoteString),
    ),
    content: Matcher.options([
      Matcher.regex(r"""\\[nrtbfav"'\\?]""", tag: Tags.stringEscape),
      Matcher.regex(r'\\[0-7]{1,3}', tag: Tags.stringEscape),
      Matcher.regex(r'\\x[0-9a-fA-F]+', tag: Tags.stringEscape),
      Matcher.regex(r'\\u[0-9a-fA-F]{4}', tag: Tags.stringEscape),
      Matcher.regex(r'\\U[0-9a-fA-F]{8}', tag: Tags.stringEscape),
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
      Matcher.regex(r"""\\[nrtbfav"'\\?]""", tag: Tags.stringEscape),
      Matcher.regex(r'\\[0-7]{1,3}', tag: Tags.stringEscape),
      Matcher.regex(r'\\x[0-9a-fA-F]+', tag: Tags.stringEscape),
      Matcher.regex(
        r"[^'\\]",
        tag: Tags.stringContent,
      ),
    ], tag: Tags.stringContent),
    tag: Tags.characterLiteral,
  );

  Matcher _keywords() => Matcher.options([
    Matcher.include(_controlKeywords),
    Matcher.include(_declarationKeywords),
    Matcher.include(_modifierKeywords),
    Matcher.include(_accessKeywords),
    Matcher.include(_exceptionKeywords),
    Matcher.include(_castKeywords),
    Matcher.include(_memoryKeywords),
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
      'class',
      'concept',
      'enum',
      'namespace',
      'struct',
      'template',
      'typedef',
      'typename',
      'union',
      'using',
    ],
    baseTag: Tags.declarationKeyword,
  );

  Matcher _modifierKeywords() => Matcher.keywords(
    [
      'auto',
      'const',
      'consteval',
      'constexpr',
      'constinit',
      'explicit',
      'export',
      'extern',
      'final',
      'friend',
      'inline',
      'mutable',
      'override',
      'register',
      'static',
      'thread_local',
      'virtual',
      'volatile',
    ],
    baseTag: Tags.modifierKeyword,
  );

  Matcher _accessKeywords() => Matcher.keywords(
    [
      'private',
      'protected',
      'public',
    ],
    baseTag: const Tag('access', parent: Tags.keyword),
  );

  Matcher _exceptionKeywords() => Matcher.keywords(
    [
      'catch',
      'noexcept',
      'throw',
      'try',
    ],
    baseTag: const Tag('exception', parent: Tags.keyword),
  );

  Matcher _castKeywords() => Matcher.keywords(
    [
      'const_cast',
      'dynamic_cast',
      'reinterpret_cast',
      'static_cast',
    ],
    baseTag: const Tag('cast', parent: Tags.keyword),
  );

  Matcher _memoryKeywords() => Matcher.keywords(
    [
      'delete',
      'new',
    ],
    baseTag: const Tag('memory', parent: Tags.keyword),
  );

  Matcher _otherKeywords() => Matcher.keywords(
    [
      'alignas',
      'alignof',
      'asm',
      'co_await',
      'co_return',
      'co_yield',
      'decltype',
      'noreturn',
      'operator',
      'requires',
      'sizeof',
      'static_assert',
      'this',
      'typeid',
    ],
    baseTag: Tags.keyword,
  );

  Matcher _literals() => Matcher.options([
    Matcher.include(_booleanLiterals),
    Matcher.include(_nullLiterals),
    Matcher.include(_numberLiterals),
  ]);

  Matcher _booleanLiterals() => Matcher.options([
    Matcher.regex(r'\btrue\b', tag: Tags.trueLiteral),
    Matcher.regex(r'\bfalse\b', tag: Tags.falseLiteral),
  ]);

  Matcher _nullLiterals() => Matcher.options([
    Matcher.regex(r'\bnullptr\b', tag: Tags.nullLiteral),
    Matcher.regex(r'\bNULL\b', tag: Tags.nullLiteral),
  ]);

  Matcher _numberLiterals() => Matcher.options([
    Matcher.regex(
      r"\b0[xX][0-9a-fA-F]+(?:'[0-9a-fA-F]+)*[uUlL]*\b",
      tag: Tags.integerLiteral,
    ),
    Matcher.regex(
      r"\b0[bB][01]+(?:'[01]+)*[uUlL]*\b",
      tag: Tags.integerLiteral,
    ),
    Matcher.regex(
      r"\b0[0-7]+(?:'[0-7]+)*[uUlL]*\b",
      tag: Tags.integerLiteral,
    ),
    Matcher.regex(
      r"\b\d+(?:'\d+)*\.?\d*(?:'\d+)*[eE][+-]?\d+(?:'\d+)*[fFlL]?\b",
      tag: Tags.floatLiteral,
    ),
    Matcher.regex(
      r"\b\d+(?:'\d+)*\.\d+(?:'\d+)*[fFlL]?\b",
      tag: Tags.floatLiteral,
    ),
    Matcher.regex(r"\b\d+(?:'\d+)*[fF]\b", tag: Tags.floatLiteral),
    Matcher.regex(
      r"\b\d+(?:'\d+)*[uUlL]*\b",
      tag: Tags.integerLiteral,
    ),
  ]);

  Matcher _types() => Matcher.options([
    Matcher.include(_builtInTypes),
    Matcher.include(_stdTypes),
    Matcher.include(_typeIdentifiers),
  ]);

  Matcher _builtInTypes() => Matcher.builtInTypes([
    'bool',
    'char',
    'char8_t',
    'char16_t',
    'char32_t',
    'double',
    'float',
    'int',
    'long',
    'short',
    'signed',
    'unsigned',
    'void',
    'wchar_t',
  ]);

  Matcher _stdTypes() => Matcher.builtInTypes([
    'int8_t',
    'int16_t',
    'int32_t',
    'int64_t',
    'uint8_t',
    'uint16_t',
    'uint32_t',
    'uint64_t',
    'intptr_t',
    'uintptr_t',
    'size_t',
    'ptrdiff_t',
    'nullptr_t',
    'max_align_t',
    'string',
    'wstring',
    'u8string',
    'u16string',
    'u32string',
    'vector',
    'map',
    'set',
    'unordered_map',
    'unordered_set',
    'array',
    'deque',
    'list',
    'queue',
    'stack',
    'pair',
    'tuple',
    'optional',
    'variant',
    'any',
    'shared_ptr',
    'unique_ptr',
    'weak_ptr',
    'function',
    'string_view',
  ]);

  Matcher _typeIdentifiers() =>
      Matcher.regex(r'\b[A-Z][a-zA-Z0-9_]*\b', tag: Tags.type);

  Matcher _functions() => Matcher.regex(
    r'\b[a-zA-Z_][a-zA-Z0-9_]*(?=\s*\()',
    tag: Tags.function,
  );

  Matcher _operators() => Matcher.options([
    Matcher.regex(
      r'\+\+|--|<<|>>|<=>|<=|>=|==|!=|&&|\|\||->|\.\.\.|::|'
      r'\.\*|->\\*',
      tag: Tags.operator,
    ),
    Matcher.regex(r'[+\-*/%&|~<>=!?:]', tag: Tags.operator),
    Matcher.regex(r'[{}()\[\],;]', tag: Tags.punctuation),
    Matcher.regex(r'\.', tag: Tags.accessor),
  ]);

  Matcher _identifiers() => Matcher.options([
    Matcher.regex(
      r'\b[A-Z][A-Z0-9_]+\b',
      tag: const Tag('constant', parent: Tags.specialIdentifier),
    ),
    Matcher.regex(r'\b[a-z_][a-zA-Z0-9_]*\b', tag: Tags.identifier),
  ]);
}
