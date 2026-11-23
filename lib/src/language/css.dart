import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';
import 'css_shared.dart';

/// A flexible lexical grammar for CSS (Cascading Style Sheets).
@internal
final class CssGrammar extends MatcherGrammar {
  const CssGrammar();

  static const String _declarationValueItemPattern =
      '(?:${StylesheetTokens.closedCommentPattern}|'
      '${StylesheetTokens.doubleQuotedValuePattern}|'
      '${StylesheetTokens.singleQuotedValuePattern}|'
      '${StylesheetTokens.escapePattern}|/(?!\\*)|'
      r'''[^;{}"'/\\]'''
      ')';
  // Avoid treating nested selectors such as `a:hover {}` as declarations.
  // The lookahead stops at the first `;`, `{`, or `}`
  // outside of a string or comment,
  // so it stays within the current declaration.
  //
  // This lookahead is line-local and can't roll back,
  // so newlines before a declaration colon or ambiguous rule brace
  // get best-effort highlighting.
  static const String _declarationValueGuard =
      '(?!$_declarationValueItemPattern*\\{)';

  @override
  List<Matcher> get matchers => [
    Matcher.include(_stylesheet),
  ];

  Matcher _stylesheet() => Matcher.options([
    Matcher.include(_comment),
    Matcher.include(_legacyMarkers),
    Matcher.include(_atRule),
    Matcher.include(_block),
    Matcher.include(_selectorContent),
  ]);

  Matcher _blockContent() => Matcher.options([
    Matcher.include(_comment),
    Matcher.include(_atRule),
    // Declarations must precede selectors because
    // `color: red` and `a:hover` have the same initial token shape.
    Matcher.include(_declarations),
    Matcher.include(_block),
    Matcher.include(_selectorContent),
  ]);

