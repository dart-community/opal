import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

/// Lexical highlighting for C#.
@internal
final class CSharpGrammar extends MatcherGrammar {
  const CSharpGrammar() : _implicitNames = null;

  CSharpGrammar._inAccessor(List<String> names)
    : _implicitNames = {
        for (final name in names)
          name: _contextual(name, Tags.specialIdentifier),
      };

  /// Implicitly declared identifiers, such as `field` and `value`,
  /// in scope within an accessor body.
  final Map<String, Matcher>? _implicitNames;

  static const String _unicodeEscape = r'\\(?:u[\da-fA-F]{4}|U[\da-fA-F]{8})';
  static const String _identifierStart = '(?:[\\p{L}\\p{Nl}_]|$_unicodeEscape)';
  static const String _identifierPart =
      '(?:[\\p{L}\\p{Nl}\\p{M}\\p{Nd}\\p{Pc}\\p{Cf}]|$_unicodeEscape)';
  static const String _nameStart = '@?$_identifierStart';
  static const String _identifier = '$_nameStart$_identifierPart*';
  static const String _rightBoundary = '(?!$_identifierPart)';
  static const String _utf8Suffix = '(?:[uU]8$_rightBoundary)?';

  @override
  List<Matcher> get matchers => [
    Matcher.regex(r'\s+', tag: Tags.whitespace),
    // Match identifiers and keywords early, since they are common
    // and can't begin any of the tokens below.
    Matcher.include(_names),
    Matcher.include(_comments),
    Matcher.regex(r'(?<=^[ \t]*)#.*', tag: Tags.preprocessorDirective),
    Matcher.include(_strings),
    Matcher.include(_numbers),
    Matcher.include(_attributes),
    Matcher.include(_unionCases),
    Matcher.include(_typeArgumentList),
    Matcher.include(_typeList),
    Matcher.include(_operators),
  ];

  /// Whitespace is matched explicitly by [matchers] and wrapped constructs,
  /// so disable the default trailing whitespace rule on [Matcher.options].
  @override
  List<Matcher> get postAppliedMatchers => const [];

  Matcher _comments() => Matcher.options([
    // Four or more slashes, such as `////`, form a regular line comment.
    Matcher.regex(r'///(?!/).*', tag: Tags.docComment),
    Matcher.regex(r'//.*', tag: Tags.lineComment),
    for (final (opener, tag) in const [
      // Exclude `/**/` and `/***`, which are regular block comments.
      (r'/\*\*(?![*/])', Tags.docComment),
      (r'/\*', Tags.blockComment),
    ])
      Matcher.wrapped(
        begin: Matcher.regex(opener, tag: Tag('begin', parent: tag)),
        end: Matcher.verbatim('*/', tag: Tag('end', parent: tag)),
        content: Matcher.regex(
          r'(?:[^*]|\*(?!/))+',
          tag: Tag('content', parent: tag),
        ),
        tag: tag,
      ),
  ]);

  Matcher _strings() => Matcher.options([
    _rawString(),
    for (final opener in const ['"', "'", '@"', r'$"', r'$@"', r'@$"'])
      _quotedString(opener),
  ]);

  Matcher _quotedString(String opener) {
    final character = opener == "'";
    final quote = character ? "'" : '"';
    final tag = character ? Tags.characterLiteral : Tags.doubleQuoteString;
    final verbatim = opener.contains('@');
    final interpolated = opener.contains(r'$');
    final suffix = character || interpolated ? '' : _utf8Suffix;
    final endQuote = verbatim ? '"(?!")' : quote;
    final excluded = [
      quote,
      if (!verbatim) r'\\',
      if (interpolated) '{}',
    ].join();

    return Matcher.wrapped(
      begin: Matcher.verbatim(opener, tag: Tag('begin', parent: tag)),
      end: Matcher.regex(
        '$endQuote$suffix${verbatim ? '' : r'|$'}',
        tag: Tag('end', parent: tag),
      ),
      content: Matcher.options([
        Matcher.regex('[^$excluded]+', tag: Tags.stringContent),
        if (verbatim)
          Matcher.verbatim('""', tag: Tags.stringEscape)
        else
          Matcher.regex(
            r'\\(?:x[\da-fA-F]{1,4}|u[\da-fA-F]{4}|U[\da-fA-F]{8}|.)?',
            tag: Tags.stringEscape,
          ),
        if (interpolated) ...[
          Matcher.regex(r'\{\{|\}\}', tag: Tags.stringEscape),
          _interpolation(1),
          // Keep an unescaped `}` as string content rather than unknown text.
          Matcher.verbatim('}', tag: Tags.stringContent),
        ],
      ]),
      tag: tag,
    );
  }

