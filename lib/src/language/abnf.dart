import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

/// A grammar for Augmented Backus-Naur Form (ABNF)
/// as standardized by RFC 5234 with
/// the case-sensitivity extensions from RFC 7405.
@internal
final class AbnfGrammar extends MatcherGrammar {
  const AbnfGrammar();

  @override
  List<Matcher> get matchers => [
    Matcher.include(_comments),
    Matcher.include(_ruleDefinitions),
    Matcher.include(_definedAs),
    Matcher.include(_terminalStrings),
    Matcher.include(_numericValues),
    Matcher.include(_proseValues),
    Matcher.include(_coreRules),
    Matcher.include(_ruleReferences),
    Matcher.include(_repetition),
    Matcher.include(_operators),
    Matcher.include(_punctuation),
  ];

  Matcher _comments() => Matcher.regex(r';.*$', tag: Tags.lineComment);

  /// A rule name followed by a defined-as symbol (`=` or `=/`).
  Matcher _ruleDefinitions() => Matcher.regex(
    r'[A-Za-z][A-Za-z0-9-]*(?=[ \t]*=)',
    tag: Tags.function,
  );

  Matcher _definedAs() => Matcher.options([
    // The incremental alternative symbol (`=/`) must be
    // matched before the basic defined-as symbol (`=`).
    Matcher.verbatim('=/', tag: Tags.operator),
    Matcher.verbatim('=', tag: Tags.operator),
  ]);

  Matcher _terminalStrings() => Matcher.options([
    // RFC 7405 case-sensitive (`%s`) and case-insensitive (`%i`) strings.
    // The prefixes themselves are matched case insensitively since
    // they are defined with ABNF quoted strings, which are.
    Matcher.capture(
      r'(%[si])("[^"]*")',
      captures: [Tags.stringEscape, Tags.doubleQuoteString],
      caseSensitive: false,
    ),
    Matcher.regex(r'"[^"]*"', tag: Tags.doubleQuoteString),
  ]);

  /// Binary (`%b`), decimal (`%d`), and hexadecimal (`%x`) terminal values,
  /// optionally with a value range (`%x41-5A`) or
  /// a concatenation of values (`%d13.10`).
  ///
  /// The base prefixes and hexadecimal digits are matched case insensitively
  /// since they are defined with ABNF quoted strings, which are.
  Matcher _numericValues() => Matcher.options([
    Matcher.regex(
      r'%b[01]+(?:(?:\.[01]+)+|-[01]+)?',
      tag: Tags.numberLiteral,
      caseSensitive: false,
    ),
    Matcher.regex(
      r'%d\d+(?:(?:\.\d+)+|-\d+)?',
      tag: Tags.numberLiteral,
      caseSensitive: false,
    ),
    Matcher.regex(
      r'%x[0-9A-F]+(?:(?:\.[0-9A-F]+)+|-[0-9A-F]+)?',
      tag: Tags.numberLiteral,
      caseSensitive: false,
    ),
  ]);

  Matcher _proseValues() => Matcher.regex(
    r'<[^>]*>',
    tag: const Tag('prose', parent: Tags.literal),
  );

  static const List<String> _coreRuleNames = [
    'ALPHA',
    'BIT',
    'CHAR',
    'CRLF',
    'CR',
    'CTL',
    'DIGIT',
    'DQUOTE',
    'HEXDIG',
    'HTAB',
    'LF',
    'LWSP',
    'OCTET',
    'SP',
    'VCHAR',
    'WSP',
  ];

  /// The core rules defined by RFC 5234 itself, such as `ALPHA` and `DIGIT`.
  ///
  /// Matched case insensitively since ABNF rule names are case insensitive,
  /// even though the core rules are conventionally written in uppercase.
  ///
  /// The lookahead prevents matching just the start of
  /// a longer rule name, such as `SP` in `SPACE`.
  Matcher _coreRules() => Matcher.options([
    for (final coreRule in _coreRuleNames)
      Matcher.regex(
        '$coreRule(?![A-Za-z0-9-])',
        tag: Tags.builtInType,
        caseSensitive: false,
      ),
  ]);

  Matcher _ruleReferences() =>
      Matcher.regex(r'[A-Za-z][A-Za-z0-9-]*', tag: Tags.variable);

  /// Repetition, such as `1*`, `*4`, `3*5`, or a specific count like `2`.
  Matcher _repetition() => Matcher.options([
    Matcher.verbatim('*', tag: Tags.operator),
    Matcher.regex(r'\d+', tag: Tags.integerLiteral),
  ]);

  Matcher _operators() => Matcher.verbatim('/', tag: Tags.operator);

  Matcher _punctuation() => Matcher.options([
    Matcher.verbatim('(', tag: Tags.punctuation),
    Matcher.verbatim(')', tag: Tags.punctuation),
    Matcher.verbatim('[', tag: Tags.punctuation),
    Matcher.verbatim(']', tag: Tags.punctuation),
  ]);
}
