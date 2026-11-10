import 'package:meta/meta.dart';

import '../matcher.dart';
import '../tag.dart';

/// Lexical highlighting for Rust code from the 2018 edition onward.
@internal
final class RustGrammar extends MatcherGrammar {
  const RustGrammar();

  static const String _identifierStart = r'[\p{XID_Start}_]';
  static const String _identifierPart = r'\p{XID_Continue}';
  static const String _identifier = '(?:r#)?$_identifierStart$_identifierPart*';
  static const String _rightBoundary = '(?!$_identifierPart)';

  /// The start of a line.
  /// Unlike `^`, which matcher regexes compile in multiline mode,
  /// this doesn't also match after a CRLF line's `\r`.
  static const String _lineStart = r'(?<![\s\S])';

  static const String _docLinePrefix = '(?:///(?!/)|//!)';
  static const Tag _docCommentBegin = Tag('begin', parent: Tags.docComment);
  static const Tag _docCommentContent = Tag('content', parent: Tags.docComment);
  static const Tag _stringBegin = Tag(
    'begin',
    parent: Tags.doubleQuoteString,
  );
  static const Tag _stringEnd = Tag('end', parent: Tags.doubleQuoteString);

  static const Tag _lifetime = Tag('lifetime', parent: Tags.type);
  static const Tag _macro = Tag('macro', parent: Tags.function);
  static const Tag _constant = Tag('constant', parent: Tags.specialIdentifier);
  static const Tag _metavariable = Tag('metavariable', parent: Tags.variable);

  @override
  List<Matcher> get matchers => [
    Matcher.include(_delimiters),
    // Strings and characters can start with a name such as `r` or `b`.
    _startingWith('bcr"\'', _strings),
    Matcher.include(_names),
    _startingWith('0-9', _numbers),
    _startingWith('/#', _comments),
    Matcher.include(_operators),
    Matcher.include(_metavariables),
    Matcher.include(_attributes),
    // A `#`, `$`, or `'` outside of an attribute, metavariable, or literal,
    // such as in `quote! { #name }`, `$(...),*`, or a doc test's hidden line.
    Matcher.regex(r"[#$']", tag: Tags.punctuation),
  ];

  /// Tries [rules] only where the next character is one of [characters],
  /// which each of the rules must begin with.
  ///
  /// Every other position then costs one check rather than one per rule.
  static Matcher _startingWith(String characters, Matcher Function() rules) {
    final included = Matcher.include(rules);
    return Matcher.select('(?=[$characters])', (_) => included);
  }

  Matcher _delimiters() => Matcher.options([
    Matcher.regex(r'[(){}\[\];]', tag: Tags.punctuation),
    // Each index in a chained tuple access like `p.0.1` is an integer.
    Matcher.capture(
      '(\\.)([0-9]+)$_rightBoundary',
      captures: [Tags.accessor, Tags.integerLiteral],
    ),
    Matcher.regex(r'::|\.(?!\.)', tag: Tags.accessor),
    Matcher.regex(r'[,:]', tag: Tags.separator),
  ]);

  Matcher _comments() => Matcher.options([
    // A shebang, such as `#!/usr/bin/env rust-script`,
    // but not an inner attribute, such as `#![allow(unused)]`.
    Matcher.regex(r'^#!(?!\s*\[).*', tag: Tags.lineComment),
    Matcher.include(_docFencedCodeBlock),
    Matcher.include(_docLineComment),
    Matcher.regex(r'//.*', tag: Tags.lineComment),
    Matcher.include(_docBlockComment),
    Matcher.include(_blockComment),
  ]);

  /// An outer (`///`) or inner (`//!`) doc comment line.
  Matcher _docLineComment() => Matcher.wrapped(
    begin: Matcher.regex(_docLinePrefix, tag: _docCommentBegin),
    end: Matcher.regex(r'$'),
    content: Matcher.options([
      Matcher.include(_docCommentReference),
      _docCommentCodeSpan(block: false),
      Matcher.regex(r'[^\[`]+|[\[`]', tag: _docCommentContent),
    ]),
    tag: Tags.docComment,
  );

