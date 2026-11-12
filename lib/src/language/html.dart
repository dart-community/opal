import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

/// Lexical highlighting for HTML, including raw-text elements and SVG/MathML.
///
/// Embedded `<script>` and `<style>` bodies are tokenized as raw code content
/// rather than delegated to separate language grammars.
@internal
final class HtmlGrammar extends MatcherGrammar {
  const HtmlGrammar();

  // Accepts custom element and foreign SVG/MathML names from any script,
  // while excluding colons so namespace prefixes can be tagged separately.
  static const String _nameChars = r'\p{L}\p{M}\p{N}_.\-\u00B7\u200C\u200D';
  static const String _nameEnd = '(?![$_nameChars:])';
  static const String _tagPrefixPattern = '[a-zA-Z][$_nameChars]*';
  static const String _tagNamePattern =
      '$_tagPrefixPattern(?::[$_nameChars:]+)?';
  static const String _identifierPattern = '[\\p{L}_][$_nameChars]*';
  static const String _colonIdentifierPattern = '[\\p{L}_][$_nameChars:]*';
  static const String _prefixedTagName =
      '($_tagPrefixPattern)(:)($_identifierPattern)$_nameEnd';
  static const String _prefixedAttrName =
      '($_identifierPattern)(:)($_identifierPattern)$_nameEnd';
  // Covers standard attributes, multi-colon names (such as
  // `hx-on:htmx:before-request`), sigil-prefixed bindings (`@click`, `:class`,
  // `?disabled`, `.value`, `*ngIf`, `#ref`), and bracket or paren bindings
  // (`[title]`, `(change)`, `[(ngModel)]`), while leaving lone stray
  // punctuation (such as `?` in `<input flag ?>`) unmatched.
  static const String _attrNamePattern =
      '(?:$_identifierPattern(?::[$_nameChars:]+)?|'
      '[@:?.*#][\\p{L}\\p{N}_][$_nameChars:]*|'
      '\\[\\($_colonIdentifierPattern\\)\\]|'
      '\\[$_colonIdentifierPattern\\]|'
      '\\($_colonIdentifierPattern\\))';

  static const String _namedReference = '[a-zA-Z][a-zA-Z0-9]*';
  static const String _referenceBody =
      '(?:#[0-9]+|#[xX][0-9a-fA-F]+|$_namedReference);';
  static const String _plainAmpersand = '&(?!$_referenceBody)';
  // Exclude `&#` from plain element text so malformed numeric references
  // such as `&#x;` surface as unknown `&` tokens.
  static const String _textAmpersand = '&(?!#|$_namedReference;)';

  // Recovers from an unclosed construct before a tag that
  // begins the next line or follows on the same line.
  static const String _lineStartsTag = r'^(?=\s*<)';
  static const String _beforeTag = '$_lineStartsTag|(?=<)';

  // Ends the element name in a raw-text element's closing tag.
  static const String _closeNameEnd = r'(?=[\s/>]|$)';

  static const Tag _begin = Tag('begin', parent: Tags.punctuation);
  static const Tag _end = Tag('end', parent: Tags.punctuation);
  static const Tag _namespace = Tag('namespace', parent: Tags.identifier);
  static const Tag _tagName = Tag('name', parent: Tags.tag);
  static const Tag _scriptSource = Tag('script', parent: Tags.codeSource);
  static const Tag _styleSource = Tag('style', parent: Tags.codeSource);

  static final Matcher _tagEnd = Matcher.regex('/?>|$_beforeTag', tag: _end);

  @override
  List<Matcher> get matchers => [
    Matcher.include(_whitespace),
    Matcher.include(_text),
    Matcher.include(_reference),
    Matcher.include(_rawElements),
    // Normal tags are far more common than declarations and comments,
    // which begin with `<!` and cannot match a tag.
    Matcher.include(_tag),
    Matcher.include(_comments),
    Matcher.include(_cdata),
    Matcher.include(_doctype),
  ];

  // Whitespace is matched explicitly,
  // since the default rule is appended to every options matcher,
  // including the one that begins a tag.
  @override
  List<Matcher> get postAppliedMatchers => const [];

