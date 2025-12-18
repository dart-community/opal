import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

@internal
final class GlslGrammar extends MatcherGrammar {
  const GlslGrammar();

  @override
  List<Matcher> get matchers => [
    Matcher.include(_preprocessor),
    Matcher.include(_comments),
    Matcher.include(_keywords),
    Matcher.include(_literals),
    Matcher.include(_types),
    Matcher.include(_functions),
    Matcher.include(_operators),
    Matcher.include(_identifiers),
  ];

  Matcher _preprocessor() => Matcher.capture(
    r'^(#)(version|extension|pragma|line|define|undef|if|ifdef|ifndef|'
    r'elif|else|endif|error)\b(.*)$',
    captures: [
      Tags.punctuation,
      const Tag('name', parent: Tags.preprocessorDirective),
      const Tag('options', parent: Tags.preprocessorDirective),
    ],
    tag: Tags.preprocessorDirective,
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

  Matcher _keywords() => Matcher.options([
    Matcher.include(_controlKeywords),
    Matcher.include(_declarationKeywords),
    Matcher.include(_modifierKeywords),
    Matcher.include(_storageKeywords),
    Matcher.include(_precisionKeywords),
    Matcher.include(_otherKeywords),
  ]);

  Matcher _controlKeywords() => Matcher.keywords(
    [
      'break',
      'case',
      'continue',
      'default',
      'discard',
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

  Matcher _declarationKeywords() => Matcher.keywords(
    [
      'struct',
    ],
    baseTag: Tags.declarationKeyword,
  );

  Matcher _modifierKeywords() => Matcher.keywords(
    [
      'const',
      'invariant',
      'precise',
    ],
    baseTag: Tags.modifierKeyword,
  );

  Matcher _storageKeywords() => Matcher.keywords(
    [
      'attribute',
      'buffer',
      'centroid',
      'coherent',
      'flat',
      'in',
      'inout',
      'layout',
      'noperspective',
      'out',
      'patch',
      'readonly',
      'restrict',
      'sample',
      'shared',
      'smooth',
      'subroutine',
      'uniform',
      'varying',
      'volatile',
      'writeonly',
    ],
    baseTag: const Tag('storage', parent: Tags.keyword),
  );

  Matcher _precisionKeywords() => Matcher.options([
    Matcher.regex(
      r'\bprecision\b',
      tag: const Tag('precision', parent: Tags.keyword),
    ),
    Matcher.keywords(
      [
        'highp',
        'lowp',
        'mediump',
      ],
      baseTag: const Tag('precision', parent: Tags.keyword),
    ),
  ]);

  Matcher _otherKeywords() => Matcher.keywords(
    [
      'demote',
    ],
    baseTag: Tags.keyword,
  );

  Matcher _literals() => Matcher.options([
    Matcher.include(_booleanLiterals),
    Matcher.include(_numberLiterals),
  ]);

  Matcher _booleanLiterals() => Matcher.options([
    Matcher.regex(r'\btrue\b', tag: Tags.trueLiteral),
    Matcher.regex(r'\bfalse\b', tag: Tags.falseLiteral),
  ]);

  Matcher _numberLiterals() => Matcher.options([
    Matcher.regex(
      r'\b0[xX][0-9a-fA-F]+[uU]?\b',
      tag: Tags.integerLiteral,
    ),
    Matcher.regex(
      r'\b\d+\.?\d*[eE][+-]?\d+\b',
      tag: Tags.floatLiteral,
    ),
    Matcher.regex(
      r'\b\d+\.\d+\b',
      tag: Tags.floatLiteral,
    ),
    Matcher.regex(r'\b\d+\.(?!\.)', tag: Tags.floatLiteral),
    Matcher.regex(r'\.\d+(?:[eE][+-]?\d+)?\b', tag: Tags.floatLiteral),
    Matcher.regex(r'\b\d+[uU]?\b', tag: Tags.integerLiteral),
  ]);

  Matcher _types() => Matcher.options([
    Matcher.include(_scalarTypes),
    Matcher.include(_vectorTypes),
    Matcher.include(_matrixTypes),
    Matcher.include(_samplerTypes),
    Matcher.include(_imageTypes),
    Matcher.include(_otherTypes),
    Matcher.include(_typeIdentifiers),
  ]);

  Matcher _scalarTypes() => Matcher.builtInTypes([
    'bool',
    'double',
    'float',
    'int',
    'uint',
    'void',
  ]);

  Matcher _vectorTypes() => Matcher.builtInTypes([
    'bvec2',
    'bvec3',
    'bvec4',
    'dvec2',
    'dvec3',
    'dvec4',
    'ivec2',
    'ivec3',
    'ivec4',
    'uvec2',
    'uvec3',
    'uvec4',
    'vec2',
    'vec3',
    'vec4',
  ]);

  Matcher _matrixTypes() => Matcher.builtInTypes([
    'dmat2',
    'dmat2x2',
    'dmat2x3',
    'dmat2x4',
    'dmat3',
    'dmat3x2',
    'dmat3x3',
    'dmat3x4',
    'dmat4',
    'dmat4x2',
    'dmat4x3',
    'dmat4x4',
    'mat2',
    'mat2x2',
    'mat2x3',
    'mat2x4',
    'mat3',
    'mat3x2',
    'mat3x3',
    'mat3x4',
    'mat4',
    'mat4x2',
    'mat4x3',
    'mat4x4',
  ]);

  Matcher _samplerTypes() => Matcher.builtInTypes([
    'isampler1D',
    'isampler1DArray',
    'isampler2D',
    'isampler2DArray',
    'isampler2DMS',
    'isampler2DMSArray',
    'isampler2DRect',
    'isampler3D',
    'isamplerBuffer',
    'isamplerCube',
    'isamplerCubeArray',
    'sampler',
    'sampler1D',
    'sampler1DArray',
    'sampler1DArrayShadow',
    'sampler1DShadow',
    'sampler2D',
    'sampler2DArray',
    'sampler2DArrayShadow',
    'sampler2DMS',
    'sampler2DMSArray',
    'sampler2DRect',
    'sampler2DRectShadow',
    'sampler2DShadow',
    'sampler3D',
    'samplerBuffer',
    'samplerCube',
    'samplerCubeArray',
    'samplerCubeArrayShadow',
    'samplerCubeShadow',
    'samplerShadow',
    'usampler1D',
    'usampler1DArray',
    'usampler2D',
    'usampler2DArray',
    'usampler2DMS',
    'usampler2DMSArray',
    'usampler2DRect',
    'usampler3D',
    'usamplerBuffer',
    'usamplerCube',
    'usamplerCubeArray',
  ]);

  Matcher _imageTypes() => Matcher.builtInTypes([
    'iimage1D',
    'iimage1DArray',
    'iimage2D',
    'iimage2DArray',
    'iimage2DMS',
    'iimage2DMSArray',
    'iimage2DRect',
    'iimage3D',
    'iimageBuffer',
    'iimageCube',
    'iimageCubeArray',
    'image1D',
    'image1DArray',
    'image2D',
    'image2DArray',
    'image2DMS',
    'image2DMSArray',
    'image2DRect',
    'image3D',
    'imageBuffer',
    'imageCube',
    'imageCubeArray',
    'uimage1D',
    'uimage1DArray',
    'uimage2D',
    'uimage2DArray',
    'uimage2DMS',
    'uimage2DMSArray',
    'uimage2DRect',
    'uimage3D',
    'uimageBuffer',
    'uimageCube',
    'uimageCubeArray',
  ]);

  Matcher _otherTypes() => Matcher.builtInTypes([
    'atomic_uint',
  ]);

  Matcher _typeIdentifiers() => Matcher.regex(
    r'\b[A-Z][a-zA-Z0-9_]*[a-z][a-zA-Z0-9_]*\b',
    tag: Tags.type,
  );

  Matcher _functions() => Matcher.regex(
    r'\b[a-zA-Z_][a-zA-Z0-9_]*(?=\s*\()',
    tag: Tags.function,
  );

  Matcher _operators() => Matcher.options([
    Matcher.regex(
      r'\+\+|--|<<|>>|<=|>=|==|!=|&&|\|\||\^\^',
      tag: Tags.operator,
    ),
    Matcher.regex(r'[+\-*/%&|^~<>=!?:]', tag: Tags.operator),
    Matcher.regex(r'[{}()\[\],;]', tag: Tags.punctuation),
    Matcher.regex(r'\.', tag: Tags.accessor),
  ]);

  Matcher _identifiers() => Matcher.options([
    Matcher.include(_builtInVariables),
    Matcher.regex(
      r'\b[A-Z][A-Z0-9_]+\b',
      tag: const Tag('constant', parent: Tags.specialIdentifier),
    ),
    Matcher.regex(r'\b[a-z_][a-zA-Z0-9_]*\b', tag: Tags.identifier),
  ]);

  Matcher _builtInVariables() => Matcher.options([
    Matcher.regex(
      r'\bgl_[A-Za-z_][A-Za-z0-9_]*\b',
      tag: const Tag('built-in', parent: Tags.variable),
    ),
  ]);
}
