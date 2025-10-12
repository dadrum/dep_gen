import 'dart:io';

import 'package:args/args.dart';

/// Класс для хранения опций, переданных через аргументы командной строки.
/// В соответствии с вашими предпочтениями, используем @immutable.
class DepGenOptions {
  final String outputFile;
  final String outputPath;
  final Iterable<String> packagesToImport;

  const DepGenOptions({
    required this.outputFile,
    required this.outputPath,
    required this.packagesToImport,
  });

  static DepGenOptions parse(List<String> args) {
    if (args.length == 1 && (args[0] == '--help' || args[0] == '-h')) {
      _printHelperDisplay();
      exit(0);
    }

    String outputFile = 'builders.dep_gen.dart';
    String outputPath = 'lib/generated';
    Iterable<String> packagesToImport = const [];

    _generateArgParser(
          (o) => outputFile = o!,
          (p) => outputPath = p!,
          (i) => packagesToImport = i?.split(',') ?? const [],
    )

    .parse(args);

    return DepGenOptions(
      outputFile: outputFile,
      outputPath: outputPath,
      packagesToImport: packagesToImport,
    );
  }

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
