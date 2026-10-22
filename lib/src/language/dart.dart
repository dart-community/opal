import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

@internal
final class DartGrammar extends MatcherGrammar {
  const DartGrammar();

  static const String _identifierStart = r'[a-zA-Z_$]';
  static const String _identifierPart = r'[a-zA-Z0-9_$]';
  static const String _identifier = '$_identifierStart$_identifierPart*';
  static const String _leftBoundary = '(?<!$_identifierPart)';
  static const String _rightBoundary = '(?!$_identifierPart)';

  /// Excludes a name directly after a member access, such as
  /// `.`, `?.`, or `..`, while still allowing one after a spread (`...`).
  static const String _notMemberName = r'(?<!(?:^|[^.])\.\.?)';

  /// Excludes a built-in identifier or contextual keyword that is
  /// being used as a name, such as when it's called, given type arguments,
  /// assigned to, or used as a named argument.
  static const String _notUsedAsName =
      r'(?![(<]|\s*(?:[:;,.?)\]}]|[!=]?=(?!>)))';

  /// Type arguments nested up to three levels deep,
  /// such as `<int>` or `<String, List<int>>`.
  static const String _typeArgumentCharacter = r'[\w$\s,.?()]';
  static const String _typeArguments =
      '<(?:$_typeArgumentCharacter|'
      '<(?:$_typeArgumentCharacter|<$_typeArgumentCharacter*>)*>)*>';

  static const String _docLineStart = '///(?!/)';
  static const Tag _docCommentContent = Tag('content', parent: Tags.docComment);
  static const Tag _blockCommentContent = Tag(
    'content',
    parent: Tags.blockComment,
  );

  @override
  List<Matcher> get matchers => [
    Matcher.include(_comments),
    Matcher.include(_strings),
    Matcher.include(_labels),
    Matcher.include(_plainIdentifiers),
    Matcher.include(_annotations),
    Matcher.include(_literals),
    // Operators and types can't overlap with keywords,
    // so match them first to avoid trying every keyword pattern.
    Matcher.include(_operators),
    Matcher.include(_types),
    Matcher.include(_keywords),
    Matcher.include(_functions),
    Matcher.include(_identifiers),
  ];

  Matcher _comments() => Matcher.options([
    // A script tag, such as `#!/usr/bin/env dart`.
    Matcher.regex(r'^#!.*$', tag: Tags.lineComment),
    Matcher.include(_docFencedCodeBlock),
    Matcher.include(_docLineComment),
    Matcher.regex(r'//.*$', tag: Tags.lineComment),
    Matcher.include(_docBlockComment),
    Matcher.include(_blockComment),
  ]);

  Matcher _docLineComment() => Matcher.wrapped(
    begin: Matcher.regex(
      _docLineStart,
      tag: const Tag('begin', parent: Tags.docComment),
    ),
    end: Matcher.regex(r'$'),
    content: Matcher.options([
      Matcher.include(_docCommentReference),
      Matcher.include(_docCommentCodeSpan),
      Matcher.regex(r'[^\[`]+|[\[`]', tag: _docCommentContent),
    ]),
    tag: Tags.docComment,
  );

  /// A fenced code block spanning multiple `///` lines.
  ///
  /// Matched separately so that code such as `list[index]`
  /// isn't highlighted as a doc comment reference.
  Matcher _docFencedCodeBlock() => Matcher.wrapped(
    begin: Matcher.capture(
      '($_docLineStart)([ \\t]*```.*)\$',
      captures: [
        const Tag('begin', parent: Tags.docComment),
        MarkupTags.codeBlock,
      ],
    ),
    // End at the closing fence or, if the fence is never closed,
    // at the first line that doesn't continue the doc comment.
    end: Matcher.regex(
      '(?<=^[ \\t]*$_docLineStart)[ \\t]*```[ \\t]*\$|'
      '^(?![ \\t]*$_docLineStart)',
      tag: MarkupTags.codeBlock,
    ),
    content: Matcher.options([
      Matcher.regex(
        _docLineStart,
        tag: const Tag('begin', parent: Tags.docComment),
      ),
      Matcher.regex('(?<=///).+', tag: MarkupTags.codeBlock),
    ]),
    tag: Tags.docComment,
  );

