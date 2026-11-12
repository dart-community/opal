import 'package:meta/meta.dart';

import '../language.dart';
import '../tag.dart';
import '../token.dart';

/// Line-based highlighting for INI configuration files.
@internal
final class IniLanguage extends Language {
  const IniLanguage() : super('ini');

  static const Tag _base = Tag('ini', parent: Tags.dataSource);

  static const List<Tag> _whitespaceTags = [_base, Tags.whitespace];
  static const List<Tag> _commentTags = [_base, Tags.lineComment];
  static const List<Tag> _punctuationTags = [_base, Tags.punctuation];
  static const List<Tag> _nameTags = [_base, Tags.property];
  static const List<Tag> _separatorTags = [_base, Tags.separator];
  static const List<Tag> _unquotedTags = [_base, Tags.unquotedString];
  static const List<Tag> _doubleQuotedTags = [_base, Tags.doubleQuoteString];
  static const List<Tag> _singleQuotedTags = [_base, Tags.singleQuoteString];
  static const List<Tag> _unknownTags = [_base, Tags.unknown];

  static final RegExp _separator = RegExp('[=:]');
  static final RegExp _quotedValue = RegExp(
    r'''^(?:"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*')$''',
    dotAll: true,
  );

  /// A section header, optionally followed by a comment.
  ///
  /// Captures the whitespace around the name within the brackets,
  /// the name itself, and the whitespace and comment after the brackets.
  ///
  /// The name ends at the first `]` that ends the line or precedes a comment,
  /// so it can contain a `]` itself, as in `[[Mm]akefile]`,
  /// while a `]` within a trailing comment is left to the comment.
  /// The rest of the name is optional lazily (`??`),
  /// so a single-character name is tried first as well.
  static final RegExp _section = RegExp(
    r'^\[(\s*)(\S(?:.*?\S)??)(\s*)\](?:(\s*)([;#].*))?$',
    dotAll: true,
  );

  @override
  List<List<TaggedToken>> tokenize(List<String> content) => [
    for (final line in content) _tokenizeLine(line),
  ];

  static List<TaggedToken> _tokenizeLine(String line) {
    final tokens = <TaggedToken>[];

    final unindented = _takeLeadingWhitespace(tokens, line);
    final text = unindented.trimRight();
    if (text.isEmpty) return tokens;

    if (text.startsWith(';') || text.startsWith('#')) {
      _add(tokens, text, _commentTags);
    } else if (text.startsWith('[')) {
      final section = _section.firstMatch(text);
      if (section != null) {
        _add(tokens, '[', _punctuationTags);
        _add(tokens, section[1]!, _whitespaceTags);
        _add(tokens, section[2]!, _nameTags);
        _add(tokens, section[3]!, _whitespaceTags);
        _add(tokens, ']', _punctuationTags);
        _add(tokens, section[4] ?? '', _whitespaceTags);
        _add(tokens, section[5] ?? '', _commentTags);
      } else {
        _add(tokens, text, _unknownTags);
      }
    } else {
      // Searching with `indexOf` would try the pattern at each index in turn.
      final separator = _separator.firstMatch(text)?.start ?? -1;
      if (separator > 0) {
        final before = text.substring(0, separator);
        final key = before.trimRight();
        _add(tokens, key, _nameTags);
        _add(tokens, before.substring(key.length), _whitespaceTags);
        _add(tokens, text[separator], _separatorTags);

        final value = _takeLeadingWhitespace(
          tokens,
          text.substring(separator + 1),
        );
        _add(tokens, value, _valueTags(value));
      } else {
        _add(tokens, text, _unknownTags);
      }
    }

    _add(tokens, unindented.substring(text.length), _whitespaceTags);
    return tokens;
  }

  /// Adds the whitespace that begins [text] to [tokens],
  /// returning the rest of [text].
  static String _takeLeadingWhitespace(List<TaggedToken> tokens, String text) {
    final rest = text.trimLeft();
    _add(tokens, text.substring(0, text.length - rest.length), _whitespaceTags);
    return rest;
  }

  static void _add(List<TaggedToken> tokens, String text, List<Tag> tags) {
    if (text.isNotEmpty) tokens.add(TaggedToken(text, tags));
  }

  static List<Tag> _valueTags(String value) {
    if (!_quotedValue.hasMatch(value)) return _unquotedTags;
    return value.startsWith('"') ? _doubleQuotedTags : _singleQuotedTags;
  }
}
