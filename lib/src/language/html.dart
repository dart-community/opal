import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

@internal
final class HtmlGrammar extends MatcherGrammar {
  const HtmlGrammar();

  @override
  List<Matcher> get matchers => [
    Matcher.include(_doctype),
    Matcher.include(_comments),
    Matcher.include(_cdata),
    Matcher.include(_scriptTag),
    Matcher.include(_styleTag),
    Matcher.include(_element),
    Matcher.include(_text),
  ];

  Matcher _doctype() => Matcher.regex(
    r'<!DOCTYPE[^>]*>',
    tag: const Tag('doctype', parent: Tags.metadata),
  );

  Matcher _comments() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '<!--',
      tag: const Tag('begin', parent: Tags.blockComment),
    ),
    end: Matcher.verbatim(
      '-->',
      tag: const Tag('end', parent: Tags.blockComment),
    ),
    content: Matcher.regex(
      r'.+?(?=-->|$)',
      tag: const Tag('content', parent: Tags.blockComment),
    ),
    tag: Tags.blockComment,
  );

  Matcher _cdata() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '<![CDATA[',
      tag: const Tag('begin', parent: Tags.stringLiteral),
    ),
    end: Matcher.verbatim(
      ']]>',
      tag: const Tag('end', parent: Tags.stringLiteral),
    ),
    content: Matcher.regex(
      r'[\s\S]*?',
      tag: Tags.stringContent,
    ),
    tag: Tags.stringLiteral,
  );

  Matcher _scriptTag() => Matcher.wrapped(
    begin: Matcher.regex(
      r'<script(?:\s+[^>]*)?>',
      tag: const Tag('script-begin', parent: Tags.tag),
    ),
    end: Matcher.regex(
      r'</script\s*>',
      tag: const Tag('script-end', parent: Tags.tag),
    ),
    content: Matcher.regex(
      r'[\s\S]*?',
      tag: const Tag('script-content', parent: Tags.source),
    ),
    tag: const Tag('script', parent: Tags.tag),
  );

  Matcher _styleTag() => Matcher.wrapped(
    begin: Matcher.regex(
      r'<style(?:\s+[^>]*)?>',
      tag: const Tag('style-begin', parent: Tags.tag),
    ),
    end: Matcher.regex(
      r'</style\s*>',
      tag: const Tag('style-end', parent: Tags.tag),
    ),
    content: Matcher.regex(
      r'[\s\S]*?',
      tag: const Tag('style-content', parent: Tags.source),
    ),
    tag: const Tag('style', parent: Tags.tag),
  );

  Matcher _element() => Matcher.options([
    Matcher.include(_voidElement),
    Matcher.include(_selfClosingTag),
    Matcher.include(_openTag),
    Matcher.include(_closeTag),
  ]);

  Matcher _voidElement() => Matcher.regex(
    r'<(?:area|base|br|col|embed|hr|img|input|link|meta|param|source|track|wbr)(?:\s+[^>]*)?>',
    tag: const Tag('void-element', parent: Tags.tag),
  );

  Matcher _selfClosingTag() => Matcher.regex(
    r'<[a-zA-Z][a-zA-Z0-9-]*(?:\s+[^>]*)?/>',
    tag: Tags.tag,
  );

  Matcher _openTag() => Matcher.regex(
    r'<[a-zA-Z][a-zA-Z0-9-]*(?:\s+[^>]*)?>',
    tag: Tags.tag,
  );

  Matcher _closeTag() => Matcher.regex(
    r'</[a-zA-Z][a-zA-Z0-9-]*\s*>',
    tag: Tags.tag,
  );

  Matcher _text() => Matcher.options([
    Matcher.regex(r'&[a-zA-Z]+;', tag: Tags.stringEscape),
    Matcher.regex(r'&#[0-9]+;', tag: Tags.stringEscape),
    Matcher.regex(r'&#x[0-9a-fA-F]+;', tag: Tags.stringEscape),
    Matcher.regex(
      r'[^<&]+',
      tag: const Tag('text', parent: Tags.literal),
    ),
  ]);
}
