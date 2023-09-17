import 'package:dep_gen/dep_gen.dart';
import 'package:flutter/material.dart';

// -----------------------------------------------------------------------------
// Some repositories whose implementations are not important for this example
class PetsRepository {}

class ShopRepository {}

// -----------------------------------------------------------------------------
// Example of a class whose constructor uses dependencies
//
// In the example, for simplicity, the Dependency Inversion
// Principle is ignored
@DepGen()
class MyPet {
  MyPet({
    required String name,
    @DepArg() required PetsRepository petsRepository,
    @DepArg() required PetsRepository shopRepository,
  }) {
    // … some magic …
  }
}

// -----------------------------------------------------------------------------
// The configuration of our environment, where all the services used
// for substitutions are prescribed
class Environment extends DepGenEnvironment {
  Environment prepare() {
    // registering a repository instance
    registry<PetsRepository>(PetsRepository());
    // registering a repository instance
    registry<PetsRepository>(PetsRepository());
    // blocking configuration from changing
    return this;
  }
}

// -----------------------------------------------------------------------------
// example of integration into the widget hierarchy
void main() {
  runApp(DepGen(
    // Prepare environment and lock it from changes
    environment: Environment().prepare().lock(),
    child: Application(),
  ));
}

// -----------------------------------------------------------------------------
// Example of using generated methods
class Application extends StatelessWidget {
  const Application({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // one of the options for creating an instance
    final myPetLucky = DepGen.of(context).buildMyPet(name: 'Lucky');

    // one of the options for creating an instance
    final myPetChester = context.depGen().buildMyPet(name: 'Lucky');

    return
    ...
    some
    beautiful
    widget
    ...;
  }
}
