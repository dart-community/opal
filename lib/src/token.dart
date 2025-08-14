import 'tag.dart';

/// A token with [content] parsed from a larger string with
/// a corresponding set of [tags] determined at a specific context.
final class TaggedToken {
  /// The textual content of this token.
  final String content;

  /// The list of tags that correspond to the specified [content]
  /// in a specific context.
  ///
  /// Tags are ordered from least to most specific.
  final List<Tag> tags;

  /// Creates a new [TaggedToken] with the specified [content] and [tags].
  TaggedToken(this.content, Iterable<Tag> tags)
    : tags = List<Tag>.unmodifiable(tags);

  @override
  String toString() {
    return content;
  }
}
