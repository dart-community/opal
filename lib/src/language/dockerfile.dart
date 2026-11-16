import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

/// A grammar for Dockerfiles and Containerfiles.
@internal
final class DockerfileGrammar extends MatcherGrammar {
  const DockerfileGrammar();

  static const String _wordStart = r'(?<!\S)';

  @override
  List<Matcher> get matchers => [
    Matcher.regex(
      r'^#[ \t]*(?:syntax|escape|check)[ \t]*=.*',
      caseSensitive: false,
      tag: Tags.preprocessorDirective,
    ),
    // Each name these declare, with or without a value.
    _instruction('ARG|ENV|LABEL', [
      Matcher.regex('$_wordStart[\\w.-]+(?==|\\s|\$)', tag: Tags.variable),
      ..._arguments,
    ]),
    // As in `FROM image AS name` and `HEALTHCHECK CMD command`.
    _instruction('FROM|HEALTHCHECK', [
      Matcher.regex(
        '$_wordStart(?:AS|CMD|NONE)(?!\\S)',
        caseSensitive: false,
        tag: Tags.keyword,
      ),
      ..._arguments,
    ]),
    _instruction('[A-Za-z]+', _arguments),
    // A line that doesn't start with an instruction, as in a partial snippet.
    ..._arguments,
  ];

  /// An instruction and its [arguments] through to the end of the line.
  static Matcher _instruction(String names, List<Matcher> arguments) =>
      Matcher.wrapped(
        // The default whitespace rule can consume indentation
        // before this is reached, so `^` alone isn't enough.
        begin: Matcher.regex(
          '(?<=^[ \\t]*)(?:$names)(?!\\S)',
          caseSensitive: false,
          tag: Tags.keyword,
        ),
        end: Matcher.regex(r'$'),
        content: Matcher.options([_heredoc, ...arguments]),
      );

  /// A trailing `\` joins the next line to this one,
  /// along with any comment lines in between.
  static final Matcher _continuation = Matcher.wrapped(
    begin: Matcher.regex(r'\\(?=[ \t]*$)', tag: Tags.stringEscape),
    end: Matcher.regex(r'^(?![ \t]*#)'),
    content: Matcher.options([Matcher.regex('#.*', tag: Tags.lineComment)]),
  );

  /// A quoted string, which gives way to the end of the line if unclosed.
  static Matcher _string(String quote, List<Matcher> content, Tag tag) =>
      Matcher.wrapped(
        begin: Matcher.verbatim(quote),
        end: Matcher.regex('$quote|\$'),
        content: Matcher.options([_continuation, ...content]),
        tag: tag,
      );

  /// A heredoc runs from its `<<` through to its delimiter.
  static final Matcher _heredoc = Matcher.select(
    r'''<<-?["']?([A-Za-z_]\w*)''',
    (match) => Matcher.wrapped(
      begin: Matcher.regex('<<-?', tag: Tags.operator),
      end: Matcher.regex('^\\t*${match[1]}\$', tag: Tags.label),
      content: Matcher.options([
        Matcher.regex('^.+', tag: Tags.stringContent),
        ..._arguments,
      ]),
    ),
  );

  static final Matcher _escape = Matcher.regex(r'\\.', tag: Tags.stringEscape);
  static final Matcher _variable = Matcher.regex(
    r'\$(?:\w+|\{[^}]*\})?',
    tag: Tags.variable,
  );

  /// Every instruction's arguments are read as shell words,
  /// since most are either a command or close enough to one.
  static final List<Matcher> _arguments = [
    Matcher.regex('$_wordStart#.*', tag: Tags.lineComment),
    Matcher.regex('$_wordStart--[a-zA-Z][\\w-]*', tag: Tags.modifierKeyword),
    _string("'", [Matcher.regex(r"[^'\\]+|\\")], Tags.singleQuoteString),
    _string('"', [
      _escape,
      _variable,
      Matcher.regex(r'[^"$\\]+'),
    ], Tags.doubleQuoteString),
    _continuation,
    _escape,
    _variable,
    Matcher.regex(r'[;&|<>=]+', tag: Tags.operator),
    Matcher.regex(r'''[^\s"'$\\;&|<>=]+''', tag: Tags.unquotedString),
  ];
}
