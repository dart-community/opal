import 'built_in.dart';
import 'language.dart' show Language;

/// A registry that manages and provides access to [Language] definitions,
/// to be used for tokenizing source content in those languages.
///
/// Languages are retrieved using a standardized version of their name or
/// an alternative name provided to the registry.
final class LanguageRegistry {
  /// Internal storage for language definitions mapped by
  /// a standardized version of their name.
  ///
  /// Should not be modified after registry creation.
  final Map<String, Language> _languages;

  /// Maps alternative language names to their standardized counterparts.
  /// Used for language name resolution when the primary name lookup fails.
  ///
  /// Should not be modified after registry creation.
  final Map<String, String> _fallbackLanguageNames;

  /// Creates a language registry with the specified
  /// [languages] mappings and [fallbackLanguageNames].
  const LanguageRegistry._({
    Map<String, Language> languages = const {},
    Map<String, String> fallbackLanguageNames = const {},
  }) : _languages = languages,
       _fallbackLanguageNames = fallbackLanguageNames;

  /// Creates an empty language registry with no predefined languages.
  const factory LanguageRegistry.empty() = LanguageRegistry._;

  /// Creates a language registry initialized with the language definitions
  /// that are bundled with `package:opal` as well as common alternative names.
  factory LanguageRegistry.withDefaults() => LanguageRegistry._(
    languages: _defaultLanguages,
    fallbackLanguageNames: _defaultFallbackLanguageNames,
  );

  /// Creates a language registry containing the
  /// specified language definitions in [languages].
  ///
  /// If [includeDefaults] is `true`, also includes the language definitions
  /// that are bundled with `package:opal` as well as common alternative names.
  ///
  /// Additional [fallbackLanguageNames] can be provided for
  /// alternative language name resolution, such as `'rs'` for `'rust'`.
  factory LanguageRegistry.of(
    Iterable<Language> languages, {
    bool includeDefaults = false,
    Map<String, String> fallbackLanguageNames = const {},
  }) => !includeDefaults && languages.isEmpty
      ? const LanguageRegistry.empty()
      : LanguageRegistry._(
          languages: {
            if (includeDefaults) ..._defaultLanguages,
            for (final language in languages) language.name: language,
          },
          fallbackLanguageNames: {
            if (includeDefaults) ..._defaultFallbackLanguageNames,
            ...fallbackLanguageNames,
          },
        );

  /// Retrieves a [Language] definition by its [name].
  ///
  /// The [name] is case-insensitive and whitespace is trimmed.
  ///
  /// If the exact name is not found in the registry,
  /// attempts to resolve a language by using alternative fallback names.
  ///
  /// Returns `null` if no matching language is found.
  Language? operator [](String name) {
    final standardizedName = name.trim().toLowerCase();
    final foundLanguage = _languages[standardizedName];
    if (foundLanguage != null) {
      return foundLanguage;
    }

    final backupName = _fallbackLanguageNames[standardizedName];
    if (backupName != null) {
      return this[backupName];
    }

    return null;
  }
}

/// A mapping of language definitions provided by `package:opal`
/// from their standardized name to the corresponding language definition.
final Map<String, Language> _defaultLanguages = {
  for (final language in BuiltInLanguages.all) language.name: language,
};

/// A mapping of alternative names for languages to
/// the standardized names used in [_defaultLanguages].
final Map<String, String> _defaultFallbackLanguageNames = {
  'xhtml': BuiltInLanguages.xml.name,
  'javascript': BuiltInLanguages.js.name,
  // If a TS-specific grammar is ever implemented,
  // remove these two mappings.
  'typescript': BuiltInLanguages.js.name,
  'ts': BuiltInLanguages.js.name,
  'kt': BuiltInLanguages.kotlin.name,
  'md': BuiltInLanguages.markdown.name,
  'plaintext': BuiltInLanguages.text.name,
  'none': BuiltInLanguages.text.name,
  'nocode': BuiltInLanguages.text.name,
  'txt': BuiltInLanguages.text.name,
  'yml': BuiltInLanguages.yaml.name,
  'gradle': BuiltInLanguages.groovy.name,
  'objc': BuiltInLanguages.objectiveC.name,
  'obj-c': BuiltInLanguages.objectiveC.name,
  'objective-c': BuiltInLanguages.objectiveC.name,
};
