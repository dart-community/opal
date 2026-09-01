import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

/// A flexible lexical grammar for CSS (Cascading Style Sheets).
@internal
final class CssGrammar extends MatcherGrammar {
  const CssGrammar();

  // Keep reusable patterns non-capturing so they can safely be interpolated
  // into `Matcher.capture` expressions.
  static const String _escapePattern =
      r'\\(?:[0-9a-fA-F]{1,6}[ \t\f]?|[^\r\n0-9a-fA-F])';
  static const String _nonAsciiPattern = r'[^\x00-\x7f]';
  static const String _nameStartPattern =
      '(?:[_a-zA-Z]|$_nonAsciiPattern|$_escapePattern)';
  static const String _nameContinuePattern =
      '(?:[-_a-zA-Z0-9]|$_nonAsciiPattern|$_escapePattern)';
  static const String _identifierPattern =
      '(?:--|-?$_nameStartPattern)$_nameContinuePattern*';
  static const String _customIdentifierPattern = '--$_nameContinuePattern+';
  static const String _numberPattern =
      r'[+-]?(?:(?:[0-9]*\.[0-9]+)|[0-9]+)'
      r'(?:[eE][+-]?[0-9]+)?';
  static const String _closedCommentPattern = r'/\*(?:[^*]|\*(?!/))*\*/';
  static const String _doubleQuotedValuePattern =
      '"(?:$_escapePattern|[^"\\\\])*"';
  static const String _singleQuotedValuePattern =
      "'(?:$_escapePattern|[^'\\\\])*'";
  static const String _declarationValueItemPattern =
      '(?:$_closedCommentPattern|$_doubleQuotedValuePattern|'
      '$_singleQuotedValuePattern|$_escapePattern|/(?!\\*)|'
      r'''[^;{}"'/\\]'''
      ')';
  static const String _declarationTriviaPattern =
      '(?:[ \t\f]|$_closedCommentPattern)*';
  // Avoid treating nested selectors such as `a:hover {}` as declarations.
  // The lookahead stops at the first `;`, `{`, or `}`
  // outside of a string or comment,
  // so it stays within the current declaration.
  //
  // This lookahead is line-local and can't roll back, so newlines before a
  // declaration colon or ambiguous rule brace get best-effort highlighting.
  static const String _declarationValueGuard =
      '(?!$_declarationValueItemPattern*\\{)';

  static const Tag _atRuleTag = Tag('at-rule', parent: Tags.keyword);
  static const Tag _colorTag = Tag('color', parent: Tags.literal);
  static const Tag _unitTag = Tag('unit', parent: Tags.keyword);
  static const Tag _importantTag = Tag(
    'important',
    parent: Tags.modifierKeyword,
  );
  static const Tag _customPropertyTag = Tag('custom', parent: Tags.property);
  static const Tag _customVariableTag = Tag('custom', parent: Tags.variable);

