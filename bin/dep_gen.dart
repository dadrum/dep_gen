// ignore_for_file: avoid_print

import 'code_generator.dart';
import 'dep_gen_options.dart';
import 'generation_context.dart';
import 'post_processor.dart';
import 'project_analyzer.dart';

// =============================================================================
// THE MAIN CODEGENERATOR CLASS
// =============================================================================

class DepGen {
  DepGen(this.options) : context = GenerationContext();
  final DepGenOptions options;
  final GenerationContext context;

  Future<void> run() async {
    print('Handle lang files');
    print('Options: $options');

    // 1. Project analysis (collecting all data)
    final analyzer = ProjectAnalyzer(context, options);
    await analyzer.analyzeProject();

    // 2. Code generation
    final generator = CodeGenerator(context, options);
    final generatedFile = await generator.generateAndWrite();

    // 3. Post-processing (removing unused imports)
    final postProcessor = PostProcessor(generatedFile);
    await postProcessor.removeUnusedImports();

    // 4. Format code
    await postProcessor.formatCode();

    print('🏁  Completed');
  }
}
