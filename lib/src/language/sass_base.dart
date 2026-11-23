import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';
import 'css_shared.dart';

/// Shared lexical rules for Sass (indented syntax) and SCSS.
///
/// Subclasses supply the syntax-specific statement terminators,
/// declaration disambiguation guards, and top-level structure.
@internal
abstract base class SassBaseGrammar extends MatcherGrammar {
  const SassBaseGrammar();

  /// A single-line `#{...}` interpolation,
  /// used inside property name and URL recovery lookaheads.
  ///
  /// The three alternatives start with disjoint characters,
  /// so scanning stays linear in the line length.
  @protected
  static const String inlineInterpolationPattern =
      r'#\{(?:[^}"'
      "'"
      r'\r\n]|"(?:\\.|[^"\\])*"|'
      "'(?:\\\\.|[^'\\\\])*'"
      r')*\}';

  /// Pattern for private Sass module variables, such as `$-gap` or `$_cache`.
  static const String _privateVariablePattern =
      '\\\$[_-]${StylesheetTokens.nameContinuePattern}*';

  /// Pattern for public Sass variables, such as `$primary`.
  static const String _publicVariablePattern =
      '\\\$${StylesheetTokens.identifierPattern}';

  /// A tag for module namespace prefixes, such as `math` in `math.div()`.
  static const Tag _namespaceTag = Tag('namespace', parent: Tags.identifier);

  /// A tag for module-private Sass variables, such as `$-internal-gap`.
  static const Tag _privateVariableTag = Tag('private', parent: Tags.variable);

  /// A tag for Sass placeholder selectors, such as `%visually-hidden`.
  static const Tag _placeholderSelectorTag = Tag(
    'placeholder',
    parent: StylesheetTokens.selectorTag,
  );

  static const Tag _docCommentContent = Tag('content', parent: Tags.docComment);
  static const Tag _blockCommentContent = Tag(
    'content',
    parent: Tags.blockComment,
  );
  static const Tag _interpolationBegin = Tag(
    'begin',
    parent: Tags.stringInterpolation,
  );
  static const Tag _interpolationEnd = Tag(
    'end',
    parent: Tags.stringInterpolation,
  );

  // Whitespace is matched explicitly in token-level option lists,
  // so disable the default trailing whitespace matcher.
  @override
  List<Matcher> get postAppliedMatchers => const [];

  /// Ends a statement, `;` in SCSS and the line end in indented Sass.
  @protected
  String get statementEnd;

  /// Extra alternatives that close an unclosed group at a line boundary,
  /// which only indented Sass needs.
  @protected
  String get lineRecovery => '';

  /// Lookbehind that the name of a declaration must follow.
  @protected
  String get lineStartPrefix;

  /// Lookahead required after `:` in standard property declarations.
  @protected
  String get propertyAfterColon;

  // A missing terminator recovers before the braces of an enclosing block.
  String get _atRuleEnd => '$statementEnd|(?=[{}@])';
  String get _declarationEnd => '$statementEnd|(?=[{}])';
  String _groupEnd(String close) => '\\$close|(?=[{;}])$lineRecovery';

  // Unclosed URLs and attribute selectors recover at the end of the line.
  // A `;` only ends a URL when the rest of the line doesn't close it.
  static const String _urlEnd =
      r'\)|(?=\})|(?=;)(?!'
      '(?:${StylesheetTokens.escapePattern}|$inlineInterpolationPattern|'
      r"""#(?!\{)|[^"'()}\\\s#])*[ \t\f]*(?:\)|$))|$""";

  /// Explicit whitespace token matcher.
  @protected
  static final Matcher whitespace = Matcher.regex(
    r'\s+',
    tag: Tags.whitespace,
  );

  /// Comments: `///` SassDoc, `//` silent line comments, and
  /// `/* ... */` / `/*! ... */` loud block comments with `#{...}` support.
  @protected
  Matcher comments() => Matcher.options([
    // Three slashes begin a SassDoc comment, while four or more (`////`)
    // remain an ordinary silent line comment.
    Matcher.wrapped(
      begin: Matcher.regex(
        r'///(?!/)',
        tag: const Tag('begin', parent: Tags.docComment),
      ),
      end: Matcher.regex(r'$'),
      content: Matcher.options([
        Matcher.regex(
          r'(?<=///[ \t]*)@[a-zA-Z][a-zA-Z0-9-]*',
          tag: Tags.annotation,
        ),
        Matcher.regex(
          r'(?<=///)[ \t]+(?=@[a-zA-Z])',
          tag: _docCommentContent,
        ),
        Matcher.regex(r'.+', tag: _docCommentContent),
      ]),
      tag: Tags.docComment,
    ),
    Matcher.regex(r'//.*$', tag: Tags.lineComment),
    loudComment(),
  ]);

  /// A `/* ... */` loud comment that ends at [end].
  ///
  /// Indented Sass passes an [end] that also closes
  /// standalone comments on dedent.
  @protected
  Matcher loudComment({String end = r'\*/'}) => Matcher.wrapped(
    begin: Matcher.regex(
      r'/\*!?',
      tag: const Tag('begin', parent: Tags.blockComment),
    ),
    end: Matcher.regex(end, tag: const Tag('end', parent: Tags.blockComment)),
    content: Matcher.options([
      Matcher.include(_interpolation),
      Matcher.regex(
        r'(?:[^*#]|\*(?!/)|#(?!\{))+',
        tag: _blockCommentContent,
      ),
    ]),
    tag: Tags.blockComment,
  );

  /// A `#{...}` interpolation expression.
  Matcher _interpolation() => Matcher.wrapped(
    begin: Matcher.verbatim('#{', tag: _interpolationBegin),
    end: Matcher.regex(r'\}|(?=;)|$', tag: _interpolationEnd),
    content: Matcher.include(_componentValues),
    tag: Tags.stringInterpolation,
  );

  /// Sass and CSS at-rules with specialized headers for
  /// contextual keywords and mixin/function targets.
  @protected
  Matcher atRules() => Matcher.options([
    _atRuleWithKeywords(
      names: const ['use', 'forward'],
      keywords: const ['as', 'with', 'show', 'hide'],
      keywordBaseTag: Tags.keyword,
    ),
    _mixinAtRule(),
    _includeAtRule(),
    _atRuleWithKeywords(
      names: const ['for'],
      keywords: const ['from', 'through', 'to'],
      keywordBaseTag: Tags.controlKeyword,
    ),
    _atRuleWithKeywords(
      names: const ['each'],
      keywords: const ['in'],
      keywordBaseTag: Tags.controlKeyword,
    ),
    _elseIfAtRule(),
    _selectorAtRule(),
    _genericAtRule(),
  ]);

  Matcher _atRule(Matcher begin, [Matcher? content]) => Matcher.wrapped(
    begin: begin,
    end: Matcher.regex(_atRuleEnd, tag: Tags.separator),
    content: content ?? Matcher.include(_componentValues),
  );

  static Matcher _atKeyword(String names) => Matcher.capture(
    '(@)($names)(?!${StylesheetTokens.nameContinuePattern})',
    captures: [Tags.punctuation, StylesheetTokens.atRuleTag],
    caseSensitive: false,
  );

  Matcher _atRuleWithKeywords({
    required List<String> names,
    required List<String> keywords,
    required Tag keywordBaseTag,
  }) => _atRule(
    _atKeyword(names.join('|')),
    Matcher.options([
      for (final keyword in keywords)
        _contextualKeyword(keyword, keywordBaseTag),
      Matcher.include(_componentValues),
    ]),
  );

  /// The `@mixin name` header or an indented `=name` shorthand.
  @protected
  Matcher mixinHeader(String prefix, List<Tag> prefixTags) => _atRule(
    Matcher.capture(
      '$prefix(${StylesheetTokens.identifierPattern})',
      captures: [...prefixTags, Tags.function],
      caseSensitive: false,
    ),
  );

  /// The `@include name` header or an indented `+name` shorthand.
  @protected
  Matcher includeHeader(String prefix, List<Tag> prefixTags) => _atRule(
    Matcher.options([
      Matcher.capture(
        '$prefix(${StylesheetTokens.identifierPattern})(\\.)'
        '(${StylesheetTokens.identifierPattern})',
        captures: [...prefixTags, _namespaceTag, Tags.accessor, Tags.function],
        caseSensitive: false,
      ),
      Matcher.capture(
        '$prefix(${StylesheetTokens.identifierPattern})',
        captures: [...prefixTags, Tags.function],
        caseSensitive: false,
      ),
    ]),
    Matcher.options([
      _contextualKeyword('using', Tags.keyword),
      Matcher.include(_componentValues),
    ]),
  );

  Matcher _mixinAtRule() => mixinHeader(r'(@)(mixin)(\s+)', const [
    Tags.punctuation,
    StylesheetTokens.atRuleTag,
    Tags.whitespace,
  ]);

  Matcher _includeAtRule() => includeHeader(r'(@)(include)(\s+)', const [
    Tags.punctuation,
    StylesheetTokens.atRuleTag,
    Tags.whitespace,
  ]);

  Matcher _elseIfAtRule() => _atRuleWithKeywords(
    names: const ['else'],
    keywords: const ['if'],
    keywordBaseTag: Tags.controlKeyword,
  );

  // `@extend` and `@at-root` take selectors rather than values.
  Matcher _selectorAtRule() => _atRule(
    _atKeyword('extend|at-root'),
    Matcher.include(selectorContent),
  );

  Matcher _genericAtRule() =>
      _atRule(_atKeyword(StylesheetTokens.identifierPattern));

  /// Matches a contextual keyword only when not part of a longer identifier.
  Matcher _contextualKeyword(String word, Tag baseTag) => Matcher.regex(
    '$word(?!${StylesheetTokens.nameContinuePattern})',
    tag: Tag(word, parent: baseTag),
  );

  /// Variable declarations (`$var: ...` and `ns.$var: ...`).
  @protected
  Matcher variableDeclarations() => Matcher.options([
    for (final (pattern, tag) in const [
      (_privateVariablePattern, _privateVariableTag),
      (_publicVariablePattern, Tags.variable),
    ]) ...[
      _declaration(
        Matcher.capture(
          '$lineStartPrefix(${StylesheetTokens.identifierPattern})'
          '(\\.)($pattern)'
          '(?=${StylesheetTokens.declarationTriviaPattern}:)',
          captures: [_namespaceTag, Tags.accessor, tag],
        ),
        nameTag: tag,
      ),
      _declaration(
        Matcher.regex(
          '$lineStartPrefix$pattern'
          '(?=${StylesheetTokens.declarationTriviaPattern}:)',
          tag: tag,
        ),
        nameTag: tag,
      ),
    ],
  ]);

  // A trailing name fragment might follow an interpolation,
  // such as `margin-#{$side}-top:`.
  static const String _nameRestPattern =
      '(?:$inlineInterpolationPattern'
      '${StylesheetTokens.nameContinuePattern}*)*';

  /// Custom property declarations (`--name:` and `--space-#{$k}:`) and
  /// standard or interpolated property declarations
  /// (`color:`, `margin-#{$s}:`).
  @protected
  Matcher propertyDeclarations() => Matcher.options([
    _declaration(
      Matcher.regex(
        '$lineStartPrefix--(?:${StylesheetTokens.nameContinuePattern}+|'
        '(?=$inlineInterpolationPattern))'
        '(?=$_nameRestPattern${StylesheetTokens.declarationTriviaPattern}:)',
        tag: StylesheetTokens.customPropertyTag,
      ),
      nameTag: StylesheetTokens.customPropertyTag,
    ),
    _declaration(
      Matcher.regex(
        '$lineStartPrefix${StylesheetTokens.identifierPattern}'
        '(?=$_nameRestPattern${StylesheetTokens.declarationTriviaPattern}:'
        '$propertyAfterColon)',
        tag: Tags.property,
      ),
      nameTag: Tags.property,
    ),
    Matcher.select(
      '$lineStartPrefix$inlineInterpolationPattern'
      '(?:${StylesheetTokens.nameContinuePattern}|$inlineInterpolationPattern)*'
      '(?=${StylesheetTokens.declarationTriviaPattern}:$propertyAfterColon)',
      // Including the declaration builds it once rather than per match.
      (_) => Matcher.include(_interpolatedPropertyDeclaration),
    ),
  ]);

  Matcher _interpolatedPropertyDeclaration() =>
      _declaration(Matcher.include(_interpolation), nameTag: Tags.property);

  // The name might continue with interpolations and name fragments,
  // and comments might sit before the colon.
  Matcher _declaration(Matcher name, {required Tag nameTag}) => Matcher.wrapped(
    begin: Matcher.wrapped(
      begin: name,
      end: Matcher.verbatim(':', tag: Tags.separator),
      content: Matcher.options([
        whitespace,
        Matcher.include(comments),
        Matcher.include(_interpolation),
        Matcher.regex(
          '${StylesheetTokens.nameContinuePattern}+',
          tag: nameTag,
        ),
      ]),
    ),
    end: Matcher.regex(_declarationEnd, tag: Tags.separator),
    content: Matcher.include(_componentValues),
  );

  /// SassScript expressions and CSS component values.
  Matcher _componentValues() => Matcher.options([
    whitespace,
    Matcher.include(comments),
    Matcher.include(_strings),
    Matcher.include(_url),
    Matcher.include(_flags),
    // Interpolation must precede color and hash literals so
    // `#{...}` isn't misread as `#`.
    Matcher.include(_interpolation),
    StylesheetTokens.unicodeRange,
    StylesheetTokens.colorLiteral,
    StylesheetTokens.hashValue,
    StylesheetTokens.dimension,
    StylesheetTokens.percentage,
    StylesheetTokens.numberLiteral,
    // Module variable prefixes and variables precede identifiers and
    // class selectors so `vars.$primary` isn't split at `.`.
    _moduleVariablePrefix,
    _variables,
    // Function calls precede custom property references,
    // keywords, and identifiers.
    Matcher.include(_moduleFunction),
    Matcher.include(_function),
    StylesheetTokens.customPropertyReference,
    _booleansAndNull,
    _logicalOperators,
    StylesheetTokens.cssWideKeywords,
    Matcher.include(_parenthesizedComponent),
    Matcher.include(_bracketedComponent),
    StylesheetTokens.featureName,
    Matcher.include(_functionalPseudoSelectors),
    StylesheetTokens.classSelector,
    StylesheetTokens.pseudoSelectors,
    _nestingSelector,
    StylesheetTokens.identifier,
    _operators,
    StylesheetTokens.punctuation,
  ]);

  /// Selector tokens, including Sass `%placeholder`,
  /// `&` with BEM suffixes, and `#{...}` interpolation.
  @protected
  Matcher selectorContent() => Matcher.options([
    whitespace,
    Matcher.include(comments),
    _interpolatedSelectorPrefix,
    Matcher.include(_selectorInterpolation),
    Matcher.include(_functionalPseudoSelectors),
    Matcher.include(_attributeSelector),
    _placeholderSelector,
    StylesheetTokens.classSelector,
    StylesheetTokens.idSelector,
    StylesheetTokens.pseudoSelectors,
    _nestingSelector,
    StylesheetTokens.selectorCombinators,
    StylesheetTokens.universalSelector,
    StylesheetTokens.namespaceSeparator,
    StylesheetTokens.typeSelector,
    // The value grammar is the recovery path for unknown selector syntax.
    Matcher.include(_componentValues),
  ]);

  // Attach any trailing selector characters directly after `#{...}` as
  // selector fragments without matching a type selector that
  // follows a `}` closing an adjacent block.
  Matcher _selectorInterpolation() => Matcher.wrapped(
    begin: Matcher.include(_interpolation),
    end: Matcher.regex('(?!${StylesheetTokens.nameContinuePattern})'),
    content: Matcher.regex(
      '${StylesheetTokens.nameContinuePattern}+',
      tag: StylesheetTokens.selectorTag,
    ),
  );

  /// Quoted strings (`'...'` and `"..."`),
  /// both supporting `#{...}` interpolation and CSS escapes.
  Matcher _strings() => Matcher.options([
    _quotedString(quote: "'", tag: Tags.singleQuoteString),
    _quotedString(quote: '"', tag: Tags.doubleQuoteString),
  ]);

  // Neither quote character is a regular expression metacharacter,
  // so it can be interpolated into these patterns directly.
  Matcher _quotedString({
    required String quote,
    required Tag tag,
  }) => Matcher.wrapped(
    begin: Matcher.verbatim(quote, tag: Tag('begin', parent: tag)),
    // An unterminated string recovers at the end of the line unless escaped.
    // Anchor `$` before the lookbehind so non-EOL positions fail in O(1).
    end: Matcher.regex(
      '$quote|\$(?<=(?:^|[^\\\\])(?:\\\\\\\\)*)',
      tag: Tag('end', parent: tag),
    ),
    content: Matcher.options([
      Matcher.include(_interpolation),
      StylesheetTokens.stringEscape,
      Matcher.regex('(?:[^$quote\\\\#]|#(?!\\{))+', tag: Tags.stringContent),
    ]),
    tag: tag,
  );

  /// `url(...)` with quoted strings, unquoted paths, and `#{...}` support.
  ///
  /// Comments are excluded from the URL body so
  /// schemes such as `http://` stay link content instead of
  /// starting a `//` silent comment.
  ///
  /// Sass parses a `url()` that starts with a variable or a call,
  /// such as `url($path)`, as an ordinary function call,
  /// so those fall through to [_function].
  Matcher _url() => Matcher.wrapped(
    begin: Matcher.wrapped(
      begin: Matcher.capture(
        r'(url)(\()(?![ \t]*[-\w.]*[$(])',
        captures: [Tags.function, Tags.punctuation],
        caseSensitive: false,
      ),
      end: Matcher.regex(r'(?=\S)'),
      content: whitespace,
    ),
    end: Matcher.regex(_urlEnd, tag: Tags.punctuation),
    content: Matcher.options([
      whitespace,
      Matcher.include(_strings),
      Matcher.include(_interpolation),
      StylesheetTokens.stringEscape,
      Matcher.regex(
        r'''(?:[^"'()}\\\s#]|#(?!\{))+''',
        tag: const Tag('content', parent: MarkupTags.link),
      ),
    ]),
    tag: MarkupTags.link,
  );

  /// Priority and variable flags:
  /// `!important`, `!default`, `!global`, and `!optional`.
  Matcher _flags() => Matcher.wrapped(
    // Leave `!=` to [_operators].
    begin: Matcher.regex(r'!(?!=)', tag: Tags.operator),
    end: Matcher.options([
      Matcher.regex(
        'important(?!${StylesheetTokens.nameContinuePattern})',
        tag: StylesheetTokens.importantTag,
        caseSensitive: false,
      ),
      for (final flag in const ['default', 'global', 'optional'])
        Matcher.regex(
          '$flag(?!${StylesheetTokens.nameContinuePattern})',
          tag: Tag(flag, parent: Tags.modifierKeyword),
          caseSensitive: false,
        ),
      // Give anything other than whitespace or a comment back to the
      // surrounding grammar so a lone `!` recovers immediately.
      Matcher.regex(r'(?=[^\s/]|/(?![/*]))|$'),
    ]),
    content: Matcher.options([
      whitespace,
      Matcher.include(comments),
    ]),
  );

  Matcher _moduleFunction() => _parenthesized(
    begin: Matcher.capture(
      '(${StylesheetTokens.identifierPattern})(\\.)'
      '(${StylesheetTokens.identifierPattern})(\\()',
      captures: [_namespaceTag, Tags.accessor, Tags.function, Tags.punctuation],
    ),
    content: Matcher.include(_componentValues),
  );

  Matcher _function() => _parenthesized(
    begin: Matcher.capture(
      '(${StylesheetTokens.identifierPattern})(\\()',
      captures: [Tags.function, Tags.punctuation],
    ),
    content: Matcher.include(_componentValues),
  );

  /// Parenthesized group, such as Sass maps, lists, or media conditions.
  Matcher _parenthesizedComponent() => _parenthesized(
    begin: Matcher.verbatim('(', tag: Tags.punctuation),
    content: Matcher.include(_componentValues),
  );

  Matcher _parenthesized({
    required Matcher begin,
    required Matcher content,
  }) => Matcher.wrapped(
    begin: begin,
    end: Matcher.regex(_groupEnd(')'), tag: Tags.punctuation),
    content: content,
  );

  Matcher _bracketedComponent() => Matcher.wrapped(
    begin: Matcher.verbatim('[', tag: Tags.punctuation),
    end: Matcher.regex(_groupEnd(']'), tag: Tags.punctuation),
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
    content: Matcher.include(selectorContent),
  );

  Matcher _attributeSelector() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '[',
      tag: const Tag('begin', parent: Tags.punctuation),
    ),
    end: Matcher.regex(
      r'\]|(?=[{;}])|$',
      tag: const Tag('end', parent: Tags.punctuation),
    ),
    content: Matcher.options([
      whitespace,
      Matcher.include(comments),
      Matcher.include(_strings),
      Matcher.include(_interpolation),
      Matcher.include(_function),
      StylesheetTokens.numberLiteral,
      Matcher.regex(StylesheetTokens.identifierPattern, tag: Tags.property),
      Matcher.include(_attributeValue),
      _operators,
      StylesheetTokens.punctuation,
    ]),
    tag: StylesheetTokens.attributeTag,
  );

  // Wrapping everything after the matcher operator separates the value from
  // the attribute name and recognizes trailing `i`/`s` flags.
  Matcher _attributeValue() => Matcher.wrapped(
    begin: Matcher.regex(r'[~|^$*]?=', tag: Tags.operator),
    end: Matcher.regex(r'(?=[\]{;}])|$'),
    content: Matcher.options([
      whitespace,
      Matcher.include(comments),
      Matcher.include(_strings),
      Matcher.include(_interpolation),
      // The flag follows a value, so a lone `[lang=i]` stays a value.
      Matcher.regex(
        '(?<=[\\s\'"\\}])[iIsS]'
        '(?=${StylesheetTokens.declarationTriviaPattern}\\])',
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

  static final Matcher _moduleVariablePrefix = Matcher.capture(
    '(${StylesheetTokens.identifierPattern})(\\.)(?=\\\$)',
    captures: [_namespaceTag, Tags.accessor],
  );

  static final Matcher _variables = Matcher.options([
    Matcher.regex(_privateVariablePattern, tag: _privateVariableTag),
    Matcher.regex(_publicVariablePattern, tag: Tags.variable),
  ]);

  static final Matcher _booleansAndNull = Matcher.options([
    for (final (word, tag) in const [
      ('true', Tags.trueLiteral),
      ('false', Tags.falseLiteral),
      ('null', Tags.nullLiteral),
    ])
      Matcher.regex(
        '$word(?!${StylesheetTokens.nameContinuePattern})',
        tag: tag,
      ),
  ]);

  static final Matcher _logicalOperators = Matcher.options([
    for (final op in const ['and', 'or', 'not'])
      Matcher.regex(
        '$op(?!${StylesheetTokens.nameContinuePattern})',
        tag: Tag(op, parent: Tags.operator),
      ),
  ]);

  static final Matcher _interpolatedSelectorPrefix = Matcher.regex(
    r'(?:\.|#|%|::?)(?=#\{)',
    tag: Tags.punctuation,
  );

  static final Matcher _placeholderSelector = Matcher.capture(
    '(%)(${StylesheetTokens.identifierPattern})',
    captures: [Tags.punctuation, _placeholderSelectorTag],
  );

  // Match attached BEM suffixes such as `&__header`, `&--featured`, and `&-2x`
  // before bare `&` so trailing hyphens and digits stay selector tokens.
  static final Matcher _nestingSelector = Matcher.options([
    Matcher.capture(
      '(&)(${StylesheetTokens.nameContinuePattern}+)',
      captures: [StylesheetTokens.nestingTag, StylesheetTokens.selectorTag],
    ),
    Matcher.verbatim('&', tag: StylesheetTokens.nestingTag),
  ]);

  // Match `...` before the `.` accessor,
  // and leave `//` and `/*` to [comments].
  static final Matcher _operators = Matcher.regex(
    r'\.\.\.|~=|\|=|\^=|\$=|\*=|<=|>=|!=|==|\|\||/(?![/*])|[>+~*=<!&|^?%-]',
    tag: Tags.operator,
  );
}
