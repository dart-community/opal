import 'package:opal/opal.dart';
import 'package:opal/src/matcher.dart';
import 'package:test/test.dart' hide Matcher, Tags;

void main() {
  group('Matcher', () {
    group('factories', () {
      test('regex creates PatternMatcher with RegExp', () {
        final matcher = Matcher.regex(r'\d+', tag: Tags.numberLiteral);
        expect(matcher, isA<PatternMatcher>());
        expect(matcher.tag, equals(Tags.numberLiteral));

        final patternMatcher = matcher as PatternMatcher;
        expect(patternMatcher.pattern, isA<RegExp>());
        expect((patternMatcher.pattern as RegExp).pattern, equals(r'\d+'));
        expect((patternMatcher.pattern as RegExp).isUnicode, isTrue);
      });

      test('verbatim creates PatternMatcher with String', () {
        final matcher = Matcher.verbatim('hello', tag: Tags.keyword);
        expect(matcher, isA<PatternMatcher>());
        expect(matcher.tag, equals(Tags.keyword));

        final patternMatcher = matcher as PatternMatcher;
        expect(patternMatcher.pattern, isA<String>());
        expect(patternMatcher.pattern, equals('hello'));
      });

      test('capture creates CaptureMatcher', () {
        const pattern = r'(\w+)\s*=\s*(\d+)';
        final captures = [Tags.identifier, Tags.numberLiteral];
        final matcher = Matcher.capture(
          pattern,
          captures: captures,
          tag: Tags.operator,
        );

        expect(matcher, isA<CaptureMatcher>());
        expect(matcher.tag, equals(Tags.operator));

        final captureMatcher = matcher as CaptureMatcher;
        expect(captureMatcher.pattern.pattern, equals(pattern));
        expect(captureMatcher.captures, equals(captures));
      });

      test('wrapped creates WrappedMatcher', () {
        final beginMatcher = Matcher.verbatim('(');
        final endMatcher = Matcher.verbatim(')');
        final contentMatcher = Matcher.regex(r'\w+');

        final matcher = Matcher.wrapped(
          begin: beginMatcher,
          end: endMatcher,
          content: contentMatcher,
          tag: Tags.punctuation,
        );

        expect(matcher, isA<WrappedMatcher>());
        expect(matcher.tag, equals(Tags.punctuation));

        final wrappedMatcher = matcher as WrappedMatcher;
        expect(wrappedMatcher.begin, equals(beginMatcher));
        expect(wrappedMatcher.end, equals(endMatcher));
        expect(wrappedMatcher.content, equals(contentMatcher));
      });

      test('options creates OptionsMatcher', () {
        final matchers = [
          Matcher.verbatim('if'),
          Matcher.verbatim('else'),
          Matcher.verbatim('while'),
        ];

        final matcher = Matcher.options(matchers, tag: Tags.controlKeyword);

        expect(matcher, isA<OptionsMatcher>());
        expect(matcher.tag, equals(Tags.controlKeyword));

        final optionsMatcher = matcher as OptionsMatcher;
        expect(optionsMatcher.matchers, equals(matchers));
        expect(optionsMatcher.includeDefaultRules, isTrue);
      });

      test('include creates IncludeMatcher', () {
        Matcher generator() => Matcher.regex(r'\d+');

        final matcher = Matcher.include(generator, tag: Tags.literal);

        expect(matcher, isA<IncludeMatcher>());
        expect(matcher.tag, equals(Tags.literal));

        final includeMatcher = matcher as IncludeMatcher;
        expect(includeMatcher.matchGenerator, equals(generator));
      });

      test('include uses null as default tag', () {
        final matcher = Matcher.include(() => Matcher.regex(r'\d+'));
        expect(matcher.tag, isNull);
      });

      test('keywords creates OptionsMatcher with keyword matchers', () {
        final keywords = ['if', 'else', 'while'];
        final matcher = Matcher.keywords(keywords);

        expect(matcher, isA<OptionsMatcher>());

        final optionsMatcher = matcher as OptionsMatcher;
        expect(optionsMatcher.matchers.length, equals(3));

        for (var i = 0; i < keywords.length; i++) {
          final keywordMatcher = optionsMatcher.matchers[i];
          expect(keywordMatcher, isA<PatternMatcher>());

          final pattern = (keywordMatcher as PatternMatcher).pattern;
          expect(pattern, isA<RegExp>());
          expect((pattern as RegExp).pattern, equals('\\b${keywords[i]}\\b'));

          expect(keywordMatcher.tag, isA<Tag>());
          expect(keywordMatcher.tag!.id, equals(keywords[i]));
          expect(keywordMatcher.tag!.parent, equals(Tags.keyword));
        }
      });

      test('keywords uses custom baseTag', () {
        final keywords = ['true', 'false'];
        final matcher = Matcher.keywords(
          keywords,
          baseTag: Tags.booleanLiteral,
        );

        final optionsMatcher = matcher as OptionsMatcher;

        for (final keywordMatcher in optionsMatcher.matchers) {
          expect(keywordMatcher.tag!.parent, equals(Tags.booleanLiteral));
        }
      });

      test('builtInTypes creates OptionsMatcher with type matchers', () {
        final types = ['int', 'double', 'String'];
        final matcher = Matcher.builtInTypes(types);

        expect(matcher, isA<OptionsMatcher>());

        final optionsMatcher = matcher as OptionsMatcher;
        expect(optionsMatcher.matchers.length, equals(3));

        for (var i = 0; i < types.length; i++) {
          final typeMatcher = optionsMatcher.matchers[i];
          expect(typeMatcher, isA<PatternMatcher>());

          final pattern = (typeMatcher as PatternMatcher).pattern;
          expect(pattern, isA<RegExp>());
          expect((pattern as RegExp).pattern, equals('\\b${types[i]}\\b'));

          expect(typeMatcher.tag, equals(Tags.builtInType));
        }
      });

      test('builtInTypes uses custom tag', () {
        final types = ['void', 'null'];
        const customTag = Tag('custom-type');
        final matcher = Matcher.builtInTypes(types, tag: customTag);

        final optionsMatcher = matcher as OptionsMatcher;

        for (final typeMatcher in optionsMatcher.matchers) {
          expect(typeMatcher.tag, equals(customTag));
        }
      });
    });

    group('inheritance', () {
      test('tag property is inherited from base class', () {
        const tag = Tag('test-tag');

        final patternMatcher = Matcher.verbatim('test', tag: tag);
        expect(patternMatcher.tag, equals(tag));

        final captureMatcher = Matcher.capture(
          '',
          captures: [],
          tag: tag,
        );
        expect(captureMatcher.tag, equals(tag));
      });
    });
  });

  group('MatcherGrammar', () {
    test('is abstract base class', () {
      expect(TestMatcherGrammar.new, returnsNormally);
    });

    test('has required matchers getter', () {
      final grammar = TestMatcherGrammar();
      expect(grammar.matchers, isA<List<Matcher>>());
    });

    test('preAppliedMatchers defaults to empty list', () {
      final grammar = TestMatcherGrammar();
      expect(grammar.preAppliedMatchers, isEmpty);
    });

    test('postAppliedMatchers includes default whitespace matchers', () {
      final grammar = TestMatcherGrammar();
      final postMatchers = grammar.postAppliedMatchers;

      expect(postMatchers.length, equals(1));

      // Verify default whitespace matcher is included as expected.
      final whitespaceMatcher = postMatchers[0] as PatternMatcher;
      expect(whitespaceMatcher.pattern, isA<RegExp>());
      expect((whitespaceMatcher.pattern as RegExp).pattern, equals(r'[\s\t]+'));
      expect(whitespaceMatcher.tag, equals(Tags.whitespace));
    });

    test('can override preAppliedMatchers', () {
      final grammar = TestMatcherGrammarWithPreMatchers();
      expect(grammar.preAppliedMatchers.length, equals(1));

      final preMatcher = grammar.preAppliedMatchers[0] as PatternMatcher;
      expect(preMatcher.pattern, equals('pre'));
    });

    test('can override postAppliedMatchers', () {
      final grammar = TestMatcherGrammarWithCustomPostMatchers();
      expect(grammar.postAppliedMatchers.length, equals(1));

      final postMatcher = grammar.postAppliedMatchers[0] as PatternMatcher;
      expect(postMatcher.pattern, equals('post'));
    });

    test('multiple grammars can coexist', () {
      final grammar1 = TestMatcherGrammar();
      final grammar2 = TestMatcherGrammarWithPreMatchers();

      expect(grammar1.matchers.length, equals(2));
      expect(grammar2.matchers.length, equals(1));

      expect(grammar1.preAppliedMatchers, isEmpty);
      expect(grammar2.preAppliedMatchers.length, equals(1));
    });
  });
}

final class TestMatcherGrammar extends MatcherGrammar {
  @override
  List<Matcher> get matchers => [
    Matcher.verbatim('test'),
    Matcher.regex(r'\d+'),
  ];
}

final class TestMatcherGrammarWithPreMatchers extends MatcherGrammar {
  @override
  List<Matcher> get matchers => [
    Matcher.verbatim('main'),
  ];

  @override
  List<Matcher> get preAppliedMatchers => [
    Matcher.verbatim('pre'),
  ];
}

final class TestMatcherGrammarWithCustomPostMatchers extends MatcherGrammar {
  @override
  List<Matcher> get matchers => [
    Matcher.verbatim('custom'),
  ];

  @override
  List<Matcher> get postAppliedMatchers => [
    Matcher.verbatim('post'),
  ];
}
