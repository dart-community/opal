/// Provides tokenization and syntax highlighting support for various
/// built-in or custom programming languages and data formats.
library;

export 'src/built_in.dart' show BuiltInLanguages;
export 'src/language.dart' show Language;
export 'src/registry.dart' show LanguageRegistry;
export 'src/tag.dart' show MarkupTags, Tag, Tags;
export 'src/token.dart' show TaggedToken;