  Matcher _docBlockComment() => Matcher.wrapped(
    begin: Matcher.regex(
      r'/\*\*(?!/)',
      tag: const Tag('begin', parent: Tags.docComment),
    ),
    end: Matcher.verbatim(
      '*/',
      tag: const Tag('end', parent: Tags.docComment),
    ),
    content: Matcher.options([
      Matcher.include(_nestedBlockComment),
      Matcher.include(_docCommentReference),
      Matcher.include(_docCommentCodeSpan),
      Matcher.regex(
        r'(?:[^*/\[`]+|\*(?!/)|/(?!\*))+|[\[`]',
        tag: _docCommentContent,
      ),
    ]),
    tag: Tags.docComment,
  );

  /// A reference to a Dart declaration in a doc comment, such as
  /// `[List]`, `[List.of]`, or `[List.new]`,
  /// but not a Markdown link such as `[text](url)` or `[text][id]`.
  Matcher _docCommentReference() => Matcher.regex(
    '\\[(?:new\\s+)?$_identifier(?:\\.$_identifier)*(?:\\(\\))?\\]'
    r'(?![(\[:])',
    tag: Tags.commentReference,
  );

  Matcher _docCommentCodeSpan() =>
      Matcher.regex(r'`(?:[^`*]|\*(?!/))+`', tag: MarkupTags.code);

  Matcher _blockComment() => Matcher.options([
    Matcher.verbatim('/**/', tag: Tags.blockComment),
    Matcher.wrapped(
      begin: Matcher.verbatim(
        '/*',
        tag: const Tag('begin', parent: Tags.blockComment),
      ),
      end: Matcher.verbatim(
        '*/',
        tag: const Tag('end', parent: Tags.blockComment),
      ),
      content: Matcher.include(_blockCommentContents),
      tag: Tags.blockComment,
    ),
  ]);

  Matcher _blockCommentContents() => Matcher.options([
    Matcher.include(_nestedBlockComment),
    Matcher.regex(
      r'(?:[^*/]+|\*(?!/)|/(?!\*))+',
      tag: _blockCommentContent,
    ),
  ]);

  /// Block comments in Dart can nest, so track inner comments to
  /// avoid ending the outer comment at the inner comment's `*/`.
  Matcher _nestedBlockComment() => Matcher.wrapped(
    begin: Matcher.verbatim('/*', tag: _blockCommentContent),
    end: Matcher.verbatim('*/', tag: _blockCommentContent),
    content: Matcher.include(_blockCommentContents),
  );

  Matcher _strings() => Matcher.options([
    for (final raw in const [true, false])
      for (final quote in const ["'''", '"""', "'", '"'])
        _string(quote, raw: raw),
  ]);

  Matcher _string(String quote, {required bool raw}) {
    final quoteCharacter = quote[0];
    final multiline = quote.length == 3;
    final tag = multiline
        ? Tags.tripleQuoteString
        : quoteCharacter == "'"
        ? Tags.singleQuoteString
        : Tags.doubleQuoteString;
    final excluded = raw ? quoteCharacter : '$quoteCharacter\\\\\$';

    return Matcher.wrapped(
      begin: raw
          ? Matcher.regex(
              '${_leftBoundary}r$quote',
              tag: Tag('begin', parent: tag),
            )
          : Matcher.verbatim(quote, tag: Tag('begin', parent: tag)),
      // Single-line string content can't continue past the end of a line,
      // so end unterminated ones there instead of
      // treating the following lines as string content.
      end: multiline
          ? Matcher.verbatim(quote, tag: Tag('end', parent: tag))
          : Matcher.regex('$quote|\$', tag: Tag('end', parent: tag)),
      // Match plain content first, so the default whitespace rule of
      // the nested interpolation options doesn't split it.
      content: Matcher.options([
        Matcher.regex(
          multiline
              ? '(?:[^$excluded]|$quoteCharacter'
                    '(?!$quoteCharacter$quoteCharacter))+'
              : '[^$excluded]+',
          tag: Tags.stringContent,
        ),
        if (!raw) ...[
          Matcher.include(_stringEscape),
          Matcher.include(_interpolation),
          // Keep a `\` or `$` that doesn't begin a valid
          // escape or interpolation as part of the string.
          Matcher.regex(r'[\\$]', tag: Tags.stringContent),
        ],
      ]),
      tag: tag,
    );
  }

