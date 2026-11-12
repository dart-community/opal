import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

/// A grammar for CMake build scripts and modules.
@internal
final class CMakeGrammar extends MatcherGrammar {
  const CMakeGrammar();

  static const String _commandName = r'[A-Za-z_][A-Za-z0-9_]*';
  static const String _beforeArguments = r'(?=[ \t]*\()';

  /// The characters that end an unquoted argument.
  static const String _argumentEndChars = r' \t\r()#"';
  static const String _argumentEnd = '(?=[$_argumentEndChars]|\$)';
  static const Tag _bracketString = Tag('bracket', parent: Tags.quotedString);

  static const String _variableNameChar = r'[A-Za-z0-9_./+-]';
  static const String _variableNamePart = '(?:$_variableNameChar|\\\\.)';
  static const String _variableOpen = r'\$(?:ENV|CACHE)?\{';
  static const String _flatVariable = '$_variableOpen$_variableNamePart*\\}';

  static final Matcher _escape = Matcher.regex(
    r'\\(?:[nrt]|[^A-Za-z0-9]|$)',
    tag: Tags.stringEscape,
  );
  static final Matcher _variable = Matcher.options([
    Matcher.regex(_flatVariable, tag: Tags.variable),
    // A reference can nest others in its name, as in `${lib_${name}}`.
    Matcher.wrapped(
      begin: Matcher.regex(
        '$_variableOpen(?=$_variableNamePart*$_variableOpen)',
      ),
      // A malformed name gives way to the text that follows it.
      end: Matcher.regex('\\}|(?!$_variableNamePart|\\\$)'),
      nestable: true,
      content: Matcher.regex('$_flatVariable|$_variableNamePart+|\\\$'),
      tag: Tags.variable,
    ),
  ]);
  static final Matcher _bracketContent = Matcher.regex(r'[^\]]+|\]');

  /// The characters that can start an escape or a reference.
  static const String _escapeOrReferenceStart = r'$\\';

  /// Matches a run of text without any of the [excluded] characters
  /// or [_escapeOrReferenceStart] characters.
  static String _textExcept(String excluded) =>
      '[^$excluded$_escapeOrReferenceStart]+';

  @override
  List<Matcher> get matchers => [
    ..._spaceAndComments,
    _argumentList,
    Matcher.regex(
      '(?:if|elseif|else|endif|foreach|endforeach|while|endwhile|'
      'block|endblock|break|continue|return)$_beforeArguments',
      caseSensitive: false,
      tag: Tags.controlKeyword,
    ),
    Matcher.regex(
      '(?:end)?(?:function|macro)$_beforeArguments',
      caseSensitive: false,
      tag: Tags.declarationKeyword,
    ),
    Matcher.regex('$_commandName$_beforeArguments', tag: Tags.function),
    Matcher.regex(_commandName, tag: Tags.identifier),
  ];

  // Whitespace separates arguments and is literal inside quotes and brackets.
  @override
  List<Matcher> get postAppliedMatchers => const [];

  static final List<Matcher> _spaceAndComments = [
    Matcher.regex(r'[ \t\r]+', tag: Tags.whitespace),
    _bracket('#', Tags.blockComment),
    Matcher.regex(r'#[\s\S]*', tag: Tags.lineComment),
  ];

  static Matcher _bracket(String prefix, Tag tag) => Matcher.select(
    '$prefix\\[(=*)\\[',
    (match) => Matcher.wrapped(
      begin: Matcher.verbatim(match[0]!),
      end: Matcher.verbatim(']${match[1]}]'),
      content: _bracketContent,
      tag: tag,
    ),
  );

  static final Matcher _unquotedParts = _argumentParts(quoted: false);

  static final Matcher _argumentList = Matcher.wrapped(
    begin: Matcher.verbatim('(', tag: Tags.punctuation),
    end: Matcher.verbatim(')', tag: Tags.punctuation),
    nestable: true,
    content: Matcher.options([
      ..._spaceAndComments,
      _bracket('', _bracketString),
      Matcher.wrapped(
        begin: Matcher.verbatim('"'),
        end: Matcher.verbatim('"'),
        content: _argumentParts(quoted: true),
        tag: Tags.doubleQuoteString,
      ),
      // The `Y` and `N` constants are left out, as they're
      // more often single-letter names, such as a loop variable.
      Matcher.regex(
        '(?:on|yes|true)$_argumentEnd',
        caseSensitive: false,
        tag: Tags.trueLiteral,
      ),
      Matcher.regex(
        '(?:off|no|false|ignore|(?:$_variableNameChar*-)?notfound)'
        '$_argumentEnd',
        caseSensitive: false,
        tag: Tags.falseLiteral,
      ),
      Matcher.regex(
        '[+-]?(?:0[xX][0-9A-Fa-f]+|[0-9]+)$_argumentEnd',
        tag: Tags.integerLiteral,
      ),
      // Read the whole argument so a suffix after an escape or variable
      // stays unquoted text, even if it looks like a boolean or integer.
      Matcher.wrapped(
        begin: _unquotedParts,
        end: Matcher.regex(_argumentEnd),
        content: _unquotedParts,
      ),
    ]),
  );

  static Matcher _argumentParts({required bool quoted}) {
    final textTag = quoted ? Tags.stringContent : Tags.unquotedString;
    return Matcher.options([
      // Plain text is the most common part and
      // can't start any other part, so try it first.
      Matcher.regex(
        _textExcept(quoted ? '"' : '$_argumentEndChars;'),
        tag: textTag,
      ),
      _escape,
      _variable,
      _generatorExpression(quoted: quoted),
      if (!quoted) Matcher.verbatim(';', tag: Tags.separator),
      // A `$` or `\` that doesn't start a reference or escape.
      Matcher.regex('[$_escapeOrReferenceStart]', tag: textTag),
    ]);
  }

  static Matcher _generatorExpression({required bool quoted}) =>
      Matcher.wrapped(
        begin: Matcher.verbatim(r'$<'),
        // An incomplete expression gives way to the enclosing argument's end.
        end: Matcher.regex(quoted ? r'>|(?=")' : '>|$_argumentEnd'),
        nestable: true,
        content: Matcher.options([
          Matcher.regex(_textExcept(quoted ? '">' : '$_argumentEndChars>')),
          _escape,
          _variable,
          Matcher.regex('[$_escapeOrReferenceStart]'),
        ]),
        tag: Tags.stringInterpolation,
      );
}
