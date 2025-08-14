import 'package:meta/meta.dart';

import '../language.dart';
import '../tag.dart';
import '../token.dart';

@internal
final class TextLanguage extends Language {
  const TextLanguage() : super('text');

  @override
  List<List<TaggedToken>> tokenize(List<String> content) => [
    for (final line in content)
      [
        TaggedToken(line, [Tags.textualSource]),
      ],
  ];
}
