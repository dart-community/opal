import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';
import 'css_shared.dart';
import 'sass_base.dart';

/// A lexical grammar for SCSS.
@internal
final class ScssGrammar extends SassBaseGrammar {
  const ScssGrammar();

  // Every branch begins with a distinct character so scanning stays linear.
  // Stopping at `//` keeps a trailing comment containing `{` from
  // tripping the nested-selector guard.
  static const String _declarationValueItemPattern =
      '(?:${StylesheetTokens.closedCommentPattern}|'
      '${SassBaseGrammar.inlineInterpolationPattern}|'
      '${StylesheetTokens.doubleQuotedValuePattern}|'
      '${StylesheetTokens.singleQuotedValuePattern}|'
      '${StylesheetTokens.escapePattern}|'
      '/(?![/*])|#(?!\\{)|'
      r'''[^;{}"'/\\#]'''
      ')';

  // Avoid treating nested selectors such as `a:hover {}` as declarations.
  // The lookahead stops at `;`, `{`, `}`, or `//` outside strings and comments.
  // A trailing `,` also marks a selector list that continues on the next line,
  // such as `li:first-child,` before `li:last-child {`.
  // This only applies without a space after the colon,
  // so `font-family: Arial,` still starts a multi-line declaration.
  static const String _declarationValueGuard =
      '(?!$_declarationValueItemPattern*(?:\\{|,[ \\t]*\$))';

  @override
  List<Matcher> get matchers => [
    Matcher.include(_stylesheet),
  ];

  @override
  String get statementEnd => ';';

  // Start declarations only after whitespace, `;`, or `{`.
  // Otherwise each `#{` in a long run of interpolations would
  // start its own scan for a declaration's colon, making the line quadratic.
  @override
  String get lineStartPrefix => r'(?<![^\s;{])';

  // Accept whitespace, `{`, or line end immediately after `:` so
  // nested properties such as
  // `font: { ... }` and `border: 1px solid { ... }` match,
  // while still allowing tight declarations such as `color:red;` and
  // rejecting nested selectors such as `a:hover {` and `p::before {`.
  @override
  String get propertyAfterColon =>
      '(?!:)(?=[ \\t\\f{]|\$|$_declarationValueGuard)';

  Matcher _stylesheet() => Matcher.options([
    SassBaseGrammar.whitespace,
    Matcher.include(comments),
    Matcher.include(atRules),
    Matcher.include(variableDeclarations),
    Matcher.include(_block),
    Matcher.include(selectorContent),
  ]);

  Matcher _blockContent() => Matcher.options([
    SassBaseGrammar.whitespace,
    Matcher.include(comments),
    Matcher.include(atRules),
    Matcher.include(variableDeclarations),
    // Property declarations must precede blocks and selectors because
    // `color: red;` and `a:hover {}` share the same initial token shape.
    Matcher.include(propertyDeclarations),
    Matcher.include(_block),
    Matcher.include(selectorContent),
  ]);

  Matcher _block() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '{',
      tag: const Tag('begin', parent: Tags.punctuation),
    ),
    end: Matcher.verbatim(
      '}',
      tag: const Tag('end', parent: Tags.punctuation),
    ),
    content: Matcher.include(_blockContent),
  );
}
