import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

/// A grammar for Extended Backus-Naur Form (EBNF)
/// as standardized by ISO/IEC 14977.
@internal
final class EbnfGrammar extends MatcherGrammar {
  const EbnfGrammar();

  @override
  List<Matcher> get matchers => [
    Matcher.include(_comments),
    Matcher.include(_specialSequences),
    Matcher.include(_terminalStrings),
    Matcher.include(_ruleDefinitions),
    Matcher.include(_metaIdentifiers),
    Matcher.include(_integers),
    Matcher.include(_brackets),
    Matcher.include(_operators),
    Matcher.include(_terminators),
  ];

  Matcher _comments() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '(*',
      tag: const Tag('begin', parent: Tags.blockComment),
    ),
    end: Matcher.verbatim(
      '*)',
      tag: const Tag('end', parent: Tags.blockComment),
    ),
    content: Matcher.options([
      // ISO EBNF comments can nest.
      Matcher.include(_comments),
      Matcher.regex(
        r'.+?(?=\(\*|\*\)|$)',
        tag: const Tag('content', parent: Tags.blockComment),
      ),
    ]),
    tag: Tags.blockComment,
  );

  Matcher _specialSequences() => Matcher.regex(
    r'\?[^?]*\?',
    tag: const Tag('special-sequence', parent: Tags.literal),
  );

  Matcher _terminalStrings() => Matcher.options([
    Matcher.regex(r"'[^']*'", tag: Tags.singleQuoteString),
    Matcher.regex(r'"[^"]*"', tag: Tags.doubleQuoteString),
  ]);

  /// ISO 14977 meta-identifiers, which can contain spaces,
  /// such as in `empty sequence`.
  static const String _metaIdentifier =
      r'[a-zA-Z][a-zA-Z0-9]*(?:[ \t]+[a-zA-Z0-9]+)*';

  /// A meta-identifier followed by a defining symbol (`=`).
  Matcher _ruleDefinitions() => Matcher.regex(
    '$_metaIdentifier(?=[ \\t]*=)',
    tag: Tags.function,
  );

  Matcher _metaIdentifiers() =>
      Matcher.regex(_metaIdentifier, tag: Tags.variable);

  Matcher _integers() => Matcher.regex(r'\d+', tag: Tags.integerLiteral);

  Matcher _brackets() => Matcher.options([
    // The alternate ISO forms of the
    // option (`(/ /)`) and repetition (`(: :)`) brackets
    // must be matched before the single-character forms.
    Matcher.verbatim('(/', tag: Tags.punctuation),
    Matcher.verbatim('/)', tag: Tags.punctuation),
    Matcher.verbatim('(:', tag: Tags.punctuation),
    Matcher.verbatim(':)', tag: Tags.punctuation),
    Matcher.verbatim('(', tag: Tags.punctuation),
    Matcher.verbatim(')', tag: Tags.punctuation),
    Matcher.verbatim('[', tag: Tags.punctuation),
    Matcher.verbatim(']', tag: Tags.punctuation),
    Matcher.verbatim('{', tag: Tags.punctuation),
    Matcher.verbatim('}', tag: Tags.punctuation),
  ]);

  Matcher _operators() => Matcher.options([
    Matcher.verbatim('=', tag: Tags.operator),
    // `|`, `/`, and `!` are all valid definition separators.
    Matcher.verbatim('|', tag: Tags.operator),
    Matcher.verbatim('/', tag: Tags.operator),
    Matcher.verbatim('!', tag: Tags.operator),
    Matcher.verbatim(',', tag: Tags.operator),
    Matcher.verbatim('-', tag: Tags.operator),
    Matcher.verbatim('*', tag: Tags.operator),
  ]);

  Matcher _terminators() => Matcher.options([
    Matcher.verbatim(';', tag: Tags.separator),
    Matcher.verbatim('.', tag: Tags.separator),
  ]);
}