  static Matcher _whitespace() => Matcher.regex(r'\s+', tag: Tags.whitespace);

  static Matcher _text() =>
      Matcher.regex(_textRun('<&', _textAmpersand), tag: MarkupTags.text);

  /// A pattern for a run of characters other than [excluded],
  /// interleaved with [special] sequences,
  /// that starts and ends with non-whitespace.
  ///
  /// Unrolled as `plain*(?:special plain*)*` so long runs stay in
  /// character-class loops rather than backtracking per character.
  static String _textRun(String excluded, String special) =>
      '(?=[^$excluded\\s]|$special)[^$excluded]*'
      '(?:(?:$special)[^$excluded]*)*(?<=\\S)';

  static Matcher _reference() => Matcher.regex(
    '&$_referenceBody',
    tag: Tags.stringEscape,
  );

  static Matcher _comments() => Matcher.options([
    // Abruptly closed empty HTML comments (`<!-->` and `<!--->`).
    Matcher.capture(
      r'(<!--)(-?>)',
      captures: [
        const Tag('begin', parent: Tags.blockComment),
        const Tag('end', parent: Tags.blockComment),
      ],
      tag: Tags.blockComment,
    ),
    Matcher.wrapped(
      begin: Matcher.verbatim(
        '<!--',
        tag: const Tag('begin', parent: Tags.blockComment),
      ),
      end: Matcher.regex(
        r'--!?>',
        tag: const Tag('end', parent: Tags.blockComment),
      ),
      content: Matcher.regex(
        r'[^-]*(?:-(?!-!?>)[^-]*)*',
        tag: const Tag('content', parent: Tags.blockComment),
      ),
      tag: Tags.blockComment,
    ),
  ]);

