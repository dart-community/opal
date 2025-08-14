import 'package:meta/meta.dart';

import 'token.dart';

/// A representation of a language that can be tokenized with [tokenize]
/// into an ordered list of tokens.
abstract base class Language {
  /// The name of this language.
  final String name;

  /// Creates a new [Language].
  const Language(this.name);

  /// Tokenize the specified [content]
  /// into an ordered list of tokens grouped by line.
  @useResult
  List<List<TaggedToken>> tokenize(List<String> content);
}
