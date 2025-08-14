import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

@internal
final class MarkdownGrammar extends MatcherGrammar {
  const MarkdownGrammar();

  @override
  List<Matcher> get matchers => [
    Matcher.include(_document),
  ];

  Matcher _document() => Matcher.options([
    Matcher.include(_frontMatter),
    Matcher.include(_heading),
    Matcher.include(_blockQuote),
    Matcher.include(_list),
    Matcher.include(_codeBlock),
    Matcher.include(_horizontalRule),
    Matcher.include(_table),
    Matcher.include(_htmlBlock),
    Matcher.include(_paragraph),
  ]);

  // Front matter often present in Markdown for site generators.
  Matcher _frontMatter() => Matcher.regex(
    r'^---\n[\s\S]*?\n---\n|^\+\+\+\n[\s\S]*?\n\+\+\+\n',
    tag: const Tag('front-matter', parent: Tags.metadata),
  );

  Matcher _heading() => Matcher.options([
    // ATX-style headings.
    Matcher.regex(
      r'^#{1,6}\s+.*$',
      tag: const Tag('heading', parent: Tags.tag),
    ),
    // Setext-style headings.
    Matcher.regex(
      r'^.+\n[=\-]+$',
      tag: const Tag('heading', parent: Tags.tag),
    ),
  ]);

  Matcher _blockQuote() => Matcher.regex(
    r'^>\s?.*$',
    tag: const Tag('block-quote', parent: Tags.punctuation),
  );

  Matcher _list() => Matcher.options([
    // Unordered lists, usually with items beginning with `-` or `*`.
    Matcher.regex(
      r'^(\s*)[-*+]\s+',
      tag: const Tag('list-marker', parent: Tags.punctuation),
    ),
    // Ordered lists, usually with items beginning with a number and a dot.
    Matcher.regex(
      r'^(\s*)\d+\.\s+',
      tag: const Tag('list-marker', parent: Tags.punctuation),
    ),
    // Tasks lists in GitHub flavored Markdown.
    Matcher.regex(
      r'^(\s*)[-*+]\s+\[[xX\s]\]\s+',
      tag: const Tag('task-list', parent: Tags.punctuation),
    ),
  ]);

  Matcher _codeBlock() => Matcher.options([
    // Fenced code block, wrapped by three or more backticks.
    Matcher.wrapped(
      begin: Matcher.regex(
        r'^```[\w\-]*\s*$',
        tag: const Tag('fence', parent: Tags.source),
      ),
      end: Matcher.regex(
        r'^```\s*$',
        tag: const Tag('fence', parent: Tags.source),
      ),
      content: Matcher.regex(
        r'.*',
        tag: const Tag('content', parent: Tags.source),
      ),
      tag: Tags.source,
    ),
    // Discouraged indented code block syntax, indented by 4 spaces or a tab.
    Matcher.regex(
      r'^(    |\t).*$',
      tag: const Tag('indented-code', parent: Tags.source),
    ),
  ]);

  Matcher _horizontalRule() => Matcher.regex(
    r'^(\*{3,}|-{3,}|_{3,})\s*$',
    tag: const Tag('horizontal-rule', parent: Tags.punctuation),
  );

  Matcher _table() => Matcher.options([
    Matcher.regex(
      r'^\|?[\s\-:|]+\|[\s\-:|]+\|?$',
      tag: const Tag('table-delimiter', parent: Tags.punctuation),
    ),
    Matcher.regex(
      r'^\|.*\|$',
      tag: const Tag('table-row', parent: Tags.tag),
    ),
  ]);

  Matcher _htmlBlock() => Matcher.regex(
    r'^<(\w+)([^>]*)>[\s\S]*?</\1>|^<\w+[^>]*/>',
    tag: const Tag('html-block', parent: Tags.tag),
  );

  Matcher _paragraph() => Matcher.options([
    Matcher.include(_inlineCode),
    Matcher.include(_emphasis),
    Matcher.include(_strong),
    Matcher.include(_strikethrough),
    Matcher.include(_link),
    Matcher.include(_image),
    Matcher.include(_autoLink),
    Matcher.include(_htmlInline),
    Matcher.include(_lineBreak),
    Matcher.include(_escape),
  ]);