  /// A fenced code block, such as a doc test, spanning multiple doc lines.
  ///
  /// Matched separately so that code such as `list[index]`
  /// isn't highlighted as an intra-doc link.
  Matcher _docFencedCodeBlock() => Matcher.wrapped(
    begin: Matcher.capture(
      '($_docLinePrefix)([ \\t]*`{3,}[^`]*)\$',
      captures: [_docCommentBegin, MarkupTags.codeBlock],
    ),
    // Recover at the next non-doc line if the fence is never closed.
    end: Matcher.regex(
      '$_lineStart(?![ \\t]*$_docLinePrefix)|[ \\t]*`{3,}[ \\t]*\$',
      tag: MarkupTags.codeBlock,
    ),
    content: Matcher.options([
      Matcher.regex(r'(?<=//[/!]).+', tag: MarkupTags.codeBlock),
      Matcher.regex(_docLinePrefix, tag: _docCommentBegin),
    ]),
    tag: Tags.docComment,
  );

  /// An outer (`/** */`) or inner (`/*! */`) block doc comment.
  Matcher _docBlockComment() => Matcher.wrapped(
    begin: Matcher.regex(r'/\*(?:\*(?![*/])|!)', tag: _docCommentBegin),
    end: Matcher.verbatim(
      '*/',
      tag: const Tag('end', parent: Tags.docComment),
    ),
    content: Matcher.options([
      Matcher.include(_blockComment),
      Matcher.include(_docCommentReference),
      _docCommentCodeSpan(block: true),
      Matcher.regex(
        r'(?:[^*/\[`]+|\*(?!/)|/(?!\*))+|[\[`]',
        tag: _docCommentContent,
      ),
    ]),
    tag: Tags.docComment,
  );

  /// An intra-doc link, such as `[Vec]`, `` [`Vec::new`] ``, `[vec!]`,
  /// `[Vec::len()]`, or `[struct@Vec]`, but not a Markdown link,
  /// such as `[text](url)` or `[text][id]`, or a link definition.
  Matcher _docCommentReference() => Matcher.regex(
    r'(?<!\])\[`?(?:[a-z]+@)?'
    '$_identifier(?:::$_identifier)*'
    r'(?:!|\(\))?`?\](?![(\[:])',
    tag: Tags.commentReference,
  );

  /// A code span, such as `` `Vec::new()` ``.
  ///
  /// In a block doc comment, the span can't contain a `/*` or `*/`,
  /// as those still nest or end the comment within Markdown.
  Matcher _docCommentCodeSpan({required bool block}) => Matcher.regex(
    block ? r'`(?:[^`*/]|\*(?!/)|/(?!\*))+`' : r'`[^`]+`',
    tag: MarkupTags.code,
  );

  Matcher _blockComment() => Matcher.wrapped(
    begin: Matcher.verbatim(
      '/*',
      tag: const Tag('begin', parent: Tags.blockComment),
    ),
    end: Matcher.verbatim(
      '*/',
      tag: const Tag('end', parent: Tags.blockComment),
    ),
    content: Matcher.regex(
      r'(?:[^*/]+|\*(?!/)|/(?!\*))+',
      tag: const Tag('content', parent: Tags.blockComment),
    ),
    nestable: true,
    tag: Tags.blockComment,
  );

  /// String-like literals as well as the lifetimes and labels
  /// that also begin with a quote.
  Matcher _strings() => Matcher.options([
    _quotedString(format: true),
    _quotedString(format: false),
    _rawString(),
    Matcher.include(_characters),
    // A loop label, such as `'outer`, is highlighted like a lifetime.
    Matcher.regex("'$_identifier", tag: _lifetime),
  ]);

  /// The start of a call to a common macro that accepts a format string,
  /// such as `println!(` or `write!(f, `, directly before the format string.
  static const String _formatMacroCall =
      r'\b(?:(?:format|format_args|print|println|eprint|eprintln|panic|'
      r'todo|unimplemented|unreachable|trace|debug|info|warn|error|'
      r'bail|anyhow)!\s*[(\[{]|(?:write|writeln)!\s*\([^,()"]*,)\s*';

  /// A string that can span multiple lines,
  /// optionally with a byte (`b`) or C string (`c`) prefix.
  ///
  /// If [format] is `true`, only matches the format string of a
  /// call to a common formatting macro, such as `println!("{name}")`,
  /// and also highlights its placeholders.
  Matcher _quotedString({required bool format}) => Matcher.wrapped(
    begin: Matcher.regex(
      format ? '(?<=$_formatMacroCall)"' : '[bc]?"',
      tag: _stringBegin,
    ),
    end: Matcher.verbatim('"', tag: _stringEnd),
    content: Matcher.options([
      Matcher.regex(
        format ? r'[^"\\{}]+' : r'[^"\\]+',
        tag: Tags.stringContent,
      ),
      Matcher.include(_stringEscape),
      if (format) ...[
        Matcher.regex(r'\{\{|\}\}', tag: Tags.stringEscape),
        Matcher.regex(r'\{[^{}"\\]*\}', tag: Tags.stringInterpolation),
        Matcher.regex(r'[{}]', tag: Tags.stringContent),
      ],
      // Keep a `\` that doesn't begin a valid escape as part of the string,
      // consuming the following character so it can't end the string.
      Matcher.regex(r'\\.?', tag: Tags.stringContent),
    ]),
    tag: Tags.doubleQuoteString,
  );

