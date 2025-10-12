// ignore_for_file: avoid_print

import 'dart:io';

import 'package:args/args.dart';

/// A class for storing options passed through command-line arguments.
class DepGenOptions {
  DepGenOptions({
    required this.commandLine,
    required this.outputFile,
    required this.outputPath,
    required this.packagesToImport,
  });

  DepGenOptions.parse(List<String> args) {
    if (args.length == 1 && (args[0] == '--help' || args[0] == '-h')) {
      _printHelperDisplay();
      exit(0);
    }

    String prepareOutputFile = 'builders.dep_gen.dart';
    String prepareOutputPath = 'lib/generated';
    Iterable<String> preparePackagesToImport = const [];

    _generateArgParser(
      (o) => prepareOutputFile = o!,
      (p) => prepareOutputPath = p!,
      (i) => preparePackagesToImport = i?.split(',') ?? const [],
    ).parse(args);

    outputFile = prepareOutputFile;
    outputPath = prepareOutputPath;
    packagesToImport = preparePackagesToImport;
    commandLine = args.join(' ');
  }

  late final String commandLine;
  late final String outputFile;
  late final String outputPath;
  late final Iterable<String> packagesToImport;

  static ArgParser _generateArgParser(
    void Function(String?) setOutputFile,
    void Function(String?) setOutputPath,
    void Function(String?) setPackagesToImport,
  ) {
    final parser = ArgParser()
      ..addOption('output-file',
          abbr: 'o',
          defaultsTo: 'builders.dep_gen.dart',
          callback: setOutputFile,
          help: 'Output file name')
      ..addOption('output-path',
          abbr: 'p',
          defaultsTo: 'lib/generated',
          callback: setOutputPath,
          help: 'Output file path]')
      ..addOption('imported-packages',
          abbr: 'i',
          defaultsTo: '',
          callback: setPackagesToImport,
          help: 'Array of packages to import');
    return parser;
  }

  static void _printHelperDisplay() {
    final parser = _generateArgParser((_) {}, (_) {}, (_) {});
    print(parser.usage);
  }

  @override
  String toString() {
    return 'outputFile: $outputFile outputPath: $outputPath packagesToImport: $packagesToImport';
  }
}
