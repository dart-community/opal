/// @docImport 'token.dart';
library;

import 'package:meta/meta.dart';

/// An optionally scoped tag for a [TaggedToken] within
/// a specific parsing context.
///
/// Rather than creating your own root tags,
/// prefer to use a tag from [Tags] or [MarkupTags],
/// either directly or as the [parent] for a new tag.
final class Tag {
  /// The unique identifier of this tag.
  final String id;

  /// An optional parent tag to scope this tag under.
  final Tag? parent;

  /// Creates a new tag with the given [id] and optional [parent] tag.
  ///
  /// Generally [id] should only contain characters a-z.
  const Tag(
    this.id, {
    this.parent,
  });

  /// Expands this tag into a list of all its ancestors and itself.
  @useResult
  List<Tag> expand() {
    return [...?parent?.expand(), this];
  }

  @override
  String toString() {
    final parent = this.parent;
    if (parent == null) {
      return id;
    }

    return '$parent-$id';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tag && id == other.id && parent == other.parent;

  @override
  int get hashCode => Object.hash(id, parent);
}

/// A namespaced collection of predefined tags.
///
/// Prefer to use tags from here and [MarkupTags] over
/// creating your own custom root tags.
abstract final class Tags {
  /// A tag for comment content.
  ///
  /// Use this for any type of comment syntax.
  /// For specific comment types, prefer using
  /// [Tags.lineComment], [Tags.blockComment], or [Tags.docComment].
  static const Tag comment = Tag('comment');

  /// A tag for single-line comments, such as
  /// those beginning with `//` in Dart or `#` in Python.
  static const Tag lineComment = Tag('line', parent: comment);

  /// A tag for multi-line block comments, such as
  /// those delineated with `/* */` in Dart and other C-style languages.
  static const Tag blockComment = Tag('block', parent: comment);

  /// A tag for documentation comments, such as
  /// those beginning with `///` in Dart or wrapped with `/** */` in Java.
  static const Tag docComment = Tag('doc', parent: blockComment);

  /// A tag for references within comments, such as
  /// `[MyClass]` in Dart documentation comments.
  static const Tag commentReference = Tag('reference', parent: comment);

  /// A tag for identifiers and names.
  ///
  /// Use this for general identifiers or as a parent tag.
  /// For specific usages, prefer using specialized identifier tags such as
  /// [Tags.function], [Tags.variable], and [Tags.type].
  static const Tag identifier = Tag('identifier');

  /// A tag for special identifiers with a reserved meaning
  /// in the current context, such as `this` in Dart.
  static const Tag specialIdentifier = Tag('special', parent: identifier);

  /// A tag for function and method names.
  static const Tag function = Tag('function', parent: identifier);

  /// A tag for constructor names and constructor calls.
  static const Tag constructor = Tag('constructor', parent: function);

  /// A tag for property and field names.
  static const Tag property = Tag('property', parent: identifier);

  /// A tag for names of types, such as those defined by
  /// classes, mixins, enums, or typedefs in Dart.
  ///
  /// For types provided by the language or its core library,
  /// consider using [Tags.builtInType] instead.
  static const Tag type = Tag('type', parent: identifier);

  /// A tag for built-in types provided by the language,
  /// such as `int`, `String`, and `bool` in Dart.
  static const Tag builtInType = Tag('built-in', parent: type);

  /// A tag for labels used in control flow, such as used as targets by
  /// `break` and `continue` in many C-like programming languages.
  static const Tag label = Tag('label', parent: identifier);

  /// A tag for variable names and function-local identifiers.
  static const Tag variable = Tag('variable', parent: identifier);

  /// A tag for function and method parameter names.
  static const Tag parameter = Tag('parameter', parent: variable);

  /// A tag for language keywords.
  ///
  /// Use this for general keywords.
  /// For specific types of keywords, prefer using more specific tags such as
  /// [Tags.declarationKeyword], [Tags.modifierKeyword],
  /// [Tags.controlKeyword], or [Tags.operator].
  static const Tag keyword = Tag('keyword');

  /// A tag for declaration keywords, such as `class` and `var` in Dart.
  static const Tag declarationKeyword = Tag('declaration', parent: keyword);

  /// A tag for modifier keywords, such as `abstract` or `final` in Dart.
  static const Tag modifierKeyword = Tag('modifier', parent: keyword);

  /// A tag for control flow keywords, such as `if` and `for` in Dart.
  static const Tag controlKeyword = Tag('control', parent: keyword);

  /// A tag for operators, such as `+`, `-`, `&&`, and `==`.
  static const Tag operator = Tag('operator', parent: keyword);

  /// A tag for user-defined or custom operators.
  static const Tag customOperator = Tag('custom', parent: operator);

  /// A tag for whitespace characters,
  /// including but not limited to spaces, tabs, and non-breaking spaces.
  static const Tag whitespace = Tag('whitespace');

  /// A tag for metadata and meta-programming constructs.
  ///
  /// Use this for general metadata.
  /// If available, prefer using a more specific tag,
  /// such as [Tags.annotation] or [Tags.preprocessor].
  static const Tag metadata = Tag('metadata');

