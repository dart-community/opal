/// @docImport 'abnf.dart';
/// @docImport 'ebnf.dart';
library;

import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

/// A grammar for Backus-Naur Form (BNF),
/// as popularized by the ALGOL 60 report,
/// tolerant of common dialect conventions such as
/// quoted terminals, bare rule names, and the `:=` and `=` defining symbols.
///
/// For other specified variants, see [AbnfGrammar] and [EbnfGrammar].
@internal
final class BnfGrammar extends MatcherGrammar {
  const BnfGrammar();

  @override
  List<Matcher> get matchers => [
    Matcher.include(_ruleDefinitions),
    Matcher.include(_nonTerminals),
    Matcher.include(_terminalStrings),
    Matcher.include(_bareAngleBrackets),
    Matcher.include(_operators),
    Matcher.include(_bareTerminals),
  ];

  /// A non-terminal or bare rule name followed by
  /// a defining symbol (`::=`, `:=`, or `=`).
  Matcher _ruleDefinitions() => Matcher.options([
    Matcher.regex(
      r'<[a-zA-Z][a-zA-Z0-9 _-]*>(?=[ \t]*:{0,2}=)',
      tag: Tags.function,
    ),
    Matcher.regex(
      r'[a-zA-Z][a-zA-Z0-9_-]*(?=[ \t]*:{0,2}=)',
      tag: Tags.function,
    ),
  ]);

  /// An angle-bracketed non-terminal reference, such as `<expression>`.
  ///
  /// As in the ALGOL 60 report, the name can contain spaces.
  Matcher _nonTerminals() => Matcher.regex(
    r'<[a-zA-Z][a-zA-Z0-9 _-]*>',
    tag: Tags.variable,
  );

  /// Quoted terminals, a common convention in later BNF dialects.
  Matcher _terminalStrings() => Matcher.options([
    Matcher.regex(r"'[^']*'", tag: Tags.singleQuoteString),
    Matcher.regex(r'"[^"]*"', tag: Tags.doubleQuoteString),
  ]);

  Matcher _operators() => Matcher.options([
    // The alternative defining symbols (`:=` and `=`) used by
    // some dialects must be matched after the original (`::=`).
    Matcher.verbatim('::=', tag: Tags.operator),
    Matcher.verbatim(':=', tag: Tags.operator),
    Matcher.verbatim('=', tag: Tags.operator),
    Matcher.verbatim('|', tag: Tags.operator),
  ]);

  /// Unquoted terminals, which the original BNF wrote as-is and
  /// distinguished from other symbols typographically.
  Matcher _bareTerminals() => Matcher.regex(
    r'[^<>|\s]+',
    tag: Tags.unquotedString,
  );

  /// Angle brackets that don't form a non-terminal, such as when
  /// used as bare relational operator terminals (`<`, `<=`, `>`, `>=`).
  Matcher _bareAngleBrackets() => Matcher.regex(
    r'[<>]=?',
    tag: Tags.unquotedString,
  );
}
