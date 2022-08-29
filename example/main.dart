import 'package:dep_gen/dep_gen.dart';
import 'package:flutter/material.dart';

// -----------------------------------------------------------------------------
class CartRepository {}

class UserRepository {}

// -----------------------------------------------------------------------------
@DepGen()
class Bloc {
  Bloc(
    int externalArgument, {
    @DepArg() required this.cartRepository,
    @DepArg() required this.userRepository,
  }) : _externalArgument = externalArgument;

  final int _externalArgument;
  final CartRepository cartRepository;
  final UserRepository userRepository;
}

// -----------------------------------------------------------------------------
class Environment {
  static Map<Type, Object> prepare() => {
        CartRepository: CartRepository(),
        UserRepository: UserRepository(),
      };
}

// -----------------------------------------------------------------------------
void main() {
  runApp(Dependencies(
    environment: Environment.prepare(),
    child: Application(),
  ));
}

class Application extends StatelessWidget {
  const Application({
    Key? key,
    required this.externalArgument,
  }) : super(key: key);

  final int externalArgument;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SomeBloc>(
      create: (context) => Dependencies.of(context).buildSomeBloc(
        externalArgument,
      ),
      child: SomeBlocConsumer(),
    );
  }
}
