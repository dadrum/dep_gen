// =============================================================================
// КОНСТАНТЫ И РАСШИРЕНИЯ
// =============================================================================

// Annotations
const String annotationDepGen = 'DepGen';
const String annotationDepArg = 'DepArg';
// Keywords
const String argumentForDepArgUseBuilders = 'useBuilders';
const String argumentForDepArgPackage = 'package';

/// Вспомогательное расширение для Iterable
extension IterableModifier<E> on Iterable<E> {
  E? firstWhereOrNull(bool Function(E) test) =>
      cast<E?>().firstWhere((v) => v != null && test(v), orElse: () => null);
}