import 'package:meta/meta.dart';

import '../language.dart';
import '../tag.dart';
import '../token.dart';

/// Line-based highlighting for unified diffs and patches,
/// including git's extended headers, combined diffs, and
/// the commit preambles of `git format-patch` and `git log --patch`.
///
/// Only the structure of the diff is tokenized,
/// not the language of the content being compared.
///
/// Unlike most languages, this isn't implemented with matchers.
/// Each matcher only sees the line being scanned, but
/// telling a `--- ` file header apart from a removed line that
/// begins with `-- ` requires the line counts of the enclosing hunk,
/// or when those are unknown, the following lines.
@internal
final class DiffLanguage extends Language {
  const DiffLanguage() : super('diff');

  static const Tag _base = Tag('diff', parent: Tags.textualSource);

  static const Tag _insertedMarker = Tag('marker', parent: MarkupTags.inserted);
  static const Tag _removedMarker = Tag('marker', parent: MarkupTags.removed);
  static const Tag _unchangedMarker = Tag(
    'marker',
    parent: MarkupTags.unchanged,
  );

  static const Tag _fromFile = Tag('from-file', parent: MarkupTags.heading);
  static const Tag _toFile = Tag('to-file', parent: MarkupTags.heading);
  static const Tag _section = Tag('section', parent: MarkupTags.heading);
  static const Tag _range = Tag('range', parent: Tags.metadata);

  static const String _fromFilePrefix = '--- ';
  static const String _toFilePrefix = '+++ ';

  /// The ranges of a hunk, optionally followed by its section heading,
  /// such as `@@ -1,4 +1,5 @@ void main() {`.
  ///
  /// The hunks of combined diffs have a range for each parent,
  /// such as `@@@ -1,4 -1,4 +1,5 @@@`,
  /// with one more `@` in each delimiter for each additional parent.
  ///
  /// Captures the ranges with their delimiters,
  /// the extra `@` of the opening delimiter, the whitespace that follows,
  /// the section heading, and a trailing carriage return.
  static final RegExp _hunkHeader = RegExp(
    r'^(@(@+)(?: [-+][0-9]+(?:,[0-9]+)?)+ @@+)([ \t]*)([\s\S]*?)(\r?)$',
  );

  /// A single range of a hunk header, capturing its sign and line count.
  static final RegExp _hunkRange = RegExp(r' ([-+])[0-9]+(?:,([0-9]+))?');

  /// The start of the header line that begins the diff of each file,
  /// which also ends the preamble of a commit.
  static const String _fileStart = r'diff -|Index: ';

  static final RegExp _fileStartPattern = RegExp('^(?:$_fileStart)');

  /// A diffstat's per-file counts, binary or unmerged status, or final total.
  static final RegExp _diffstatLine = RegExp(
    r' \| +(?:[0-9]+(?: [+-]+)?|Bin .+|Unmerged)\r?$|^ [0-9]+ files? changed\b',
  );

  /// The extended header lines of git, as well as
  /// the header lines of Subversion and recursive diffs.
  static final RegExp _metadata = RegExp(
    '^(?:$_fileStart|'
    r'index [0-9a-f]+(?:,[0-9a-f]+)*\.\.[0-9a-f]+|'
    r'(?:old|new|deleted file|new file) mode |'
    r'mode [0-7]+(?:,[0-7]+)*\.\.[0-7]+|(?:copy|rename) (?:from|to) |'
    r'(?:dis)?similarity index |Binary files |GIT binary patch|'
    r'={3,}|Only in )',
  );

  /// The line that begins each patch of `git format-patch`.
  static final RegExp _mailStart = RegExp(r'^From [0-9a-f]{7,64} ');

  /// The line that begins each commit of `git log`.
  ///
  /// As abbreviated hashes can be as short as English words like `face`,
  /// only the parents, decorations, or source that git can print may follow.
  static final RegExp _commitStart = RegExp(
    r'^commit [0-9a-f]{4,64}(?: [0-9a-f(]|\t|\r?$)',
  );

  /// A possible hunk marker after an ambiguous `-- ` line, used to
  /// tell if it continues a hunk with lines remaining in its counts.
  static final RegExp _hunkLineStart = RegExp(r'^[-+ \\@]');