  /// The escapes of a character code, such as `\x7f` or `\u{1F980}`,
  /// that string and character literals share.
  static const String _codeEscape =
      r'x[0-9a-fA-F]{2}|u\{(?:[0-9a-fA-F]_*){1,6}\}';

  /// An escape sequence, including a `\` at the end of a line,
  /// which skips the line break and the next line's leading whitespace.
  Matcher _stringEscape() => Matcher.regex(
    r'''\\(?:[nrt\\0'"]|'''
    '$_codeEscape'
    r'|$)',
    tag: Tags.stringEscape,
  );

  /// A raw string, such as `r"C:\path"` or `r#"say "hi""#`,
  /// optionally with a byte (`b`) or C string (`c`) prefix.
  Matcher _rawString() => Matcher.select(
    '[bc]?r(#{0,255})"',
    (match) {
      final hashes = match[1]!;
      return Matcher.wrapped(
        begin: Matcher.verbatim(match[0]!, tag: _stringBegin),
        end: Matcher.verbatim('"$hashes', tag: _stringEnd),
        content: Matcher.regex(
          // Without hashes, the empty lookahead never matches a `"`.
          '(?:[^"]|"(?!$hashes))+',
          tag: Tags.stringContent,
        ),
        tag: Tags.doubleQuoteString,
      );
    },
  );

  /// A character or byte literal, such as `'a'`, `'\n'`, or `b'\x7f'`.
  ///
  /// Only complete literals are matched,
  /// so the `'` of a lifetime or label is never mistaken for the start of one.
  Matcher _characters() => Matcher.regex(
    r"b?'(?:[^'\\\r\n]|\\(?:"
    "$_codeEscape|.))'",
    tag: Tags.characterLiteral,
  );

  /// The start of an outer or inner attribute,
  /// such as `#[derive`, `#![allow`, or `#[unsafe(no_mangle`.
  ///
  /// The rest of the attribute is highlighted like other code,
  /// so an unterminated attribute doesn't affect the following lines.
  Matcher _attributes() => Matcher.regex(
    '#!?\\[(?:\\s*(?:unsafe\\s*\\(\\s*)?'
    '$_identifier(?:::$_identifier)*)?',
    tag: Tags.annotation,
  );

  static const String _digits = '[0-9][0-9_]*';
  static const String _exponent = '[eE][+-]?[0-9_]*';
  static const String _integerSuffix = '(?:[iu](?:8|16|32|64|128|size))?';
  static const String _floatSuffix = '(?:f(?:16|32|64|128))';

  // Accept misplaced digit separators and unfinished exponents while editing.
  Matcher _numbers() => Matcher.options([
    Matcher.regex(
      '0(?:x[0-9a-fA-F_]+|o[0-7_]+|b[01_]+)'
      '$_integerSuffix$_rightBoundary',
      tag: Tags.integerLiteral,
    ),
    Matcher.regex(
      '$_digits(?:\\.$_digits(?:$_exponent)?$_floatSuffix?|'
      '$_exponent$_floatSuffix?|$_floatSuffix)$_rightBoundary',
      tag: Tags.floatLiteral,
    ),
    // A float without a fractional part, such as `1.`,
    // but not the start of a range or method call, such as `1..` or `1.max`.
    Matcher.regex(
      '$_digits\\.(?!\\.|$_identifierPart)',
      tag: Tags.floatLiteral,
    ),
    Matcher.regex(
      '$_digits$_integerSuffix$_rightBoundary',
      tag: Tags.integerLiteral,
    ),
    // Keep a number with an invalid suffix or digit as a single token.
    Matcher.regex(
      '[0-9]$_identifierPart*',
      tag: Tags.numberLiteral,
    ),
  ]);

  static const String _fragmentSpecifiers =
      'block|expr(?:_2021)?|ident|item|lifetime|literal|meta|'
      'pat(?:_param)?|path|stmt|tt|ty|vis';

