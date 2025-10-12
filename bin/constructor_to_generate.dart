import 'package:analyzer/dart/ast/ast.dart';

/// Stores information about the constructor that needs to be generated.
class ConstructorToGenerate {
  ConstructorToGenerate({required this.declaration, required this.constructor});

  final CompilationUnitMember declaration;
  final ConstructorDeclaration constructor;
}
