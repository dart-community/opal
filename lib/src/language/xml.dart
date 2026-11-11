import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

/// Lexical highlighting for XML, including namespace prefixes and DTDs.
@internal
final class XmlGrammar extends MatcherGrammar {
  const XmlGrammar();

  // An approximation of XML names that accepts letters from any script,
  // as well as the middle dot and joiners some scripts use within words.
  // Colons are excluded so that namespace prefixes can be tagged separately.
  static const String _nameChars = r'\p{L}\p{M}\p{N}_.\-\u00B7\u200C\u200D';
  static const String _name = '[\\p{L}_][$_nameChars]*';
  static const String _prefixedName = '($_name)(:)($_name)';
  static const String _qualifiedName = '$_name(?::$_name)?';
  static const String _nameEnd = '(?![$_nameChars:])';

  static const Tag _begin = Tag('begin', parent: Tags.punctuation);
  static const Tag _end = Tag('end', parent: Tags.punctuation);
  static const Tag _namespace = Tag('namespace', parent: Tags.identifier);
  static const Tag _tagName = Tag('name', parent: Tags.tag);

  @override
  List<Matcher> get matchers => [
    Matcher.include(_whitespace),
    Matcher.include(_text),
    Matcher.include(_reference),
    // Tags are by far the most common markup, so try them first.
    // The other constructs begin with `<!` or `<?`, which a tag can't match.
    Matcher.include(_tag),
    Matcher.include(_comments),
    Matcher.include(_cdata),
    Matcher.include(_doctype),
    Matcher.include(_dtdDeclaration),
    Matcher.include(_xmlDeclaration),
    Matcher.include(_processingInstruction),
  ];

  // Whitespace is matched explicitly,
  // since the default rule is appended to every options matcher,
  // including the one that begins a tag.
  @override
  List<Matcher> get postAppliedMatchers => const [];

  Matcher _whitespace() => Matcher.regex(r'\s+', tag: Tags.whitespace);

  Matcher _text() => Matcher.regex(r'[^<&]*[^<&\s]', tag: MarkupTags.text);

  Matcher _reference() => Matcher.regex(
    '&(?:#[0-9]+|#x[0-9a-fA-F]+|$_name);',
    tag: Tags.stringEscape,
  );