  static Matcher _cdata() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '<![CDATA[',
      tag: const Tag('begin', parent: Tags.stringLiteral),
    ),
    end: Matcher.verbatim(
      ']]>',
      tag: const Tag('end', parent: Tags.stringLiteral),
    ),
    content: Matcher.regex(
      r'[^\]]*(?:\](?!\]>)[^\]]*)*',
      tag: Tags.stringContent,
    ),
    tag: Tags.stringLiteral,
  );

  static Matcher _doctype() => Matcher.wrapped(
    begin: Matcher.capture(
      '(<!)(DOCTYPE)$_nameEnd',
      captures: [_begin, Tags.declarationKeyword],
      caseSensitive: false,
    ),
    end: Matcher.regex('>|$_beforeTag', tag: _end),
    content: Matcher.options([
      Matcher.include(_whitespace),
      Matcher.regex(
        '(?:PUBLIC|SYSTEM)$_nameEnd',
        tag: Tags.keyword,
        caseSensitive: false,
      ),
      Matcher.include(_strings),
      Matcher.capture(
        _prefixedTagName,
        captures: [_namespace, Tags.separator, _tagName],
      ),
      Matcher.regex(_tagNamePattern, tag: _tagName),
    ]),
    tag: const Tag('doctype', parent: Tags.metadata),
  );

  /// Matches raw-text (`<script>`, `<style>`) and escapable raw-text
  /// (`<textarea>`, `<title>`) elements through their closing tag.
  static Matcher _rawElements() => Matcher.options([
    for (final (name, contentTag, escapable) in const [
      ('script', _scriptSource, false),
      ('style', _styleSource, false),
      ('textarea', MarkupTags.text, true),
      ('title', MarkupTags.text, true),
    ])
      _rawElement(name, contentTag: contentTag, escapable: escapable),
  ]);

  /// Matches the raw-text element [name] through its closing tag,
  /// tagging its body with [contentTag].
  ///
  /// Only enters raw-content mode when the opening tag closes with `>`;
  /// self-closed (`/>`) or interrupted opening tags end the element.
  static Matcher _rawElement(
    String name, {
    required Tag contentTag,
    required bool escapable,
  }) {
    final strayAngle = '<(?!/$name$_closeNameEnd)';
    final body = Matcher.wrapped(
      begin: Matcher.options([
        Matcher.verbatim('>', tag: _end),
      ], tag: Tags.tag),
      end: _tagWith(
        Matcher.capture(
          '(</)($name)$_closeNameEnd',
          captures: [_begin, _tagName],
          caseSensitive: false,
        ),
      ),
      content: Matcher.options([
        Matcher.include(_whitespace),
        if (escapable) Matcher.include(_reference),
        Matcher.regex(
          escapable
              ? _textRun('<&', '$_textAmpersand|$strayAngle')
              : _textRun('<', strayAngle),
          tag: contentTag,
          caseSensitive: false,
        ),
      ]),
    );

    return Matcher.wrapped(
      // Stops before the opening tag's `>` or `/>`,
      // so that `end` can choose whether the body follows.
      begin: Matcher.wrapped(
        begin: Matcher.capture(
          '(<)($name)$_nameEnd',
          captures: [_begin, _tagName],
          caseSensitive: false,
        ),
        end: Matcher.regex('(?=/?>)|$_beforeTag'),
        content: Matcher.include(_attributes),
        tag: Tags.tag,
      ),
      end: Matcher.options([
        body,
        Matcher.options([_tagEnd], tag: Tags.tag),
      ]),
      // Never reached, since `end` matches wherever `begin` stops.
      content: Matcher.options(const []),
    );
  }

  /// Matches both opening and closing tags.
  static Matcher _tag() => _tagWith(
    Matcher.options([
      Matcher.capture(
        '(</?)$_prefixedTagName',
        captures: [_begin, _namespace, Tags.separator, _tagName],
      ),
      Matcher.capture(
        '(</?)($_tagNamePattern)',
        captures: [_begin, _tagName],
      ),
    ]),
  );

  /// Matches a tag that starts with [begin], followed by attributes,
  /// until it closes or is interrupted by another tag.
  static Matcher _tagWith(Matcher begin) => Matcher.wrapped(
    begin: begin,
    end: _tagEnd,
    content: Matcher.include(_attributes),
    tag: Tags.tag,
  );

  static Matcher _attributes() => Matcher.options([
    Matcher.include(_whitespace),
    Matcher.capture(
      _prefixedAttrName,
      captures: [_namespace, Tags.separator, Tags.property],
    ),
    Matcher.regex(_attrNamePattern, tag: Tags.property),
    Matcher.include(_attributeAssignment),
    Matcher.include(_strings),
  ]);

  /// Matches `=` and an optional unquoted attribute value,
  /// such as `charset=utf-8` or `href=/search?q=1&amp;page=2`,
  /// yielding to quoted literals or a following attribute when appropriate.
  static Matcher _attributeAssignment() => Matcher.wrapped(
    begin: Matcher.wrapped(
      begin: Matcher.verbatim('=', tag: Tags.separator),
      end: Matcher.regex('$_lineStartsTag|(?=\\S)'),
      content: Matcher.include(_whitespace),
    ),
    end: Matcher.regex(
      r'''(?=[\s<>]|/>|$)|(?<=^|\s|=)(?=["'`=])|(?<=^|\s)(?='''
      '$_attrNamePattern[ \\t]*=)',
    ),
    content: Matcher.options([
      Matcher.include(_reference),
      Matcher.regex(
        '[^\\s&<>/]*(?:(?:/(?!>)|$_plainAmpersand)[^\\s&<>/]*)*',
        tag: Tags.unquotedString,
      ),
    ]),
  );

  /// Matches quoted attribute and doctype literals,
  /// tagging character references within them.
  static Matcher _strings() => Matcher.options([
    for (final (quote, tag) in const [
      ('"', Tags.doubleQuoteString),
      ("'", Tags.singleQuoteString),
    ])
      Matcher.wrapped(
        begin: Matcher.verbatim(quote, tag: Tag('begin', parent: tag)),
        end: Matcher.verbatim(quote, tag: Tag('end', parent: tag)),
        content: Matcher.options([
          Matcher.include(_reference),
          Matcher.regex(
            '[^$quote&]*(?:$_plainAmpersand[^$quote&]*)*',
            tag: Tags.stringContent,
          ),
        ]),
        tag: tag,
      ),
  ]);
}
