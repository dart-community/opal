import 'dart:convert';

import 'package:opal/opal.dart';

void main() {
  final dart = BuiltInLanguages.dart;
  final tokens = dart.tokenize(
    const LineSplitter().convert('''
void main() {
  print('hi!');
}
'''),
  );

  print(tokens);
}