  /// A raw string literal, such as `"""text"""` or `$$"""{{value}}"""`.
  ///
  /// The `$` and `"` counts determine the interpolation and end delimiters.
  /// A raw string spans lines only when whitespace alone follows its opener;
  /// otherwise, an unclosed literal ends with the line.
  Matcher _rawString() => Matcher.select(r'(\$*)("{3,})\s*', (match) {
    final dollars = match[1]!;
    final quotes = match[2]!;
    final multiline = match.end == match.input.length;
    final suffix = dollars.isEmpty ? _utf8Suffix : '';
    final delimiters = dollars.isEmpty
        ? quotes
        : '$quotes|${_openingBraces(dollars.length)}';
    const tag = Tags.tripleQuoteString;

    return Matcher.wrapped(
      begin: Matcher.verbatim(
        '$dollars$quotes',
        tag: const Tag('begin', parent: tag),
      ),
      end: Matcher.regex(
        '$quotes$suffix${multiline ? '' : r'|$'}',
        tag: const Tag('end', parent: tag),
      ),
      content: Matcher.options([
        if (dollars.isNotEmpty) _interpolation(dollars.length),
        Matcher.regex('[\\s\\S]+?(?=$delimiters|\$)', tag: Tags.stringContent),
      ]),
      tag: tag,
    );
  });

