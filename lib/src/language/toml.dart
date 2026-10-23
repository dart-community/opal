import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

/// Contextual highlighting for TOML 1.1, without semantic validation.
@internal
final class TomlGrammar extends MatcherGrammar {
  const TomlGrammar();

  static const Tag _dateTime = Tag('datetime', parent: Tags.literal);
  static const int _maxDepth = 64;
  // Matcher regexes enable multiline mode,
  // whose '$' also matches Unicode line separators.
  // Those are ordinary characters in TOML strings/comments.
  static const String _lineEnd = r'(?![\s\S])';
  static const String _lineStart = r'(?<![\s\S])';
  // A CR is tolerated wherever a line can end,
  // in case CRLF input was only split on LF.
  static const String _valueEnd = '(?=[ \\t\\r,\\]}#]|$_lineEnd)';
  static const String _simpleKey =
      r'''(?:[a-zA-Z0-9_-]+|"(?:[^"\\]|\\[\s\S])*"|'[^']*')''';
  // A line that begins a new key/value pair,
  // which can never continue an array.
  static const String _keyValueLine =
      '$_lineStart(?=[ \\t]*$_simpleKey'
      '(?:[ \\t]*\\.[ \\t]*$_simpleKey)*[ \\t]*=)';
  static const String _digits = r'[0-9](?:_?[0-9])*';
  static const String _decimal = r'(?:0|[1-9](?:_?[0-9])*)';
  static const String _hex = r'[0-9a-fA-F]';
  // Exclude surrogate code points, which are not Unicode scalar values.
  static const String _scalar4 =
      '(?:[0-9a-cA-Ce-fE-F]$_hex{3}|[dD][0-7]$_hex{2})';
  static const String _date = r'[0-9]{4}-[0-9]{2}-[0-9]{2}';
  static const String _time = r'[0-9]{2}:[0-9]{2}(?::[0-9]{2}(?:\.[0-9]+)?)?';

  // Arrays and inline tables at the same depth share a generator,
  // so the tokenizer caches a single value matcher per depth.
  static final List<Matcher Function()> _valueAtDepth = [
    for (var depth = 0; depth <= _maxDepth; depth += 1)
      () => const TomlGrammar()._value(depth),
  ];

  @override
  List<Matcher> get matchers => _keyContext([
    _header('[[', ']]'),
    _header('[', ']'),
    _assignment(0),
  ]);

  // TOML whitespace is deliberately narrower than RegExp's \s.
  @override
  List<Matcher> get postAppliedMatchers => const [];

  // Every context allows whitespace and comments around [inner],
  // and falls back to consuming malformed bare text.
  List<Matcher> _context(List<Matcher> inner) => [
    Matcher.include(_whitespace),
    Matcher.include(_comment),
    ...inner,
    Matcher.include(_unknown),
  ];

  // Top-level lines, headers, and inline tables accept dotted keys.
  List<Matcher> _keyContext([List<Matcher> inner = const []]) => _context([
    Matcher.include(_key),
    Matcher.verbatim('.', tag: Tags.accessor),
    ...inner,
    Matcher.include(_unknownKey),
  ]);

  Matcher _whitespace() => Matcher.regex(r'[ \t\r]+', tag: Tags.whitespace);

  Matcher _comment() => Matcher.regex(r'#[\s\S]*', tag: Tags.lineComment);

  Matcher _header(String open, String close) => Matcher.wrapped(
    begin: Matcher.verbatim(open, tag: Tags.punctuation),
    end: Matcher.regex(
      '${RegExp.escape(close)}|$_lineEnd',
      tag: Tags.punctuation,
    ),
    content: Matcher.options(_keyContext()),
  );

  Matcher _key() => Matcher.options([
    Matcher.regex(r'[a-zA-Z0-9_-]+', tag: Tags.property),
    _string('"', Tags.property),
    _string("'", Tags.property),
  ]);

  // Only '=' enters value context.
  // In particular, numeric/boolean-looking keys and
  // bracketed headers must not be interpreted as values.
  // A value only reaches a later line's start when an
  // unterminated collection gave way there, so end with it.
  Matcher _assignment(int depth, {bool inline = false}) => Matcher.wrapped(
    begin: Matcher.verbatim('=', tag: Tags.separator),
    end: Matcher.regex(
      inline ? '(?=[,}\\]])|$_lineEnd|$_lineStart' : '$_lineEnd|$_lineStart',
    ),
    content: Matcher.include(_valueAtDepth[depth]),
  );

  Matcher _value(int depth) => Matcher.options(
    _context([
      Matcher.include(_strings),
      Matcher.include(_scalars),
      if (depth < _maxDepth) ...[
        _array(depth + 1),
        _inlineTable(depth + 1),
      ] else
        // Bound matcher recursion on pathological input.
        // Beyond this depth, preserve the source and
        // retain lexical highlighting of values.
        Matcher.regex(r'[\[\]{}]', tag: Tags.punctuation),
      Matcher.verbatim(',', tag: Tags.separator),
    ]),
  );

