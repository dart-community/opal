/// End-to-end golden testing for `package:opal`.
///
/// ## Overview
///
/// Golden tests verify that language tokenization produces consistent,
/// correct output by comparing against pre-generated reference files.
///
/// ## Testing structure
///
/// Tests are organized by language in `test/goldens/<language>/`:
///
/// - `.in` files contain input source code to tokenize.
/// - `.out` files contain expected tokenization output.
///
/// Tests are automatically discovered based on the directory structure.
/// Each language directory becomes a test group and
/// each `.in` file becomes a test case.
///
/// ## Running tests
///
/// Run all golden tests:
///
/// ```bash
/// dart test test/golden_test.dart
/// ```
///
/// Run tests for a specific language:
///
/// ```bash
/// dart test test/golden_test.dart --plain-name "dart"
/// ```
///
/// ## Generating golden files
///
/// To create or update golden files:
///
/// 1. Create/edit the `.in` file in `test/goldens/<language>/`.
/// 2. Set [generateGoldens] to `true` in this file.
/// 3. Run: `dart test test/golden_test.dart`.
/// 4. Review the generated `.out` files.
/// 5. Set [generateGoldens] back to `false`.
///
/// The generator automatically discovers all `.in` files and
/// generates the corresponding `.out` files.
library;

import 'package:test/test.dart';

import 'goldens/golden_test_util.dart';

/// Set to `true` to generate golden files instead of running tests.
const generateGoldens = false;

void main() {
  // Discover all languages and their test cases from the file system.
  final suite = GoldenTestSuite.discover();

  if (generateGoldens) {
    // Create or update all golden files.
    group('Generate golden files', () {
      test('generate all', () async {
        for (final language in suite.languages) {
          for (final goldenTest in language.tests) {
            await goldenTest.generate(suite.registry);
            print('Generated: ${language.name}/${goldenTest.name}.out');
          }
        }
      });
    });

    return;
  }

  // Run all discovered golden tests.
  for (final language in suite.languages) {
    group(language.name, () {
      for (final goldenTest in language.tests) {
        test(goldenTest.name, () async {
          await goldenTest.run(suite.registry);
        });
      }
    });
  }
}