  /// A tag for annotations and decorators, such as `@override` in Dart.
  static const Tag annotation = Tag('annotation', parent: metadata);

  /// A tag for preprocessor directives, such as `#include` or `#define`.
  static const Tag preprocessor = Tag('preprocessor', parent: metadata);

  /// A general tag for literals.
  ///
  /// If available, prefer using a more specific tag,
  /// such as [Tags.booleanLiteral], [Tags.numberLiteral],
  /// [Tags.stringLiteral], and [Tags.collectionLiteral].
  static const Tag literal = Tag('literal');

  /// A tag for boolean literals, such as `true` and `false` in Dart.
  static const Tag booleanLiteral = Tag('boolean', parent: literal);

  /// A tag specifically for `true` literals.
  static const Tag trueLiteral = Tag('true', parent: booleanLiteral);

  /// A tag specifically for `false` literals.
  static const Tag falseLiteral = Tag('false', parent: booleanLiteral);

  /// A tag for null literals, such as `null` in Dart.
  static const Tag nullLiteral = Tag('null', parent: literal);

  /// A tag for numerical literals.
  ///
  /// If known, prefer using the more specific tags of
  /// [Tags.integerLiteral] and [Tags.floatLiteral].
  static const Tag numberLiteral = Tag('number', parent: literal);

  /// A tag for integer literals, such as `42`, `0xFF`, and `0b1010`.
  static const Tag integerLiteral = Tag('integer', parent: numberLiteral);

  /// A tag for floating-point literals, such as `3.14` and `1.5e-10`.
  static const Tag floatLiteral = Tag('float', parent: numberLiteral);

  /// A parent tag for string literals and their content.
  ///
  /// For specific types of strings, prefer using a more specific tag,
  /// such as [Tags.singleQuoteString], [Tags.doubleQuoteString],
  /// [Tags.tripleQuoteString], and [Tags.characterLiteral].
  static const Tag stringLiteral = Tag('string', parent: literal);

  /// A tag for regular expression literals.
  static const Tag regexpLiteral = Tag('quoted', parent: stringLiteral);

  /// A tag for the unquoted string content.
  static const Tag stringContent = Tag('unquoted', parent: stringLiteral);

  /// A tag for quoted string literals including the quote marks.
  static const Tag quotedString = Tag('quoted', parent: stringLiteral);

  /// A tag for single-quoted string literals, such as `'hello'`;
  static const Tag singleQuoteString = Tag('single', parent: quotedString);

  /// A tag for double-quoted string literals, such as `"hello"`.
  static const Tag doubleQuoteString = Tag('double', parent: quotedString);

  /// A tag for triple-quoted string literals,
  /// such as `"""hello"""` or `'''hello'''`.
  static const Tag tripleQuoteString = Tag('triple', parent: quotedString);

  /// A tag for an unquoted string literals, such as a plain scaler in YAML.
  static const Tag unquotedString = Tag('unquoted', parent: stringLiteral);

  /// A tag for character literal values, such as `'a'` or `'\n'`.
  static const Tag characterLiteral = Tag('character', parent: stringLiteral);

  /// A tag for escape sequences within strings, such as `\n`, `\t`, and `\"`
  static const Tag stringEscape = Tag('escape', parent: stringLiteral);

  /// A tag for string interpolation expressions inside string literals,
  /// such as `$variable` or `${expression}` in Dart.
  static const Tag stringInterpolation = Tag(
    'interpolation',
    parent: stringLiteral,
  );

  /// A tag for collection literals.
  ///
  /// For specific collection types,
  /// prefer using [Tags.arrayLiteral] or [Tags.mapLiteral].
  static const Tag collectionLiteral = Tag('collection', parent: literal);

  /// A tag for array and list literals, such as `[1, 2, 3]` in Dart.
  static const Tag arrayLiteral = Tag('array', parent: collectionLiteral);

  /// A tag for set literal values, such as `{1, 2, 3}` in Dart.
  static const Tag setLiteral = Tag('array', parent: arrayLiteral);

  /// A tag for map and dictionary literals, such as `{'key': 'value'}` in Dart.
  static const Tag mapLiteral = Tag('map', parent: collectionLiteral);

  /// A tag for punctuation characters.
  ///
  /// For specific types of punctuation, prefer using a more specific tag,
  /// such as [Tags.separator] or [Tags.accessor].
  ///
  /// Operators that are composed of punctuation should
  /// usually be tagged with [Tags.operator].
  static const Tag punctuation = Tag('punctuation');

  /// A tag for separator punctuation, such as
  /// `,` in Dart lists or `:` in Dart maps.
  static const Tag separator = Tag('separator', parent: punctuation);

  /// A tag for accessor punctuation, such as `.` in Dart.
  static const Tag accessor = Tag('accessor', parent: punctuation);

  /// A tag for markup tags and XML-like elements,
  /// such as `<h1>` in HTML.
  static const Tag tag = Tag('tag');

