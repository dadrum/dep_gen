// ignore_for_file: avoid_print

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:path/path.dart';

// =============================================================================
// Post - Processor
// =============================================================================

class PostProcessor {
  PostProcessor(this.generatedFile);
  final File generatedFile;

  Future<void> removeUnusedImports() async {
    print('🧹  Remove unused imports');

    final filePath = generatedFile.path;
    if (!generatedFile.existsSync()) {
      throw Exception('File not found: $filePath');
    }

    // Convert to absolute, normalized path
    final absoluteFilePath = normalize(absolute(filePath));

    // Root of the project (directory with pubspec.yaml)
    final rootPath = _findProjectRoot(absoluteFilePath);

    final collection = AnalysisContextCollection(includedPaths: [rootPath]);
    try {
      final context = collection.contextFor(absoluteFilePath);
      var removedCount = 0;

      while (true) {
        final result =
            await context.currentSession.getResolvedUnit(absoluteFilePath);
        if (result is! ResolvedUnitResult) {
          throw Exception('Failed to resolve: $absoluteFilePath');
        }

        final unresolvedImports = result.diagnostics.where((diagnostic) {
          final name = diagnostic.diagnosticCode.lowerCaseName;
          return name == 'uri_does_not_exist' ||
              name == 'uri_has_not_been_generated';
        }).where((diagnostic) => result.unit.directives
            .whereType<ImportDirective>()
            .any((directive) =>
                directive.offset <= diagnostic.offset &&
                diagnostic.offset < directive.end));
        if (unresolvedImports.isNotEmpty) {
          print('⚠️  Import cleanup stopped: some imports could not be '
              'resolved in $absoluteFilePath.');
          for (final diagnostic in unresolvedImports) {
            print('    ${diagnostic.message}');
          }
          break;
        }

        final importErrors = result.diagnostics.where((diagnostic) {
          final name = diagnostic.diagnosticCode.lowerCaseName;
          return name == 'unused_import' || name == 'unnecessary_import';
        });
        if (importErrors.isEmpty) {
          print('✅   Removed $removedCount unused or unnecessary import(s).');
          print('    Import diagnostics may be disabled in analysis options.');
          break;
        }

        final error = importErrors.first;
        final directives = result.unit.directives.whereType<ImportDirective>();
        final matching = directives.where(
          (directive) =>
              directive.offset <= error.offset && error.offset < directive.end,
        );
        if (matching.isEmpty) {
          throw StateError(
              'Import diagnostic at ${error.offset} does not match an import directive in $absoluteFilePath');
        }

        final directive = matching.first;
        final content = result.content;
        var start = directive.offset;
        var end = directive.end;
        final lineStart = content.lastIndexOf('\n', start - 1) + 1;
        final nextLine = content.indexOf('\n', end);
        final lineEnd = nextLine == -1 ? content.length : nextLine;
        final before = content.substring(lineStart, start);
        final after = content.substring(end, lineEnd);
        if (RegExp(r'^[ \t]*$').hasMatch(before) &&
            RegExp(r'^[ \t\r]*$').hasMatch(after)) {
          start = lineStart;
          end = nextLine == -1 ? lineEnd : nextLine + 1;
        }
        final updated = content.replaceRange(start, end, '');
        await generatedFile.writeAsString(updated);
        removedCount++;
        context.changeFile(absoluteFilePath);
        await context.applyPendingFileChanges();
      }
    } finally {
      await collection.dispose();
    }
  }

  /// Finds the nearest ancestor folder containing a pubspec.yaml.
  String _findProjectRoot(String filePath) {
    var dir = Directory(filePath).parent;
    while (dir.path != dir.parent.path) {
      if (File(join(dir.path, 'pubspec.yaml')).existsSync()) {
        return dir.path;
      }
      dir = dir.parent;
    }
    throw Exception('Could not find project root for $filePath');
  }

  /// Executes code formatting using the system command 'dart format'.
  Future<void> formatCode() async {
    print('✨   Running code formatting...');

    try {
      // Use Process.run to execute the external command asynchronously.
      // Allows finding 'dart' command in the system PATH
      final result = await Process.run(
        'dart',
        ['format', generatedFile.path],
        runInShell: true,
      );

      if (result.exitCode != 0) {
        // If formatting failed (e.g., due to a remaining syntax error)
        print('❌   Formatting failed for file ${generatedFile.path}:');
        print(result.stderr);
      } else {
        // The dart format command typically prints the list of formatted files to stdout.
        final output = result.stdout.toString().trim();
        if (output.isNotEmpty) {
          print('✅   Code successfully formatted.');
        } else {
          print('✅   Formatting completed (no changes needed).');
        }
      }
    } on ProcessException catch (e) {
      // Catch error if the 'dart' command itself could not be launched.
      print(
          '🚨   Could not execute the dart format command. Ensure Dart SDK is installed and in your PATH. Error: ${e.message}');
    } on Object catch (e) {
      // Catch any other unexpected errors during the process.
      print('🚨   An unexpected error occurred during formatting: $e');
    }
  }
}
