/// An annotation for the `dep_deg` package.
///
/// Annotating a class for whose constructors it is necessary to generate
/// build methods by code generator
class DepGen {
  const DepGen();
}

/// An annotation for the `dep_deg` package.
///
/// Annotation of class constructor arguments. Determines which arguments
/// should be replaced with dependencies using a code generator
class DepArg {
  const DepArg({this.package});

  /// If parameter type is described in the external package;
  /// import 'package_name/package_name.dart' as xxx
  /// ...
  /// @DepArg(package: 'xxx')
  final String? package;
}
