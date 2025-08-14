import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

@internal
final class YamlGrammar extends MatcherGrammar {
  const YamlGrammar();

  @override
  List<Matcher> get matchers => [
    Matcher.include(_document),
  ];

  Matcher _document() => Matcher.options([
    Matcher.include(_comment),
    Matcher.include(_directive),
    Matcher.include(_documentSeparator),
    Matcher.include(_blockNode),
    Matcher.include(_flowNode),
  ]);

  Matcher _comment() => Matcher.regex(
    r'#.*$',
    tag: Tags.comment,
  );

  Matcher _directive() => Matcher.regex(
    r'^%[A-Z]+.*$',
    tag: const Tag('directive', parent: Tags.metadata),
  );

  Matcher _documentSeparator() => Matcher.regex(
    r'^(---|\.\.\.)\s*$',
    tag: const Tag('document-separator', parent: Tags.punctuation),
  );

  Matcher _blockScalar() => Matcher.options([
    // A literal scaler, starting with a `|`.
    Matcher.regex(
      r'\|[-+]?\d*\s*\n(\s+.*(\n|$))+',
      tag: const Tag('block-literal', parent: Tags.stringLiteral),
    ),
    // A folded scalar, starting with a `>`.
    Matcher.regex(
      r'>[-+]?\d*\s*\n(\s+.*(\n|$))+',
      tag: const Tag('block-folded', parent: Tags.stringLiteral),
    ),
  ]);

  Matcher _flowScalar() => Matcher.options([
    Matcher.wrapped(
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
      tag: Tags.doubleQuoteString,
    ),

    Matcher.wrapped(
      begin: Matcher.verbatim(
        "'",
        tag: const Tag('begin', parent: Tags.stringLiteral),
      ),
      end: Matcher.verbatim(
        "'",
        tag: const Tag('end', parent: Tags.stringLiteral),
      ),
      content: Matcher.options([
        Matcher.regex(
          r"''",
          tag: Tags.stringEscape,
        ),
        Matcher.regex(
          r"[^']+",
        ),
      ], tag: Tags.stringContent),
      tag: Tags.doubleQuoteString,
    ),
  ]);

  Matcher _plainScalar() => Matcher.regex(
    r'[^\s:,[\]{}#&*!|>"%@`][^\s:,[\]{}#]*',
    tag: const Tag('plain-scalar', parent: Tags.literal),
  );

  Matcher _number() => Matcher.regex(
    r'-?(0|[1-9]\d*)(\.\d+)?([eE][+-]?\d+)?',
    tag: Tags.numberLiteral,
  );

  Matcher _boolean() => Matcher.regex(
    r'\b(true|false|yes|no|on|off)\b',
    tag: Tags.booleanLiteral,
  );

  Matcher _null() => Matcher.regex(
    r'\b(null|~)\b',
    tag: Tags.nullLiteral,
  );

  Matcher _anchor() => Matcher.regex(
    r'&\w+',
    tag: const Tag('anchor', parent: Tags.identifier),
  );

  Matcher _alias() => Matcher.regex(
    r'\*\w+',
    tag: const Tag('alias', parent: Tags.identifier),
  );

  Matcher _tag() => Matcher.regex(
    r'!<!?[\w/]+>?',
    tag: const Tag('type-tag', parent: Tags.metadata),
  );

  Matcher _blockSequence() => Matcher.regex(
    r'^(\s*)- ',
    tag: const Tag('list-marker', parent: Tags.punctuation),
  );

  Matcher _blockMapping() => Matcher.options([
    Matcher.regex(
      r'\? ',
      tag: const Tag('key-marker', parent: Tags.punctuation),
    ),
    Matcher.regex(
      r': ',
      tag: const Tag('separator', parent: Tags.punctuation),
    ),
  ]);

  Matcher _flowSequence() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '[',
      tag: const Tag('bracket-square-begin', parent: Tags.punctuation),
    ),
    end: Matcher.verbatim(
      ']',
      tag: const Tag('bracket-square-end', parent: Tags.punctuation),
    ),
    content: Matcher.options([
      Matcher.include(_flowNode),
      Matcher.verbatim(
        ',',
        tag: const Tag('separator', parent: Tags.punctuation),
      ),
    ]),
    tag: Tags.arrayLiteral,
  );

  Matcher _flowMapping() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '{',
      tag: const Tag('bracket-curly-begin', parent: Tags.punctuation),
    ),
    end: Matcher.verbatim(
      '}',
      tag: const Tag('bracket-curly-end', parent: Tags.punctuation),
    ),
    content: Matcher.options([
      Matcher.include(_flowNode),
      Matcher.verbatim(
        ':',
        tag: const Tag('separator', parent: Tags.punctuation),
      ),
      Matcher.verbatim(
        ',',
        tag: const Tag('separator', parent: Tags.punctuation),
      ),
    ]),
    tag: Tags.mapLiteral,
  );

  Matcher _blockNode() => Matcher.options([
    Matcher.include(_blockSequence),
    Matcher.include(_blockMapping),
    Matcher.include(_blockScalar),
    Matcher.include(_anchor),
    Matcher.include(_alias),
    Matcher.include(_tag),
    Matcher.include(_flowScalar),
    Matcher.include(_plainScalar),
    Matcher.include(_number),
    Matcher.include(_boolean),
    Matcher.include(_null),
  ]);

  Matcher _flowNode() => Matcher.options([
    Matcher.include(_flowSequence),
    Matcher.include(_flowMapping),
    Matcher.include(_flowScalar),
    Matcher.include(_anchor),
    Matcher.include(_alias),
    Matcher.include(_tag),
    Matcher.include(_plainScalar),
    Matcher.include(_number),
    Matcher.include(_boolean),
    Matcher.include(_null),
  ]);
}
