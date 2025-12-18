import 'package:opal/opal.dart';
import 'package:test/test.dart';

void main() {
  group('LanguageRegistry', () {
    group('empty factory', () {
      test('creates an empty registry', () {
        const registry = LanguageRegistry.empty();

        expect(registry['dart'], isNull);
        expect(registry['yaml'], isNull);
        expect(registry['unknown'], isNull);
      });
    });

    group('withDefaults factory', () {
      late LanguageRegistry registry;

      setUp(() {
        registry = LanguageRegistry.withDefaults();
      });

      test('includes dart language', () {
        final language = registry['dart'];
        expect(language, isNotNull);
        expect(language, same(BuiltInLanguages.dart));
        expect(language?.name, equals('dart'));
      });

      test('includes yaml language', () {
        final language = registry['yaml'];
        expect(language, isNotNull);
        expect(language, same(BuiltInLanguages.yaml));
        expect(language?.name, equals('yaml'));
      });

      test('returns null for unknown language', () {
        expect(registry['unknown'], isNull);
        expect(registry['perl'], isNull);
        expect(registry['python'], isNull);
      });

      test('is case insensitive', () {
        expect(registry['DART'], same(BuiltInLanguages.dart));
        expect(registry['Dart'], same(BuiltInLanguages.dart));
        expect(registry['dArT'], same(BuiltInLanguages.dart));
        expect(registry['YAML'], same(BuiltInLanguages.yaml));
      });

      test('trims whitespace', () {
        expect(registry[' dart '], same(BuiltInLanguages.dart));
        expect(registry['\tdart\n'], same(BuiltInLanguages.dart));
        expect(registry['  yaml  '], same(BuiltInLanguages.yaml));
      });

      test('includes fallback mappings by default', () {
        expect(registry['yml'], same(BuiltInLanguages.yaml));
        expect(registry['javascript'], same(BuiltInLanguages.js));
        expect(registry['ts'], same(BuiltInLanguages.js));
      });
    });

    group('of factory', () {
      test(
        'creates empty registry when no languages and includeDefaults is false',
        () {
          final registry = LanguageRegistry.of({});

          expect(registry['dart'], isNull);
          expect(registry['yaml'], isNull);
        },
      );

      test(
        'includes only provided languages when includeDefaults is false',
        () {
          const customLanguage = _TestLanguage('custom');
          final registry = LanguageRegistry.of([customLanguage]);

          expect(registry['custom'], same(customLanguage));
          expect(registry['dart'], isNull);
          expect(registry['yaml'], isNull);
        },
      );

      test(
        'includes both default and provided languages when '
        'includeDefaults is true',
        () {
          const customLanguage = _TestLanguage('custom');
          final registry = LanguageRegistry.of(
            [customLanguage],
            includeDefaults: true,
          );

          expect(registry['custom'], same(customLanguage));
          expect(registry['dart'], same(BuiltInLanguages.dart));
          expect(registry['yaml'], same(BuiltInLanguages.yaml));
        },
      );

      test('provided languages override default languages', () {
        const customDart = _TestLanguage('dart');
        final registry = LanguageRegistry.of(
          [customDart],
          includeDefaults: true,
        );

        expect(registry['dart'], same(customDart));
        expect(registry['dart'], isNot(same(BuiltInLanguages.dart)));
        expect(registry['yaml'], same(BuiltInLanguages.yaml));
      });

      test('includes fallback mappings when provided', () {
        final registry = LanguageRegistry.of(
          {},
          includeDefaults: true,
          fallbackLanguageNames: {'yml': 'yaml'},
        );

        expect(registry['yml'], same(BuiltInLanguages.yaml));
        expect(registry['yaml'], same(BuiltInLanguages.yaml));
      });

      test(
        'includes default fallback mappings when includeDefaults is true',
        () {
          final registry = LanguageRegistry.of(
            {},
            includeDefaults: true,
            fallbackLanguageNames: {},
          );

          // Test the yml -> yaml fallback from the provided defaults.
          expect(registry['yml'], same(BuiltInLanguages.yaml));
          expect(registry['javascript'], same(registry['js']));
          expect(registry['typescript'], same(registry['js']));
          expect(registry['ts'], same(registry['js']));
        },
      );

      test(
        'does not include default fallback mappings when '
        'includeDefaults is false',
        () {
          final registry = LanguageRegistry.of(
            {},
            includeDefaults: false,
            fallbackLanguageNames: {},
          );

          expect(registry['yml'], isNull);
          expect(registry['javascript'], isNull);
          expect(registry['typescript'], isNull);
          expect(registry['ts'], isNull);
        },
      );

      test('custom fallback mappings override default ones', () {
        const customYaml = _TestLanguage('custom-yaml');
        final registry = LanguageRegistry.of(
          [customYaml],
          includeDefaults: true,
          fallbackLanguageNames: {'yml': 'custom-yaml'},
        );

        expect(registry['yml'], same(customYaml));
        expect(registry['yml'], isNot(same(BuiltInLanguages.yaml)));
      });
    });

    group('operator []', () {
      test('returns language for exact match', () {
        const dart = _TestLanguage('dart');
        const yaml = _TestLanguage('yaml');
        final registry = LanguageRegistry.of([dart, yaml]);

        expect(registry['dart'], same(dart));
        expect(registry['yaml'], same(yaml));
      });

      test('is case insensitive', () {
        const language = _TestLanguage('language');
        final registry = LanguageRegistry.of([language]);

        expect(registry['LANGUAGE'], same(language));
        expect(registry['Language'], same(language));
        expect(registry['lAnGuAgE'], same(language));
      });

      test('trims whitespace', () {
        const language = _TestLanguage('language');
        final registry = LanguageRegistry.of([language]);

        expect(registry[' language'], same(language));
        expect(registry['language '], same(language));
        expect(registry[' language '], same(language));
        expect(registry['\tlanguage\n'], same(language));
      });

      test('uses fallback mappings', () {
        const yaml = _TestLanguage('yaml');
        final registry = LanguageRegistry.of(
          [yaml],
          fallbackLanguageNames: {'yml': 'yaml'},
        );

        expect(registry['yml'], same(yaml));
        expect(registry['YML'], same(yaml));
        expect(registry[' yml '], same(yaml));
      });

      test('returns null when fallback target does not exist', () {
        final registry = LanguageRegistry.of(
          {},
          fallbackLanguageNames: {'yml': 'yaml'},
        );

        expect(registry['yml'], isNull);
      });

      test('handles chained fallbacks', () {
        const targetLanguage = _TestLanguage('target');
        final registry = LanguageRegistry.of(
          [targetLanguage],
          fallbackLanguageNames: {
            'alias1': 'alias2',
            'alias2': 'target',
          },
        );

        expect(registry['alias1'], same(targetLanguage));
        expect(registry['alias2'], same(targetLanguage));
        expect(registry['target'], same(targetLanguage));
      });

      test('returns null for circular fallbacks', () {
        final registry = LanguageRegistry.of(
          {},
          fallbackLanguageNames: {
            'a': 'b',
            'b': 'a',
          },
        );

        expect(registry['a'], isNull);
        expect(registry['b'], isNull);
      });
    });

    group('const behavior', () {
      test('empty registry is const constructible', () {
        const registry = LanguageRegistry.empty();
        expect(registry, isA<LanguageRegistry>());
      });
    });
  });
}

final class _TestLanguage extends Language {
  const _TestLanguage(super.name);

  @override
  List<List<TaggedToken>> tokenize(List<String> content, {Uri? sourceFile}) {
    throw UnimplementedError('Test language');
  }
}