  static const Tag _selectorTag = Tag('selector', parent: Tags.identifier);
  static const Tag _typeSelectorTag = Tag('type', parent: _selectorTag);
  static const Tag _universalTag = Tag('universal', parent: _selectorTag);
  static const Tag _classSelectorTag = Tag('class', parent: _selectorTag);
  static const Tag _idSelectorTag = Tag('id', parent: _selectorTag);
  static const Tag _attributeTag = Tag('attribute', parent: _selectorTag);
  static const Tag _attributeFlagTag = Tag(
    'flag',
    parent: Tags.modifierKeyword,
  );
  static const Tag _pseudoTag = Tag('pseudo', parent: _selectorTag);
  static const Tag _pseudoClassTag = Tag('class', parent: _pseudoTag);
  static const Tag _pseudoElementTag = Tag('element', parent: _pseudoTag);
  static const Tag _nestingTag = Tag('nesting', parent: _selectorTag);

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
    // Declarations must precede selectors because `color: red` and
    // `a:hover` have the same initial token shape.
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
      '(@)($_identifierPattern)',
      captures: [Tags.punctuation, _atRuleTag],
      caseSensitive: false,
    ),
    // A missing `;` would otherwise let the prelude swallow
    // the name of the at-rule that follows it.
    end: Matcher.regex(r'(?=[;{@])'),
    content: Matcher.include(_componentValues),
  );

  Matcher _declarations() => Matcher.options([
    // Custom-property values can contain arbitrary blocks, so match them
    // before applying the nested-rule guard used by normal declarations.
    _declaration(
      namePattern: _customIdentifierPattern,
      nameTag: _customPropertyTag,
    ),
    _declaration(
      namePattern: _identifierPattern,
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
        '$namePattern(?=$_declarationTriviaPattern:$afterColonPattern)',
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
    Matcher.include(_unicodeRange),
    Matcher.include(_colorLiteral),
    Matcher.include(_hashValue),
    Matcher.include(_dimension),
    Matcher.include(_percentage),
    Matcher.include(_numberLiteral),
    Matcher.include(_customPropertyReference),
    Matcher.include(_cssWideKeywords),
    Matcher.include(_selectorFunction),
    Matcher.include(_function),
    Matcher.include(_parenthesizedComponent),
    Matcher.include(_bracketedComponent),
    Matcher.include(_block),
    Matcher.include(_featureName),
    Matcher.include(_functionalPseudoSelectors),
    Matcher.include(_classSelector),
    Matcher.include(_idSelector),
    Matcher.include(_pseudoSelectors),
    Matcher.include(_nestingSelector),
    Matcher.include(_identifier),
    Matcher.include(_operators),
    Matcher.include(_punctuation),
  ]);

  Matcher _featureName() => Matcher.capture(
    '($_identifierPattern)(:)(?!:)',
    captures: [Tags.identifier, Tags.separator],
  );

  Matcher _selectorContent() => Matcher.options([
    Matcher.include(_comment),
    Matcher.include(_functionalPseudoSelectors),
    Matcher.include(_attributeSelector),
    Matcher.include(_classSelector),
    Matcher.include(_idSelector),
    Matcher.include(_pseudoSelectors),
    Matcher.include(_nestingSelector),
    Matcher.include(_selectorCombinators),
    Matcher.include(_universalSelector),
    Matcher.include(_namespaceSeparator),
    Matcher.include(_typeSelector),
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
        Matcher.include(_stringEscape),
        Matcher.regex(contentPattern, tag: Tags.stringContent),
      ]),
      tag: tag,
    );
  }

  Matcher _stringEscape() => Matcher.regex(
    '(?:$_escapePattern|'
    r'\\$'
    ')',
    tag: Tags.stringEscape,
  );

  Matcher _url() => Matcher.wrapped(
    begin: Matcher.capture(
      r'(url)(\()',
      captures: [Tags.function, Tags.punctuation],
      caseSensitive: false,
    ),
    // Recovering at `}` keeps a missing `)` from swallowing the rules that
    // follow. A `;` stays part of the URL so unquoted data URLs keep working.
    end: Matcher.regex(
      r'\)|(?=\})|$',
      tag: Tags.punctuation,
    ),
    content: Matcher.options([
      Matcher.include(_strings),
      Matcher.include(_stringEscape),
      Matcher.regex(
        r'''[^"'()}\\\s]+''',
        tag: const Tag('content', parent: MarkupTags.link),
      ),
    ]),
    tag: MarkupTags.link,
  );

  // Kept as two alternatives rather than one `([ \t]*)` group:
  // every capture group is emitted as a token, so an optional group
  // would tag an empty whitespace token when no space is present.
  Matcher _important() => Matcher.options([
    Matcher.capture(
      '(!)([ \\t]+)(important)(?!$_nameContinuePattern)',
      captures: [
        Tags.operator,
        Tags.whitespace,
        _importantTag,
      ],
      caseSensitive: false,
    ),
    Matcher.capture(
      '(!)(important)(?!$_nameContinuePattern)',
      captures: [
        Tags.operator,
        _importantTag,
      ],
      caseSensitive: false,
    ),
  ]);

  Matcher _unicodeRange() => Matcher.regex(
    r'[uU]\+[0-9a-fA-F?]{1,6}(?:-[0-9a-fA-F]{1,6})?',
    tag: Tags.numberLiteral,
  );

  Matcher _colorLiteral() => Matcher.regex(
    r'#(?:[0-9a-fA-F]{8}|[0-9a-fA-F]{6}|[0-9a-fA-F]{4}|'
    '[0-9a-fA-F]{3})(?!$_nameContinuePattern)',
    tag: _colorTag,
  );

  Matcher _hashValue() => Matcher.regex(
    '#$_nameContinuePattern+',
    tag: const Tag('hash', parent: Tags.literal),
  );

  Matcher _dimension() => Matcher.capture(
    '($_numberPattern)((?![eE][+-]?[0-9])$_identifierPattern)',
    captures: [Tags.numberLiteral, _unitTag],
  );

  Matcher _percentage() => Matcher.capture(
    '($_numberPattern)(%)',
    captures: [Tags.numberLiteral, _unitTag],
  );

  Matcher _numberLiteral() => Matcher.regex(
    _numberPattern,
    tag: Tags.numberLiteral,
  );

  Matcher _customPropertyReference() => Matcher.regex(
    _customIdentifierPattern,
    tag: _customVariableTag,
  );

  Matcher _cssWideKeywords() => Matcher.options([
    for (final keyword in [
      'inherit',
      'initial',
      'revert',
      'revert-layer',
      'unset',
    ])
      Matcher.regex(
        '$keyword(?!$_nameContinuePattern)',
        tag: Tag(keyword, parent: Tags.keyword),
        caseSensitive: false,
      ),
  ]);

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
      '($_identifierPattern)(\\()',
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
    _functionalPseudoSelector('::', _pseudoElementTag),
    _functionalPseudoSelector(':', _pseudoClassTag),
  ]);

  Matcher _functionalPseudoSelector(String prefix, Tag tag) => _parenthesized(
    begin: Matcher.capture(
      '($prefix)($_identifierPattern)(\\()',
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
      Matcher.include(_numberLiteral),
      Matcher.regex(_identifierPattern, tag: Tags.property),
      Matcher.include(_attributeValue),
      Matcher.include(_operators),
      Matcher.include(_punctuation),
    ]),
    tag: _attributeTag,
  );

  // Wrapping everything after the matcher operator separates the value from
  // the attribute name and gives the trailing case-sensitivity flag a
  // position it can be recognized in.
  Matcher _attributeValue() => Matcher.wrapped(
    begin: Matcher.regex(r'[~|^$*]?=', tag: Tags.operator),
    end: Matcher.regex(r'(?=[\]{;}])'),
    content: Matcher.options([
      Matcher.include(_comment),
      Matcher.include(_strings),
      // The flag follows a value, so a lone `[lang=i]` stays a value.
      Matcher.regex(
        '(?<=[\\s\'"])[iIsS](?=$_declarationTriviaPattern\\])',
        tag: _attributeFlagTag,
      ),
      Matcher.include(_numberLiteral),
      Matcher.regex(_identifierPattern, tag: Tags.unquotedString),
      Matcher.include(_punctuation),
    ]),
  );

  Matcher _classSelector() => Matcher.capture(
    '(\\.)($_identifierPattern)',
    captures: [Tags.punctuation, _classSelectorTag],
  );

  Matcher _idSelector() => Matcher.capture(
    '(#)($_identifierPattern)',
    captures: [Tags.punctuation, _idSelectorTag],
  );

  Matcher _pseudoSelectors() => Matcher.options([
    Matcher.capture(
      '(::)($_identifierPattern)',
      captures: [Tags.punctuation, _pseudoElementTag],
    ),
    Matcher.capture(
      '(:)($_identifierPattern)',
      captures: [Tags.punctuation, _pseudoClassTag],
    ),
  ]);

  Matcher _nestingSelector() => Matcher.verbatim(
    '&',
    tag: _nestingTag,
  );

  Matcher _selectorCombinators() => Matcher.options([
    Matcher.verbatim('||', tag: Tags.operator),
    Matcher.regex(r'[>+~]', tag: Tags.operator),
  ]);

  Matcher _universalSelector() => Matcher.verbatim(
    '*',
    tag: _universalTag,
  );

  Matcher _namespaceSeparator() => Matcher.verbatim(
    '|',
    tag: Tags.punctuation,
  );

  Matcher _typeSelector() => Matcher.regex(
    _identifierPattern,
    tag: _typeSelectorTag,
  );

  Matcher _identifier() => Matcher.regex(
    _identifierPattern,
    tag: Tags.identifier,
  );

  Matcher _operators() => Matcher.regex(
    r'~=|\|=|\^=|\$=|\*=|<=|>=|!=|==|\|\||[>+~*/=<!&|^?%-]',
    tag: Tags.operator,
  );

  Matcher _punctuation() => Matcher.options([
    Matcher.regex(r'[:,;]', tag: Tags.separator),
    Matcher.regex(r'[{}()\[\]#@]', tag: Tags.punctuation),
    Matcher.verbatim('.', tag: Tags.accessor),
  ]);
}
