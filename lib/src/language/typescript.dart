import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';
import 'ecma_script.dart';

@internal
final class TypeScriptGrammar extends EcmaScriptGrammar {
  const TypeScriptGrammar();

  @override
  List<Matcher> get matchers => [
    Matcher.include(_comments),
    Matcher.include(strings),
    Matcher.include(_decorators),
    Matcher.include(_namedDeclarations),
    Matcher.include(_builtInTypes),
    Matcher.include(_typescriptKeywords),
    Matcher.include(javascriptKeywords),
    Matcher.include(literals),
    Matcher.include(_typeIdentifiers),
    Matcher.include(_constructors),
    Matcher.include(_functions),
    Matcher.include(privateIdentifiers),
    Matcher.include(operators),
    Matcher.include(identifiers),
  ];

  Matcher _comments() => Matcher.options([
    Matcher.include(_tripleSlashDirectives),
    Matcher.include(_typeScriptDirectives),
    Matcher.include(_documentationComments),
    Matcher.include(comments),
  ]);

  Matcher _tripleSlashDirectives() => Matcher.regex(
    r'^///\s*<(?:reference|amd-module|amd-dependency)\b[^>]*\/?>\s*$',
    tag: Tags.preprocessor,
  );

  Matcher _typeScriptDirectives() => Matcher.options([
    Matcher.regex(
      r'///?\s*@ts-(?:check|nocheck|ignore|expect-error)\b.*$',
      tag: Tags.preprocessorDirective,
    ),
    Matcher.regex(
      r'/\*\s*@ts-(?:ignore|expect-error)\b.*?\*/',
      tag: Tags.preprocessorDirective,
    ),
  ]);

  Matcher _documentationComments() => Matcher.options([
    Matcher.verbatim('/**/', tag: Tags.docComment),
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
          r'@[a-zA-Z][a-zA-Z0-9-]*',
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
        Matcher.verbatim(
          '@',
          tag: const Tag('content', parent: Tags.docComment),
        ),
      ], tag: const Tag('content', parent: Tags.docComment)),
      tag: Tags.docComment,
    ),
  ]);

  Matcher _decorators() => Matcher.regex(
    '@${EcmaScriptGrammar.identifierPattern}'
    '(?:\\.${EcmaScriptGrammar.identifierPattern})*'
    '${EcmaScriptGrammar.identifierRightBoundary}',
    tag: Tags.annotation,
  );

  Matcher _namedDeclarations() => Matcher.options([
    for (final keyword in [
      'class',
      'enum',
      'interface',
      'module',
      'namespace',
      'type',
    ])
      Matcher.capture(
        '(\\b$keyword\\b)(\\s+)(${EcmaScriptGrammar.identifierPattern})',
        captures: [
          Tag(keyword, parent: Tags.declarationKeyword),
          Tags.whitespace,
          Tags.type,
        ],
      ),
  ]);

  Matcher _builtInTypes() => builtInTypeIdentifiers([
    'any',
    'bigint',
    'boolean',
    'intrinsic',
    'never',
    'number',
    'object',
    'string',
    'symbol',
    'undefined',
    'unknown',
    'void',
    'Array',
    'ArrayLike',
    'AsyncGenerator',
    'AsyncIterable',
    'AsyncIterableIterator',
    'AsyncIterator',
    'AsyncIteratorObject',
    'Date',
    'Error',
    'Function',
    'Generator',
    'Iterable',
    'IterableIterator',
    'Iterator',
    'IteratorObject',
    'Map',
    'Object',
    'Promise',
    'PromiseLike',
    'PropertyKey',
    'ReadonlyArray',
    'ReadonlyMap',
    'ReadonlySet',
    'RegExp',
    'Set',
    'TemplateStringsArray',
    'WeakMap',
    'WeakSet',
    'Awaited',
    'Capitalize',
    'ConstructorParameters',
    'Exclude',
    'Extract',
    'InstanceType',
    'Lowercase',
    'NoInfer',
    'NonNullable',
    'Omit',
    'OmitThisParameter',
    'Parameters',
    'Partial',
    'Pick',
    'Readonly',
    'Record',
    'Required',
    'ReturnType',
    'ThisParameterType',
    'ThisType',
    'Uncapitalize',
    'Uppercase',
  ]);

  Matcher _typescriptKeywords() => Matcher.options([
    Matcher.include(_declarationKeywords),
    Matcher.include(_modifierKeywords),
    Matcher.include(_typeOperatorKeywords),
    Matcher.include(_otherKeywords),
  ]);

  Matcher _declarationKeywords() => keywordIdentifiers(
    ['implements', 'interface', 'module', 'namespace', 'type'],
    baseTag: Tags.declarationKeyword,
  );

  Matcher _modifierKeywords() => keywordIdentifiers(
    [
      'abstract',
      'accessor',
      'declare',
      'out',
      'override',
      'private',
      'protected',
      'public',
      'readonly',
      'static',
    ],
    baseTag: Tags.modifierKeyword,
  );

  Matcher _typeOperatorKeywords() => keywordIdentifiers(
    [
      'as',
      'asserts',
      'in',
      'infer',
      'is',
      'keyof',
      'satisfies',
      'typeof',
      'unique',
    ],
    baseTag: Tags.operator,
  );

  Matcher _otherKeywords() =>
      keywordIdentifiers(['assert', 'defer', 'global', 'require']);

  Matcher _typeIdentifiers() => Matcher.regex(
    '${EcmaScriptGrammar.identifierLeftBoundary}'
    '[A-Z]${EcmaScriptGrammar.identifierContinue}*'
    '${EcmaScriptGrammar.identifierRightBoundary}',
    tag: Tags.type,
  );

  Matcher _constructors() => Matcher.regex(
    '${EcmaScriptGrammar.identifierLeftBoundary}constructor'
    '${EcmaScriptGrammar.identifierRightBoundary}'
    r'(?=\s*\()',
    tag: Tags.constructor,
  );

  Matcher _functions() => Matcher.regex(
    '${EcmaScriptGrammar.identifierLeftBoundary}'
    '${EcmaScriptGrammar.identifierPattern}'
    '${EcmaScriptGrammar.identifierRightBoundary}'
    r'(?=\s*(?:<(?:[^<>]|<[^<>]*>)*>\s*)?\()',
    tag: Tags.function,
  );
}
