import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

/// Shared lexical patterns and tags for CSS-based stylesheet grammars.
@internal
abstract final class StylesheetTokens {
  // Keep reusable patterns non-capturing so they can safely be interpolated
  // into `Matcher.capture` expressions.
  // Hex escapes must consume up to six digits and
  // their optional whitespace terminator greedily.
  // Allowing either to backtrack makes declaration lookaheads slow on
  // incomplete escaped names or strings.
  static const String escapePattern =
      r'\\(?:(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{1,5}(?![0-9a-fA-F]))'
      r'(?:[ \t\f]|(?![ \t\f]))|[^\r\n0-9a-fA-F])';
  static const String _nonAsciiPattern = r'[^\x00-\x7f]';
  static const String _nameStartPattern =
      '(?:[_a-zA-Z]|$_nonAsciiPattern|$escapePattern)';
  static const String nameContinuePattern =
      '(?:[-_a-zA-Z0-9]|$_nonAsciiPattern|$escapePattern)';
  static const String identifierPattern =
      '(?:--|-?$_nameStartPattern)$nameContinuePattern*';
  static const String customIdentifierPattern = '--$nameContinuePattern+';
  static const String closedCommentPattern = r'/\*(?:[^*]|\*(?!/))*\*/';
  static const String doubleQuotedValuePattern =
      '"(?:$escapePattern|[^"\\\\])*"';
  static const String singleQuotedValuePattern =
      "'(?:$escapePattern|[^'\\\\])*'";

  /// Horizontal whitespace and closed block comments allowed
  /// between a declaration name and its colon.
  static const String declarationTriviaPattern =
      '(?:[ \\t\\f]|$closedCommentPattern)*';
  static const String _numberPattern =
      r'[+-]?(?:(?:[0-9]*\.[0-9]+)|[0-9]+)'
      r'(?:[eE][+-]?[0-9]+)?';

  static const Tag atRuleTag = Tag('at-rule', parent: Tags.keyword);
  static const Tag _colorTag = Tag('color', parent: Tags.literal);
  static const Tag _unitTag = Tag('unit', parent: Tags.keyword);
  static const Tag importantTag = Tag(
    'important',
    parent: Tags.modifierKeyword,
  );
  static const Tag customPropertyTag = Tag('custom', parent: Tags.property);
  static const Tag _customVariableTag = Tag('custom', parent: Tags.variable);

  static const Tag selectorTag = Tag('selector', parent: Tags.identifier);
  static const Tag _typeSelectorTag = Tag('type', parent: selectorTag);
  static const Tag _universalTag = Tag('universal', parent: selectorTag);
  static const Tag _classSelectorTag = Tag('class', parent: selectorTag);
  static const Tag _idSelectorTag = Tag('id', parent: selectorTag);
  static const Tag attributeTag = Tag('attribute', parent: selectorTag);
  static const Tag attributeFlagTag = Tag(
    'flag',
    parent: Tags.modifierKeyword,
  );
  static const Tag _pseudoTag = Tag('pseudo', parent: selectorTag);
  static const Tag pseudoClassTag = Tag('class', parent: _pseudoTag);
  static const Tag pseudoElementTag = Tag('element', parent: _pseudoTag);
  static const Tag nestingTag = Tag('nesting', parent: selectorTag);

  // Leaf matchers that CSS, SCSS, and Sass tokenize identically.

  static final Matcher stringEscape = Matcher.regex(
    '(?:$escapePattern|'
    r'\\$'
    ')',
    tag: Tags.stringEscape,
  );

  static final Matcher unicodeRange = Matcher.regex(
    r'[uU]\+[0-9a-fA-F?]{1,6}(?:-[0-9a-fA-F]{1,6})?',
    tag: Tags.numberLiteral,
  );

  static final Matcher colorLiteral = Matcher.regex(
    r'#(?:[0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{4}|'
    '[0-9a-fA-F]{3})(?!$nameContinuePattern)',
    tag: _colorTag,
  );

  static final Matcher hashValue = Matcher.regex(
    '#$nameContinuePattern+',
    tag: const Tag('hash', parent: Tags.literal),
  );

  static final Matcher dimension = Matcher.capture(
    '($_numberPattern)'
    '((?![eE][+-]?[0-9])$identifierPattern)',
    captures: [Tags.numberLiteral, _unitTag],
  );

  static final Matcher percentage = Matcher.capture(
    '($_numberPattern)(%)',
    captures: [Tags.numberLiteral, _unitTag],
  );

  static final Matcher numberLiteral = Matcher.regex(
    _numberPattern,
    tag: Tags.numberLiteral,
  );

  static final Matcher customPropertyReference = Matcher.regex(
    customIdentifierPattern,
    tag: _customVariableTag,
  );

  static final Matcher cssWideKeywords = Matcher.options([
    for (final keyword in const [
      'inherit',
      'initial',
      'revert',
      'revert-layer',
      'unset',
    ])
      Matcher.regex(
        '$keyword(?!$nameContinuePattern)',
        tag: Tag(keyword, parent: Tags.keyword),
        caseSensitive: false,
      ),
  ]);

  static final Matcher featureName = Matcher.capture(
    '($identifierPattern)(:)(?!:)',
    captures: [Tags.identifier, Tags.separator],
  );

  static final Matcher classSelector = Matcher.capture(
    '(\\.)($identifierPattern)',
    captures: [Tags.punctuation, _classSelectorTag],
  );

  static final Matcher idSelector = Matcher.capture(
    '(#)($identifierPattern)',
    captures: [Tags.punctuation, _idSelectorTag],
  );

  static final Matcher pseudoSelectors = Matcher.options([
    Matcher.capture(
      '(::)($identifierPattern)',
      captures: [Tags.punctuation, pseudoElementTag],
    ),
    Matcher.capture(
      '(:)($identifierPattern)',
      captures: [Tags.punctuation, pseudoClassTag],
    ),
  ]);

  static final Matcher selectorCombinators = Matcher.options([
    Matcher.verbatim('||', tag: Tags.operator),
    Matcher.regex(r'[>+~]', tag: Tags.operator),
  ]);

  static final Matcher universalSelector = Matcher.verbatim(
    '*',
    tag: _universalTag,
  );

  static final Matcher namespaceSeparator = Matcher.verbatim(
    '|',
    tag: Tags.punctuation,
  );

  static final Matcher typeSelector = Matcher.regex(
    identifierPattern,
    tag: _typeSelectorTag,
  );

  static final Matcher identifier = Matcher.regex(
    identifierPattern,
    tag: Tags.identifier,
  );

  static final Matcher punctuation = Matcher.options([
    Matcher.regex(r'[:,;]', tag: Tags.separator),
    Matcher.regex(r'[{}()\[\]#@]', tag: Tags.punctuation),
    Matcher.verbatim('.', tag: Tags.accessor),
  ]);
}
