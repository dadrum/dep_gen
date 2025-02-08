import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:yaml/yaml.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:path/path.dart' as path;

// annotations
final String annotationDepGen = 'DepGen';
final String annotationDepArg = 'DepArg';
// keywords
final String argumentForDepArgPackage = 'package';

// Class name -> Class path
Map<String, String> allClassesPath = {};

// custom name -> Package path
Map<String, String> foundedExternalPaths = {};
Map<String, String> usedExternalPaths = {};

// User classes
Set<String> usedClasses = {};

// Founded package name
String packageName = '';

extension IterableModifier<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) =>
      cast<E?>().firstWhere((v) => v != null && test(v), orElse: () => null);
}

void main(List<String> args) {
  print('Starting DepGen');
  if (_isHelpCommand(args)) {
    _printHelperDisplay();
  } else {
    handleLangFiles(_generateOption(args));
  }
}

bool _isHelpCommand(List<String> args) {
  return args.length == 1 && (args[0] == '--help' || args[0] == '-h');
}

void _printHelperDisplay() {
  var parser = _generateArgParser(null);
  print(parser.usage);
}

// -----------------------------------------------------------------------------
GenerateOptions _generateOption(List<String> args) {
  var generateOptions = GenerateOptions();
  var parser = _generateArgParser(generateOptions);
  parser.parse(args);
  return generateOptions;
}

// -----------------------------------------------------------------------------
ArgParser _generateArgParser(GenerateOptions? generateOptions) {
  var parser = ArgParser();

  parser.addOption('output-file',
      abbr: 'o',
      defaultsTo: 'builders.dep_gen.dart',
      callback: (String? x) => generateOptions!.outputFile = x,
      help: 'Output file name');

  parser.addOption('output-path',
      abbr: 'p',
      defaultsTo: 'lib/generated',
      callback: (String? x) => generateOptions!.outputPath = x,
      help: 'Output file path]');
  return parser;
}

// -----------------------------------------------------------------------------
class GenerateOptions {
  String? outputFile;
  String? outputPath;

  @override
  String toString() {
    return 'outputFile: $outputFile outputPath: $outputPath';
  }
}

// -----------------------------------------------------------------------------
void handleLangFiles(GenerateOptions options) async {
  print('Handle lang files');
  // prepare output file
  final current = Directory.current;
  final output = Directory.fromUri(Uri.parse(options.outputPath!));
  final outputPath = Directory(path.join(output.path, options.outputFile));
  var generatedFile = File(outputPath.path);
  if (!generatedFile.existsSync()) {
    generatedFile.createSync(recursive: true);
  } else {
    generatedFile.deleteSync();
    generatedFile.createSync(recursive: true);
  }
  print('  .. generated file = $generatedFile');
  // prepare string builder for parse
  StringBuffer outBuffer = StringBuffer();

  // write common file header
  writeHeader(outBuffer);

  // recursive directory parse and write data to outBuffer
  print('  .. start project parsing from \'$current\'');
  await recursiveDirectory(current, outBuffer, true);

  // write common file footer
  writeFooter(outBuffer);

  // open sink to write file
  IOSink outputSink = generatedFile.openWrite();

  // write widgets import to file
  outputSink.write("""
// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: type=lint
// coverage:ignore-start

import 'dart:collection';

import 'package:flutter/widgets.dart';

// **************************************************************************
// DepGen code generator
// **************************************************************************

""");

  // remove nullable signs
  usedClasses = usedClasses.map((e) => e.replaceAll('?', '')).toSet();

  // remove all unused classes
  print('  .. remove all unused classes');

  final int currentPathLength = current.path.length;
  allClassesPath.removeWhere((key, value) {
    return !usedClasses.contains(key);
  });

  // write used packages
  usedExternalPaths.forEach((key, value) => outputSink.write('$value\n'));
  late final String pathSeparator;
  try {
    pathSeparator = Platform.pathSeparator;
  } on Object {
    pathSeparator = '/';
  }

  // convert all import files to package dependencies
  Set<String> usedPaths = allClassesPath.entries
      .map((e) => e.value.substring(currentPathLength))
      .map((e) =>
          '${e.replaceFirst('${pathSeparator}lib$pathSeparator', 'import \'package:$packageName/')}\';')
      .map((e) => e.replaceAll(Platform.pathSeparator, '/'))
      .toSet();

  // write dependencies to file
  for (var value in usedPaths) {
    outputSink.write('$value\n');
  }

  // write to file all generated build methods
  outputSink.write('\n');
  outputSink.write(outBuffer.toString());
  print('  .. write to file completed');

  outputSink.write("""
  
// coverage:ignore-end
  """);
  outputSink.close();
}

