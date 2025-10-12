import 'dart:io';

import 'dep_gen_options.dart';
import 'dep_gen.dart';

// =============================================================================
// MAIN ФУНКЦИЯ
// =============================================================================

void main(List<String> args) async {
  print('Starting DepGen');
  try {
    final options = DepGenOptions.parse(args);
    await DepGen(options).run();
  } on Object catch (e) {
    print('❌   Error: $e');
    exit(1);
  }
}