  @override
  List<List<TaggedToken>> tokenize(List<String> content) {
    final lines = <List<TaggedToken>>[];

    // If within the statistics or commit message that precede the diff,
    // where a leading '-', '+', or space has no meaning.
    var inPreamble = _startsWithDiffstat(content);
    // If any patch began with a mail header,
    // meaning a mail signature can be expected to follow its diff.
    var sawMail = false;
    // The number of marker columns that begin each line of the current hunk,
    // which is one for each parent of a combined diff.
    var markerWidth = 1;
    // The number of lines that remain in the current hunk for
    // each parent and then the result, as declared by the hunk's header,
    // or `null` if not within a hunk with known line counts.
    List<int>? remaining;
    // Where the file headers are within the latest run of
    // consecutive lines that begin with the from-file prefix.
    var fileHeaders = (fromFile: 0, toFile: 0, beforeHunk: false);

    for (var index = 0; index < content.length; index += 1) {
      final line = content[index];
      final nextLine = content.elementAtOrNull(index + 1);

      if (_isBlank(line)) {
        // Likely a context line that had its trailing whitespace stripped.
        if (remaining != null) {
          remaining = _consume(remaining, ' ' * markerWidth);
        }
        lines.add([if (line.isNotEmpty) _token(line, Tags.whitespace)]);
        continue;
      }

      // If the line is the first from-file header of a file.
      var isFromFile = false;
      if (line.startsWith(_fromFilePrefix)) {
        // Only scan each run of lines with the prefix once.
        if (fileHeaders.toFile <= index) {
          fileHeaders = _fileHeaders(content, index);
        }
        isFromFile = fileHeaders.fromFile == index;
      }

      // A preamble always ends any hunk that precedes it,
      // so the checks that follow never apply within one.
      if (inPreamble) {
        if (!isFromFile && !line.startsWith(_fileStartPattern)) {
          lines.add([_token(line)]);
          continue;
        }
        inPreamble = false;
      }

      if (line.startsWith(r'\ ')) {
        // A note about the preceding line, usually
        // that it has no trailing newline.
        lines.add([_token(line, Tags.comment)]);
        continue;
      }

      // If the line is the signature separator that
      // git ends each mailed patch with.
      //
      // Outside a hunk with lines remaining,
      // the signature can start with any character,
      // so only a following hunk header rules it out.
      final isSignature =
          sawMail &&
          (line == '-- ' || line == '-- \r') &&
          (remaining == null
              ? _hunkHeaderOf(nextLine) == null
              : !(nextLine?.startsWith(_hunkLineStart) ?? false));

      if (remaining != null) {
        if (_markerOf(line, markerWidth) case final marker?) {
          // Hunks with incorrect line counts, such as from hand-edited diffs,
          // can overlap the file headers or mail signature that follow.
          //
          // A hunk header can't follow within a hunk,
          // so file headers that precede one only
          // belong to this hunk if they complete it,
          // such as a removed `-- ` line and an added `++ ` line.
          final beginsFile =
              isFromFile &&
              fileHeaders.beforeHunk &&
              !_completes(
                remaining,
                content.getRange(index, fileHeaders.toFile + 1),
                markerWidth,
              );

          if (!beginsFile) {
            remaining = _consume(remaining, marker);
            final beginsSignature =
                remaining != null &&
                isSignature &&
                nextLine != null &&
                !_isBlank(nextLine);

            if (!beginsSignature) {
              lines.add(_change(line, marker));
              continue;
            }
          }
        }

        // The hunk ended before the line counts in its header did.
        remaining = null;
      }

      if (isFromFile) {
        // A combined diff can have a from-file header for each parent.
        for (final fromFile in content.getRange(index, fileHeaders.toFile)) {
          lines.add([_token(fromFile, _fromFile)]);
        }
        lines.add([_token(content[fileHeaders.toFile], _toFile)]);
        index = fileHeaders.toFile;
        continue;
      }

      final hunk = _hunkHeaderOf(line);
      if (hunk != null) {
        lines.add([
          _token(hunk[1]!, _range),
          if (hunk[3]! case final space when space.isNotEmpty)
            _token(space, Tags.whitespace),
          if (hunk[4]! case final section when section.isNotEmpty)
            _token(section, _section),
          if (hunk[5]! case final carriageReturn when carriageReturn.isNotEmpty)
            _token(carriageReturn, Tags.whitespace),
        ]);

        markerWidth = hunk[2]!.length;
        remaining = _hunkCounts(hunk[1]!, markerWidth);
        continue;
      }

      switch (line[0]) {
        case '-' when isSignature:
          inPreamble = true;
          lines.add([_token(line)]);
        case '+' || '-' || ' ':
          lines.add(_change(line, _markerOf(line, markerWidth) ?? line[0]));
        case _ when _metadata.hasMatch(line):
          lines.add([_token(line, Tags.metadata)]);
        default:
          if (_mailStart.hasMatch(line)) {
            inPreamble = true;
            sawMail = true;
          } else if (_commitStart.hasMatch(line)) {
            inPreamble = true;
          }
          lines.add([_token(line)]);
      }
    }

    return lines;
  }

  /// Whether the input starts with indented file statistics,
  /// such as from `git diff --stat` or `diffstat`,
  /// and then the headers of a file.
  /// A standalone hunk can contain the same indented text.
  static bool _startsWithDiffstat(List<String> content) {
    final start = content.indexWhere((line) => !_isBlank(line));
    if (start == -1) return false;
    final first = content[start];
    if (!first.startsWith(' ') || !_diffstatLine.hasMatch(first)) return false;

    for (var index = start + 1; index < content.length; index += 1) {
      final line = content[index];
      if (_isBlank(line) || line.startsWith(' ')) continue;
      if (line.startsWith(_fileStartPattern)) return true;
      // Like the preamble, also end at the file headers of a plain diff.
      if (!line.startsWith(_fromFilePrefix)) return false;
      final headers = _fileHeaders(content, index);
      return headers.fromFile < headers.toFile;
    }
    return false;
  }