  Matcher _stringEscape() => Matcher.regex(
    r'\\(?:x[0-9a-fA-F]{2}|u[0-9a-fA-F]{4}|u\{[0-9a-fA-F]{1,6}\}|.)',
    tag: Tags.stringEscape,
  );

  /// An interpolation in a string, such as `$name` or `${expression}`.
  ///
  /// The expression can span lines or contain strings with the same quotes
  /// as its enclosing string, so only its matching `}` ends the interpolation.
  /// An unterminated interpolation continues to the end of the input.
  Matcher _interpolation() => Matcher.options([
    Matcher.regex(r'\$[a-zA-Z_][a-zA-Z0-9_]*', tag: Tags.stringInterpolation),
    Matcher.wrapped(
      begin: Matcher.verbatim(
        r'${',
        tag: const Tag('begin', parent: Tags.stringInterpolation),
      ),
      end: Matcher.verbatim(
        '}',
        tag: const Tag('end', parent: Tags.stringInterpolation),
      ),
      content: Matcher.include(_interpolatedExpression),
      tag: Tags.stringInterpolation,
    ),
  ]);

  /// The expression in a `${}` interpolation, keeping track of
  /// nested braces, such as from a map literal or function body,
  /// so they don't end the interpolation early.
  Matcher _interpolatedExpression() => Matcher.options([
    Matcher.wrapped(
      begin: Matcher.verbatim('{', tag: Tags.punctuation),
      end: Matcher.verbatim('}', tag: Tags.punctuation),
      content: Matcher.include(_interpolatedExpression),
    ),
    ...matchers,
  ]);

  Matcher _annotations() => Matcher.regex(
    '@$_identifier(?:\\.$_identifier)*',
    tag: Tags.annotation,
  );

  Matcher _literals() => Matcher.options([
    _namedIdentifier('true', tag: Tags.trueLiteral),
    _namedIdentifier('false', tag: Tags.falseLiteral),
    _namedIdentifier('null', tag: Tags.nullLiteral),
    Matcher.include(_numberLiterals),
    Matcher.include(_symbolLiterals),
  ]);

  // Accept misplaced digit separators and unfinished exponents while editing,
  // but avoid highlighting numeric fragments within identifiers.
  Matcher _numberLiterals() => Matcher.options([
    Matcher.regex(
      '${_leftBoundary}0[xX][0-9a-fA-F][0-9a-fA-F_]*$_rightBoundary',
      tag: Tags.integerLiteral,
    ),
    Matcher.regex(
      '$_leftBoundary(?:[0-9][0-9_]*)?\\.[0-9][0-9_]*'
      '(?:[eE][+-]?[0-9_]*)?$_rightBoundary',
      tag: Tags.floatLiteral,
    ),
    Matcher.regex(
      '$_leftBoundary[0-9][0-9_]*[eE][+-]?[0-9_]*$_rightBoundary',
      tag: Tags.floatLiteral,
    ),
    Matcher.regex(
      '$_leftBoundary[0-9][0-9_]*$_rightBoundary',
      tag: Tags.integerLiteral,
    ),
  ]);

  Matcher _symbolLiterals() => Matcher.regex(
    '#(?:unary-|$_identifier(?:\\.$_identifier)*|'
    r'\[\]=?|~/|>>>|>>|<<|[<>]=?|==|[-+*/%&|^~])',
    tag: const Tag('symbol', parent: Tags.literal),
  );

  Matcher _keywords() => Matcher.options([
    Matcher.regex(
      '$_leftBoundary(?:this|super)$_rightBoundary',
      tag: Tags.specialIdentifier,
    ),
    _keywordIdentifiers(_controlKeywords, baseTag: Tags.controlKeyword),
    _keywordIdentifiers(_declarationKeywords, baseTag: Tags.declarationKeyword),
    _keywordIdentifiers(_modifierKeywords, baseTag: Tags.modifierKeyword),
    _keywordIdentifiers(_otherKeywords, baseTag: Tags.keyword),
    // Contextual keywords that are only keywords in a specific position.
    Matcher.regex(
      '(?<=${_leftBoundary}extension\\s+)type$_rightBoundary',
      tag: const Tag('type', parent: Tags.declarationKeyword),
    ),
    Matcher.regex(
      '(?<=${_leftBoundary}part\\s+)of$_rightBoundary',
      tag: const Tag('of', parent: Tags.keyword),
    ),
    // An unnamed library directive.
    Matcher.regex(
      r'^library(?=\s*;)',
      tag: const Tag('library', parent: Tags.declarationKeyword),
    ),
  ]);

