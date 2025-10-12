// ignore_for_file: avoid_print

import 'dart:io';

import 'dep_gen.dart';
import 'dep_gen_options.dart';

// =============================================================================
// MAIN
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