  Matcher _peReference() => Matcher.regex(
    '%$_name;',
    tag: Tags.stringEscape,
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
      r'[^-]*(?:-(?!->)[^-]*)*',
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
      r'[^\]]*(?:\](?!\]>)[^\]]*)*',
      tag: Tags.stringContent,
    ),
    tag: Tags.stringLiteral,
  );

  Matcher _doctype() => Matcher.wrapped(
    begin: Matcher.capture(
      '(<!)(DOCTYPE)$_nameEnd',
      captures: [_begin, Tags.declarationKeyword],
    ),
    // The declarations, comments, and instructions of an internal subset
    // are part of the content, so only give way to an element tag.
    end: Matcher.regex('>|(?=<[^!?])', tag: _end),
    content: Matcher.options([
      Matcher.include(_whitespace),
      Matcher.include(_comments),
      Matcher.include(_dtdDeclaration),
      Matcher.include(_processingInstruction),
      Matcher.include(_peReference),
      Matcher.regex('(?:PUBLIC|SYSTEM)$_nameEnd', tag: Tags.keyword),
      _strings(),
      Matcher.regex(_qualifiedName, tag: _tagName),
      Matcher.verbatim('[', tag: _begin),
      Matcher.verbatim(']', tag: _end),
    ]),
    tag: const Tag('doctype', parent: Tags.metadata),
  );

  Matcher _dtdDeclaration() => Matcher.wrapped(
    begin: Matcher.capture(
      '(<!)(ELEMENT|ATTLIST|ENTITY|NOTATION)$_nameEnd',
      captures: [_begin, Tags.declarationKeyword],
    ),
    end: Matcher.regex('>|(?=<)', tag: _end),
    content: Matcher.options([
      Matcher.include(_whitespace),
      Matcher.include(_peReference),
      _strings(inDtd: true),
      Matcher.regex(
        '(?:#(?:PCDATA|REQUIRED|IMPLIED|FIXED)|EMPTY|ANY|SYSTEM|PUBLIC|NDATA)'
        '$_nameEnd',
        tag: Tags.keyword,
      ),
      Matcher.regex(
        '(?:CDATA|IDREFS?|ID|ENTITY|ENTITIES|NMTOKENS?|NOTATION)$_nameEnd',
        tag: Tags.builtInType,
      ),
      // Names and name tokens, which aren't namespace-aware in a DTD.
      Matcher.regex('[$_nameChars:]+', tag: Tags.identifier),
      Matcher.regex('[,|]', tag: Tags.separator),
      Matcher.regex('[?*+%]', tag: Tags.operator),
      Matcher.regex('[()]', tag: Tags.punctuation),
    ]),
    tag: const Tag('declaration', parent: Tags.metadata),
  );

  Matcher _xmlDeclaration() => Matcher.wrapped(
    begin: Matcher.capture(
      '(<\\?)(xml)$_nameEnd',
      captures: [_begin, Tags.keyword],
    ),
    end: Matcher.regex(r'\?>|(?=<)', tag: _end),
    content: Matcher.include(_attributes),
    tag: const Tag('xml-declaration', parent: Tags.metadata),
  );

  Matcher _processingInstruction() {
    const tag = Tag('processing-instruction', parent: Tags.metadata);
    return Matcher.wrapped(
      begin: Matcher.capture(
        '(<\\?)($_qualifiedName)',
        captures: [_begin, Tags.identifier],
      ),
      end: Matcher.verbatim('?>', tag: _end),
      content: Matcher.regex(
        r'[^?]*(?:\?(?!>)[^?]*)*',
        tag: const Tag('content', parent: tag),
      ),
      tag: tag,
    );
  }

  /// Matches both opening and closing tags.
  Matcher _tag() => Matcher.wrapped(
    begin: Matcher.options([
      Matcher.capture(
        '(</?)$_prefixedName',
        captures: [_begin, _namespace, Tags.separator, _tagName],
      ),
      Matcher.capture('(</?)($_name)', captures: [_begin, _tagName]),
    ]),
    end: Matcher.regex('/?>|(?=<)', tag: _end),
    content: Matcher.include(_attributes),
    tag: Tags.tag,
  );

  Matcher _attributes() => Matcher.options([
    Matcher.include(_whitespace),
    Matcher.capture(
      _prefixedName,
      captures: [_namespace, Tags.separator, Tags.property],
    ),
    Matcher.regex(_name, tag: Tags.property),
    Matcher.verbatim('=', tag: Tags.separator),
    _strings(),
  ]);

  /// Matches quoted literals, tagging entity references within them.
  ///
  /// Only literals [inDtd] declarations can
  /// contain `<` and parameter-entity references,
  /// so others end before a `<` if unclosed.
  Matcher _strings({bool inDtd = false}) => Matcher.options([
    for (final (quote, tag) in const [
      ('"', Tags.doubleQuoteString),
      ("'", Tags.singleQuoteString),
    ])
      Matcher.wrapped(
        begin: Matcher.verbatim(quote, tag: Tag('begin', parent: tag)),
        end: Matcher.regex(
          inDtd ? quote : '$quote|(?=<)',
          tag: Tag('end', parent: tag),
        ),
        content: Matcher.options([
          Matcher.include(_reference),
          if (inDtd) Matcher.include(_peReference),
          // A `&` or `%` that isn't part of a reference is plain content.
          Matcher.regex(
            '[^$quote&${inDtd ? '%' : '<'}]+|[&%]',
            tag: Tags.stringContent,
          ),
        ]),
        tag: tag,
      ),
  ]);
}