  /// Finds the file headers at the end of the run of consecutive lines
  /// that begin with the from-file prefix, starting at [runStart].
  ///
  /// Returns the index of the first from-file header,
  /// the index of the line that follows the run,
  /// which is the to-file header if the run has any file headers,
  /// and whether a hunk header follows the file headers.
  /// If the run has no file headers, both indices are the same.
  static ({int fromFile, int toFile, bool beforeHunk}) _fileHeaders(
    List<String> content,
    int runStart,
  ) {
    var runEnd = runStart + 1;
    while (runEnd < content.length &&
        content[runEnd].startsWith(_fromFilePrefix)) {
      runEnd += 1;
    }

    // A removed line can also begin with the from-file prefix,
    // such as a removed SQL comment, so require the to-file header as well.
    if (!(content.elementAtOrNull(runEnd)?.startsWith(_toFilePrefix) ??
        false)) {
      return (fromFile: runEnd, toFile: runEnd, beforeHunk: false);
    }

    // A combined diff has a from-file header for each parent.
    // More than one is only expected before a hunk with as many parents,
    // as otherwise all but the last are likely removed lines.
    final hunk = _hunkHeaderOf(content.elementAtOrNull(runEnd + 1));
    final parents = hunk == null ? 1 : hunk[2]!.length;
    return (
      fromFile: runEnd - (parents <= runEnd - runStart ? parents : 1),
      toFile: runEnd,
      beforeHunk: hunk != null,
    );
  }

  /// The match of [line] as a hunk header, or `null` if it isn't one.
  static RegExpMatch? _hunkHeaderOf(String? line) =>
      // Skip matching the lines that can't be a hunk header.
      line != null && line.startsWith('@@')
      ? _hunkHeader.firstMatch(line)
      : null;

  /// Whether the specified [lines] are exactly the lines that
  /// are [remaining] in a hunk with [width] marker columns.
  static bool _completes(
    List<int> remaining,
    Iterable<String> lines,
    int width,
  ) {
    final counts = [...remaining];
    for (final line in lines) {
      final marker = _markerOf(line, width);
      if (marker == null) return false;
      _consume(counts, marker);
    }

    return counts.every((count) => count == 0);
  }

  /// The line counts that the [ranges] of a hunk header declare for
  /// each of the hunk's [parents] and then the result,
  /// or `null` if the ranges don't match the header or declare no lines.
  static List<int>? _hunkCounts(String ranges, int parents) {
    final matches = _hunkRange.allMatches(ranges).toList(growable: false);
    if (matches.length != parents + 1) return null;

    final counts = <int>[];
    for (final (index, match) in matches.indexed) {
      if (match[1] != (index < parents ? '-' : '+')) return null;
      final count = int.tryParse(match[2] ?? '1');
      if (count == null) return null;
      counts.add(count);
    }

    return counts.any((count) => count > 0) ? counts : null;
  }

  /// Counts a hunk line that begins with [marker] against the [remaining]
  /// lines of each parent and then the result,
  /// returning [remaining], or `null` if the hunk has no lines remaining.
  static List<int>? _consume(List<int> remaining, String marker) {
    // A removed line is in each parent with a `-` in its column,
    // while any other line is in the result and
    // each parent with a space in its column.
    final isRemoved = marker.contains('-');
    final counted = isRemoved ? '-' : ' ';
    final parents = marker.length;
    for (var parent = 0; parent < parents; parent += 1) {
      if (marker[parent] == counted) remaining[parent] -= 1;
    }
    if (!isRemoved) remaining[parents] -= 1;

    return remaining.any((count) => count > 0) ? remaining : null;
  }

  /// The [width] marker columns that begin the hunk [line],
  /// or `null` if [line] doesn't begin with a valid marker.
  static String? _markerOf(String line, int width) {
    if (line.length < width) return null;
    for (var column = 0; column < width; column += 1) {
      if (!'+- '.contains(line[column])) return null;
    }
    return line.substring(0, width);
  }

  /// Whether [line] is empty, ignoring the carriage return of a CRLF line.
  static bool _isBlank(String line) => line.isEmpty || line == '\r';

  /// Splits a hunk [line] into its [marker] and its content,
  /// tagged by the change the marker indicates.
  static List<TaggedToken> _change(String line, String marker) {
    final (tag, markerTag) = marker.contains('+')
        ? const (MarkupTags.inserted, _insertedMarker)
        : marker.contains('-')
        ? const (MarkupTags.removed, _removedMarker)
        : const (MarkupTags.unchanged, _unchangedMarker);

    return [
      _token(marker, markerTag),
      if (line.length > marker.length)
        _token(line.substring(marker.length), tag),
    ];
  }

  static TaggedToken _token(String content, [Tag? tag]) =>
      TaggedToken(content, [_base, ?tag]);
}
