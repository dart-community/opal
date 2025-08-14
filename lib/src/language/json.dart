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

  Matcher _array() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '[',
      tag: const Tag('bracket-square-begin', parent: Tags.punctuation),
    ),
    end: Matcher.verbatim(
      ']',
      tag: const Tag('bracket-square-end', parent: Tags.punctuation),
    ),
    content: Matcher.options([
      Matcher.include(_value),
      Matcher.verbatim(
        ',',
        tag: const Tag('separator', parent: Tags.punctuation),
      ),
    ]),
    tag: Tags.arrayLiteral,
  );

  Matcher _boolean() => Matcher.options(
    [
      Matcher.regex(r'\btrue\b', tag: Tags.trueLiteral),
      Matcher.regex(r'\bfalse\b', tag: Tags.falseLiteral),
    ],
    tag: Tags.literal,
  );

  Matcher _null() => Matcher.regex(r'\bnull\b', tag: Tags.nullLiteral);

  Matcher _number() => Matcher.regex(
    r'-?(0|[1-9]\d*)(\.\d+)?([eE][+-]?\d+)?',
    tag: Tags.numberLiteral,
  );

  Matcher _object() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '{',
      tag: const Tag('bracket-curly-begin', parent: Tags.punctuation),
    ),
    end: Matcher.verbatim(
      '}',
      tag: const Tag('bracket-curly-end', parent: Tags.punctuation),
    ),
    content: Matcher.options([
      Matcher.options([
        Matcher.include(_string),
        Matcher.verbatim(
          ':',
          tag: const Tag('separator', parent: Tags.punctuation),
        ),
        Matcher.include(_value),
      ], tag: const Tag('key-value-pair', parent: Tags.mapLiteral)),
      Matcher.verbatim(
        ',',
        tag: const Tag('separator', parent: Tags.punctuation),
      ),
    ]),
    tag: Tags.mapLiteral,
  );

  Matcher _string() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '"',
      tag: const Tag('begin', parent: Tags.stringLiteral),
    ),
    end: Matcher.verbatim(
      '"',
      tag: const Tag('end', parent: Tags.stringLiteral),
    ),
    content: Matcher.options([
      Matcher.regex(
        r'\\["\\/bfnrt]',
        tag: Tags.stringEscape,
      ),
      Matcher.regex(
        r'\\u[0-9a-fA-F]{4}',
        tag: Tags.stringEscape,
      ),
      Matcher.regex(
        r'[^"\\]+',
      ),
    ], tag: Tags.stringContent),
  );

  Matcher _value() => Matcher.options(
    [
      Matcher.include(_array),
      Matcher.include(_object),
      Matcher.include(_string),
      Matcher.include(_number),
      Matcher.include(_boolean),
      Matcher.include(_null),
    ],
  );
}