  /// A metavariable in a `macro_rules!` definition,
  /// such as `$name` or `$name:ident`, or the special `$crate`.
  Matcher _metavariables() => Matcher.options([
    Matcher.regex(
      '\\\$crate$_rightBoundary',
      tag: Tags.specialIdentifier,
    ),
    Matcher.capture(
      '(\\\$$_identifier)(:)($_fragmentSpecifiers)$_rightBoundary',
      captures: [_metavariable, Tags.separator, Tags.builtInType],
    ),
    Matcher.regex('\\\$$_identifier', tag: _metavariable),
  ]);

  /// Operators besides the [_delimiters].
  Matcher _operators() => Matcher.options([
    Matcher.regex(
      r'>>=|<<=|\.\.=|\.\.\.|\.\.|->|=>|==|!=|<=|>=|&&|\|\||'
      r'[-+*/%^&|]=',
      tag: Tags.operator,
    ),
    // Formatted code surrounds comparison and shift operators with spaces,
    // so a `<` or `>` without them likely delimits generic arguments instead,
    // such as in `Vec<Vec<u8>>`, `Ref<'a, T>`, or `Vec<<T as Trait>::Item>`.
    Matcher.regex(r'(?<=\s)(?:<<?|>>?)(?=\s|$)', tag: Tags.operator),
    Matcher.regex(r'[<>]', tag: Tags.punctuation),
    Matcher.regex(r'[-+*/%^&|!=?@~]', tag: Tags.operator),
  ]);

  /// Each name is scanned once, then highlighted by its text,
  /// or as a macro invocation, which can use any name,
  /// including a type or a raw identifier.
  Matcher _names() => Matcher.select(
    '$_identifier(!(?=\\s*[(\\[{]))?',
    (match) => match[1] != null
        ? _macroInvocation
        : _knownNames[match[0]] ?? _ordinaryName,
  );

  static final Matcher _macroInvocation = Matcher.regex(
    '$_identifier!',
    tag: _macro,
  );

  static const Tag _fnKeyword = Tag('fn', parent: Tags.declarationKeyword);
  static const Tag _macroRulesKeyword = Tag(
    'macro_rules',
    parent: Tags.declarationKeyword,
  );

  static final Map<String, Matcher> _knownNames = {
    for (final MapEntry(key: keyword, value: parent) in _keywordTags.entries)
      keyword: Matcher.verbatim(keyword, tag: Tag(keyword, parent: parent)),
    for (final name in _builtInTypes)
      name: Matcher.verbatim(name, tag: Tags.builtInType),
    for (final MapEntry(key: name, value: tag) in _specialNameTags.entries)
      name: Matcher.verbatim(name, tag: tag),
    // Replaces the plain `fn` entry from [_keywordTags] to
    // also match the name in a definition, as with `macro_rules! name`.
    'fn': Matcher.options([
      Matcher.capture(
        '(fn)(\\s+)($_identifier)',
        captures: [_fnKeyword, Tags.whitespace, Tags.function],
      ),
      Matcher.verbatim('fn', tag: _fnKeyword),
    ]),
    'macro_rules': Matcher.options([
      Matcher.capture(
        '(macro_rules!)(\\s+)($_identifier)',
        captures: [_macroRulesKeyword, Tags.whitespace, _macro],
      ),
      Matcher.verbatim('macro_rules!', tag: _macroRulesKeyword),
      _ordinaryName,
    ]),
    'union': _weakKeyword(
      'union(?=\\s+(?!(?:as|in)$_rightBoundary)$_identifierStart)',
      const Tag('union', parent: Tags.declarationKeyword),
    ),
    'raw': _weakKeyword(
      '(?<=&\\s*)raw(?=\\s+(?:const|mut)$_rightBoundary)',
      const Tag('raw', parent: Tags.modifierKeyword),
    ),
    'safe': _weakKeyword(
      'safe(?=\\s+(?:fn|static)$_rightBoundary)',
      const Tag('safe', parent: Tags.modifierKeyword),
    ),
  };

  /// Names besides keywords and types with a fixed meaning.
  static const Map<String, Tag> _specialNameTags = {
    'Some': Tags.constructor,
    'Ok': Tags.constructor,
    'Err': Tags.constructor,
    'None': _constant,
    'self': Tags.specialIdentifier,
    'Self': Tags.specialIdentifier,
    'super': Tags.specialIdentifier,
    'crate': Tags.specialIdentifier,
    '_': Tags.specialIdentifier,
    'true': Tags.trueLiteral,
    'false': Tags.falseLiteral,
  };

