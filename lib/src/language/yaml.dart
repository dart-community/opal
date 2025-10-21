import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

@internal
final class YamlGrammar extends MatcherGrammar {
  const YamlGrammar();

  @override
  List<Matcher> get matchers => [
    Matcher.include(_comments),
    Matcher.include(_documentMarkers),
    Matcher.include(_anchorsAndAliases),
    Matcher.include(_tags),
    Matcher.include(_multilineIndicators),
    Matcher.include(_keys),
    Matcher.include(_literals),
    Matcher.include(_strings),
    Matcher.include(_punctuation),
  ];

  Matcher _comments() => Matcher.regex(r'#.*$', tag: Tags.lineComment);

  Matcher _documentMarkers() => Matcher.options([
    Matcher.regex(
      r'^---\s*$',
      tag: const Tag('start', parent: _documentMarker),
    ),
    Matcher.regex(
      r'^\.\.\.\s*$',
      tag: const Tag('end', parent: _documentMarker),
    ),
  ]);

  static const Tag _documentMarker = Tag('document', parent: Tags.punctuation);

  Matcher _anchorsAndAliases() => Matcher.options([
    Matcher.regex(
      r'&[a-zA-Z0-9_-]+',
      tag: const Tag('anchor', parent: Tags.metadata),
    ),
    Matcher.regex(
      r'\*[a-zA-Z0-9_-]+',
      tag: const Tag('alias', parent: Tags.metadata),
    ),
  ]);

  Matcher _tags() => Matcher.options([
    Matcher.regex(
      r'!![a-zA-Z0-9_-]+',
      tag: const Tag('builtin', parent: Tags.annotation),
    ),
    Matcher.regex(
      r'![a-zA-Z0-9_-]+',
      tag: Tags.annotation,
    ),
    Matcher.regex(
      r'!<[^>]+>',
      tag: Tags.annotation,
    ),
  ]);

  Matcher _multilineIndicators() => Matcher.options([
    Matcher.regex(
      r'\|[+-]?',
      tag: const Tag('literal', parent: _multiline),
    ),
    Matcher.regex(
      r'>[+-]?',
      tag: const Tag('folded', parent: _multiline),
    ),
  ]);

  static const Tag _multiline = Tag('multiline', parent: Tags.stringLiteral);

  Matcher _strings() => Matcher.options([
    Matcher.include(_doubleQuotedString),
    Matcher.include(_singleQuotedString),
    Matcher.include(_plainScalar),
  ]);

  Matcher _doubleQuotedString() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '"',
      tag: const Tag('begin', parent: Tags.doubleQuoteString),
    ),
    end: Matcher.verbatim(
      '"',
      tag: const Tag('end', parent: Tags.doubleQuoteString),
    ),
    content: Matcher.options([
      Matcher.regex(r'\\[0abtnvfre "\\\/N_LP]', tag: Tags.stringEscape),
      Matcher.regex(r'\\x[0-9a-fA-F]{2}', tag: Tags.stringEscape),
      Matcher.regex(r'\\u[0-9a-fA-F]{4}', tag: Tags.stringEscape),
      Matcher.regex(r'\\U[0-9a-fA-F]{8}', tag: Tags.stringEscape),
      Matcher.regex(r'[^"\\]+'),
    ], tag: Tags.stringContent),
    tag: Tags.doubleQuoteString,
  );

  Matcher _singleQuotedString() => Matcher.wrapped(
    begin: Matcher.verbatim(
      "'",
      tag: const Tag('begin', parent: Tags.singleQuoteString),
    ),
    end: Matcher.verbatim(
      "'",
      tag: const Tag('end', parent: Tags.singleQuoteString),
    ),
    content: Matcher.options([
      Matcher.regex(r"''", tag: Tags.stringEscape),
      Matcher.regex(r"[^']+"),
    ], tag: Tags.stringContent),
    tag: Tags.singleQuoteString,
  );

  Matcher _plainScalar() => Matcher.regex(
    r'''[^\s:#\[\]{},&*!|>'"%@`-][^\n:#]*(?<![\s,])''',
    tag: Tags.unquotedString,
  );

  Matcher _literals() => Matcher.options([
    Matcher.include(_booleanLiterals),
    Matcher.include(_nullLiterals),
    Matcher.include(_numberLiterals),
  ]);

  Matcher _booleanLiterals() => Matcher.options([
    Matcher.regex(r'\b(?:true|True|TRUE)\b', tag: Tags.trueLiteral),
    Matcher.regex(r'\b(?:false|False|FALSE)\b', tag: Tags.falseLiteral),
    Matcher.regex(
      r'\b(?:yes|Yes|YES)\b',
      tag: const Tag('yes', parent: Tags.trueLiteral),
    ),
    Matcher.regex(
      r'\b(?:no|No|NO)\b',
      tag: const Tag('no', parent: Tags.falseLiteral),
    ),
    Matcher.regex(
      r'\b(?:on|On|ON)\b',
      tag: const Tag('on', parent: Tags.trueLiteral),
    ),
    Matcher.regex(
      r'\b(?:off|Off|OFF)\b',
      tag: const Tag('off', parent: Tags.falseLiteral),
    ),
  ]);

  Matcher _nullLiterals() => Matcher.options([
    Matcher.regex(r'\b(?:null|Null|NULL)\b', tag: Tags.nullLiteral),
    Matcher.regex(r'~', tag: Tags.nullLiteral),
  ]);

  Matcher _numberLiterals() => Matcher.options([
    Matcher.regex(
      r'\b0o[0-7]+\b',
      tag: const Tag('octal', parent: Tags.integerLiteral),
    ),
    Matcher.regex(
      r'\b0x[0-9a-fA-F]+\b',
      tag: const Tag('hex', parent: Tags.integerLiteral),
    ),
    Matcher.regex(
      r'\b[+-]?(?:\.[0-9]+|[0-9]+(?:\.[0-9]*)?)(?:[eE][+-]?[0-9]+)?\b',
      tag: Tags.numberLiteral,
    ),
    Matcher.regex(
      r'\b[+-]?\.(?:inf|Inf|INF)\b',
      tag: const Tag('infinity', parent: Tags.floatLiteral),
    ),
    Matcher.regex(
      r'\b\.(?:nan|NaN|NAN)\b',
      tag: const Tag('nan', parent: Tags.floatLiteral),
    ),
  ]);

  Matcher _keys() => Matcher.options([
    Matcher.regex(
      r'[a-zA-Z0-9_-]+(?=\s*:(?:\s|$))',
      tag: Tags.property,
    ),
    Matcher.regex(
      r'"(?:[^"\\]|\\.)*"(?=\s*:)',
      tag: _quotedKey,
    ),
    Matcher.regex(
      r"'(?:[^']|'')*'(?=\s*:)",
      tag: _quotedKey,
    ),
  ]);

  static const Tag _quotedKey = Tag('quoted', parent: Tags.property);

  Matcher _punctuation() => Matcher.options([
    Matcher.regex(
      r'^\s*-(?=\s)',
      tag: const Tag('list', parent: Tags.punctuation),
    ),
    Matcher.regex(r':', tag: Tags.separator),
    Matcher.regex(r',', tag: Tags.separator),
    Matcher.regex(r'[\[\]{}]', tag: Tags.punctuation),
    Matcher.regex(r'\?(?=\s)', tag: Tags.punctuation),
  ]);
}