  Matcher _inlineCode() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '`',
      tag: const Tag('backtick', parent: Tags.source),
    ),
    end: Matcher.verbatim(
      '`',
      tag: const Tag('backtick', parent: Tags.source),
    ),
    content: Matcher.regex(
      r'[^`]+',
      tag: const Tag('content', parent: Tags.source),
    ),
    tag: Tags.source,
  );

  Matcher _emphasis() => Matcher.options([
    Matcher.wrapped(
      begin: Matcher.regex(
        r'(?<!\*)\*(?!\*)',
        tag: const Tag('emphasis-marker', parent: Tags.punctuation),
      ),
      end: Matcher.regex(
        r'(?<!\*)\*(?!\*)',
        tag: const Tag('emphasis-marker', parent: Tags.punctuation),
      ),
      content: Matcher.regex(
        r'[^*]+',
        tag: const Tag('emphasis', parent: Tags.tag),
      ),
      tag: const Tag('emphasis', parent: Tags.tag),
    ),

    Matcher.wrapped(
      begin: Matcher.regex(
        r'(?<!_)_(?!_)',
        tag: const Tag('emphasis-marker', parent: Tags.punctuation),
      ),
      end: Matcher.regex(
        r'(?<!_)_(?!_)',
        tag: const Tag('emphasis-marker', parent: Tags.punctuation),
      ),
      content: Matcher.regex(
        r'[^_]+',
        tag: const Tag('emphasis', parent: Tags.tag),
      ),
      tag: const Tag('emphasis', parent: Tags.tag),
    ),
  ]);

  Matcher _strong() => Matcher.options([
    Matcher.wrapped(
      begin: Matcher.verbatim(
        '**',
        tag: const Tag('strong-marker', parent: Tags.punctuation),
      ),
      end: Matcher.verbatim(
        '**',
        tag: const Tag('strong-marker', parent: Tags.punctuation),
      ),
      content: Matcher.regex(
        r'[^*]+',
        tag: const Tag('strong', parent: Tags.tag),
      ),
      tag: const Tag('strong', parent: Tags.tag),
    ),
    Matcher.wrapped(
      begin: Matcher.verbatim(
        '__',
        tag: const Tag('strong-marker', parent: Tags.punctuation),
      ),
      end: Matcher.verbatim(
        '__',
        tag: const Tag('strong-marker', parent: Tags.punctuation),
      ),
      content: Matcher.regex(
        r'[^_]+',
        tag: const Tag('strong', parent: Tags.tag),
      ),
      tag: const Tag('strong', parent: Tags.tag),
    ),
  ]);

  Matcher _strikethrough() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '~~',
      tag: const Tag('strikethrough-marker', parent: Tags.punctuation),
    ),
    end: Matcher.verbatim(
      '~~',
      tag: const Tag('strikethrough-marker', parent: Tags.punctuation),
    ),
    content: Matcher.regex(
      r'[^~]+',
      tag: const Tag('strikethrough', parent: Tags.tag),
    ),
    tag: const Tag('strikethrough', parent: Tags.tag),
  );

  Matcher _link() => Matcher.options([
    Matcher.regex(
      r'\[([^\]]+)\]\(([^)]+)\)',
      tag: MarkupTags.link,
    ),
    Matcher.regex(
      r'\[([^\]]+)\]\[([^\]]*)\]',
      tag: MarkupTags.link,
    ),
    Matcher.regex(
      r'^\[([^\]]+)\]:\s*(.+)$',
      tag: const Tag('link-definition', parent: MarkupTags.link),
    ),
  ]);

  Matcher _image() => Matcher.options([
    Matcher.regex(
      r'!\[([^\]]*)\]\(([^)]+)\)',
      tag: const Tag('image', parent: Tags.tag),
    ),
    Matcher.regex(
      r'!\[([^\]]*)\]\[([^\]]*)\]',
      tag: const Tag('image', parent: Tags.tag),
    ),
  ]);

  Matcher _autoLink() => Matcher.options([
    Matcher.regex(
      r'<(https?://[^>]+|[^@>]+@[^>]+)>',
      tag: MarkupTags.link,
    ),
    Matcher.regex(
      r'https?://[^\s<]+',
      tag: MarkupTags.link,
    ),
  ]);

  Matcher _htmlInline() => Matcher.regex(
    r'</?[A-Za-z][^>]*>',
    tag: const Tag('html-inline', parent: Tags.tag),
  );

  Matcher _lineBreak() => Matcher.regex(
    r'  $|\\$',
    tag: const Tag('line-break', parent: Tags.whitespace),
  );

  Matcher _escape() => Matcher.regex(
    r'\\[\\`*_{}[\]()#+\-.!|]',
    tag: const Tag('escape', parent: Tags.stringEscape),
  );
}
