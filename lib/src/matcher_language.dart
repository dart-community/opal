import 'dart:collection';

import 'language.dart';
import 'matcher.dart';
import 'tag.dart';
import 'token.dart';

/// A tokenizing language implementation that uses matchers to tokenize content.
final class MatcherLanguage extends Language {
  /// The root tag used for tokenizing the content.
  final Tag _baseTag;

  /// The list of matchers used to tokenize the content at the top level.
  final List<Matcher> _topLevelMatchers;

  /// The list of matchers checked before the other matchers
  /// at the top-level and by an [OptionsMatcher].
  final List<Matcher> _defaultPreMatchers;

  /// The list of matchers checked after the other matchers
  /// at the top-level and by an [OptionsMatcher].
  final List<Matcher> _defaultPostMatchers;

  /// Creates a new [MatcherLanguage] instance for a language with
  /// the specified [name], [grammar], and [baseTag].
  ///
  /// [baseTag] is the root tag used for tokenizing the content
  /// and should usually have a source tag as its parent, such as:
  ///
  /// - [Tags.codeSource]
  /// - [Tags.dataSource]
  /// - [Tags.markupSource]
  /// - [Tags.textualSource]
  MatcherLanguage({
    required String name,
    required MatcherGrammar grammar,
    required Tag baseTag,
  }) : _topLevelMatchers = grammar.matchers,
       _defaultPreMatchers = grammar.preAppliedMatchers,
       _defaultPostMatchers = grammar.postAppliedMatchers,
       _baseTag = baseTag,
       super(name);

  @override
  List<List<TaggedToken>> tokenize(List<String> content) {
    final lines = <List<TaggedToken>>[];
    var lineTokens = <TaggedToken>[];
    final scanner = _LineScanner(content);
    final cachedMatchers = <Matcher Function(), Matcher>{};
    final tags = ListQueue<Tag>();
    tags.add(_baseTag);

    void handleUnknownToken() {
      final char = scanner.readChar();
      if (char == _newLineCodeUnit) {
        lines.add(lineTokens);
        lineTokens = [];
      } else {
        tags.addLast(Tags.unknown);
        lineTokens.add(TaggedToken(String.fromCharCode(char), tags));
        tags.removeLast();
      }
    }

    while (!scanner.isDone) {
      bool tryMatcher(Matcher matcher) {
        switch (matcher) {
          case PatternMatcher(:final pattern, :final tag):
            if (scanner.match(pattern) case final match?) {
              if (match.isZeroLength) {
                // Do not accept zero-length matches; they don't advance.
                return false;
              }
              if (tag != null) {
                tags.addLast(tag);
              }
              lineTokens.add(TaggedToken(match.group(0)!, tags));
              if (tag != null) {
                tags.removeLast();
              }
              return true;
            }
          case CaptureMatcher(:final pattern, :final captures, :final tag):
            if (scanner.match(pattern) case final match?) {
              if (match.isZeroLength) {
                return false;
              }
              if (tag != null) {
                tags.addLast(tag);
              }
              if (captures.length != match.groupCount - 1) {
                throw StateError(
                  'The amount of captures specified (${captures.length}) '
                  'doesn\'t match the amount of non-full groups matched '
                  '(${match.groupCount - 1}).',
                );
              }

              for (
                var captureIndex = 0;
                captureIndex < captures.length;
                captureIndex += 1
              ) {
                tags.addLast(captures[captureIndex]);
                lineTokens.add(
                  TaggedToken(match.group(captureIndex + 1)!, tags),
                );
                tags.removeLast();
              }

              if (tag != null) {
                tags.removeLast();
              }
              return true;
            }
          case WrappedMatcher(
            :final begin,
            :final end,
            :final content,
            :final tag,
          ):
            if (tag != null) {
              tags.addLast(tag);
            }

            if (tryMatcher(begin)) {
              while (!scanner.isDone && !tryMatcher(end)) {
                if (!tryMatcher(content)) {
                  handleUnknownToken();
                }
              }

              if (tag != null) {
                tags.removeLast();
              }

              return true;
            }

            if (tag != null) {
              tags.removeLast();
            }
          case OptionsMatcher(
            :final matchers,
            :final includeDefaultRules,
            :final tag,
          ):
            for (final child in [
              if (includeDefaultRules) ..._defaultPreMatchers,
              ...matchers,
              if (includeDefaultRules) ..._defaultPostMatchers,
            ]) {
              if (tag != null) {
                tags.addLast(tag);
              }
              final result = tryMatcher(child);
              if (tag != null) {
                tags.removeLast();
              }

              if (result) {
                return true;
              }
            }
          case IncludeMatcher(
            matchGenerator: final repositoryGetter,
            :final tag,
          ):
            final matcher = cachedMatchers.putIfAbsent(
              repositoryGetter,
              repositoryGetter.call,
            );

            if (tag != null) {
              tags.addLast(tag);
            }

            final result = tryMatcher(matcher);

            if (tag != null) {
              tags.removeLast();
            }

            return result;
        }

        return false;
      }

      final topLevelMatcher = Matcher.options(_topLevelMatchers);

      while (!scanner.isDone) {
        if (!tryMatcher(topLevelMatcher)) {
          handleUnknownToken();
        }
      }
    }

    // Add the last line if it has any tokens.
    if (lineTokens.isNotEmpty) {
      lines.add(lineTokens);
    }

    return lines;
  }
}

/// A scanner that processes text line by line while
/// supporting multi-line patterns.
final class _LineScanner {
  final List<String> lines;
  int _currentLine = 0;
  int _positionInLine = 0;

  _LineScanner(this.lines);

  bool get isDone =>
      _currentLine >= lines.length ||
      (_currentLine == lines.length - 1 &&
          _positionInLine >= lines[_currentLine].length);

  String get _currentLineText =>
      _currentLine < lines.length ? lines[_currentLine] : '';

  /// The index of the current line within [lines] being scanned.
  int get lineIndex => _currentLine;

  /// The index of the current column within the current line being scanned.
  int get columnIndex => _positionInLine;

  /// Attempts to match the given pattern at the current position.
  ///
  /// If a match is found, advances the position past it then
  /// returns the corresponding [Match], otherwise returns `null`.
  Match? match(Pattern pattern) {
    if (isDone) return null;

    final match = pattern.matchAsPrefix(_currentLineText, _positionInLine);
    if (match != null) {
      _positionInLine = match.end;
    }
    return match;
  }

  /// Reads and returns the next character, advancing the position.
  ///
  /// Returns `\n` when at end of a line, besides the final line.
  /// Throws an error if at end of text (as determined by [isDone]).
  int readChar() {
    if (isDone) {
      throw StateError('No more characters to read.');
    }

    // Check if we're at the end of the current line.
    if (_positionInLine >= _currentLineText.length) {
      // If not the last line, return a newline and move to next line.
      if (_currentLine < lines.length - 1) {
        _currentLine++;
        _positionInLine = 0;
        return _newLineCodeUnit;
      }
    }

    return _currentLineText.codeUnitAt(_positionInLine++);
  }
}

final int _newLineCodeUnit = '\n'.codeUnitAt(0);

extension on Match {
  bool get isZeroLength => group(0)?.isEmpty ?? true;
}