  static const List<String> _controlKeywords = [
    'assert',
    'await',
    'break',
    'case',
    'catch',
    'continue',
    'default',
    'do',
    'else',
    'finally',
    'for',
    'if',
    'rethrow',
    'return',
    'switch',
    'throw',
    'try',
    'when',
    'while',
    'yield',
  ];

  static const List<String> _declarationKeywords = [
    'class',
    'enum',
    'export',
    'extension',
    'get',
    'import',
    'library',
    'mixin',
    'operator',
    'part',
    'set',
    'typedef',
    'var',
  ];

  static const List<String> _modifierKeywords = [
    'abstract',
    'async',
    'augment',
    'base',
    'const',
    'covariant',
    'external',
    'factory',
    'final',
    'interface',
    'late',
    'required',
    'sealed',
    'static',
    'sync',
  ];

  static const List<String> _otherKeywords = [
    'as',
    'deferred',
    'extends',
    'hide',
    'implements',
    'in',
    'is',
    'new',
    'on',
    'show',
    'with',
  ];

  /// The reserved words, which are always keywords, even after a
  /// member access, such as the `new` in a `List.new` constructor tear-off.
  static const Set<String> _reservedWords = {
    'assert',
    'break',
    'case',
    'catch',
    'class',
    'const',
    'continue',
    'default',
    'do',
    'else',
    'enum',
    'extends',
    'final',
    'finally',
    'for',
    'if',
    'in',
    'is',
    'new',
    'rethrow',
    'return',
    'switch',
    'throw',
    'try',
    'var',
    'while',
    'with',
  };

  /// The conditions for a built-in identifier or contextual keyword to be
  /// highlighted as a keyword, if different from [_notUsedAsName].
  static const Map<String, String> _keywordConditions = {
    // Effectively reserved in the asynchronous and generator functions
    // where they're used.
    'await': '',
    'yield': '',
    // Followed by the operator being declared, such as in `operator ==(...)`.
    'operator': r'(?=\s*(?:[-+*/%&|^~<>\[]|==))',
    // Followed by the names in a combinator, which the formatter
    // might move to the following lines, or the type in an `on` clause.
    'hide': r'(?=\s+[a-zA-Z_$]|\s*$)',
    'show': r'(?=\s+[a-zA-Z_$]|\s*$)',
    'on': r'(?=\s+[a-zA-Z_$(])',
  };

  Matcher _keywordIdentifiers(
    List<String> keywords, {
    required Tag baseTag,
  }) => Matcher.options([
    for (final keyword in keywords)
      // Check for the keyword first, as that fails faster than
      // the lookbehinds on the many words that aren't this keyword.
      Matcher.regex(
        _reservedWords.contains(keyword)
            ? '(?=$keyword)$_leftBoundary$keyword$_rightBoundary'
            : '(?=$keyword)$_leftBoundary$_notMemberName$keyword'
                  '$_rightBoundary'
                  '${_keywordConditions[keyword] ?? _notUsedAsName}',
        tag: Tag(keyword, parent: baseTag),
      ),
  ]);

  Matcher _types() => Matcher.options([
    Matcher.regex(
      '$_leftBoundary(?:$_builtInTypePattern)$_rightBoundary',
      tag: Tags.builtInType,
    ),
    Matcher.regex(
      '${_leftBoundary}_*[A-Z]$_identifierPart*$_rightBoundary',
      tag: Tags.type,
    ),
  ]);

  static final String _builtInTypePattern = _builtInTypes.join('|');

  static const List<String> _builtInTypes = [
    'BigInt',
    'Comparable',
    'DateTime',
    'Duration',
    'Enum',
    'Error',
    'Exception',
    'Expando',
    'Function',
    'Future',
    'FutureOr',
    'Iterable',
    'Iterator',
    'List',
    'Map',
    'MapEntry',
    'Never',
    'Null',
    'Object',
    'Pattern',
    'Record',
    'RegExp',
    'Set',
    'StackTrace',
    'Stream',
    'String',
    'StringBuffer',
    'Symbol',
    'Type',
    'Uri',
    'bool',
    'double',
    'dynamic',
    'int',
    'num',
    'void',
  ];