// -----------------------------------------------------------------------------
Future<void> recursiveDirectory(
    Directory directory, StringBuffer outputSink, bool isTop) async {
  List<FileSystemEntity> content = await (dirContents(directory));

  if (isTop) {
    late final String pathSeparator;
    try {
      pathSeparator = Platform.pathSeparator;
    } on Object {
      pathSeparator = '/';
    }

    content = content
        .where((element) => (element.path.endsWith('${pathSeparator}lib') ||
            element.path.endsWith('${pathSeparator}pubspec.yaml')))
        .toList();
  }

  for (final entity in content) {
    if (entity.path.contains('.git')) {
      continue;
    }

    if (entity is Directory) {
      await recursiveDirectory(entity, outputSink, false);
      continue;
    }
    if (entity is! File) {
      continue;
    }

    final String filePath = entity.path.toLowerCase();

    if (isTop && filePath.endsWith('pubspec.yaml')) {
      final fileContent = await entity.readAsString();
      final result = loadYaml(fileContent);

      if (result is YamlMap) {
        Iterable<Object?> dd = result.entries
            .where((element) => element.key == 'name')
            .map((e) => e.value);
        if (dd.isEmpty) {
          throw UnimplementedError(
              'package name not found in \'${entity.path}\'');
        }
        packageName = '${dd.first}';
      }
    }

    if (filePath.endsWith('.dep_gen.dart') || !filePath.endsWith('.dart')) {
      continue;
    }

    await processDartFile(entity, outputSink);
  }
}

// -----------------------------------------------------------------------------
Future<List<FileSystemEntity>> dirContents(Directory dir) async {
  var files = <FileSystemEntity>[];
  var completer = Completer<List<FileSystemEntity>>();
  var lister = dir.list(recursive: false);
  lister.listen(
    (file) => files.add(file),
    onDone: () => completer.complete(files),
  );
  return await completer.future;
}

// -----------------------------------------------------------------------------
Future<void> processDartFile(File inFile, StringBuffer outputSink) async {
  final fileContent = inFile.readAsStringSync();

  final result = parseString(content: fileContent);

  // add declared
  for (var directive in result.unit.directives) {
    for (var e in directive.childEntities) {
      if (e.runtimeType.toString().contains('SimpleIdentifierImpl')) {
        foundedExternalPaths['$e'] = directive.toSource();
      }
    }
  }

  // save classes path of this dart file
  result.unit.declarations
      .map<Token?>((declaration) => getClassIdentifier(declaration))
      .where((element) => element != null)
      .map((e) => e?.lexeme)
      .where((element) => element != null)
      .forEach((lexeme) {
    allClassesPath[lexeme!] = inFile.path;
  });

  // select declarations with DepGen annotation
  final declarationsWithDepGenAnnotation = result.unit.declarations.where(
      (declaration) => declaration.metadata
          .where((annotation) => annotation.name.name == annotationDepGen)
          .isNotEmpty);

  // for every class with declared constructors...
  for (final declaration in declarationsWithDepGenAnnotation) {
    final constructors =
        declaration.childEntities.whereType<ConstructorDeclaration>();

    for (final constructor in constructors) {
      await writeConstructorsMethod(declaration, constructor, outputSink);
    }
  }
}

