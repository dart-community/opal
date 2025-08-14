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
    Matcher.include(_multilineString),
    Matcher.include(_interpolatedString),
    Matcher.include(_rawString),
    Matcher.include(_singleQuotedString),
  ]);

  Matcher _multilineString() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '"""',
      tag: const Tag('begin', parent: Tags.stringLiteral),
    ),
    end: Matcher.verbatim(
      '"""',
      tag: const Tag('end', parent: Tags.stringLiteral),
    ),
    content: Matcher.options(
      [
        Matcher.regex(r'\\\(.*?\)', tag: Tags.stringInterpolation),
        Matcher.regex(
          r'[\s\S]*?',
        ),
      ],
      tag: Tags.stringContent,
    ),
    tag: Tags.stringLiteral,
  );

  Matcher _interpolatedString() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '"',
      tag: const Tag('begin', parent: Tags.stringLiteral),
    ),
    end: Matcher.verbatim(
      '"',
      tag: const Tag('end', parent: Tags.stringLiteral),
    ),
    content: Matcher.options(
      [
        Matcher.regex(r'\\\(.*?\)', tag: Tags.stringInterpolation),
        Matcher.regex(r"""\\[nrtbf"'\\]""", tag: Tags.stringEscape),
        Matcher.regex(r'\\u\{[0-9a-fA-F]+\}', tag: Tags.stringEscape),
        Matcher.regex(
          r'[^"\\]+',
        ),
      ],
      tag: Tags.stringContent,
    ),
    tag: Tags.stringLiteral,
  );

  Matcher _rawString() => Matcher.options([
    Matcher.regex(r'#"[^"]*"#', tag: Tags.stringLiteral),
    Matcher.regex(r'##"[^"]*"##', tag: Tags.stringLiteral),
    Matcher.regex(r'###"""[\s\S]*?"""###', tag: Tags.stringLiteral),
    Matcher.regex(r'##"""[\s\S]*?"""##', tag: Tags.stringLiteral),
    Matcher.regex(r'#"""[\s\S]*?"""#', tag: Tags.stringLiteral),
  ]);

  Matcher _singleQuotedString() => Matcher.wrapped(
    begin: Matcher.verbatim(
      "'",
      tag: const Tag('begin', parent: Tags.stringLiteral),
    ),
    end: Matcher.verbatim(
      "'",
      tag: const Tag('end', parent: Tags.stringLiteral),
    ),
    content: Matcher.options(
      [
        Matcher.regex(r"""\\[nrtbf"'\\]""", tag: Tags.stringEscape),
        Matcher.regex(r'\\u\{[0-9a-fA-F]+\}', tag: Tags.stringEscape),
        Matcher.regex(
          r"[^'\\]",
        ),
      ],
      tag: Tags.stringContent,
    ),
    tag: Tags.stringLiteral,
  );

  Matcher _keywords() => Matcher.options([
    Matcher.include(_controlKeywords),
    Matcher.include(_declarationKeywords),
    Matcher.include(_modifierKeywords),
    Matcher.include(_asyncKeywords),
    Matcher.include(_exceptionKeywords),
    Matcher.include(_otherKeywords),
  ]);

  Matcher _controlKeywords() => Matcher.keywords([
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
  ]);

  Matcher _declarationKeywords() => Matcher.keywords([
    'associatedtype',
    'class',
    'deinit',
    'enum',
    'extension',
    'func',
    'import',
    'init',
    'let',
    'operator',
    'precedencegroup',
    'protocol',
    'struct',
    'subscript',
    'typealias',
    'var',
  ]);

  Matcher _modifierKeywords() => Matcher.keywords([
    'convenience',
    'dynamic',
    'final',
    'indirect',
    'infix',
    'lazy',
    'mutating',
    'nonmutating',
    'optional',
    'override',
    'postfix',
    'prefix',
    'required',
    'static',
    'unowned',
    'weak',
    'private',
    'fileprivate',
    'internal',
    'public',
    'open',
    'isolated',
    'nonisolated',
  ]);

  Matcher _asyncKeywords() => Matcher.keywords([
    'async',
    'await',
    'actor',
  ]);

  Matcher _exceptionKeywords() => Matcher.keywords([
    'catch',
    'rethrows',
    'throw',
    'throws',
    'try',
  ]);

  Matcher _otherKeywords() => Matcher.keywords([
    'as',
    'is',
    'nil',
    'self',
    'Self',
    'super',
    'Any',
    'some',
  ]);

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
    Matcher.regex(r'\b0x[0-9a-fA-F_]+\b', tag: Tags.numberLiteral),
    Matcher.regex(r'\b0b[01_]+\b', tag: Tags.numberLiteral),
    Matcher.regex(r'\b0o[0-7_]+\b', tag: Tags.numberLiteral),
    Matcher.regex(
      r'\b\d[\d_]*\.[\d_]+([eE][+-]?\d[\d_]*)?\b',
      tag: Tags.numberLiteral,
    ),
    Matcher.regex(r'\b\d[\d_]*([eE][+-]?\d[\d_]*)?\b', tag: Tags.numberLiteral),
  ]);

  Matcher _attributes() => Matcher.options([
    Matcher.regex(r'@\w+', tag: Tags.annotation),
    Matcher.regex(r'#\w+', tag: Tags.annotation),
  ]);

  Matcher _types() => Matcher.options([
    Matcher.include(_primitiveTypes),
    Matcher.include(_builtInTypes),
    Matcher.include(_typeIdentifiers),
  ]);

  Matcher _primitiveTypes() => Matcher.keywords([
    'Bool',
    'Double',
    'Float',
    'Int',
    'Int8',
    'Int16',
    'Int32',
    'Int64',
    'String',
    'UInt',
    'UInt8',
    'UInt16',
    'UInt32',
    'UInt64',
    'Void',
  ]);

  Matcher _builtInTypes() => Matcher.builtInTypes([
    'Array',
    'Character',
    'ClosedRange',
    'Dictionary',
    'Error',
    'Optional',
    'Range',
    'Result',
    'Set',
    'Substring',
  ]);

  Matcher _typeIdentifiers() =>
      Matcher.regex(r'\b[A-Z][a-zA-Z0-9_]*\b', tag: Tags.type);

  Matcher _operators() => Matcher.options([
    Matcher.regex(
      r'\.\.\.|\.\.<?|===|!==|<=|>=|==|!=|&&|\|\||->|=>|\?\?|!',
      tag: Tags.operator,
    ),
    Matcher.regex(r'[+\-*/%&|^~<>=!?:]', tag: Tags.operator),
    Matcher.regex(r'[{}()\[\],.;]', tag: Tags.punctuation),
  ]);

  Matcher _identifiers() => Matcher.options([
    Matcher.regex(r'\b[a-z_][a-zA-Z0-9_]*\b', tag: Tags.identifier),
    Matcher.regex(r'\$\d+', tag: Tags.specialIdentifier),
    Matcher.regex(r'`[^`]+`', tag: Tags.identifier),
  ]);
}
