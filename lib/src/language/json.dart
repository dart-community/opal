import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

@internal
final class JsonGrammar extends MatcherGrammar {
  const JsonGrammar();

  @override
  List<Matcher> get matchers => [
    Matcher.include(_value),
  ];

  Matcher _value() => Matcher.options([
    Matcher.include(_comments),
    Matcher.include(_object),
    Matcher.include(_array),
    Matcher.include(_string),
    Matcher.include(_number),
    Matcher.include(_boolean),
    Matcher.include(_null),
  ]);

  Matcher _object() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '{',
      tag: const Tag('begin', parent: Tags.mapLiteral),
    ),
    // Give way to an enclosing array's `]` so an object missing its `}`
    // doesn't swallow the rest of the document. The zero-width alternative
    // emits no closing brace and leaves the `]` to the array.
    end: Matcher.regex(
      r'\}|(?=\])',
      tag: const Tag('end', parent: Tags.mapLiteral),
    ),
    content: Matcher.options([
      Matcher.include(_comments),
      Matcher.include(_objectKey),
      Matcher.verbatim(':', tag: Tags.separator),
      Matcher.include(_value),
      Matcher.verbatim(',', tag: Tags.separator),
    ]),
    tag: Tags.mapLiteral,
  );

  Matcher _objectKey() => _string(
    begin:
        r'"(?=(?:[^"\\]|\\.)*"'
        r'(?:\s|/\*(?:[^*]|\*(?!/))*\*/)*:)',
    tag: Tags.property,
  );

  Matcher _array() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '[',
      tag: const Tag('begin', parent: Tags.arrayLiteral),
    ),
    // Mirrors the object's recovery: an array missing its `]` gives way to
    // an enclosing object's `}` instead of running to the end of the input.
    end: Matcher.regex(
      r'\]|(?=\})',
      tag: const Tag('end', parent: Tags.arrayLiteral),
    ),
    content: Matcher.options([
      Matcher.include(_value),
      Matcher.verbatim(',', tag: Tags.separator),
    ]),
    tag: Tags.arrayLiteral,
  );

  Matcher _string({
    String begin = '"',
    Tag tag = Tags.doubleQuoteString,
  }) => Matcher.wrapped(
    begin: Matcher.regex(
      begin,
      tag: Tag('begin', parent: tag),
    ),
    // Recover at the line end so an unfinished string doesn't
    // swallow later properties or values.
    // The zero-width alternative emits no closing quote.
    end: Matcher.regex(
      r'"|$',
      tag: Tag('end', parent: tag),
    ),
    content: Matcher.options([
      Matcher.regex(r'\\["\\/bfnrt]', tag: Tags.stringEscape),
      Matcher.regex(r'\\u[0-9a-fA-F]{4}', tag: Tags.stringEscape),
      Matcher.regex(r'[^"\\]+'),
      // Keep invalid or incomplete escapes as string content.
      Matcher.regex(r'\\(?:.|$)'),
    ], tag: Tags.stringContent),
    tag: tag,
  );

  // Accept leading zeros and unfinished fractions/exponents while editing,
  // but avoid highlighting numeric fragments within bare words.
  Matcher _number() => Matcher.regex(
    r'(?<![\w.])-?\d+(?:\.\d*)?(?:[eE][+-]?\d*)?(?![\w.])',
    tag: Tags.numberLiteral,
  );

  Matcher _boolean() => Matcher.options([
    Matcher.regex(r'\btrue\b', tag: Tags.trueLiteral),
    Matcher.regex(r'\bfalse\b', tag: Tags.falseLiteral),
  ]);

  Matcher _null() => Matcher.regex(r'\bnull\b', tag: Tags.nullLiteral);

  // While not supported in standard JSON, comments are common in some formats.
  Matcher _comments() => Matcher.options([
    Matcher.regex(r'//.*$', tag: Tags.lineComment),
    Matcher.wrapped(
      begin: Matcher.verbatim(
        '/*',
        tag: const Tag('begin', parent: Tags.blockComment),
      ),
      end: Matcher.verbatim(
        '*/',
        tag: const Tag('end', parent: Tags.blockComment),
      ),
      content: Matcher.regex(
        r'.+?(?=\*/|$)',
        tag: const Tag('content', parent: Tags.blockComment),
      ),
      tag: Tags.blockComment,
    ),
  ]);
}
