import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';
import 'css_shared.dart';
import 'sass_base.dart';

/// A lexical grammar for Sass (indented syntax).
@internal
final class SassGrammar extends SassBaseGrammar {
  const SassGrammar();

  @override
  List<Matcher> get matchers => [
    Matcher.include(_stylesheet),
  ];

  // Statements terminate at the end of the line unless
  // a trailing comma continues a comma-separated list onto the next line.
  @override
  String get statementEnd => r'$(?<!,[ \t]*)';

  // Allow multi-line maps, lists, and `with (...)` blocks whose
  // lines end with `(`, `[`, or `,`,
  // while recovering on unclosed calls such as
  // `calc(100% - 2rem` at line end or before a blank line or top-level rule.
  @override
  String get lineRecovery => r'|$(?<![(\[,][ \t]*)|^(?=[ \t]*$|[^ \t)\]])';

  @override
  String get lineStartPrefix => r'(?<=^[ \t]*)';

  // Indented Sass requires whitespace or
  // a line break after `:` in property declarations,
  // which cleanly separates `color: red` and `font:` from
  // pseudo-class selectors such as `a:focus-visible` and `p::before`.
  @override
  String get propertyAfterColon => r'(?=[ \t\f]|$)';

  Matcher _stylesheet() => Matcher.options([
    SassBaseGrammar.whitespace,
    // Standalone comments also cover the lines indented beneath them,
    // so they end when a nonblank line returns to the opening indentation.
    // Comments inside expressions keep their usual extent.
    Matcher.select(
      '$lineStartPrefix//',
      (opening) => Matcher.wrapped(
        begin: Matcher.include(comments),
        end: Matcher.regex('^(?=[ \\t]{0,${opening.start}}\\S)'),
        content: Matcher.regex('.+', tag: Tags.lineComment),
      ),
    ),
    // A `*/` aligned with its `/*` still closes the comment
    // rather than ending it just before the closer.
    Matcher.select(
      '$lineStartPrefix/\\*',
      (opening) => loudComment(
        end: '\\*/|^(?=[ \\t]{0,${opening.start}}(?!\\*/)\\S)',
      ),
    ),
    Matcher.include(comments),
    Matcher.include(atRules),
    Matcher.include(_mixinShorthand),
    Matcher.include(_includeShorthand),
    Matcher.include(variableDeclarations),
    Matcher.include(propertyDeclarations),
    Matcher.include(selectorContent),
  ]);

  /// Indented-syntax `=name` mixin declaration shorthand.
  Matcher _mixinShorthand() =>
      mixinHeader('$lineStartPrefix(=)', const [StylesheetTokens.atRuleTag]);

  /// Indented-syntax `+name` and `+ns.name` mixin include shorthand.
  ///
  /// Requires the name directly after `+` with no intervening space so
  /// adjacent-sibling combinators such as `+ p` stay selectors.
  Matcher _includeShorthand() => includeHeader('$lineStartPrefix(\\+)', const [
    StylesheetTokens.atRuleTag,
  ]);
}