// -----------------------------------------------------------------------------
// generate build method for each class constructor
Future<void> writeConstructorsMethod(
  CompilationUnitMember declaration,
  ConstructorDeclaration constructor,
  StringBuffer outputSink,
) async {
  //
  // ********************
  // parse and prepare constructor's name
  String constructorName = constructor.name?.lexeme ?? '';

  String constructorCall =
      (constructorName.isNotEmpty) ? '.$constructorName' : '';
  if (constructorName.isNotEmpty) {
    constructorName = constructorName.replaceRange(
        0, 1, constructorName.substring(0, 1).toUpperCase());
  }

  //
  // ********************
  // skip private constructors
  if (constructorName.startsWith('_')) {
    return;
  }

  //
  // ********************
  // get class identifier
  final Token? classIdentifier = getClassIdentifier(declaration);
  if (classIdentifier == null) {
    return;
  }

  // save used class
  usedClasses.add(classIdentifier.lexeme);

  // write header of build method
  outputSink.write("""\n
  // ---------------------------------------------------------------------------
  $classIdentifier build$classIdentifier$constructorName(""");

  // string builders for in and out arguments
  StringBuffer inArgs = StringBuffer();
  StringBuffer inNamedArgs = StringBuffer();
  StringBuffer inPositionalArgs = StringBuffer();
  StringBuffer outArgs = StringBuffer();
  StringBuffer outNamedArgs = StringBuffer();

  // bypassing all constructor's parameters
  for (final param in constructor.parameters.parameters) {
    if (param is SimpleFormalParameter) {
      // simple parameter:
      //     final int k,
      inArgs.write('\n    $param, ');
      outArgs.write('\n      ${param.name}, ');

      final namedTypes = param.childEntities.whereType<NamedType>();
      if (namedTypes.isNotEmpty) {
        // parse type arguments
        // Abs<X>, Abs<X,Y>
        for (var namedType in namedTypes) {
          final childEntities = namedType.typeArguments?.childEntities;
          childEntities?.forEach((element) {
            if (element is NamedType) {
              usedClasses.add(element.name2.lexeme);
            }
          });
        }

        final String type = '${namedTypes.first.name2}';
        usedClasses.add(type);
      }
    } else if (param is FieldFormalParameter) {
      final String? type = getPropertyType(declaration, '${param.name}');
      inArgs.write('\n    ');
      if (param.keyword != null) {
        inArgs.write('${param.keyword} ');
      }
      inArgs.write('$type ${param.name}, ');
      outArgs.write('\n      ${param.name}, ');

      final namedTypes = param.childEntities.whereType<NamedType>();
      if (namedTypes.isNotEmpty) {
        final String type = '${namedTypes.first.name2}';
        usedClasses.add(type);
      }
    } else if (param is DefaultFormalParameter) {
      /*
            required String ssss,
            @DepArg() required bool testBool,
            @DepArg() required this.storeRepository,
            int kk = 7,
            int? jj,
      * */
      if (param.metadata
          .where((annotation) => annotation.name.name == annotationDepArg)
          .isNotEmpty) {
        // annotationDepArg
        // find external package argument in DepArg
        final argument = param.parameter.metadata
            .firstWhereOrNull((e) => true)
            ?.arguments
            ?.childEntities
            .whereType<NamedExpression>()
            .firstWhereOrNull(
                (e) => e.beginToken.lexeme == argumentForDepArgPackage);
        String? declaredPackageName;
        if (argument != null) {
          // add founded package import to used imports list
          foundedExternalPaths.entries.where((e) {
            declaredPackageName = argument.endToken.lexeme
                .replaceAll('\'', '')
                .replaceAll('"', '');
            return e.key == declaredPackageName;
          }).forEach((e) => usedExternalPaths.addEntries([e]));
        }
        if (declaredPackageName != null) {
          declaredPackageName = '$declaredPackageName.';
        } else {
          declaredPackageName = '';
        }

        // param has DepArg annotation
        if (param.childEntities.first is SimpleFormalParameter) {
          final paramName =
              (param.childEntities.first as SimpleFormalParameter).name;
          final namedTypes =
              param.parameter.childEntities.whereType<NamedType>();
          if (namedTypes.isNotEmpty) {
            String type = '${namedTypes.first.name2}';
            type.replaceAll('?', '');

            if ((declaredPackageName?.isNotEmpty ?? false) &&
                type.startsWith(declaredPackageName!)) {
              type = type.replaceFirst(declaredPackageName!, '');
            }

            if (param.isNamed) {
              // if (param.isOptional) {
              outArgs.write(
                  "\n      $paramName: _env.g<$declaredPackageName$type>(),");
              // "\n      $paramName: _env.mayBeGet<$declaredPackageName$type>(),");
              // } else {
              //   outArgs.write("\n      _env.g<$declaredPackageName$type>(),");
              // }
            } else {
              outArgs
                  .write("\n      _env.mayBeGet<$declaredPackageName$type>(),");
            }
            usedClasses.add(type);
          }
        } else if (param.childEntities.first is FieldFormalParameter) {
          final paramName =
              (param.childEntities.first as FieldFormalParameter).name;
          String? type = getPropertyType(declaration, '$paramName');

          if (type != null) {
            type = type.replaceAll('?', '');

            if ((declaredPackageName?.isNotEmpty ?? false) &&
                type.startsWith(declaredPackageName!)) {
              type = type.replaceFirst(declaredPackageName!, '');
            }

            if (param.isOptional) {
              if (param.isNamed) {
                outArgs.write(
                    "\n      $paramName: _env.mayBeGet<$declaredPackageName$type>(),");
              } else {
                outArgs.write(
                    "\n      _env.mayBeGet<$declaredPackageName$type>(),");
              }
            } else {
              outArgs.write(
                  "\n      $paramName: _env.g<$declaredPackageName$type>(),");
            }
            usedClasses.add(type);
          }
        }
      } else {
        if (param.childEntities.first is SimpleFormalParameter) {
          final paramName =
              (param.childEntities.first as SimpleFormalParameter).name;
          final namedTypes =
              param.parameter.childEntities.whereType<NamedType>();

          if (namedTypes.isNotEmpty) {
            // parse type arguments
            // Abs<X>, Abs<X,Y>
            for (var namedType in namedTypes) {
              final childEntities = namedType.typeArguments?.childEntities;
              childEntities?.forEach((element) {
                if (element is NamedType) {
                  usedClasses.add(element.name2.lexeme);
                }
              });
            }

            final String type = '${namedTypes.first.name2}';
            usedClasses.add(type);
            if (param.isNamed) {
              inNamedArgs.write('\n      $param, ');
              outArgs.write("\n      $paramName: $paramName,");
            } else {
              inPositionalArgs.write('\n      $param, ');
              outNamedArgs.write("\n      $paramName,");
            }
          }
        } else if (param.childEntities.first is FieldFormalParameter) {
          final paramName =
              (param.childEntities.first as FieldFormalParameter).name;
          final String? type = getPropertyType(declaration, '$paramName');
          if (type != null) {
            usedClasses.add(type);

            if (param.isNamed) {
              inNamedArgs.write('\n      ');
              if (param.isRequired) {
                inNamedArgs.write(' required ');
              }
              inNamedArgs.write('$type $paramName, ');
              outArgs.write("\n      $paramName: $paramName,");
            } else {
              inPositionalArgs.write('\n      ');
              if (param.isRequired) {
                inPositionalArgs.write(' required ');
              }
              inPositionalArgs.write('$type $paramName, ');
              outNamedArgs.write("\n      $paramName,");
            }
          }
        }
      }
    }
  }

  // write input positioned arguments
  outputSink.write(inArgs.toString());

  if (inNamedArgs.isNotEmpty) {
    // write input named arguments
    outputSink.write('{');
    outputSink.write(inNamedArgs.toString());
    outputSink.write('\n    }');
  } else if (inPositionalArgs.isNotEmpty) {
    // write input optional arguments
    outputSink.write('[');
    outputSink.write(inPositionalArgs.toString());
    outputSink.write('\n    ]');
  } else {
    outputSink.write('\n  ');
  }

  // write code between input and output arguments
  outputSink.write(') => $classIdentifier$constructorCall(');
  // write output positional arguments
  outputSink.write(outArgs.toString());

  // write output named arguments
  if (outNamedArgs.isNotEmpty) {
    outputSink.write(outNamedArgs.toString());
  }

  // close of method definition
  outputSink.write("\n    );\n");
}