  Matcher _array(int depth) => Matcher.wrapped(
    begin: Matcher.verbatim(
      '[',
      tag: const Tag('begin', parent: Tags.arrayLiteral),
    ),
    // Give an enclosing inline table its closing brace if ']' is missing,
    // and stop before a following key/value line.
    end: Matcher.regex(
      '\\]|(?=\\})|$_keyValueLine',
      tag: const Tag('end', parent: Tags.arrayLiteral),
    ),
    content: Matcher.include(_valueAtDepth[depth]),
    tag: Tags.arrayLiteral,
  );

  Matcher _inlineTable(int depth) => Matcher.wrapped(
    begin: Matcher.verbatim(
      '{',
      tag: const Tag('begin', parent: Tags.mapLiteral),
    ),
    // Give way to an enclosing array's ']' if '}' is missing,
    // and to a following line that starts a table header.
    end: Matcher.regex(
      '\\}|(?=\\])|$_lineStart(?=[ \\t]*\\[)',
      tag: const Tag('end', parent: Tags.mapLiteral),
    ),
    content: Matcher.options(
      _keyContext([
        _assignment(depth, inline: true),
        Matcher.verbatim(',', tag: Tags.separator),
      ]),
    ),
    tag: Tags.mapLiteral,
  );

  Matcher _strings() => Matcher.options([
    _string('"""', Tags.tripleQuoteString),
    _string("'''", Tags.tripleQuoteString),
    _string('"', Tags.doubleQuoteString),
    _string("'", Tags.singleQuoteString),
  ]);

  Matcher _string(String quote, Tag stringTag) {
    final character = quote[0];
    final multiline = quote.length == 3;
    final basic = character == '"';
    final endTag = Tag('end', parent: stringTag);
    final excluded = basic ? '$character\\\\' : character;

    return Matcher.wrapped(
      begin: Matcher.verbatim(quote, tag: Tag('begin', parent: stringTag)),
      end: multiline
          ? Matcher.options([
              // A run of four/five quotes ends with three delimiter quotes.
              // The preceding one/two quotes belong to the string's content.
              Matcher.capture(
                '($character{1,2})($quote)',
                captures: [Tags.stringContent, endTag],
              ),
              Matcher.verbatim(quote, tag: endTag),
            ])
          : Matcher.regex('$quote|$_lineEnd', tag: endTag),
      content: Matcher.options([
        Matcher.regex(
          multiline
              ? '(?:[^$excluded]|$character(?!$character$character))+'
              : '[^$excluded]+',
          tag: Tags.stringContent,
        ),
        if (basic) ...[
          Matcher.include(_escape),
          if (multiline)
            Matcher.regex(
              r'\\[ \t\r]*'
              '$_lineEnd',
              tag: Tags.stringEscape,
            ),
          // Invalid/incomplete escapes remain content.
          // Consuming both characters also prevents
          // escaped quotes from ending a string.
          Matcher.regex(r'\\[\s\S]?', tag: Tags.stringContent),
        ],
      ]),
      tag: stringTag,
    );
  }

  Matcher _escape() => Matcher.regex(
    r'\\(?:["\\btnfre]|x'
    '$_hex{2}|u$_scalar4|'
    'U(?:0000$_scalar4|000[1-9a-fA-F]$_hex{4}|0010$_hex{4}))',
    tag: Tags.stringEscape,
  );

  Matcher _scalars() => Matcher.options([
    // Dates precede numbers, and longer date-time forms precede local dates.
    Matcher.regex(
      '(?:$_date[Tt ]$_time(?:[Zz]|[+-][0-9]{2}:[0-9]{2})?|'
      '$_date(?! [0-9]{2}:)|$_time)$_valueEnd',
      tag: _dateTime,
    ),
    Matcher.regex('true$_valueEnd', tag: Tags.trueLiteral),
    Matcher.regex('false$_valueEnd', tag: Tags.falseLiteral),
    Matcher.regex(
      '[+-]?(?:inf|nan|$_decimal'
      '(?:\\.$_digits(?:[eE][+-]?$_digits)?|[eE][+-]?$_digits))$_valueEnd',
      tag: Tags.floatLiteral,
    ),
    Matcher.regex(
      '(?:0x$_hex(?:_?$_hex)*|0o[0-7](?:_?[0-7])*|'
      '0b[01](?:_?[01])*|[+-]?$_decimal)$_valueEnd',
      tag: Tags.integerLiteral,
    ),
  ]);

  // Consume a failed bare value in one pass,
  // so a malformed suffix can't become a
  // valid-looking literal on the next matcher iteration.
  Matcher _unknown() => Matcher.regex(
    r'''[^ \t\r\n"'#,\[\]{}]+''',
    tag: Tags.unknown,
  );

  // Stop malformed key text before '.' or '=',
  // so the rest of a key/value pair is still recognized.
  Matcher _unknownKey() => Matcher.regex(
    r'''[^ \t\r\n"'#,.=\[\]{}]+''',
    tag: Tags.unknown,
  );
}
