import 'package:opal/opal.dart';
import 'package:test/test.dart';

void main() {
  group('TaggedToken', () {
    group('constructor', () {
      test('creates token with content and empty tags', () {
        final token = TaggedToken('test', []);
        expect(token.content, equals('test'));
        expect(token.tags, isEmpty);
      });

      test('creates token with content and single tag', () {
        const tag = Tag('identifier');
        final token = TaggedToken('variable', [tag]);
        expect(token.content, equals('variable'));
        expect(token.tags, equals([tag]));
      });

      test('creates token with content and multiple tags', () {
        const tag1 = Tag('keyword');
        const tag2 = Tag('control', parent: tag1);
        final token = TaggedToken('if', [tag1, tag2]);
        expect(token.content, equals('if'));
        expect(token.tags, equals([tag1, tag2]));
      });

      test('creates unmodifiable tags list', () {
        const tag = Tag('test');
        final mutableList = [tag];
        final token = TaggedToken('content', mutableList);

        // Verify the token's tags list is unmodifiable.
        expect(() => token.tags.add(const Tag('new')), throwsUnsupportedError);
        expect(() => token.tags.remove(tag), throwsUnsupportedError);
        expect(token.tags.clear, throwsUnsupportedError);

        // Verify modifying original tag list doesn't affect the tagged token.
        mutableList.add(const Tag('another'));
        expect(token.tags, hasLength(1));
      });

      test('preserves tag order from iterable', () {
        const tag1 = Tag('first');
        const tag2 = Tag('second');
        const tag3 = Tag('third');
        final token = TaggedToken('test', [tag1, tag2, tag3]);
        expect(token.tags, equals([tag1, tag2, tag3]));
      });

      test('accepts Set as iterable', () {
        const tag1 = Tag('a');
        const tag2 = Tag('b');
        final tagSet = {tag1, tag2};
        final token = TaggedToken('test', tagSet);
        expect(token.tags, hasLength(2));
        expect(token.tags, containsAll([tag1, tag2]));
      });

      test('accepts custom iterable', () {
        const tag1 = Tag('one');
        const tag2 = Tag('two');
        final customIterable = [tag1, tag2].where((t) => true);
        final token = TaggedToken('test', customIterable);
        expect(token.tags, equals([tag1, tag2]));
      });
    });

    group('content property', () {
      test('returns empty string content', () {
        final token = TaggedToken('', []);
        expect(token.content, equals(''));
      });

      test('returns single character content', () {
        final token = TaggedToken('a', []);
        expect(token.content, equals('a'));
      });

      test('returns multi-line content', () {
        const content = 'line1\nline2\nline3';
        final token = TaggedToken(content, []);
        expect(token.content, equals(content));
      });

      test('returns content with special characters', () {
        const content = 'test\t\n\r\'"\\';
        final token = TaggedToken(content, []);
        expect(token.content, equals(content));
      });
    });

    group('tags property', () {
      test('returns empty list when no tags provided', () {
        final token = TaggedToken('test', []);
        expect(token.tags, isEmpty);
        expect(token.tags, isA<List<Tag>>());
      });

      test('returns tags in order from least to most specific', () {
        const root = Tag('root');
        const middle = Tag('middle', parent: root);
        const specific = Tag('specific', parent: middle);

        // Order should be maintained as provided.
        final token = TaggedToken('test', [root, middle, specific]);
        expect(token.tags[0], equals(root));
        expect(token.tags[1], equals(middle));
        expect(token.tags[2], equals(specific));
      });

      test('handles duplicate tags', () {
        const tag = Tag('test');
        final token = TaggedToken('content', [tag, tag, tag]);
        expect(token.tags, hasLength(3));
        expect(token.tags, everyElement(equals(tag)));
      });
    });

    group('toString', () {
      test('returns content for simple token', () {
        final token = TaggedToken('hello', []);
        expect(token.toString(), equals('hello'));
      });

      test('returns content regardless of tags', () {
        const tag1 = Tag('tag1');
        const tag2 = Tag('tag2');
        final token = TaggedToken('content', [tag1, tag2]);
        expect(token.toString(), equals('content'));
      });

      test('returns empty string for empty content', () {
        final token = TaggedToken('', [const Tag('test')]);
        expect(token.toString(), equals(''));
      });

      test('returns complex content unchanged', () {
        const complexContent = '  \n\t special chars: <>&"\'  ';
        final token = TaggedToken(complexContent, []);
        expect(token.toString(), equals(complexContent));
      });
    });

    group('equality', () {
      test('tokens are not equal by default', () {
        final token1 = TaggedToken('test', []);
        final token2 = TaggedToken('test', []);
        expect(token1, isNot(equals(token2)));
      });

      test('same instance is equal to itself', () {
        final token = TaggedToken('test', [const Tag('tag')]);
        expect(token, equals(token));
      });
    });

    group('use cases', () {
      test('keyword token', () {
        const keywordTag = Tag('keyword');
        const controlTag = Tag('control', parent: keywordTag);
        final token = TaggedToken('while', [keywordTag, controlTag]);

        expect(token.content, equals('while'));
        expect(token.tags, hasLength(2));
        expect(token.tags[0].id, equals('keyword'));
        expect(token.tags[1].id, equals('control'));
        expect(token.tags[1].parent, equals(keywordTag));
      });

      test('string literal token', () {
        const literalTag = Tag('literal');
        const stringTag = Tag('string', parent: literalTag);
        const quotedTag = Tag('quoted', parent: stringTag);
        const doubleQuoteTag = Tag('double', parent: quotedTag);

        final token = TaggedToken(
          '"Hello, World!"',
          [literalTag, stringTag, quotedTag, doubleQuoteTag],
        );

        expect(token.content, equals('"Hello, World!"'));
        expect(token.tags, hasLength(4));
        expect(token.toString(), equals('"Hello, World!"'));
      });

      test('comment token with empty content', () {
        const commentTag = Tag('comment');
        const lineCommentTag = Tag('line', parent: commentTag);
        final token = TaggedToken('', [commentTag, lineCommentTag]);

        expect(token.content, isEmpty);
        expect(token.tags, hasLength(2));
        expect(token.toString(), isEmpty);
      });
    });
  });
}