// -----------------------------------------------------------------------------
void writeHeader(StringBuffer outputSink) {
  outputSink.write("""

/// The environment in which all used dependency instances are configured
@immutable
class DepGenEnvironment {
  DepGenEnvironment({Map<Type, Object>? initialServices})
      : _environment = initialServices ?? {};

  late final Map<Type, Object> _environment;

  // ---------------------------------------------------------------------------
  /// An unsafe method for getting an instance by its type. You need to be sure
  /// that an instance of the requested type has been registered
  T g<T>() => _environment[T] as T;

  // ---------------------------------------------------------------------------
  /// A safe method for trying to get an instance by its type.
  T? mayBeGet<T>() => _environment.containsKey(T) ? _environment[T] as T : null;

  // ---------------------------------------------------------------------------
  /// Registration of an instance with an indication of its type. You cannot
  /// register multiple instances of the same type
  void registry<T>(Object instance) => _environment[T] = instance;

  // ---------------------------------------------------------------------------
  /// Is the collection of instances blocked
  bool get isLocked => _environment is UnmodifiableMapView;

  // ---------------------------------------------------------------------------
  /// Returns an instance of the environment settings with the collection
  /// blocked from changes
  DepGenEnvironment lock() {
    return DepGenEnvironment(initialServices: Map.unmodifiable(_environment));
  }
}

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
extension DepProviderContextExtension on BuildContext {
  /// Obtain a value from the nearest ancestor DepProvider.
  DepProvider depGen() => DepProvider.of(this);
}
  
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
class DepProvider extends InheritedWidget {
  const DepProvider({
    Key? key,
    required Widget child,
    required DepGenEnvironment environment,
  })  : _env = environment,
        super(key: key, child: child);
        
  // --------------------------------------------------------------------------- 
  /// A pre-configured environment containing the dependencies used 
  final DepGenEnvironment _env;

  // ---------------------------------------------------------------------------
  static DepProvider of(BuildContext context) {
    final DepProvider? dp = context.findAncestorWidgetOfExactType<DepProvider>();
    if (dp == null) {
      throw UnimplementedError('DepProvider is not initialized in context');
    }
    return dp;
  }

  // ---------------------------------------------------------------------------
  @override
  bool updateShouldNotify(DepProvider oldWidget) {
    return false;
  }

  // ---------------------------------------------------------------------------
  /// An unsafe method for getting an instance by its type. You need to be sure
  /// that an instance of the requested type has been registered
  T g<T>() => _env.g<T>();

  // ---------------------------------------------------------------------------
  /// A safe method for trying to get an instance by its type.
  T? mayBeGet<T>() => _env.mayBeGet<T>();

  """);
}

// -----------------------------------------------------------------------------
void writeFooter(StringBuffer outputSink) {
  outputSink.write('\n}');
}

// -----------------------------------------------------------------------------
// get class identifier
Token? getClassIdentifier(CompilationUnitMember declaration) {
  final declarationIdentifiers = declaration.childEntities
      .whereType<Token>()
      .where((token) => token.type == TokenType.IDENTIFIER);
  // if identifier is not found
  if (declarationIdentifiers.isEmpty) {
    return null;
  }
  return (declarationIdentifiers.first);
}

// -----------------------------------------------------------------------------
// find type of class property
String? getPropertyType(
    CompilationUnitMember declaration, String propertyName) {
  final fieldsDeclaration =
      declaration.childEntities.whereType<FieldDeclaration>();
  for (final field in fieldsDeclaration) {
    final declarations =
        field.childEntities.whereType<VariableDeclarationList>();
    if (declarations.isEmpty) {
      continue;
    }

    if (declarations.first.variables
        .where((element) => '${element.name}' == propertyName)
        .isNotEmpty) {
      return '${declarations.first.type}';
    }
  }
  return null;
}