  Matcher _labels() => Matcher.options([
    // The target of a `break` or `continue` statement.
    Matcher.regex(
      '(?=$_identifierStart)'
      '(?<=$_leftBoundary(?:break|continue)\\s+)$_identifier$_rightBoundary',
      tag: Tags.label,
    ),
    // A label on a loop or switch case.
    Matcher.regex(
      '(?=$_identifierStart)(?<=^\\s*)$_identifier'
      '(?=\\s*:\\s*(?:for|while|do|case|default)$_rightBoundary)',
      tag: Tags.label,
    ),
  ]);

  Matcher _functions() => Matcher.regex(
    '$_leftBoundary$_identifier$_rightBoundary'
    '(?=\\s*\\(|$_typeArguments\\()',
    tag: Tags.function,
  );

  Matcher _operators() => Matcher.options([
    Matcher.regex(
      r'>>>=|>>=|<<=|~/=|\?\?=|\.\.\.\?|\.\.\.|\?\.\.|\?\?|\?\.|\.\.|'
      r'\+\+|--|[-+*/%&|^]=|=>|==|!=|<=|>=|&&|\|\||<<|~/',
      tag: Tags.operator,
    ),
    // Formatted code surrounds relational and shift operators with spaces,
    // so a `<` or `>` without them likely delimits type arguments instead,
    // such as in `List<List<int>>`.
    Matcher.regex(r'(?<=\s)>{1,3}', tag: Tags.operator),
    Matcher.regex(r'(?<=\s)<(?=\s|$)', tag: Tags.operator),
    Matcher.regex(r'[<>]', tag: Tags.punctuation),
    // Similarly, a `:` after a space is likely part of a conditional
    // expression rather than separating a key or name from its value.
    Matcher.regex(r'(?<=\s):', tag: Tags.operator),
    Matcher.regex(r'[:,]', tag: Tags.separator),
    Matcher.regex(r'[-+*/%&|^~=!?]', tag: Tags.operator),
    Matcher.regex(r'\.', tag: Tags.accessor),
    Matcher.regex(r'[{}()\[\];]', tag: Tags.punctuation),
  ]);

  /// Function names and other identifiers that can't be
  /// a keyword, literal, or type.
  ///
  /// Most identifiers are such plain names, so matching them with
  /// a few patterns before trying each keyword's pattern
  /// significantly speeds up tokenization.
  Matcher _plainIdentifiers() {
    final plainName =
        '$_leftBoundary(?!(?:$_specialNames)$_rightBoundary|_*[A-Z])'
        '$_identifier$_rightBoundary';
    const notFunctionName = r'(?!\s*\(|<)';

    return Matcher.options([
      Matcher.regex(
        '(?=[a-z_\$])$plainName(?=\\s*\\(|$_typeArguments\\()',
        tag: Tags.function,
      ),
      Matcher.regex(
        '(?=[a-z\$])$plainName$notFunctionName',
        tag: Tags.identifier,
      ),
      Matcher.regex(
        '(?=_)${_leftBoundary}_+[a-z0-9\$]$_identifierPart*'
        '$_rightBoundary$notFunctionName',
        tag: Tags.privateIdentifier,
      ),
    ]);
  }

  /// The names that a matcher besides [_identifiers] might handle,
  /// which [_plainIdentifiers] must leave to those matchers.
  static final String _specialNames = [
    ..._controlKeywords,
    ..._declarationKeywords,
    ..._modifierKeywords,
    ..._otherKeywords,
    'of',
    'type',
    'this',
    'super',
    'true',
    'false',
    'null',
    ..._builtInTypes,
  ].join('|');

  Matcher _identifiers() => Matcher.options([
    Matcher.regex(
      '${_leftBoundary}_$_identifierPart+$_rightBoundary',
      tag: Tags.privateIdentifier,
    ),
    Matcher.regex(
      '$_leftBoundary$_identifier$_rightBoundary',
      tag: Tags.identifier,
    ),
  ]);

  Matcher _namedIdentifier(String name, {required Tag tag}) =>
      Matcher.regex('$_leftBoundary$name$_rightBoundary', tag: tag);
}
