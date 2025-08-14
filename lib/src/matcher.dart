import 'package:meta/meta.dart';

import 'tag.dart';

/// Base class for defining a complete grammar of [matchers] for
/// turning source of a language or format into tagged tokens.
///
/// A grammar combines multiple [Matcher] instances to define
/// syntax highlighting rules for a specific language.
///
/// Subclasses should override [matchers] to provide the core matching rules.
///
/// [preAppliedMatchers] and [postAppliedMatchers] can also be specified
/// for rules that should be processed before or after the top-level matchers
/// and the matchers from an [Matcher.options] matcher.
abstract base class MatcherGrammar {
  /// Creates a new matcher grammar.
  const MatcherGrammar();

  /// The top-level collection of matchers that define the grammar rules.
  @useResult
  List<Matcher> get matchers;

  /// Matchers that are applied before the top-level [matchers]
  /// as well as before the matchers from an [Matcher.options] matcher.
  ///
  /// These are useful for preprocessing or handling special cases
  /// that should take precedence over normal grammar rules.
  ///
  /// Defaults to no pre-applied matchers.
  List<Matcher> get preAppliedMatchers => [];

  /// Matchers that are applied after the top-level [matchers]
  /// as well as after the matchers from an [Matcher.options] matcher.
  ///
  /// These typically handle common elements like whitespace that
  /// should be processed last.
  ///
  /// Defaults to handling whitespace matching.
  List<Matcher> get postAppliedMatchers => [
    Matcher.regex(r'[\s\t]+', tag: Tags.whitespace),
  ];
}

/// A pattern matcher that can identify and tag specific text patterns.
///
/// Matchers are used to define syntax highlighting rules for
/// different programming languages and text formats.
/// Each matcher can optionally be associated with a [Tag] that defines how
/// the matched text should be styled or categorized.
///
/// Use one of the provided factory constructors to create a matcher that
/// corresponds to your desired matching functionality:
///
/// - [Matcher.regex]
/// - [Matcher.verbatim]
/// - [Matcher.capture]
/// - [Matcher.wrapped]
/// - [Matcher.options]
/// - [Matcher.include]
///
/// There are also a few utility matchers that help with
/// common use cases such as matching a large set of patterns:
///
/// - [Matcher.keywords]
/// - [Matcher.builtInTypes]
sealed class Matcher {
  /// An optional tag associated with this matcher.
  ///
  /// When this matcher successfully identifies a pattern,
  /// the matched text is be tagged with this [Tag].
  final Tag? tag;

  /// Creates a new matcher with an optional [tag].
  Matcher({this.tag});

  /// Creates a matcher that matches with a Dart [RegExp]
  /// created from the specified regular expression [pattern].
  ///
  /// The regular expression is created with the
  /// [RegExp.isUnicode] and [RegExp.isMultiLine] flags enabled.
  ///
  /// The optional [tag] is applied to any text that matches the pattern.
  ///
  /// Usage example:
  ///
  /// ```dart
  /// // Match single-line comments.
  /// Matcher.regex(r'//.*$', tag: Tags.lineComment)
  /// ```
  factory Matcher.regex(String pattern, {Tag? tag}) => PatternMatcher._(
    pattern: RegExp(pattern, unicode: true, multiLine: true),
    tag: tag,
  );

  /// Creates a matcher that matches the exact literal [pattern].
  ///
  /// Unlike [Matcher.regex], this performs exact string matching without
  /// any regular expression interpretation.
  ///
  /// The optional [tag] is applied to any text that matches the pattern.
  ///
  /// Usage example:
  ///
  /// ```dart
  /// // Match the exact keyword "function".
  /// Matcher.verbatim('function', tag: Tags.keyword)
  /// ```
  factory Matcher.verbatim(String pattern, {Tag? tag}) =>
      PatternMatcher._(pattern: pattern, tag: tag);

  /// Creates a matcher that captures groups with a Dart [RegExp]
  /// created from the specified regular expression [pattern].
  ///
  /// Each capture group in the [pattern] is be tagged with
  /// the corresponding [Tag] from the [captures] list.
  /// The number of items in [captures] should
  /// match the number of capture groups in the pattern.
  ///
  /// The optional [tag] is applied to the entire span of text matched.
  ///
  /// Usage example:
  ///
  /// ```dart
  /// // Capture function names and parameters separately.
  /// Matcher.capture(
  ///   RegExp(r'(\w+)\s*\((.*)\)'),
  ///   captures: [Tags.function, Tags.parameter],
  /// )
  /// ```
  factory Matcher.capture(
    String pattern, {
    required List<Tag> captures,
    Tag? tag,
  }) => CaptureMatcher._(
    pattern: RegExp(pattern, unicode: true, multiLine: true),
    captures: captures,
    tag: tag,
  );

