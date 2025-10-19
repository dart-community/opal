import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

@internal
final class SwiftGrammar extends MatcherGrammar {
  const SwiftGrammar();

  @override
  List<Matcher> get matchers => [
    Matcher.include(_comments),
    Matcher.include(_strings),
    Matcher.include(_keywords),
    Matcher.include(_literals),
    Matcher.include(_attributes),
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
      content: Matcher.regex(
        r'.+?(?=\*/|$)',
        tag: const Tag('content', parent: Tags.docComment),
      ),
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
    Matcher.include(_rawMultilineString),
    Matcher.include(_rawString),
    Matcher.include(_multilineString),
    Matcher.include(_interpolatedString),
  ]);

  Matcher _rawMultilineString() => Matcher.options([
    Matcher.regex(r'###"""[\s\S]*?"""###', tag: Tags.tripleQuoteString),
    Matcher.regex(r'##"""[\s\S]*?"""##', tag: Tags.tripleQuoteString),
    Matcher.regex(r'#"""[\s\S]*?"""#', tag: Tags.tripleQuoteString),
  ]);

  Matcher _rawString() => Matcher.options([
    Matcher.regex(r'###"[^"]*"###', tag: Tags.stringLiteral),
    Matcher.regex(r'##"[^"]*"##', tag: Tags.stringLiteral),
    Matcher.regex(r'#"[^"]*"#', tag: Tags.stringLiteral),
  ]);

  Matcher _multilineString() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '"""',
      tag: const Tag('begin', parent: Tags.tripleQuoteString),
    ),
    end: Matcher.verbatim(
      '"""',
      tag: const Tag('end', parent: Tags.tripleQuoteString),
    ),
    content: Matcher.options([
      Matcher.regex(r'\\\([^)]*\)', tag: Tags.stringInterpolation),
      Matcher.regex(r"""\\[0nrtbf"'\\]""", tag: Tags.stringEscape),
      Matcher.regex(r'\\u\{[0-9a-fA-F]+\}', tag: Tags.stringEscape),
      Matcher.regex(
        r'[\s\S]+?',
        tag: Tags.stringContent,
      ),
    ], tag: Tags.stringContent),
    tag: Tags.tripleQuoteString,
  );

  Matcher _interpolatedString() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '"',
      tag: const Tag('begin', parent: Tags.doubleQuoteString),
    ),
    end: Matcher.verbatim(
      '"',
      tag: const Tag('end', parent: Tags.doubleQuoteString),
    ),
    content: Matcher.options([
      Matcher.regex(r'\\\([^)]*\)', tag: Tags.stringInterpolation),
      Matcher.regex(r"""\\[0nrtbf"'\\]""", tag: Tags.stringEscape),
      Matcher.regex(r'\\u\{[0-9a-fA-F]+\}', tag: Tags.stringEscape),
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
    Matcher.include(_asyncKeywords),
    Matcher.include(_exceptionKeywords),
    Matcher.include(_otherKeywords),
  ]);

  Matcher _controlKeywords() => Matcher.keywords(
    [
      'break',
      'case',
      'continue',
      'default',
      'defer',
      'do',
      'else',
      'fallthrough',
      'for',
      'guard',
      'if',
      'in',
      'repeat',
      'return',
      'switch',
      'where',
      'while',
    ],
    baseTag: Tags.controlKeyword,
  );

  Matcher _declarationKeywords() => Matcher.keywords(
    [
      'associatedtype',
      'class',
      'deinit',
      'enum',
      'extension',
      'func',
      'import',
      'init',
      'let',
      'macro',
      'operator',
      'precedencegroup',
      'protocol',
      'struct',
      'subscript',
      'typealias',
      'var',
    ],
    baseTag: Tags.declarationKeyword,
  );

  Matcher _modifierKeywords() => Matcher.keywords(
    [
      'borrowing',
      'consuming',
      'convenience',
      'dynamic',
      'fileprivate',
      'final',
      'indirect',
      'infix',
      'internal',
      'isolated',
      'lazy',
      'mutating',
      'nonisolated',
      'nonmutating',
      'open',
      'optional',
      'override',
      'postfix',
      'prefix',
      'private',
      'public',
      'required',
      'static',
      'unowned',
      'weak',
    ],
    baseTag: Tags.modifierKeyword,
  );

  Matcher _asyncKeywords() => Matcher.keywords(
    [
      'actor',
      'async',
      'await',
    ],
    baseTag: Tags.controlKeyword,
  );

  Matcher _exceptionKeywords() => Matcher.keywords(
    [
      'catch',
      'rethrows',
      'throw',
      'throws',
      'try',
    ],
    baseTag: Tags.controlKeyword,
  );

  Matcher _otherKeywords() => Matcher.keywords(
    [
      'Any',
      'Self',
      'as',
      'is',
      'nil',
      'self',
      'some',
      'super',
    ],
    baseTag: Tags.keyword,
  );

  Matcher _literals() => Matcher.options([
    Matcher.include(_booleanLiterals),
    Matcher.include(_nilLiteral),
    Matcher.include(_numberLiterals),
  ]);

  Matcher _booleanLiterals() => Matcher.options([
    Matcher.regex(r'\btrue\b', tag: Tags.trueLiteral),
    Matcher.regex(r'\bfalse\b', tag: Tags.falseLiteral),
  ]);

  Matcher _nilLiteral() => Matcher.regex(r'\bnil\b', tag: Tags.nullLiteral);

  Matcher _numberLiterals() => Matcher.options([
    Matcher.regex(r'\b0x[0-9a-fA-F_]+\b', tag: Tags.integerLiteral),
    Matcher.regex(r'\b0b[01_]+\b', tag: Tags.integerLiteral),
    Matcher.regex(r'\b0o[0-7_]+\b', tag: Tags.integerLiteral),
    Matcher.regex(
      r'\b\d[\d_]*\.[\d_]+([eE][+-]?\d[\d_]*)?\b',
      tag: Tags.floatLiteral,
    ),
    Matcher.regex(
      r'\b\d[\d_]*[eE][+-]?\d[\d_]*\b',
      tag: Tags.floatLiteral,
    ),
    Matcher.regex(r'\b\d[\d_]*\b', tag: Tags.integerLiteral),
  ]);

  Matcher _attributes() => Matcher.options([
    Matcher.regex(r'@[a-zA-Z_][a-zA-Z0-9_]*', tag: Tags.annotation),
    Matcher.regex(
      r'#(available|unavailable|selector|keyPath|colorLiteral|'
      r'imageLiteral|fileLiteral|file|fileID|filePath|line|column|'
      r'function|dsohandle)\b',
      tag: Tags.preprocessor,
    ),
    Matcher.regex(r'#[a-zA-Z_][a-zA-Z0-9_]*', tag: Tags.annotation),
  ]);

  Matcher _types() => Matcher.options([
    Matcher.include(_builtInTypes),
    Matcher.include(_typeIdentifiers),
  ]);

  Matcher _builtInTypes() => Matcher.builtInTypes([
    'Any',
    'AnyObject',
    'Array',
    'Bool',
    'Character',
    'ClosedRange',
    'Dictionary',
    'Double',
    'Error',
    'Float',
    'Int',
    'Int16',
    'Int32',
    'Int64',
    'Int8',
    'Optional',
    'Range',
    'Result',
    'Set',
    'String',
    'Substring',
    'UInt',
    'UInt16',
    'UInt32',
    'UInt64',
    'UInt8',
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
      r'\.\.\.|\.\.<?|===|!==|<=|>=|==|!=|&&|\|\||->|=>|\?\?|~=',
      tag: Tags.operator,
    ),
    Matcher.regex(r'[+\-*/%&|^~<>=!?:]', tag: Tags.operator),
    Matcher.regex(r'[{}()\[\],.;]', tag: Tags.punctuation),
    Matcher.regex(r'\.', tag: Tags.accessor),
  ]);

  Matcher _identifiers() => Matcher.options([
    Matcher.regex(
      r'\$[a-zA-Z_][a-zA-Z0-9_]*',
      tag: const Tag('property-wrapper', parent: Tags.property),
    ),
    Matcher.regex(
      r'_[a-zA-Z_][a-zA-Z0-9_]*',
      tag: const Tag('backing', parent: Tags.property),
    ),
    Matcher.regex(r'\$\d+', tag: Tags.parameter),
    Matcher.regex(r'`[^`]+`', tag: Tags.identifier),
    Matcher.regex(
      r'\b[A-Z][A-Z0-9_]+\b',
      tag: const Tag('constant', parent: Tags.specialIdentifier),
    ),
    Matcher.regex(r'\b[a-z_][a-zA-Z0-9_]*\b', tag: Tags.identifier),
  ]);
}
