// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/syntactic_entity.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:yaml/yaml.dart';

import 'constructor_to_generate.dart';
import 'core.dart';
import 'dep_gen_options.dart';
import 'generation_context.dart';

// =============================================================================
// Project Analyzer
// =============================================================================

class ProjectAnalyzer {
  ProjectAnalyzer(this.context, this.options);

  final GenerationContext context;
  final DepGenOptions options;

  Future<void> analyzeProject() async {
    final current = Directory.current;
    print('🚀  Start project parsing from \'${current.path}\'');
    await _recursiveDirectory(current, true);
  }

  Future<void> _recursiveDirectory(Directory directory, bool isTop) async {
    List<FileSystemEntity> content = await _dirContents(directory);

    if (isTop) {
      late final String pathSeparator;
      try {
        pathSeparator = Platform.pathSeparator;
      } on Object {
        pathSeparator = '/';
      }

      content = content
          .where((element) =>
              element.path.endsWith('${pathSeparator}lib') ||
              element.path.endsWith('${pathSeparator}pubspec.yaml'))
          .toList();
    }

    for (final entity in content) {
      if (entity.path.contains('.git')) {
        continue;
      }

      if (entity is Directory) {
        await _recursiveDirectory(entity, false);
        continue;
      }
      if (entity is! File) {
        continue;
      }

      final String filePath = entity.path.toLowerCase();

      if (isTop && filePath.endsWith('pubspec.yaml')) {
        await _processPubspec(entity);
      }

      if (filePath.endsWith('.dep_gen.dart') || !filePath.endsWith('.dart')) {
        continue;
      }

      await _processDartFile(entity);
    }
  }

  Future<void> _processPubspec(File entity) async {
    final fileContent = await entity.readAsString();
    final result = loadYaml(fileContent);

    if (result is YamlMap) {
      final Iterable<Object?> dd = result.entries
          .where((element) => element.key == 'name')
          .map((e) => e.value);
      if (dd.isEmpty) {
        throw UnimplementedError(
            'package name not found in \'${entity.path}\'');
      }
      context.packageName = '${dd.first}';
    }
  }

  Future<List<FileSystemEntity>> _dirContents(Directory dir) async {
    final files = <FileSystemEntity>[];
    final completer = Completer<List<FileSystemEntity>>();
    dir.list(recursive: false).listen(
          files.add,
          onDone: () => completer.complete(files),
        );
    return completer.future;
  }

  Future<void> _processDartFile(File inFile) async {
    final fileContent = inFile.readAsStringSync();
    // disabling exception throwing
    final result = parseString(
        content: fileContent, path: inFile.path, throwIfDiagnostics: false);

    // ----------------------------------------------------
    // Syntax error handling
    if (result.errors.isNotEmpty) {
      print('💥  Syntax errors were found in the file: ${inFile.path}');
      for (final error in result.errors) {
        // We get the row and column by offset
        final lineInfo = result.lineInfo;
        final location = lineInfo.getLocation(error.offset);
        print(
            '    -> row: ${location.lineNumber}, column: ${location.columnNumber}');
        print('    [${error.diagnosticCode.lowerCaseName}] ${error.message}');
      }
      // The file contains syntax errors, so we stop working
      throw ArgumentError('Error in file analysis');
    }
    // ----------------------------------------------------

    // 1. Collect all declared imports for potential external package use
    for (final directive in result.unit.directives) {
      for (final e in directive.childEntities) {
        if (e.runtimeType.toString().contains('SimpleStringLiteral')) {
          context.foundedExternalPaths['$e'] = directive.toSource();
        }
      }
    }

    // 2. Add explicitly imported packages from options
    if (options.packagesToImport.isNotEmpty) {
      for (final directive in result.unit.directives) {
        final directiveString = '$directive';
        final contains = options.packagesToImport
            .any((e) => directiveString.contains('package:$e'));
        if (contains) {
          context.importedPackages.add(directiveString);
        }
      }
    }

    // 3. Save classes path of this dart file
    result.unit.declarations
        .map<Token?>(_getClassIdentifier)
        .where((element) => element != null)
        .map((e) => e?.lexeme)
        .where((element) => element != null)
        .forEach((lexeme) {
      context.allClassesPath[lexeme!] = inFile.path;
    });

    // 4. Select declarations with DepGen annotation
    final declarationsWithDepGenAnnotation = result.unit.declarations.where(
        (declaration) => declaration.metadata
            .where((annotation) => annotation.name.name == annotationDepGen)
            .isNotEmpty);

    for (final f in declarationsWithDepGenAnnotation) {
      // Find class name
      Iterable<SyntacticEntity> searchEntity = f.childEntities.where((e) =>
          e.runtimeType.toString().contains('NameWithTypeParametersImpl'));

      if (searchEntity.isEmpty) continue;

      final implClassName = searchEntity.first.toString();
      context.possibleBuildersForClass.add(implClassName);

      // ext
      searchEntity = f.childEntities.whereType<ExtendsClause>();
      if (searchEntity.isNotEmpty) {
        final name = searchEntity.first as ExtendsClause;
        context.possibleImplementationForInterface[name.superclass.toString()] =
            implClassName;
      }

      // impl
      searchEntity = f.childEntities.whereType<ImplementsClause>();

      if (searchEntity.isNotEmpty) {
        for (final impl
            in (searchEntity.first as ImplementsClause).interfaces) {
          context.possibleImplementationForInterface[impl.toString()] =
              implClassName;
        }
      }

      // For every class with declared constructors...
      final constructors = f.childEntities.whereType<BlockClassBody>();

      for (final constructor in constructors) {
        constructor.childEntities
            .whereType<ConstructorDeclaration>()
            .forEach((c) {
          context.constructorsToGenerate
              .add(ConstructorToGenerate(declaration: f, constructor: c));
        });
      }
    }
  }

  // get class identifier
  Token? _getClassIdentifier(CompilationUnitMember declaration) {
    final declarationIdentifiers =
        declaration.childEntities.whereType<NameWithTypeParameters>();
    if (declarationIdentifiers.isEmpty) {
      return null;
    }
    return declarationIdentifiers.first.typeName;
  }
}
