import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

@internal
final class XmlGrammar extends MatcherGrammar {
  const XmlGrammar();

  @override
  List<Matcher> get matchers => [
    Matcher.include(_xmlDeclaration),
    Matcher.include(_doctypeDeclaration),
    Matcher.include(_comments),
    Matcher.include(_cdata),
    Matcher.include(_processingInstruction),
    Matcher.include(_element),
    Matcher.include(_text),
  ];

  Matcher _xmlDeclaration() => Matcher.regex(
    r'<\?xml[^?>]*\?>',
    tag: const Tag('xml-declaration', parent: Tags.metadata),
  );

  Matcher _doctypeDeclaration() => Matcher.regex(
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

  Matcher _processingInstruction() => Matcher.regex(
    r'<\?[^?>]+\?>',
    tag: const Tag('processing-instruction', parent: Tags.metadata),
  );

  Matcher _element() => Matcher.options([
    Matcher.include(_selfClosingTag),
    Matcher.include(_openTag),
    Matcher.include(_closeTag),
  ]);

  Matcher _selfClosingTag() => Matcher.regex(
    r'<[a-zA-Z_][\w:.-]*(?:\s+[^>]*)?/>',
    tag: Tags.tag,
  );

  Matcher _openTag() => Matcher.regex(
    r'<[a-zA-Z_][\w:.-]*(?:\s+[^>]*)?>',
    tag: Tags.tag,
  );

  Matcher _closeTag() => Matcher.regex(
    r'</[a-zA-Z_][\w:.-]*>',
    tag: Tags.tag,
  );

  Matcher _text() => Matcher.regex(
    r'[^<]+',
    tag: const Tag('text', parent: Tags.literal),
  );
}
