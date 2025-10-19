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
    end: Matcher.verbatim(
      '}',
      tag: const Tag('end', parent: Tags.mapLiteral),
    ),
    content: Matcher.options([
      Matcher.include(_objectKey),
      Matcher.verbatim(':', tag: Tags.separator),
      Matcher.include(_value),
      Matcher.verbatim(',', tag: Tags.separator),
    ]),
    tag: Tags.mapLiteral,
  );

  Matcher _objectKey() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '"',
      tag: const Tag('begin', parent: Tags.property),
    ),
    end: Matcher.verbatim(
      '"',
      tag: const Tag('end', parent: Tags.property),
    ),
    content: Matcher.options([
      Matcher.regex(r'\\["\\/bfnrt]', tag: Tags.stringEscape),
      Matcher.regex(r'\\u[0-9a-fA-F]{4}', tag: Tags.stringEscape),
      Matcher.regex(r'[^"\\]+'),
    ], tag: Tags.stringContent),
    tag: Tags.property,
  );

  Matcher _array() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '[',
      tag: const Tag('begin', parent: Tags.arrayLiteral),
    ),
    end: Matcher.verbatim(
      ']',
      tag: const Tag('end', parent: Tags.arrayLiteral),
    ),
    content: Matcher.options([
      Matcher.include(_value),
      Matcher.verbatim(',', tag: Tags.separator),
    ]),
    tag: Tags.arrayLiteral,
  );

  Matcher _string() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '"',
      tag: const Tag('begin', parent: Tags.doubleQuoteString),
    ),
    end: Matcher.verbatim(
      '"',
      tag: const Tag('end', parent: Tags.doubleQuoteString),
    ),
    content: Matcher.options([
      Matcher.regex(r'\\["\\/bfnrt]', tag: Tags.stringEscape),
      Matcher.regex(r'\\u[0-9a-fA-F]{4}', tag: Tags.stringEscape),
      Matcher.regex(r'[^"\\]+'),
    ], tag: Tags.stringContent),
    tag: Tags.doubleQuoteString,
  );

  Matcher _number() => Matcher.regex(
    r'-?(0|[1-9]\d*)(\.\d+)?([eE][+-]?\d+)?',
    tag: Tags.numberLiteral,
  );

  Matcher _boolean() => Matcher.options([
    Matcher.regex(r'\btrue\b', tag: Tags.trueLiteral),
    Matcher.regex(r'\bfalse\b', tag: Tags.falseLiteral),
  ]);

  Matcher _null() => Matcher.regex(r'\bnull\b', tag: Tags.nullLiteral);
}
