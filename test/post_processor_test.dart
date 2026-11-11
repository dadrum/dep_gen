import 'dart:io';

import '../bin/post_processor.dart';

Future<void> main() async {
  final root = await Directory.systemTemp.createTemp('dep_gen_imports_');
  try {
    final lib = Directory('${root.path}/lib')..createSync();
    File('${root.path}/pubspec.yaml').writeAsStringSync('''
name: import_cleanup_fixture
environment:
  sdk: '>=3.3.0 <4.0.0'
''');
    File('${lib.path}/a.dart').writeAsStringSync('class A {}\n');
    File('${lib.path}/b.dart').writeAsStringSync('class B {}\n');
    File('${lib.path}/c.dart').writeAsStringSync('class C {}\n');
    File('${lib.path}/unused.dart').writeAsStringSync('class Unused {}\n');
    File('${lib.path}/barrel.dart')
        .writeAsStringSync("export 'a.dart';\nexport 'c.dart';\n");
    final generated = File('${lib.path}/generated.dart')..writeAsStringSync('''
// ignore_for_file: type=lint
import 'barrel.dart';
import
    'a.dart';
import 'unused.dart'; import 'b.dart' as b;

A makeA() => A();
C makeC() => C();
b.B makeB() => b.B();
''');

    final processor = PostProcessor(generated);
    await processor.removeUnusedImports();
    final actual = await generated.readAsString();
    _expect(!actual.contains("'a.dart'"),
        'Redundant import was not removed: $actual');
    _expect(!actual.contains("'unused.dart'"), 'Unused import was not removed');
    _expect(actual.contains("import 'barrel.dart';"), 'Barrel import was lost');
    _expect(
        actual.contains("import 'b.dart' as b;"), 'Prefixed import was lost');
    _expect(actual.contains("import 'barrel.dart';\n import 'b.dart' as b;"),
        'Removing a multiline import left an empty line');
    _expect(actual.contains('A makeA() => A();'), 'Generated code was changed');
    _expect(
        actual.contains('b.B makeB() => b.B();'), 'Generated code was changed');

    await processor.removeUnusedImports();
    _expect(
        await generated.readAsString() == actual, 'Cleanup is not idempotent');

    final lines = File('${lib.path}/lines.dart')..writeAsStringSync('''
import 'barrel.dart';
  import 'unused.dart';  
import 'b.dart' as b;
import 'unused.dart'; // Keep this comment.

A makeA() => A();
C makeC() => C();
b.B makeB() => b.B();
''');
    await PostProcessor(lines).removeUnusedImports();
    final linesContent = await lines.readAsString();
    _expect(
        linesContent.contains("import 'barrel.dart';\nimport 'b.dart' as b;"),
        'Removing an import left an empty line');
    _expect(linesContent.contains('// Keep this comment.'),
        'A trailing comment was removed');
    _expect(linesContent.contains('\n\nA makeA()'),
        'The separator before generated code was removed');

    final windowsLines = File('${lib.path}/windows_lines.dart')
      ..writeAsStringSync("import 'barrel.dart';\r\n"
          "import 'unused.dart';\r\n"
          "import 'b.dart' as b;\r\n\r\n"
          'A makeA() => A();\r\n'
          'C makeC() => C();\r\n'
          'b.B makeB() => b.B();\r\n');
    await PostProcessor(windowsLines).removeUnusedImports();
    final windowsContent = await windowsLines.readAsString();
    _expect(
        windowsContent
            .contains("import 'barrel.dart';\r\nimport 'b.dart' as b;"),
        'Removing an import left an empty CRLF line');

    final unresolved = File('${lib.path}/unresolved.dart')
      ..writeAsStringSync('''
import 'missing.dart';
import 'unused.dart';
''');
    final unresolvedContent = await unresolved.readAsString();
    await PostProcessor(unresolved).removeUnusedImports();
    _expect(await unresolved.readAsString() == unresolvedContent,
        'Imports were removed despite an unresolved import');
  } finally {
    await root.delete(recursive: true);
  }
}

void _expect(bool condition, String message) {
  if (!condition) throw StateError(message);
}