  /// Creates a matcher for content wrapped between [begin] and [end] matchers.
  ///
  /// This is useful for matching constructs such as strings or comments that
  /// have distinct start and end delimiters or span across multiple-lines.
  ///
  /// The [content] matcher defines how to
  /// match the text between the delimiters.
  ///
  /// The optional [tag] applies to the entire wrapped construct.
  ///
  /// Usage example:
  ///
  /// ```dart
  /// // Match strings wrapped in double quotes.
  /// Matcher.wrapped(
  ///   begin: Matcher.verbatim('"'),
  ///   end: Matcher.verbatim('"'),
  ///   content: Matcher.regex(r'[^"]*'),
  ///   tag: Tags.string,
  /// )
  /// ```
  factory Matcher.wrapped({
    required Matcher begin,
    required Matcher end,
    required Matcher content,
    Tag? tag,
  }) => WrappedMatcher._(begin: begin, end: end, content: content, tag: tag);

  /// Creates a matcher that tries multiple alternative [matchers].
  ///
  /// The matcher attempts to match each of the provided [matchers]
  /// in the specified order until one succeeds.
  ///
  /// This can be useful for defining groups of related patterns,
  /// such as keywords or operators.
  ///
  /// The optional [tag] applies when any of the alternative matchers succeed.
  ///
  /// Usage example:
  ///
  /// ```dart
  /// // Match various loop keywords.
  /// Matcher.options([
  ///   Matcher.verbatim('for'),
  ///   Matcher.verbatim('while'),
  ///   Matcher.verbatim('do'),
  /// ], tag: Tags.keyword)
  /// ```
  factory Matcher.options(List<Matcher> matchers, {Tag? tag}) =>
      OptionsMatcher._(matchers: matchers, tag: tag);

  /// Creates a matcher that lazily includes the
  /// matcher returned by [matchGenerator].
  ///
  /// This is useful for creating recursive or self-referential grammar rules.
  /// The [matchGenerator] function is called when the matcher is needed,
  /// allowing for forward references and circular dependencies.
  ///
  /// The optional [tag] applies to matches from the generated matcher.
  ///
  /// Usage example:
  ///
  /// ```dart
  /// // Reference a matcher that might recursively include this one.
  /// Matcher.include(() => expressionMatcher, tag: Tags.expression)
  /// ```
  factory Matcher.include(Matcher Function() matchGenerator, {Tag? tag}) =>
      IncludeMatcher._(matchGenerator: matchGenerator, tag: tag);

  /// Creates a matcher for a list of language keywords,
  /// such as `class`, `if`, and `for`.
  ///
  /// Each keyword in the list is matched as a whole word and
  /// tagged with a tag of the keyword name and [baseTag] as the parent.
  ///
  /// Usage example:
  ///
  /// ```dart
  /// // Match common programming keywords.
  /// Matcher.keywords([
  ///   'if', 'else', 'while', 'for', 'return'
  /// ], baseTag: Tags.keyword)
  /// ```
  factory Matcher.keywords(
    List<String> keywords, {
    Tag baseTag = Tags.keyword,
  }) => OptionsMatcher._(
    matchers: [
      for (final keyword in keywords)
        Matcher.regex(
          '\\b$keyword\\b',
          tag: Tag(keyword, parent: baseTag),
        ),
    ],
  );

  /// Creates a matcher for a list of built-in type names.
  ///
  /// Each type name in is matched as a whole word and
  /// tagged with [Tags.builtInType] or the specified [tag].
  /// Unlike [Matcher.keywords], all types share the same tag.
  ///
  /// Usage example:
  ///
  /// ```dart
  /// // Match primitive types in a language.
  /// Matcher.builtInTypes([
  ///   'int', 'string', 'bool', 'double'
  /// ], tag: Tags.builtInType)
  /// ```
  factory Matcher.builtInTypes(
    List<String> builtInTypes, {
    Tag tag = Tags.builtInType,
  }) => OptionsMatcher._(
    matchers: [
      for (final builtInType in builtInTypes)
        Matcher.regex(
          '\\b$builtInType\\b',
          tag: tag,
        ),
    ],
  );
}

@internal
final class PatternMatcher extends Matcher {
  final Pattern pattern;

  PatternMatcher._({required this.pattern, super.tag});
}

@internal
final class CaptureMatcher extends Matcher {
  final RegExp pattern;
  final List<Tag> captures;

  CaptureMatcher._({
    required this.pattern,
    required this.captures,
    super.tag,
  });
}

@internal
final class WrappedMatcher extends Matcher {
  final Matcher begin;
  final Matcher end;

  final Matcher content;

  WrappedMatcher._({
    required this.begin,
    required this.end,
    required this.content,
    super.tag,
  });
}

@internal
final class OptionsMatcher extends Matcher {
  final List<Matcher> matchers;
  final bool includeDefaultRules;

  OptionsMatcher._({
    required this.matchers,
    super.tag,
    // ignore: unused_element_parameter
    this.includeDefaultRules = true,
  });
}

@internal
final class IncludeMatcher extends Matcher {
  final Matcher Function() matchGenerator;

  IncludeMatcher._({required this.matchGenerator, super.tag = Tags.unknown});
}
