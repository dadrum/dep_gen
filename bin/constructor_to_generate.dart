import 'package:analyzer/dart/ast/ast.dart';

/// Хранит информацию о конструкторе, который нужно сгенерировать.
class ConstructorToGenerate {
  final CompilationUnitMember declaration;
  final ConstructorDeclaration constructor;

  ConstructorToGenerate({required this.declaration, required this.constructor});
}