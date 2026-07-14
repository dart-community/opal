import 'package:meta/meta.dart';

import '../matcher.dart';
import 'ecma_script.dart';

@internal
final class JSGrammar extends EcmaScriptGrammar {
  const JSGrammar();

  @override
  List<Matcher> get matchers => [
    Matcher.include(comments),
    Matcher.include(strings),
    Matcher.include(javascriptKeywords),
    Matcher.include(literals),
    Matcher.include(privateIdentifiers),
    Matcher.include(operators),
    Matcher.include(identifiers),
  ];
}
