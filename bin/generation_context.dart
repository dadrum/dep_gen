import 'constructor_to_generate.dart';

/// Хранилище для всех данных, собранных во время анализа проекта.
class GenerationContext {
  GenerationContext();

  // Class name -> Class path
  final Map<String, String> allClassesPath = {};

  // custom name -> Package import statement (e.g., 'import 'package:foo/foo.dart' as foo;')
  final Map<String, String> foundedExternalPaths = {};
  final Map<String, String> usedExternalPaths = {};

  // User classes that need to be imported
  final Set<String> usedClasses = {};

  // User packages that must be imported (from --imported-packages option)
  final Set<String> importedPackages = {};

  // Founded package name from pubspec.yaml
  String packageName = '';

  // Class names that have the @DepGen annotation
  final List<String> possibleBuildersForClass = [];

  // Interface -> Implementation class name
  final Map<String, String> possibleImplementationForInterface = {};

  // List of constructors to generate
  final List<ConstructorToGenerate> constructorsToGenerate = [];
}