  /// A word that is only a keyword in the context [pattern] checks for,
  /// and is otherwise an ordinary identifier.
  static Matcher _weakKeyword(String pattern, Tag tag) =>
      Matcher.options([Matcher.regex(pattern, tag: tag), _ordinaryName]);

  static final Matcher _ordinaryName = Matcher.options([
    // A constant such as `MAX_SIZE` has at least two capital letters.
    // A single capital such as `T` usually names a type parameter.
    Matcher.regex('[A-Z][0-9_]*[A-Z][A-Z0-9_]*$_rightBoundary', tag: _constant),
    Matcher.regex('[A-Z]$_identifierPart*', tag: Tags.type),
    // Treat `collect::<` as a function without parsing its type arguments.
    Matcher.regex('$_identifier(?=\\s*(?:\\(|::<))', tag: Tags.function),
    Matcher.regex(_identifier, tag: Tags.identifier),
  ]);

  /// The primitive types as well as common types and traits from
  /// the prelude and standard library.
  static const List<String> _builtInTypes = [
    'Arc',
    'AsMut',
    'AsRef',
    'BTreeMap',
    'BTreeSet',
    'Box',
    'Cell',
    'Clone',
    'Copy',
    'Debug',
    'Default',
    'Display',
    'DoubleEndedIterator',
    'Drop',
    'Eq',
    'ExactSizeIterator',
    'Extend',
    'Fn',
    'FnMut',
    'FnOnce',
    'From',
    'FromIterator',
    'Future',
    'Hash',
    'HashMap',
    'HashSet',
    'Into',
    'IntoFuture',
    'IntoIterator',
    'Iterator',
    'Mutex',
    'Option',
    'Ord',
    'PartialEq',
    'PartialOrd',
    'Rc',
    'RefCell',
    'Result',
    'RwLock',
    'Send',
    'Sized',
    'String',
    'Sync',
    'ToOwned',
    'ToString',
    'TryFrom',
    'TryInto',
    'Unpin',
    'Vec',
    'VecDeque',
    'bool',
    'char',
    'f128',
    'f16',
    'f32',
    'f64',
    'i128',
    'i16',
    'i32',
    'i64',
    'i8',
    'isize',
    'str',
    'u128',
    'u16',
    'u32',
    'u64',
    'u8',
    'usize',
  ];

  static const Map<String, Tag> _keywordTags = {
    'let': Tags.declarationKeyword,
    'fn': Tags.declarationKeyword,
    'mut': Tags.modifierKeyword,
    'pub': Tags.modifierKeyword,
    'use': Tags.declarationKeyword,
    'impl': Tags.declarationKeyword,
    'for': Tags.controlKeyword,
    'if': Tags.controlKeyword,
    'where': Tags.keyword,
    'await': Tags.controlKeyword,
    'async': Tags.modifierKeyword,
    'match': Tags.controlKeyword,
    'struct': Tags.declarationKeyword,
    'unsafe': Tags.modifierKeyword,
    'else': Tags.controlKeyword,
    'return': Tags.controlKeyword,
    'in': Tags.keyword,
    'as': Tags.keyword,
    'mod': Tags.declarationKeyword,
    'type': Tags.declarationKeyword,
    'const': Tags.modifierKeyword,
    'move': Tags.modifierKeyword,
    'ref': Tags.modifierKeyword,
    'enum': Tags.declarationKeyword,
    'trait': Tags.declarationKeyword,
    'static': Tags.modifierKeyword,
    'dyn': Tags.modifierKeyword,
    'extern': Tags.declarationKeyword,
    'loop': Tags.controlKeyword,
    'while': Tags.controlKeyword,
    'break': Tags.controlKeyword,
    'continue': Tags.controlKeyword,
    'try': Tags.controlKeyword,
    'yield': Tags.controlKeyword,
    // Reserved for possible future use.
    'abstract': Tags.modifierKeyword,
    'become': Tags.controlKeyword,
    'box': Tags.keyword,
    'do': Tags.controlKeyword,
    'final': Tags.modifierKeyword,
    'macro': Tags.declarationKeyword,
    'override': Tags.modifierKeyword,
    'priv': Tags.modifierKeyword,
    'typeof': Tags.keyword,
    'unsized': Tags.keyword,
    'virtual': Tags.modifierKeyword,
  };
}
