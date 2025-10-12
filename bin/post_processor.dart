// ignore_for_file: avoid_print

import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
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

    // Create a full analysis context
    final collection = AnalysisContextCollection(includedPaths: [rootPath]);
    final context = collection.contextFor(absoluteFilePath);

    // Fully resolve the file (same as IDE)
    final result =
        await context.currentSession.getResolvedUnit(absoluteFilePath);
    if (result is! ResolvedUnitResult) {
      throw Exception('Failed to resolve: $absoluteFilePath');
    }
    // Collect unused/unnecessary import diagnostics
    final importErrors = result.errors.where((e) {
      final name = e.errorCode.name;
      return name == 'UNUSED_IMPORT' || name == 'UNNECESSARY_IMPORT';
    }).toList();

    if (importErrors.isEmpty) {
      print('✅  No unused imports found in ${generatedFile.path}');
      return;
    }

    final content = await generatedFile.readAsString();
    final lines = content.split('\n');
    final linesToRemove = <int>{};

    for (final error in importErrors) {
      final lineNumber = _getLineNumber(content, error.offset);
      linesToRemove.add(lineNumber);
    }

    // Remove import lines
    final filtered = [
      for (var i = 0; i < lines.length; i++)
        if (!linesToRemove.contains(i + 1)) lines[i],
    ].join('\n');

    await generatedFile.writeAsString(filtered);
    print('✅   Removed ${linesToRemove.length} unused import(s)');
  }

  /// Calculates the line number of a given character offset.
  int _getLineNumber(String content, int offset) {
    return '\n'.allMatches(content.substring(0, offset)).length + 1;
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