  /// A tag for template tags and template engine directives,
  /// such as `{% if %}` in Liquid or Jinja.
  static const Tag templateTag = Tag('template', parent: tag);

  /// A root tag for source content classification.
  ///
  /// Prefer using a more specific source tag,
  /// such as [Tags.codeSource], [Tags.textualSource],
  /// [Tags.dataSource], or [Tags.markupSource].
  static const Tag source = Tag('source');

  /// A tag for programming language source code content.
  static const Tag codeSource = Tag('code', parent: source);

  /// A tag for textual content (non-code source).
  static const Tag textualSource = Tag('text', parent: source);

  /// A tag for structured data content, such as JSON, YAML, or CSV.
  static const Tag dataSource = Tag('data', parent: textualSource);

  /// A tag for markup language content, such as HTML or Markdown.
  static const Tag markupSource = Tag('markup', parent: textualSource);

  /// A tag for content that is invalid or contains syntax errors.
  static const Tag invalid = Tag('invalid');

  /// A tag for content that cannot be categorized or recognized.
  static const Tag unknown = Tag('unknown');

  /// A tag for markup language elements.
  ///
  /// Consider using tags from [MarkupTags] for specific markup constructs.
  static const Tag markup = Tag('markup');
}

/// A namespaced collection of predefined tags
/// for markup content, such as found in Markdown.
///
/// Prefer to use tags from here and [Tags] over
/// creating your own custom root tags.
abstract final class MarkupTags {
  /// A tag for plain text content within markup.
  static const Tag text = Tag('text', parent: Tags.markup);

  /// A parent tag for hyperlinks and link elements.
  static const Tag link = Tag('link');

  /// A tag for link reference labels,
  /// such as `[link text][ref]` in Markdown.
  static const Tag linkReference = Tag('reference', parent: link);

  /// A tag for link reference definitions,
  /// such as `[ref]: https://dart.dev` in Markdown.
  static const Tag linkDefinition = Tag('definition', parent: link);

  /// A tag for image elements and image references.
  static const Tag image = Tag('image', parent: Tags.markup);

  /// A tag for block-level markup elements.
  ///
  /// If available, prefer using a more specific tag,
  /// such as [MarkupTags.codeBlock] or [MarkupTags.quoteBlock].
  static const Tag block = Tag('block', parent: Tags.markup);

  /// A tag for code blocks and fenced code sections.
  static const Tag codeBlock = Tag('code', parent: block);

  /// A tag for blockquote elements and quoted text blocks.
  static const Tag quoteBlock = Tag('quote', parent: block);

  /// A tag for lists and their elements.
  ///
  /// If applicable to a specific list,
  /// prefer using [MarkupTags.unorderedList] or [MarkupTags.orderedList].
  static const Tag list = Tag('list', parent: block);

  /// A tag for unordered lists, such as bulleted lists in Markdown.
  static const Tag unorderedList = Tag('unordered', parent: list);

  /// A tag for ordered (numbered) lists.
  static const Tag orderedList = Tag('ordered', parent: list);

  /// A tag for inline text formatting and styling.
  ///
  /// If available, prefer using a specific formatting tag such as
  /// [MarkupTags.bold], [MarkupTags.italic], [MarkupTags.code],
  /// [MarkupTags.underline], [MarkupTags.strikethrough],
  /// or other specific formatting tags.
  static const Tag format = Tag('format', parent: Tags.markup);

  /// A tag for inline code formatting, such as `` `code` `` in Markdown.
  static const Tag code = Tag('code', parent: format);

  /// A tag for bold text formatting, such as `**bold**` in Markdown.
  static const Tag bold = Tag('bold', parent: format);

  /// A tag for italic text formatting, such as `*italic*` in Markdown.
  static const Tag italic = Tag('italic', parent: format);

  /// A tag for subscript text formatting,
  /// such as `H~2~O` in some markup languages.
  static const Tag subscript = Tag('subscript', parent: format);

  /// A tag for superscript text formatting,
  /// such as `x^2^` in some markup languages.
  static const Tag superscript = Tag('superscript', parent: format);

  /// A tag for underlined text formatting.
  static const Tag underline = Tag('underline', parent: format);

  /// A tag for strikethrough text formatting, such as `~~text~~` in Markdown.
  static const Tag strikethrough = Tag('strikethrough', parent: format);

  /// A tag for diff formatting and change indicators.
  ///
  /// If the type of change is known,
  /// prefer the more specific [MarkupTags.inserted] and [MarkupTags.removed].
  static const Tag diff = Tag('diff', parent: format);

  /// A tag for inserted/added content in diffs,
  /// such as often delineated by `+` in unified diffs.
  static const Tag inserted = Tag('inserted', parent: diff);

  /// A tag for removed/deleted content in diffs,
  /// such as often delineated by `-` in unified diffs.
  static const Tag removed = Tag('removed', parent: diff);

  /// A tag for heading elements, such as `# Heading` in Markdown.
  static const Tag heading = Tag('heading', parent: Tags.markup);

  /// A tag for table elements and tabular data.
  static const Tag table = Tag('table', parent: Tags.markup);
}
