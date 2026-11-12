import 'package:meta/meta.dart';

import '../language.dart';
import '../tag.dart';
import '../token.dart';

/// Line-based highlighting for Java `.properties` files.
///
/// Unlike most languages, this isn't implemented with matchers.
/// A line that ends in a backslash continues on the next line,
/// even in the middle of a key or between a key and its separator,
/// so each line resumes in the part of the entry where the last one ended.
@internal
final class PropertiesLanguage extends Language {
  const PropertiesLanguage() : super('properties');

  static const Tag _base = Tag('properties', parent: Tags.dataSource);

  static const List<Tag> _whitespaceTags = [_base, Tags.whitespace];
  static const List<Tag> _commentTags = [_base, Tags.lineComment];
  static const List<Tag> _keyTags = [_base, Tags.property];
  static const List<Tag> _keyEscapeTags = [..._keyTags, Tags.stringEscape];
  static const List<Tag> _separatorTags = [_base, Tags.separator];
  static const List<Tag> _valueTags = [_base, Tags.unquotedString];
  static const List<Tag> _valueEscapeTags = [..._valueTags, Tags.stringEscape];
  static const List<Tag> _continuationTags = [_base, Tags.stringEscape];

  /// Whitespace, which `Properties.load` limits to
  /// spaces, tabs, and form feeds.
  static final RegExp _whitespace = RegExp(r'[ \t\f]+');

  static final RegExp _comment = RegExp(r'[#!][\s\S]*');

  static final RegExp _separator = RegExp('[=:]');

  /// A backslash that ends the line, continuing it on the next line.
  static final RegExp _continuation = RegExp(r'\\$');

  /// A `\uXXXX` escape or any other escaped character,
  /// matched by code point to keep a surrogate pair together.
  ///
  /// A `\u` without four hex digits is malformed,
  /// so it's left as text.
  static final RegExp _escape = RegExp(
    r'\\(?:u[0-9a-fA-F]{4}|[^u])',
    unicode: true,
  );

  static final RegExp _keyText = RegExp(
    r'(?:[^\\=: \t\f]|\\u(?![0-9a-fA-F]{4}))+',
  );

  static final RegExp _valueText = RegExp(r'(?:[^\\]|\\u(?![0-9a-fA-F]{4}))+');

  /// A continuation keeps the current part,
  /// so the next line resumes where this one ended.
  static final _Rule _continuationRule = (
    _continuation,
    _continuationTags,
    null,
  );

  static final List<_Rule> _keyRules = [
    _continuationRule,
    (_escape, _keyEscapeTags, _Part.key),
    (_keyText, _keyTags, _Part.key),
    (_whitespace, _whitespaceTags, _Part.afterKey),
    (_separator, _separatorTags, _Part.beforeValue),
  ];

  static final List<_Rule> _valueRules = [
    _continuationRule,
    (_escape, _valueEscapeTags, _Part.value),
    (_valueText, _valueTags, _Part.value),
  ];

  /// The rules to try, in order, in each part of an entry.
  static final Map<_Part, List<_Rule>> _rules = {
    _Part.start: [
      (_comment, _commentTags, null),
      // A lone backslash leaves the logical line empty, so as with
      // `Properties.load`, a `#` or `!` on the next line begins a comment.
      ..._keyRules,
    ],
    _Part.key: _keyRules,
    _Part.afterKey: [
      (_whitespace, _whitespaceTags, null),
      (_separator, _separatorTags, _Part.beforeValue),
      ..._valueRules,
    ],
    _Part.beforeValue: [(_whitespace, _whitespaceTags, null), ..._valueRules],
    _Part.value: _valueRules,
  };

  @override
  List<List<TaggedToken>> tokenize(List<String> content) {
    final lines = <List<TaggedToken>>[];
    var part = _Part.start;

    for (final line in content) {
      // Tolerate a carriage return, in case CRLF input was only split on LF.
      final hasCarriageReturn = line.endsWith('\r');
      final text = hasCarriageReturn
          ? line.substring(0, line.length - 1)
          : line;
      final tokens = <TaggedToken>[];

      // Leading whitespace is skipped, even on a continuation line,
      // so it never ends a key.
      var position = _whitespace.matchAsPrefix(text)?.end ?? 0;
      if (position > 0) {
        tokens.add(TaggedToken(text.substring(0, position), _whitespaceTags));
      }

      var continues = false;
      while (position < text.length) {
        // The rules of each part match any character, so one always matches.
        for (final (pattern, tags, next) in _rules[part]!) {
          final match = pattern.matchAsPrefix(text, position);
          if (match == null) continue;
          tokens.add(TaggedToken(match[0]!, tags));
          position = match.end;
          continues = identical(pattern, _continuation);
          part = next ?? part;
          break;
        }
      }

      if (hasCarriageReturn) tokens.add(TaggedToken('\r', _whitespaceTags));
      if (!continues) part = _Part.start;
      lines.add(tokens);
    }

    return lines;
  }
}

/// A pattern to match, the tags of its match,
/// and the part of the entry that follows,
/// or `null` if the part is unchanged.
typedef _Rule = (RegExp pattern, List<Tag> tags, _Part? next);

/// The part of an entry that the next token belongs to.
enum _Part {
  /// The start of a logical line, where `#` or `!` begins a comment.
  start,

  /// The key, which ends at unescaped whitespace, `=`, or `:`.
  key,

  /// The whitespace after a key, which `=` or `:` can still follow.
  afterKey,

  /// The whitespace after a separator.
  beforeValue,

  /// The value, which runs to the end of the logical line.
  value,
}
