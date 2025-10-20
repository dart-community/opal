/// Utilities for golden file testing for tokenization.
library;

import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:opal/opal.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

/// Represents a complete suite of golden tests for all languages.
///
/// The suite discovers all language directories and their
/// test files automatically from the file system.
final class GoldenTestSuite {
  /// The path to the goldens directory.
  static const String goldensPath = 'test/goldens';

  /// All discovered language test collections.
  final List<GoldenLanguage> languages;

  /// The language registry to use for tokenization.
  final LanguageRegistry registry;

  const GoldenTestSuite._({
    required this.languages,
    required this.registry,
  });

  /// Discovers all golden tests from the file system.
  ///
  /// Scans the [goldensPath] directory for language subdirectories,
  /// and within each language directory, finds all `.in` files.
  factory GoldenTestSuite.discover({LanguageRegistry? registry}) {
    final languageRegistry = registry ?? LanguageRegistry.withDefaults();
    final goldensDir = Directory(goldensPath);

    if (!goldensDir.existsSync()) {
      return GoldenTestSuite._(
        languages: const [],
        registry: languageRegistry,
      );
    }

    final languages = <GoldenLanguage>[];

    for (final entity in goldensDir.listSync()) {
      if (entity is Directory) {
        final languageName = path.basename(entity.path);
        final tests = _discoverTestsForLanguage(languageName);

        if (tests.isNotEmpty) {
          languages.add(
            GoldenLanguage._(
              name: languageName,
              tests: tests,
              registry: languageRegistry,
            ),
          );
        }
      }
    }

    return GoldenTestSuite._(
      languages: languages.sortedBy((language) => language.name),
      registry: languageRegistry,
    );
  }

  /// Discovers all test files for a given language.
  static List<GoldenTest> _discoverTestsForLanguage(String language) {
    final languageDir = Directory('$goldensPath/$language');

    if (!languageDir.existsSync()) {
      return const [];
    }

    final tests = <GoldenTest>[];

    for (final inputFile in languageDir.listSync().whereType<File>().where(
      (entity) => path.extension(entity.path) == '.in',
    )) {
      final fileName = path.basename(inputFile.path);
      final testName = fileName.substring(0, fileName.length - 3);
      final outputFile = File(path.setExtension(inputFile.path, '.out'));

      tests.add(
        GoldenTest._(
          language: language,
          name: testName,
          inputFile: inputFile,
          outputFile: outputFile,
        ),
      );
    }

    return tests.sortedBy((test) => test.name);
  }

  /// Generates all golden output files from their input files.
  Future<void> generateAll() async {
    for (final language in languages) {
      await language.generateAll();
    }
  }
}

/// Represents all golden tests for a specific language.
final class GoldenLanguage {
  /// The language identifier, such as `dart` or `js`.
  final String name;

  /// All golden tests for this language.
  final List<GoldenTest> tests;

  /// The language registry to use for tokenization.
  final LanguageRegistry registry;

  const GoldenLanguage._({
    required this.name,
    required this.tests,
    required this.registry,
  });

  /// Generates all golden output files for this language.
  Future<void> generateAll() async {
    for (final test in tests) {
      await test.generate(registry);
    }
  }
}

/// Represents a single golden test case for a language.
final class GoldenTest {
  /// The identifier of the language this test belongs to.
  final String language;

  /// The name of this test.
  ///
  /// Derived from the input filename without the extension.
  final String name;

  /// The input file containing the source code to tokenize.
  final File inputFile;

  /// The output file containing the expected tokenization output.
  final File outputFile;

  const GoldenTest._({
    required this.language,
    required this.name,
    required this.inputFile,
    required this.outputFile,
  });

  /// Runs this golden test.
  ///
  /// Retrieves the tokenizer for the [language] from the specified [registry].
  ///
  /// Tokenizes the [inputFile] and compares the result against
  /// the contents of the expected [outputFile].
  Future<void> run(LanguageRegistry registry) async {
    final languageDefinition = registry[language];

    if (languageDefinition == null) {
      fail('Language "$language" not found in registry');
    }

    if (!inputFile.existsSync()) {
      fail('Input file not found: ${inputFile.path}');
    }

    if (!outputFile.existsSync()) {
      fail('Output file not found: ${outputFile.path}');
    }

    final input = await inputFile.readAsString();
    final expectedOutput = await outputFile.readAsString();

    final lines = const LineSplitter().convert(input);
    final tokensByLine = languageDefinition.tokenize(lines);
    final actualOutput = _formatTokens(lines, tokensByLine);

    expect(
      actualOutput.trim(),
      equals(expectedOutput.trim()),
      reason: 'Golden file mismatch for $language/$name',
    );
  }

  /// Generates the golden [outputFile] from the [inputFile].
  ///
  /// Retrieves the tokenizer for the [language] from the specified [registry].
  Future<void> generate(LanguageRegistry registry) async {
    final languageDefinition = registry[language];

    if (languageDefinition == null) {
      fail('Language "$language" not found in registry');
    }

    if (!inputFile.existsSync()) {
      fail('Input file not found: ${inputFile.path}');
    }

    final input = await inputFile.readAsString();
    final lines = const LineSplitter().convert(input);
    final tokensByLine = languageDefinition.tokenize(lines);
    final output = _formatTokens(lines, tokensByLine);

    await outputFile.writeAsString(output);
  }

  /// Formats tokens into the golden file output format.
  static String _formatTokens(
    List<String> inputLines,
    List<List<TaggedToken>> tokensByLine,
  ) {
    final buffer = StringBuffer();

    for (var lineIndex = 0; lineIndex < inputLines.length; lineIndex += 1) {
      final line = inputLines[lineIndex];
      final tokens = lineIndex < tokensByLine.length
          ? tokensByLine[lineIndex]
          : <TaggedToken>[];

      // Write the input line.
      buffer.writeln(line);

      // Write token annotations if there are any tokens.
      if (tokens.isNotEmpty) {
        _writeTokenAnnotations(buffer, line, tokens);
      }
    }

    return buffer.toString();
  }

  /// Writes the `^` markers and tag names for tokens on a line.
  static void _writeTokenAnnotations(
    StringBuffer buffer,
    String line,
    List<TaggedToken> tokens,
  ) {
    var position = 0;

    for (final token in tokens) {
      final content = token.content;
      final start = position;
      final end = position + content.length;
      final length = end - start;

      if (length > 0) {
        // Write marker line with leading spaces.
        final markerLine = ' ' * start + ('^' * length);
        buffer.writeln(markerLine);

        // Write tag line with leading spaces.
        final tagString = token.tags.map((tag) => tag.toString()).join('-');
        final tagLine = ' ' * start + tagString;
        buffer.writeln(tagLine);
      }

      position = end;
    }
  }
}