  /// Matches the [width] opening braces of an interpolation hole.
  ///
  /// In a longer run of braces, such as `{{{x}}}` in a `$$"""` string,
  /// the extra leading braces stay literal content,
  /// and the final [width] braces open the hole.
  static String _openingBraces(int width) =>
      '${RegExp.escape('{' * width)}(?!\\{)';

  Matcher _interpolation(int width) => Matcher.wrapped(
    begin: Matcher.regex(
      _openingBraces(width),
      tag: const Tag('begin', parent: Tags.stringInterpolation),
    ),
    end: Matcher.verbatim(
      '}' * width,
      tag: const Tag('end', parent: Tags.stringInterpolation),
    ),
    content: Matcher.include(_interpolatedExpression),
    tag: Tags.stringInterpolation,
  );

  Matcher _interpolatedExpression() => Matcher.options([
    // A single top-level colon starts a format string,
    // such as `:N2` in `{amount,8:N2}`, whereas `::` is an accessor.
    Matcher.regex(r':(?!:)[^}]*', tag: Tags.stringContent),
    Matcher.include(_expression),
  ]);

  /// An expression that balances `{}`, `()`, and `[]` groups
  /// so nested delimiters and colons, such as in `(ready ? a : b)`,
  /// stay inside the group rather than ending an enclosing construct.
  ///
  /// Unclosed `(` and `[` groups recover before a closing `}`.
  Matcher _expression() => Matcher.options([
    for (final (open, close) in const [
      ('{', r'\}'),
      ('(', r'\)|(?=\})'),
      ('[', r'\]|(?=\})'),
    ])
      Matcher.wrapped(
        begin: Matcher.verbatim(open, tag: Tags.punctuation),
        end: Matcher.regex(close, tag: Tags.punctuation),
        content: Matcher.include(_expression),
      ),
    ...matchers,
  ]);

  Matcher _numbers() {
    const digits = '[0-9][0-9_]*';
    const exponent = '[eE][+-]?$digits';
    const realSuffix = '[fFdDmM]';
    return Matcher.options([
      Matcher.regex(
        '(?:(?:$digits)?\\.$digits(?:$exponent)?$realSuffix?|'
        '$digits(?:$exponent$realSuffix?|$realSuffix))$_rightBoundary',
        tag: Tags.floatLiteral,
      ),
      Matcher.regex(
        '(?:0[xX][0-9a-fA-F_]+|0[bB][01_]+|$digits)'
        '(?:[uU][lL]?|[lL][uU]?)?$_rightBoundary',
        tag: Tags.integerLiteral,
      ),
      // Consume a malformed number, such as `0x` or `12abc`, as one token
      // so its trailing characters aren't highlighted as an identifier.
      Matcher.regex('[0-9]$_identifierPart*', tag: Tags.numberLiteral),
    ]);
  }

  static const String _attributeName =
      '(?:$_identifier\\.)*$_capitalized(?=\\s*[(,<\\]])';

  /// An attribute list, such as `[Obsolete]` or `[return: NotNull]`.
  ///
  /// Excludes bracketed expressions that can also start a statement or block,
  /// such as index initializers (`[Key] = 1`)
  /// and list patterns (`[First, ..] => 1`).
  Matcher _attributes() => Matcher.wrapped(
    begin: Matcher.regex(
      // Match `[` before the lookbehind so other characters fail immediately.
      '\\[(?<=(?:$_statementStart|\\]\\s*)\\[)(?=\\s*(?:[a-z]+\\s*:\\s*)?'
      '$_attributeName)'
      r'(?![^\[\]]*\]\s*[=,;.)\]])',
      tag: Tags.punctuation,
    ),
    end: Matcher.regex(r'\]|(?=[;{}])', tag: Tags.punctuation),
    content: Matcher.options([
      Matcher.regex(_attributeName, tag: Tags.annotation),
      // Highlight type and constructor arguments as normal expressions.
      Matcher.include(_expression),
    ]),
  );

  /// The case list of a union declaration,
  /// such as `(Ok, Error)` in `union Result(Ok, Error)`.
  ///
  /// Matching from the opening `(` lets the list span multiple lines
  /// without every identifier checking whether it follows `union`.
  Matcher _unionCases() => Matcher.wrapped(
    begin: Matcher.regex(
      '\\((?<=\\bunion\\s+$_notInfixKeyword$_identifier'
      '(?:$_typeArguments)?\\s*\\()',
      tag: Tags.punctuation,
    ),
    // Recover at the end of the declaration if the list is never closed.
    end: Matcher.regex(r'\)|(?=[;{}])', tag: Tags.punctuation),
    content: Matcher.options([_nameOr(_unionCase), ...matchers]),
  );

  static final Matcher _unionCase = Matcher.regex(_identifier, tag: Tags.type);

  /// A type argument or type parameter list,
  /// such as `<string, List<Person>>` or `<in T>`.
  ///
  /// Matching from the opening `<` avoids having every identifier
  /// check for an enclosing `<...>` list.
  Matcher _typeArgumentList() => Matcher.wrapped(
    begin: Matcher.regex(
      '(?<=$_identifierPart)(?=$_typeArguments)<',
      tag: Tags.punctuation,
    ),
    // `begin` requires a closing `>` on this line; `|$` guards recovery.
    end: Matcher.regex(r'>|$', tag: Tags.punctuation),
    content: Matcher.options([_nameOr(_typeName, _typeNames), ...matchers]),
  );

  /// A base-type list or type-parameter constraint clause,
  /// such as `: Base, IBox where T : IItem, new()`.
  ///
  /// Matching from the `:` lets the list span multiple lines
  /// without every identifier checking whether it follows a declaration.
  Matcher _typeList() => Matcher.wrapped(
    begin: Matcher.regex(
      ':(?<=(?:\\b(?:class|interface|struct|record)\\s+$_identifier'
      '(?:$_typeArguments)?\\s*(?:$_parenthesized\\s*)?|'
      '\\bwhere\\s+$_identifier\\s*):)',
      tag: Tags.separator,
    ),
    // End before the body, or recover at an unbalanced closing delimiter.
    end: Matcher.regex(r'(?=[{};)]|=>)'),
    content: Matcher.options([
      _nameOr(_typeName, _constraintNames),
      // Group base-constructor arguments, such as `(size)` in `: Base(size)`,
      // so they aren't treated as types and their `)` doesn't end this list.
      Matcher.include(_expression),
    ]),
  );

  /// A name in a type list, highlighting a capitalized identifier as a type
  /// unless it qualifies another name (such as `System` in `System.Text`),
  /// invokes a base constructor (such as `Base` in `: Base(size)`),
  /// or names a tuple element (such as `Ok` in `(bool Ok, int)`).
  static final Matcher _typeName = Matcher.options([
    Matcher.regex(
      // Allow a variance modifier before a type parameter, such as `<in T>`,
      // while rejecting a preceding type before a tuple element name.
      '(?:(?<=\\b(?:in|out)\\s+)|(?<!(?:$_identifierPart|[>?\\]])\\s+))'
      '$_capitalized$_rightBoundary(?!\\s*\\.|$_callStart)',
      tag: Tags.type,
    ),
    _ordinaryName,
  ]);

  /// Contextual type names ([_contextualTypes]),
  /// which are always built-in types inside a type list.
  static final Map<String, Matcher> _typeNames = {
    for (final type in _contextualTypes)
      type: Matcher.verbatim(type, tag: Tags.builtInType),
  };

  /// Scoped names in [_typeList], including constraint-only keywords
  /// such as `notnull` and `unmanaged` in `where T : notnull`.
  static final Map<String, Matcher> _constraintNames = {
    ..._typeNames,
    ..._keywords(['notnull', 'unmanaged'], Tags.keyword),
  };

  Matcher _operators() => Matcher.options([
    Matcher.regex(r'\?\.|::|->', tag: Tags.accessor),
    Matcher.regex(
      r'>{2,3}=?|<<=?|\?\?=?|\.\.|=>|==|!=|<=|>=|&&|\|\||\+\+|--|'
      r'[-+*/%&|^]=',
      tag: Tags.operator,
    ),
    // Require surrounding spaces or an opening delimiter to distinguish
    // relational `<` and `>`, such as `a < b` or `(> 0)`, from `<T>`.
    Matcher.regex(
      r'(?<=[\s(\[{,:]|^)[<>](?=\s|$)',
      tag: Tags.operator,
    ),
    Matcher.regex(r'[-+*/%&|^~!=?]', tag: Tags.operator),
    Matcher.verbatim('.', tag: Tags.accessor),
    Matcher.regex(r'[:,]', tag: Tags.separator),
    Matcher.regex(r'[{}()\[\]<>;]', tag: Tags.punctuation),
  ]);

  /// A single character allowed inside [_typeArguments],
  /// excluding `&` and `|` so comparisons such as `a < b && c > d`
  /// aren't mistaken for type arguments.
  static const String _typeArgument = r'[^<>(){};=&|]';

  /// A balanced `<...>` type list, including tuple types and nested generics,
  /// such as `<string, List<(int, Person)>>`.
  static final String _typeArguments = _typeArgumentsOf(3);

  /// Optional generic, nullable, and array suffixes on a type,
  /// such as `<int>?[]` in `List<int>?[]`.
  static final String _typeSuffix =
      '(?:$_typeArguments)?'
      r'(?:\?|\[,*\])*';

  /// A `<...>` type list with up to [depth] levels of nested `<...>` lists.
  static String _typeArgumentsOf(int depth) {
    final argument = depth == 0
        ? _typeArgument
        : '$_typeArgument|${_typeArgumentsOf(depth - 1)}';
    return '<(?!<)(?:$argument|\\((?:$argument)*\\))*>';
  }

  /// A parenthesized group with up to one level of nested parentheses,
  /// such as `(int count, (int, int) pair)`.
  static const String _parenthesized = r'\((?:[^()]|\([^()]*\))*\)';
  static final String _callStart = '\\s*(?:$_typeArguments\\s*)?\\(';
  static final String _call = '(?=$_callStart)';

  /// A `.`, `?.`, or `->` member access before a member name,
  /// excluding `..` in ranges and spreads such as `0..count` or `..items`.
  static const String _memberAccess = r'(?:(?<!\.)\.|->)\s*';
  static const String _capitalized = '\\p{Lu}$_identifierPart*';
  static const String _statementStart = r'(?:^|[{};])\s*';

  /// Keywords that continue an expression after an operand,
  /// such as `with` in `record with { }` or `is` in `required is true`.
  static const String _infixKeywords = 'as|in|is|switch|with';
  static const String _notInfixKeyword = '(?!(?:$_infixKeywords)\\b)';

  /// The start of a declared name after a type,
  /// excluding keywords that continue an expression or query,
  /// such as `switch` in `Kind switch` or `select` in `in Items select`.
  static const String _declaredName =
      '(?!(?:$_infixKeywords|ascending|by|descending|equals|from|group|into|'
      'join|let|on|orderby|select|when|where)\\b)$_nameStart';

  Matcher _names() => _nameOr(_ordinaryName, _implicitNames ?? _accessors());

  /// Scans a complete identifier once and dispatches on its full text,
  /// so names such as `@class` or `class名` don't match keywords.
  ///
  /// Any [scoped] names take precedence over [_knownNames].
  static Matcher _nameOr(
    Matcher fallback, [
    Map<String, Matcher> scoped = const {},
  ]) => Matcher.select(_identifier, (match) {
    final name = match[0];
    return scoped[name] ?? _knownNames[name] ?? fallback;
  });

  /// Implicit identifiers, such as `field` and `value`,
  /// in scope within each kind of accessor body.
  static const Map<String, List<String>> _accessorNames = {
    'get': ['field'],
    'set': ['field', 'value'],
    'init': ['field', 'value'],
    'add': ['value'],
    'remove': ['value'],
  };

  /// Matchers for property and event accessors, such as `get;`,
  /// `set => field = value;`, or a `set` with a block on the next line.
  ///
  /// The wrapper's `content` skips whitespace and comments across lines
  /// until `end` ([_accessorBody]) consumes the body,
  /// or exits at another token such as `;` in `get;`.
  Map<String, Matcher> _accessors() => {
    for (final MapEntry(key: word, value: names) in _accessorNames.entries)
      word: Matcher.options([
        Matcher.wrapped(
          begin: Matcher.regex(
            // An accessor can follow its attributes or modifiers.
            '(?<=(?:$_statementStart|\\]\\s*)'
            '(?:(?:private|protected|internal|readonly)\\s+)*)'
            '$word(?=\\s*(?:[;{]|=>|/[/*]|\$))',
            tag: Tag(word, parent: Tags.declarationKeyword),
          ),
          end: _accessorBody(names),
          content: Matcher.options([
            Matcher.regex(r'\s+', tag: Tags.whitespace),
            Matcher.include(_comments),
          ]),
        ),
        _ordinaryName,
      ]),
  };

  /// Consumes an accessor's block or expression body
  /// with [names] highlighted as special identifiers.
  Matcher _accessorBody(List<String> names) {
    // Nested expressions, including string interpolations, share this scope.
    final content = Matcher.options(CSharpGrammar._inAccessor(names).matchers);
    final block = Matcher.wrapped(
      begin: Matcher.verbatim('{', tag: Tags.punctuation),
      end: Matcher.verbatim('}', tag: Tags.punctuation),
      content: content,
      nestable: true,
    );
    return Matcher.options([
      block,
      Matcher.wrapped(
        begin: Matcher.verbatim('=>', tag: Tags.operator),
        // Recover before the enclosing `}` if `;` is missing.
        end: Matcher.regex(r';|(?=\})', tag: Tags.punctuation),
        content: Matcher.options([block, content]),
      ),
      // Keep skipping whitespace, line breaks, and comments; any other token,
      // such as `;` in `get;`, ends the accessor without consuming a body.
      Matcher.regex(r'(?!\s|$|/[/*])'),
    ]);
  }

  static final Matcher _ordinaryName = Matcher.options([
    Matcher.regex(
      '(?<=\\b(?:break|continue|goto)\\s+)$_identifier',
      tag: Tags.label,
    ),
    // A statement label, such as `retry:` before a statement or at line end,
    // excluding `Name: value` in property patterns and named arguments.
    Matcher.regex(
      '(?<=$_statementStart)$_identifier(?=\\s*:\\s*(?:(?:break|continue|do|'
      'for|foreach|goto|if|lock|return|switch|throw|try|using|while)\\b|;|\$))',
      tag: Tags.label,
    ),
    Matcher.regex(
      '(?<=\\b(?:class|interface|struct|enum|record|union)\\s+)$_identifier|'
      '(?<=\\busing\\s+)$_identifier(?=\\s*=)',
      tag: Tags.type,
    ),
    Matcher.regex(
      '(?<=\\bnew\\s+(?:$_identifier\\.)*)$_identifier$_call',
      tag: Tags.constructor,
    ),
    Matcher.regex('$_identifier$_call', tag: Tags.function),
    // A qualified type before a declared name,
    // such as `Exception` in `System.Exception error`,
    // rather than a pattern member such as in `is Kind.Small or Kind.Large`.
    Matcher.regex(
      '(?<=\\.)$_capitalized'
      '(?=$_typeSuffix\\s+(?!(?:and|or)\\b)$_declaredName)',
      tag: Tags.type,
    ),
    Matcher.regex('(?<=$_memberAccess)$_identifier', tag: Tags.property),
    Matcher.regex(_typePattern(_capitalized, generic: true), tag: Tags.type),
    // A property declaration,
    // an object-initializer assignment such as `{ Name = "x" }`,
    // or a capitalized name before `:` in a property pattern, tuple,
    // or argument list, such as `(Name: "x")`.
    Matcher.regex(
      '(?<=[\\w>?\\]]\\s+)(?<!\\b(?:case|namespace|when)\\s+)'
      '$_capitalized(?=\\s*(?:\\{|=>))|'
      // A modifier and type before a name at line end indicate a property
      // whose body starts on the next line, such as `public int Count`,
      // unlike a return type at line end, such as `public static Result`.
      '(?<=\\b(?:$_memberModifiers)\\s+(?!(?:$_memberModifiers)\\b)'
      '(?:$_identifier\\.)*$_identifier$_typeSuffix\\s+)'
      '$_capitalized(?=\\s*\$)|'
      '(?<=[{,]\\s*)$_capitalized(?=\\s*=(?![=>]))|'
      '(?<=[{,(]\\s*)$_capitalized(?=\\s*:(?!:))',
      tag: Tags.property,
    ),
    Matcher.regex(_identifier, tag: Tags.identifier),
  ]);

  static final Map<String, Matcher> _knownNames = {
    ..._keywords([
      'break',
      'case',
      'catch',
      'continue',
      'default',
      'do',
      'else',
      'finally',
      'for',
      'foreach',
      'goto',
      'if',
      'lock',
      'return',
      'switch',
      'throw',
      'try',
      'while',
    ], Tags.controlKeyword),
    ..._keywords([
      'class',
      'delegate',
      'enum',
      'event',
      'interface',
      'namespace',
      'operator',
      'struct',
      'using',
    ], Tags.declarationKeyword),
    ..._keywords([
      'abstract',
      'const',
      'explicit',
      'extern',
      'implicit',
      'internal',
      'out',
      'override',
      'params',
      'private',
      'protected',
      'public',
      'readonly',
      'ref',
      'sealed',
      'static',
      'unsafe',
      'virtual',
      'volatile',
    ], Tags.modifierKeyword),
    ..._keywords([
      'as',
      'checked',
      'fixed',
      'in',
      'is',
      'new',
      'sizeof',
      'stackalloc',
      'typeof',
      'unchecked',
    ], Tags.keyword),
    for (final type in _builtInTypes)
      type: Matcher.verbatim(type, tag: Tags.builtInType),
    'this': Matcher.verbatim('this', tag: Tags.specialIdentifier),
    'base': Matcher.verbatim('base', tag: Tags.specialIdentifier),
    'true': Matcher.verbatim('true', tag: Tags.trueLiteral),
    'false': Matcher.verbatim('false', tag: Tags.falseLiteral),
    'null': Matcher.verbatim('null', tag: Tags.nullLiteral),

    'record': _keyword(
      'record',
      Tags.declarationKeyword,
      after:
          '(?=\\s+(?:(?:class|struct)\\s+)?'
          '$_notInfixKeyword$_identifier\\s*(?:[<({:;]|\$))',
    ),
    'union': _keyword(
      'union',
      Tags.declarationKeyword,
      after: '(?=\\s+$_notInfixKeyword$_identifier\\s*(?:[<({;]|\$))',
    ),
    'closed': _keyword(
      'closed',
      Tags.modifierKeyword,
      after: '(?=\\s+$_typeModifiers(?:class|record|enum)\\b)',
    ),
    'file': _keyword(
      'file',
      Tags.modifierKeyword,
      after:
          '(?=\\s+$_typeModifiers'
          '(?:class|record|struct|interface|enum|delegate|union)\\b)',
    ),
    // An extension block, such as `extension(string s) { ... }`,
    // rather than a call statement ending in `;`.
    'extension': _keyword(
      'extension',
      Tags.declarationKeyword,
      before: '(?<=$_statementStart)',
      after: '(?=$_callStart(?![^{]*;))',
    ),
    'var': _keyword('var', Tags.declarationKeyword, after: _beforeDeclaration),
    ..._keywords(
      ['async', 'partial', 'required'],
      Tags.modifierKeyword,
      after: _beforeDeclaration,
    ),
    // Omit `$_notInfixKeyword` since `scoped` can precede the `in` modifier,
    // such as in `scoped in ReadOnlySpan<int>`.
    'scoped': _keyword(
      'scoped',
      Tags.modifierKeyword,
      after: '(?=\\s+$_nameStart)',
    ),
    ..._keywords(['await', 'when'], Tags.controlKeyword, after: _beforeOperand),
    'yield': _keyword(
      'yield',
      Tags.controlKeyword,
      after: r'(?=\s+(?:return|break)\b)',
    ),
    // Either a `with` expression, such as `record with { ... }`,
    // or collection-expression arguments, such as `[with(capacity: 8), ..xs]`
    // (excluding an index expression such as `values[with()]`).
    'with': _contextual(
      r'with(?=\s*\{)|'
      r'(?<=(?:^|[=(,:\[{]|=>|\?\?|\?\s|\breturn)\s*\[\s*)with(?=\s*\()|'
      // When `[` is on an earlier line, `with(...)` is followed by `,` or `]`
      // or spans another line, unlike a call such as `with(items[0]);`.
      '(?<=^\\s*)with(?=\\s*(?:$_parenthesized\\s*[,\\]]|'
      r'\((?:[^()]|\([^()]*\))*$))',
      const Tag('with', parent: Tags.keyword),
    ),
    'nameof': _keyword('nameof', Tags.keyword, after: r'(?=\s*\()'),
    'global': _keyword('global', Tags.keyword, after: r'(?=\s*(?:::|using\b))'),
    ..._keywords(
      ['from', 'join'],
      Tags.keyword,
      after: r'(?=\s+[^;{}()=]+\bin\b)',
    ),
    'let': _keyword('let', Tags.keyword, after: '(?=\\s+$_identifier\\s*=)'),
    ..._keywords(
      ['by', 'equals', 'group', 'into', 'on', 'orderby', 'select', 'where'],
      Tags.keyword,
      after: _beforeOperand,
    ),
    ..._keywords(
      ['and', 'not', 'or'],
      Tags.keyword,
      after: '(?:$_beforeOperand|(?=\\s+[<>]))',
    ),
    ..._keywords(
      ['ascending', 'descending'],
      Tags.keyword,
      before: r'(?<=\borderby\s+[^;{}]*)',
    ),
    for (final type in _contextualTypes)
      type: _contextual(_typePattern(type), Tags.builtInType),
    // A calling convention on a function pointer,
    // such as in `delegate* unmanaged<int, void>`;
    // constraint uses (`where T : unmanaged`) are in `_constraintNames`.
    'unmanaged': _keyword(
      'unmanaged',
      Tags.keyword,
      before: r'(?<=\bdelegate\s*\*\s*)',
    ),
    'allows': _keyword('allows', Tags.keyword, after: r'(?=\s+ref\s+struct\b)'),
    'alias': _keyword(
      'alias',
      Tags.declarationKeyword,
      before: r'(?<=\bextern\s+)',
    ),
  };

  /// Contextual keywords that name built-in types in type positions
  /// but remain valid identifiers elsewhere.
  static const List<String> _contextualTypes = ['dynamic', 'nint', 'nuint'];

  /// Pattern matching [type] in standalone type contexts
  /// outside [_typeArgumentList] and [_typeList].
  ///
  /// When [generic] is `true`, also matches [type] before `<`
  /// or as the constrained parameter in `where T :`.
  static String _typePattern(String type, {bool generic = false}) =>
      '(?<=\\b(?:and|as|is|new|not|or)\\s+)$type|'
      '$type(?=\\s+$_declaredName|${generic ? '<(?!<)|' : ''}'
      r'\s*\[[,\]\s]*\]|\?(?![.\[?]))|'
      '${generic ? '(?<=\\bwhere\\s+)$type(?=\\s*:)|' : ''}'
      '(?<=\\b(?:typeof|sizeof|default|catch)\\s*\\(\\s*)$type|'
      '$_castStart$type$_castOperand';

  /// The opening `(` of a cast, such as in `(nint)handle`,
  /// excluding argument lists such as `Find(Key)!`
  /// and statement conditions such as `if (Ready) return;`.
  static const String _castStart =
      '(?<!(?:$_identifierPart|[)\\]>])\\(\\s*)'
      '(?<!\\b(?:fixed|for|foreach|if|lock|switch|using|when|while)\\s+'
      '\\(\\s*)(?<=\\(\\s*)';

  /// The closing `)` and start of the operand in a cast,
  /// such as in `(nint)handle` or `(nint)-1`.
  static const String _castOperand =
      '(?=\\s*\\)\\s*(?:$_notInfixKeyword$_identifierStart|'
      r'''[@0-9($"'~]|[+-](?![=\s])|!(?!=)))''';

  /// Lookahead for a declared name or a `(`,
  /// such as in `var x`, `var (x, y)`, or `async (x) =>`.
  static const String _beforeDeclaration =
      '(?=\\s+(?:$_notInfixKeyword$_nameStart|\\())';

  static const List<String> _builtInTypes = [
    'bool',
    'byte',
    'char',
    'decimal',
    'double',
    'float',
    'int',
    'long',
    'object',
    'sbyte',
    'short',
    'string',
    'uint',
    'ulong',
    'ushort',
    'void',
  ];

  /// Lookahead for the start of an expression after a contextual keyword,
  /// such as in `await task` or `select (nint)x`.
  static const String _beforeOperand =
      '(?=\\s+$_notInfixKeyword(?:$_identifierStart|'
      r'''[@0-9($\[{"'~]|\.\d|[+-](?![=\s])|!(?!=)))''';

  static const String _typeModifiers =
      r'(?:(?:abstract|closed|file|internal|new|partial|private|protected|'
      r'public|readonly|ref|sealed|static|unsafe)\s+)*';

  /// Keywords that can directly precede the type of a property or event.
  static const String _memberModifiers =
      'abstract|event|extern|internal|new|override|partial|private|protected|'
      'public|readonly|ref|required|sealed|static|unsafe|virtual';

  static Map<String, Matcher> _keywords(
    List<String> words,
    Tag parent, {
    String before = '',
    String after = '',
  }) => {
    for (final word in words)
      word: _keyword(word, parent, before: before, after: after),
  };

  /// Matches [word] with a child tag of [parent],
  /// unconditionally or restricted to the [before] and [after] lookarounds.
  static Matcher _keyword(
    String word,
    Tag parent, {
    String before = '',
    String after = '',
  }) {
    final tag = Tag(word, parent: parent);
    return before.isEmpty && after.isEmpty
        ? Matcher.verbatim(word, tag: tag)
        : _contextual('$before$word$after', tag);
  }

  /// Matches [pattern] with [tag] unless preceded by [_memberAccess],
  /// such as in `this.value`,
  /// and otherwise falls back to [_ordinaryName].
  static Matcher _contextual(String pattern, Tag tag) => Matcher.options([
    Matcher.regex('(?<!$_memberAccess)(?:$pattern)', tag: tag),
    _ordinaryName,
  ]);
}
