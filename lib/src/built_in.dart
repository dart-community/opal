import 'package:meta/meta.dart';

import 'language.dart';
import 'language/c.dart';
import 'language/c_plus_plus.dart';
import 'language/dart.dart';
import 'language/groovy.dart';
import 'language/html.dart';
import 'language/java.dart';
import 'language/js.dart';
import 'language/json.dart';
import 'language/kotlin.dart';
import 'language/markdown.dart';
import 'language/objective_c.dart';
import 'language/swift.dart';
import 'language/text.dart';
import 'language/xml.dart';
import 'language/yaml.dart';
import 'matcher_language.dart';
import 'tag.dart';

/// A namespace containing the [Language] implementations
/// for the languages with built-in support by the package.
abstract final class BuiltInLanguages {
  /// A collection of all built-in languages.
  @useResult
  static final List<Language> all = [
    c,
    cPlusPlus,
    dart,
    groovy,
    html,
    java,
    js,
    json,
    kotlin,
    markdown,
    objectiveC,
    swift,
    text,
    xml,
    yaml,
  ];

  /// A tokenizing language implementation for the C programming language.
  static final Language c = MatcherLanguage(
    name: 'c',
    grammar: const CGrammar(),
    baseTag: const Tag('c', parent: Tags.codeSource),
  );

  /// A tokenizing language implementation for the C++ programming language.
  static final Language cPlusPlus = MatcherLanguage(
    name: 'cpp',
    grammar: const CPlusPlusGrammar(),
    baseTag: const Tag('cpp', parent: Tags.codeSource),
  );

  /// A tokenizing language implementation for the Dart programming language.
  static final Language dart = MatcherLanguage(
    name: 'dart',
    grammar: const DartGrammar(),
    baseTag: const Tag('dart', parent: Tags.codeSource),
  );

  /// A tokenizing language implementation for the Groovy programming language.
  static final Language groovy = MatcherLanguage(
    name: 'groovy',
    grammar: const GroovyGrammar(),
    baseTag: const Tag('groovy', parent: Tags.codeSource),
  );

  /// A tokenizing language implementation for HTML.
  static final Language html = MatcherLanguage(
    name: 'html',
    grammar: const HtmlGrammar(),
    baseTag: const Tag('html', parent: Tags.markupSource),
  );

  /// A tokenizing language implementation for the Java programming language.
  static final Language java = MatcherLanguage(
    name: 'java',
    grammar: const JavaGrammar(),
    baseTag: const Tag('java', parent: Tags.codeSource),
  );

  /// A tokenizing language implementation for JavaScript.
  static final Language js = MatcherLanguage(
    name: 'js',
    grammar: const JSGrammar(),
    baseTag: const Tag('js', parent: Tags.codeSource),
  );

  /// A tokenizing language implementation for the JSON data format.
  static final Language json = MatcherLanguage(
    name: 'json',
    grammar: const JsonGrammar(),
    baseTag: const Tag('json', parent: Tags.dataSource),
  );

  /// A tokenizing language implementation for the Kotlin programming language.
  static final Language kotlin = MatcherLanguage(
    name: 'kotlin',
    grammar: const KotlinGrammar(),
    baseTag: const Tag('kotlin', parent: Tags.codeSource),
  );

  /// A tokenizing language implementation for Markdown.
  static final Language markdown = MatcherLanguage(
    name: 'markdown',
    grammar: const MarkdownGrammar(),
    baseTag: const Tag('markdown', parent: Tags.markupSource),
  );

  /// A tokenizing language implementation for Objective-C.
  static final Language objectiveC = MatcherLanguage(
    name: 'objective-c',
    grammar: const ObjectiveCGrammar(),
    baseTag: const Tag('objective-c', parent: Tags.codeSource),
  );

  /// A tokenizing language implementation for the Swift programming language.
  static final Language swift = MatcherLanguage(
    name: 'swift',
    grammar: const SwiftGrammar(),
    baseTag: const Tag('swift', parent: Tags.codeSource),
  );

  /// A [Language] for textual content that
  /// passes through each line as a single token.
  static const Language text = TextLanguage();

  /// A tokenizing language implementation for the XML data format.
  static final Language xml = MatcherLanguage(
    name: 'xml',
    grammar: const XmlGrammar(),
    baseTag: const Tag('xml', parent: Tags.markupSource),
  );

  /// A tokenizing language implementation for the YAML data format.
  static final Language yaml = MatcherLanguage(
    name: 'yaml',
    grammar: const YamlGrammar(),
    baseTag: const Tag('yaml', parent: Tags.dataSource),
  );
}
