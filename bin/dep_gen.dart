import 'dep_gen_options.dart';
import 'generation_context.dart';
import 'project_analyzer.dart';
import 'code_generator.dart';
import 'post_processor.dart';

// =============================================================================
// ГЛАВНЫЙ КЛАСС КОДОГЕНЕРАТОРА
// =============================================================================

class DepGen {
  final DepGenOptions options;
  final GenerationContext context;

  DepGen(this.options) : context = GenerationContext();

  Future<void> run() async {
    print('Handle lang files');
    print('Options: $options');

    // 1. Анализ проекта (сбор всех данных)
    final analyzer = ProjectAnalyzer(context, options);
    await analyzer.analyzeProject();

    // 2. Генерация кода
    final generator = CodeGenerator(context, options);
    final generatedFile = await generator.generateAndWrite();

    // 3. Пост-процессинг (удаление неиспользуемых импортов)
    final postProcessor = PostProcessor(generatedFile);
    await postProcessor.removeUnusedImports();

    print('🏁  Completed');
  }
}