  Matcher _block() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '{',
      tag: const Tag('begin', parent: Tags.punctuation),
    ),
    end: Matcher.verbatim(
      '}',
      tag: const Tag('end', parent: Tags.punctuation),
    ),
    content: Matcher.include(_blockContent),
  );

  Matcher _comment() => Matcher.wrapped(
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
  );

  /// CDO and CDC tokens are ignored at the top level by the CSS parser.
  Matcher _legacyMarkers() => Matcher.regex(
    r'<!--|-->',
    tag: Tags.comment,
  );

  Matcher _atRule() => Matcher.wrapped(
    begin: Matcher.capture(
      '(@)(${StylesheetTokens.identifierPattern})',
      captures: [Tags.punctuation, StylesheetTokens.atRuleTag],
      caseSensitive: false,
    ),
    // A missing `;` must not swallow the enclosing block's closing brace
    // or the name of the at-rule that follows it.
    end: Matcher.regex(r'(?=[;{}@])'),
    content: Matcher.include(_componentValues),
  );

  Matcher _declarations() => Matcher.options([
    // Custom-property values can contain arbitrary blocks,
    // so match them before applying the nested-rule guard
    // used by normal declarations.
    _declaration(
      namePattern: StylesheetTokens.customIdentifierPattern,
      nameTag: StylesheetTokens.customPropertyTag,
    ),
    _declaration(
      namePattern: StylesheetTokens.identifierPattern,
      nameTag: Tags.property,
      afterColonPattern: _declarationValueGuard,
      // A non-custom declaration value can never contain a block,
      // so stopping at `{` keeps a nested rule that the line-local guard missed
      // from swallowing the declarations that follow it.
      endPattern: r';|(?=[{}])',
    ),
  ]);

  // Comments are whitespace in CSS.
  // A wrapped prefix preserves their comment tags and surrounding whitespace
  // between the name and colon.
  Matcher _declaration({
    required String namePattern,
    required Tag nameTag,
    String afterColonPattern = '',
    String endPattern = r';|(?=\})',
  }) => Matcher.wrapped(
    begin: Matcher.wrapped(
      begin: Matcher.regex(
        '$namePattern'
        '(?=${StylesheetTokens.declarationTriviaPattern}:$afterColonPattern)',
        tag: nameTag,
      ),
      end: Matcher.verbatim(':', tag: Tags.separator),
      content: Matcher.options([
        Matcher.include(_comment),
      ]),
    ),
    end: Matcher.regex(
      endPattern,
      tag: Tags.separator,
    ),
    content: Matcher.include(_componentValues),
  );

  Matcher _componentValues() => Matcher.options([
    Matcher.include(_comment),
    Matcher.include(_strings),
    Matcher.include(_url),
    Matcher.include(_important),
    StylesheetTokens.unicodeRange,
    StylesheetTokens.colorLiteral,
    StylesheetTokens.hashValue,
    StylesheetTokens.dimension,
    StylesheetTokens.percentage,
    StylesheetTokens.numberLiteral,
    // A following `(` takes precedence over identifier classifications,
    // including custom names such as `--spacing()`.
    Matcher.include(_selectorFunction),
    Matcher.include(_function),
    StylesheetTokens.customPropertyReference,
    StylesheetTokens.cssWideKeywords,
    Matcher.include(_parenthesizedComponent),
    Matcher.include(_bracketedComponent),
    Matcher.include(_block),
    StylesheetTokens.featureName,
    Matcher.include(_functionalPseudoSelectors),
    StylesheetTokens.classSelector,
    StylesheetTokens.idSelector,
    StylesheetTokens.pseudoSelectors,
    Matcher.include(_nestingSelector),
    StylesheetTokens.identifier,
    Matcher.include(_operators),
    StylesheetTokens.punctuation,
  ]);

  Matcher _selectorContent() => Matcher.options([
    Matcher.include(_comment),
    Matcher.include(_functionalPseudoSelectors),
    Matcher.include(_attributeSelector),
    StylesheetTokens.classSelector,
    StylesheetTokens.idSelector,
    StylesheetTokens.pseudoSelectors,
    Matcher.include(_nestingSelector),
    StylesheetTokens.selectorCombinators,
    StylesheetTokens.universalSelector,
    StylesheetTokens.namespaceSeparator,
    StylesheetTokens.typeSelector,
    // The value grammar is the recovery path for unknown selector syntax.
    Matcher.include(_componentValues),
  ]);

  Matcher _strings() => Matcher.options([
    Matcher.include(_singleQuotedString),
    Matcher.include(_doubleQuotedString),
  ]);

  Matcher _singleQuotedString() => _quotedString(
    quote: "'",
    tag: Tags.singleQuoteString,
  );

  Matcher _doubleQuotedString() => _quotedString(
    quote: '"',
    tag: Tags.doubleQuoteString,
  );

  // Neither quote character is a regular expression metacharacter,
  // so it can be interpolated into these patterns directly.
  Matcher _quotedString({
    required String quote,
    required Tag tag,
  }) {
    // An unterminated string recovers at the end of the line.
    final endPattern =
        '$quote|'
        r'(?<=(?:^|[^\\])(?:\\\\)*)$';
    final contentPattern =
        '[^$quote'
        r'\\]+';

    return Matcher.wrapped(
      begin: Matcher.verbatim(
        quote,
        tag: Tag('begin', parent: tag),
      ),
      end: Matcher.regex(
        endPattern,
        tag: Tag('end', parent: tag),
      ),
      content: Matcher.options([
        StylesheetTokens.stringEscape,
        Matcher.regex(contentPattern, tag: Tags.stringContent),
      ]),
      tag: tag,
    );
  }

  Matcher _url() => Matcher.wrapped(
    // Let the value start on a later line while
    // retaining line-end recovery once it begins,
    // so an unfinished URL doesn't swallow later declarations.
    begin: Matcher.wrapped(
      begin: Matcher.capture(
        r'(url)(\()',
        captures: [Tags.function, Tags.punctuation],
        caseSensitive: false,
      ),
      end: Matcher.regex(r'(?=\S)'),
      content: Matcher.regex(r'\s+', tag: Tags.whitespace),
    ),
    // Recover at `;` only when the remaining unquoted URL
    // can't reach `)` or the line ending.
    // A semicolon can start URL text or follow an escape,
    // where the end matcher runs before the content matcher.
    // Continue recovering at `}` and line endings.
    end: Matcher.regex(
      r'\)|(?=\})|(?=;)(?!'
      '(?:${StylesheetTokens.escapePattern}|'
      r'''[^"'()}\\\s])*[ \t\f]*(?:\)|$))|$''',
      tag: Tags.punctuation,
    ),
    content: Matcher.options([
      Matcher.include(_strings),
      StylesheetTokens.stringEscape,
      Matcher.regex(
        r'''[^"'()}\\\s]+''',
        tag: const Tag('content', parent: MarkupTags.link),
      ),
    ]),
    tag: MarkupTags.link,
  );

  Matcher _important() => Matcher.wrapped(
    begin: Matcher.regex(r'!(?!=)', tag: Tags.operator),
    // Give anything other than whitespace or a comment
    // back to the value grammar.
    // The wrapper can cross lines without searching past a token.
    end: Matcher.regex(
      'important(?!${StylesheetTokens.nameContinuePattern})|'
      r'(?=[^\s/]|/(?!\*))',
      tag: StylesheetTokens.importantTag,
      caseSensitive: false,
    ),
    content: Matcher.options([
      Matcher.include(_comment),
    ]),
  );

  Matcher _selectorFunction() => _parenthesized(
    begin: Matcher.capture(
      r'(selector)(\()',
      captures: [Tags.function, Tags.punctuation],
      caseSensitive: false,
    ),
    content: Matcher.include(_selectorContent),
  );

  Matcher _function() => _parenthesized(
    begin: Matcher.capture(
      '(${StylesheetTokens.identifierPattern})(\\()',
      captures: [Tags.function, Tags.punctuation],
    ),
    content: Matcher.include(_componentValues),
  );

  Matcher _parenthesizedComponent() => _parenthesized(
    begin: Matcher.verbatim('(', tag: Tags.punctuation),
    content: Matcher.include(_componentValues),
  );

  Matcher _parenthesized({
    required Matcher begin,
    required Matcher content,
    bool recoverBeforeBlock = false,
  }) => Matcher.wrapped(
    begin: begin,
    end: Matcher.regex(
      recoverBeforeBlock ? r'\)|(?=[{;}])' : r'\)|(?=[;}])',
      tag: Tags.punctuation,
    ),
    content: content,
  );

  Matcher _bracketedComponent() => Matcher.wrapped(
    begin: Matcher.verbatim('[', tag: Tags.punctuation),
    end: Matcher.regex(
      r'\]|(?=[{;}])',
      tag: Tags.punctuation,
    ),
    content: Matcher.include(_componentValues),
  );

  Matcher _functionalPseudoSelectors() => Matcher.options([
    _functionalPseudoSelector('::', StylesheetTokens.pseudoElementTag),
    _functionalPseudoSelector(':', StylesheetTokens.pseudoClassTag),
  ]);

  Matcher _functionalPseudoSelector(String prefix, Tag tag) => _parenthesized(
    begin: Matcher.capture(
      '($prefix)(${StylesheetTokens.identifierPattern})(\\()',
      captures: [Tags.punctuation, tag, Tags.punctuation],
    ),
    content: Matcher.include(_selectorContent),
    recoverBeforeBlock: true,
  );

  Matcher _attributeSelector() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '[',
      tag: const Tag('begin', parent: Tags.punctuation),
    ),
    end: Matcher.regex(
      r'\]|(?=[{;}])',
      tag: const Tag('end', parent: Tags.punctuation),
    ),
    content: Matcher.options([
      Matcher.include(_comment),
      Matcher.include(_strings),
      Matcher.include(_function),
      StylesheetTokens.numberLiteral,
      Matcher.regex(StylesheetTokens.identifierPattern, tag: Tags.property),
      Matcher.include(_attributeValue),
      Matcher.include(_operators),
      StylesheetTokens.punctuation,
    ]),
    tag: StylesheetTokens.attributeTag,
  );

  // Wrapping everything after the matcher operator
  // separates the value from the attribute name and
  // gives the trailing case-sensitivity flag
  // a position it can be recognized in.
  Matcher _attributeValue() => Matcher.wrapped(
    begin: Matcher.regex(r'[~|^$*]?=', tag: Tags.operator),
    end: Matcher.regex(r'(?=[\]{;}])'),
    content: Matcher.options([
      Matcher.include(_comment),
      Matcher.include(_strings),
      // The flag follows a value, so a lone `[lang=i]` stays a value.
      Matcher.regex(
        '(?<=[\\s\'"])[iIsS](?=${StylesheetTokens.declarationTriviaPattern}\\])',
        tag: StylesheetTokens.attributeFlagTag,
      ),
      StylesheetTokens.numberLiteral,
      Matcher.regex(
        StylesheetTokens.identifierPattern,
        tag: Tags.unquotedString,
      ),
      StylesheetTokens.punctuation,
    ]),
  );

  Matcher _nestingSelector() => Matcher.verbatim(
    '&',
    tag: StylesheetTokens.nestingTag,
  );

  Matcher _operators() => Matcher.regex(
    r'~=|\|=|\^=|\$=|\*=|<=|>=|!=|==|\|\||[>+~*/=<!&|^?%-]',
    tag: Tags.operator,
  );
}
