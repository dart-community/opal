import 'package:opal/opal.dart';
import 'package:test/test.dart' hide Tags;

void main() {
  group('Tag', () {
    group('constructor', () {
      test('creates tag without parent', () {
        const tag = Tag('test');
        expect(tag.id, equals('test'));
        expect(tag.parent, isNull);
      });

      test('creates tag with id and parent', () {
        const parent = Tag('parent');
        const tag = Tag('child', parent: parent);
        expect(tag.id, equals('child'));
        expect(tag.parent, equals(parent));
      });
    });

    group('expand', () {
      test('returns single tag when no parent', () {
        const tag = Tag('test');
        expect(tag.expand(), equals([tag]));
      });

      test('returns tag hierarchy with single parent', () {
        const parent = Tag('parent');
        const tag = Tag('child', parent: parent);
        expect(tag.expand(), equals([parent, tag]));
      });

      test('returns full tag hierarchy with multiple parents', () {
        const grandparent = Tag('grandparent');
        const parent = Tag('parent', parent: grandparent);
        const tag = Tag('child', parent: parent);
        expect(tag.expand(), equals([grandparent, parent, tag]));
      });

      test('returns deep tag hierarchy', () {
        const root = Tag('root');
        const level1 = Tag('level1', parent: root);
        const level2 = Tag('level2', parent: level1);
        const level3 = Tag('level3', parent: level2);
        const level4 = Tag('level4', parent: level3);

        expect(
          level4.expand(),
          equals([root, level1, level2, level3, level4]),
        );
      });
    });

    group('toString', () {
      test('returns id when no parent', () {
        const tag = Tag('test');
        expect(tag.toString(), equals('test'));
      });

      test('returns formatted string with single parent', () {
        const parent = Tag('parent');
        const tag = Tag('child', parent: parent);
        expect(tag.toString(), equals('parent-child'));
      });

      test('returns formatted string with multiple parents', () {
        const grandparent = Tag('grandparent');
        const parent = Tag('parent', parent: grandparent);
        const tag = Tag('child', parent: parent);
        expect(tag.toString(), equals('grandparent-parent-child'));
      });

      test('handles deep hierarchy correctly', () {
        const root = Tag('a');
        const level1 = Tag('b', parent: root);
        const level2 = Tag('c', parent: level1);
        const level3 = Tag('d', parent: level2);

        expect(level3.toString(), equals('a-b-c-d'));
      });

      test('handles special characters in ids', () {
        const parent = Tag('parent-with-dash');
        const tag = Tag('child_with_underscore', parent: parent);
        expect(
          tag.toString(),
          equals('parent-with-dash-child_with_underscore'),
        );
      });
    });

    group('equality', () {
      test('tags with same id and no parent are equal', () {
        const tag1 = Tag('test');
        const tag2 = Tag('test');
        expect(tag1, equals(tag2));
      });

      test('tags with different ids are not equal', () {
        const tag1 = Tag('test1');
        const tag2 = Tag('test2');
        expect(tag1, isNot(equals(tag2)));
      });

      test('tags with same id but different parents are not equal', () {
        const parent1 = Tag('parent1');
        const parent2 = Tag('parent2');
        const tag1 = Tag('child', parent: parent1);
        const tag2 = Tag('child', parent: parent2);
        expect(tag1, isNot(equals(tag2)));
      });

      test('tags with same id and same parent are equal', () {
        const parent = Tag('parent');
        const tag1 = Tag('child', parent: parent);
        const tag2 = Tag('child', parent: parent);
        expect(tag1, equals(tag2));
      });
    });

    group('edge cases', () {
      test('handles empty id', () {
        const tag = Tag('');
        expect(tag.id, equals(''));
        expect(tag.toString(), equals(''));
      });

      test('handles empty id with parent', () {
        const parent = Tag('parent');
        const tag = Tag('', parent: parent);
        expect(tag.toString(), equals('parent-'));
      });
    });
  });

  group('Tags', () {
    test('comment tags have correct hierarchy', () {
      expect(Tags.comment.id, equals('comment'));
      expect(Tags.comment.parent, isNull);

      expect(Tags.lineComment.id, equals('line'));
      expect(Tags.lineComment.parent, equals(Tags.comment));

      expect(Tags.blockComment.id, equals('block'));
      expect(Tags.blockComment.parent, equals(Tags.comment));

      expect(Tags.docComment.id, equals('doc'));
      expect(Tags.docComment.parent, equals(Tags.blockComment));

      expect(Tags.commentReference.id, equals('reference'));
      expect(Tags.commentReference.parent, equals(Tags.comment));
    });

    test('identifier tags have correct hierarchy', () {
      expect(Tags.identifier.id, equals('identifier'));
      expect(Tags.identifier.parent, isNull);

      expect(Tags.specialIdentifier.id, equals('special'));
      expect(Tags.specialIdentifier.parent, equals(Tags.identifier));

      expect(Tags.function.id, equals('function'));
      expect(Tags.function.parent, equals(Tags.identifier));

      expect(Tags.constructor.id, equals('constructor'));
      expect(Tags.constructor.parent, equals(Tags.function));

      expect(Tags.property.id, equals('property'));
      expect(Tags.property.parent, equals(Tags.identifier));

      expect(Tags.type.id, equals('type'));
      expect(Tags.type.parent, equals(Tags.identifier));

      expect(Tags.builtInType.id, equals('built-in'));
      expect(Tags.builtInType.parent, equals(Tags.type));

      expect(Tags.label.id, equals('label'));
      expect(Tags.label.parent, equals(Tags.identifier));

      expect(Tags.variable.id, equals('variable'));
      expect(Tags.variable.parent, equals(Tags.identifier));

      expect(Tags.parameter.id, equals('parameter'));
      expect(Tags.parameter.parent, equals(Tags.variable));
    });

    test('keyword tags have correct hierarchy', () {
      expect(Tags.keyword.id, equals('keyword'));
      expect(Tags.keyword.parent, isNull);

      expect(Tags.declarationKeyword.id, equals('declaration'));
      expect(Tags.declarationKeyword.parent, equals(Tags.keyword));

      expect(Tags.modifierKeyword.id, equals('modifier'));
      expect(Tags.modifierKeyword.parent, equals(Tags.keyword));

      expect(Tags.controlKeyword.id, equals('control'));
      expect(Tags.controlKeyword.parent, equals(Tags.keyword));

      expect(Tags.operator.id, equals('operator'));
      expect(Tags.operator.parent, equals(Tags.keyword));

      expect(Tags.customOperator.id, equals('custom'));
      expect(Tags.customOperator.parent, equals(Tags.operator));
    });

    test('literal tags have correct hierarchy', () {
      expect(Tags.literal.id, equals('literal'));
      expect(Tags.literal.parent, isNull);

      expect(Tags.booleanLiteral.id, equals('boolean'));
      expect(Tags.booleanLiteral.parent, equals(Tags.literal));

      expect(Tags.numberLiteral.id, equals('number'));
      expect(Tags.numberLiteral.parent, equals(Tags.literal));

      expect(Tags.integerLiteral.id, equals('integer'));
      expect(Tags.integerLiteral.parent, equals(Tags.numberLiteral));

      expect(Tags.floatLiteral.id, equals('float'));
      expect(Tags.floatLiteral.parent, equals(Tags.numberLiteral));

      expect(Tags.stringLiteral.id, equals('string'));
      expect(Tags.stringLiteral.parent, equals(Tags.literal));

      expect(Tags.collectionLiteral.id, equals('collection'));
      expect(Tags.collectionLiteral.parent, equals(Tags.literal));

      expect(Tags.arrayLiteral.id, equals('array'));
      expect(Tags.arrayLiteral.parent, equals(Tags.collectionLiteral));

      expect(Tags.mapLiteral.id, equals('map'));
      expect(Tags.mapLiteral.parent, equals(Tags.collectionLiteral));
    });

    test('string literal children tags have correct hierarchy', () {
      expect(Tags.regexpLiteral.id, equals('quoted'));
      expect(Tags.regexpLiteral.parent, equals(Tags.stringLiteral));

      expect(Tags.stringContent.id, equals('unquoted'));
      expect(Tags.stringContent.parent, equals(Tags.stringLiteral));

      expect(Tags.quotedString.id, equals('quoted'));
      expect(Tags.quotedString.parent, equals(Tags.stringLiteral));

      expect(Tags.singleQuoteString.id, equals('single'));
      expect(Tags.singleQuoteString.parent, equals(Tags.quotedString));

      expect(Tags.doubleQuoteString.id, equals('double'));
      expect(Tags.doubleQuoteString.parent, equals(Tags.quotedString));

      expect(Tags.tripleQuoteString.id, equals('triple'));
      expect(Tags.tripleQuoteString.parent, equals(Tags.quotedString));

      expect(Tags.unquotedString.id, equals('unquoted'));
      expect(Tags.unquotedString.parent, equals(Tags.stringLiteral));

      expect(Tags.characterLiteral.id, equals('character'));
      expect(Tags.characterLiteral.parent, equals(Tags.stringLiteral));

      expect(Tags.stringEscape.id, equals('escape'));
      expect(Tags.stringEscape.parent, equals(Tags.stringLiteral));

      expect(Tags.stringInterpolation.id, equals('interpolation'));
      expect(Tags.stringInterpolation.parent, equals(Tags.stringLiteral));
    });

    test('source tags have correct hierarchy', () {
      expect(Tags.source.id, equals('source'));
      expect(Tags.source.parent, isNull);

      expect(Tags.codeSource.id, equals('code'));
      expect(Tags.codeSource.parent, equals(Tags.source));

      expect(Tags.textualSource.id, equals('text'));
      expect(Tags.textualSource.parent, equals(Tags.source));

      expect(Tags.dataSource.id, equals('data'));
      expect(Tags.dataSource.parent, equals(Tags.textualSource));

      expect(Tags.markupSource.id, equals('markup'));
      expect(Tags.markupSource.parent, equals(Tags.textualSource));
    });

    test('other tags have correct values', () {
      expect(Tags.whitespace.id, equals('whitespace'));
      expect(Tags.whitespace.parent, isNull);

      expect(Tags.metadata.id, equals('metadata'));
      expect(Tags.metadata.parent, isNull);

      expect(Tags.annotation.id, equals('annotation'));
      expect(Tags.annotation.parent, equals(Tags.metadata));

      expect(Tags.preprocessor.id, equals('preprocessor'));
      expect(Tags.preprocessor.parent, equals(Tags.metadata));

      expect(Tags.punctuation.id, equals('punctuation'));
      expect(Tags.punctuation.parent, isNull);

      expect(Tags.separator.id, equals('separator'));
      expect(Tags.separator.parent, equals(Tags.punctuation));

      expect(Tags.accessor.id, equals('accessor'));
      expect(Tags.accessor.parent, equals(Tags.punctuation));

      expect(Tags.tag.id, equals('tag'));
      expect(Tags.tag.parent, isNull);

      expect(Tags.templateTag.id, equals('template'));
      expect(Tags.templateTag.parent, equals(Tags.tag));

      expect(Tags.invalid.id, equals('invalid'));
      expect(Tags.invalid.parent, isNull);

      expect(Tags.unknown.id, equals('unknown'));
      expect(Tags.unknown.parent, isNull);

      expect(Tags.markup.id, equals('markup'));
      expect(Tags.markup.parent, isNull);
    });

    test('tags expand correctly', () {
      expect(
        Tags.constructor.expand(),
        equals([
          Tags.identifier,
          Tags.function,
          Tags.constructor,
        ]),
      );

      expect(
        Tags.docComment.expand(),
        equals([
          Tags.comment,
          Tags.blockComment,
          Tags.docComment,
        ]),
      );

      expect(
        Tags.dataSource.expand(),
        equals([
          Tags.source,
          Tags.textualSource,
          Tags.dataSource,
        ]),
      );
    });
  });

  group('MarkupTags', () {
    test('basic markup tags have correct hierarchy', () {
      expect(MarkupTags.text.id, equals('text'));
      expect(MarkupTags.text.parent, equals(Tags.markup));

      expect(MarkupTags.link.id, equals('link'));
      expect(MarkupTags.link.parent, isNull);

      expect(MarkupTags.linkReference.id, equals('reference'));
      expect(MarkupTags.linkReference.parent, equals(MarkupTags.link));

      expect(MarkupTags.linkDefinition.id, equals('definition'));
      expect(MarkupTags.linkDefinition.parent, equals(MarkupTags.link));

      expect(MarkupTags.image.id, equals('image'));
      expect(MarkupTags.image.parent, equals(Tags.markup));
    });

    test('block tags have correct hierarchy', () {
      expect(MarkupTags.block.id, equals('block'));
      expect(MarkupTags.block.parent, equals(Tags.markup));

      expect(MarkupTags.codeBlock.id, equals('code'));
      expect(MarkupTags.codeBlock.parent, equals(MarkupTags.block));

      expect(MarkupTags.quoteBlock.id, equals('quote'));
      expect(MarkupTags.quoteBlock.parent, equals(MarkupTags.block));

      expect(MarkupTags.list.id, equals('list'));
      expect(MarkupTags.list.parent, equals(MarkupTags.block));

      expect(MarkupTags.unorderedList.id, equals('unordered'));
      expect(MarkupTags.unorderedList.parent, equals(MarkupTags.list));

      expect(MarkupTags.orderedList.id, equals('ordered'));
      expect(MarkupTags.orderedList.parent, equals(MarkupTags.list));
    });

    test('format tags have correct hierarchy', () {
      expect(MarkupTags.format.id, equals('format'));
      expect(MarkupTags.format.parent, equals(Tags.markup));

      expect(MarkupTags.code.id, equals('code'));
      expect(MarkupTags.code.parent, equals(MarkupTags.format));

      expect(MarkupTags.bold.id, equals('bold'));
      expect(MarkupTags.bold.parent, equals(MarkupTags.format));

      expect(MarkupTags.italic.id, equals('italic'));
      expect(MarkupTags.italic.parent, equals(MarkupTags.format));

      expect(MarkupTags.subscript.id, equals('subscript'));
      expect(MarkupTags.subscript.parent, equals(MarkupTags.format));

      expect(MarkupTags.superscript.id, equals('superscript'));
      expect(MarkupTags.superscript.parent, equals(MarkupTags.format));

      expect(MarkupTags.underline.id, equals('underline'));
      expect(MarkupTags.underline.parent, equals(MarkupTags.format));

      expect(MarkupTags.strikethrough.id, equals('strikethrough'));
      expect(MarkupTags.strikethrough.parent, equals(MarkupTags.format));

      expect(MarkupTags.diff.id, equals('diff'));
      expect(MarkupTags.diff.parent, equals(MarkupTags.format));

      expect(MarkupTags.inserted.id, equals('inserted'));
      expect(MarkupTags.inserted.parent, equals(MarkupTags.diff));

      expect(MarkupTags.removed.id, equals('removed'));
      expect(MarkupTags.removed.parent, equals(MarkupTags.diff));
    });

    test('other markup tags have correct values', () {
      expect(MarkupTags.heading.id, equals('heading'));
      expect(MarkupTags.heading.parent, equals(Tags.markup));

      expect(MarkupTags.table.id, equals('table'));
      expect(MarkupTags.table.parent, equals(Tags.markup));
    });

    test('markup tags expand correctly', () {
      expect(
        MarkupTags.text.expand(),
        equals([
          Tags.markup,
          MarkupTags.text,
        ]),
      );

      expect(
        MarkupTags.codeBlock.expand(),
        equals([
          Tags.markup,
          MarkupTags.block,
          MarkupTags.codeBlock,
        ]),
      );

      expect(
        MarkupTags.unorderedList.expand(),
        equals([
          Tags.markup,
          MarkupTags.block,
          MarkupTags.list,
          MarkupTags.unorderedList,
        ]),
      );

      expect(
        MarkupTags.inserted.expand(),
        equals([
          Tags.markup,
          MarkupTags.format,
          MarkupTags.diff,
          MarkupTags.inserted,
        ]),
      );
    });
  });
}
