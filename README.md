<!-- 
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages). 

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages). 
-->

Generates methods to create class instances with auto dependency injection.

## Features
This package lets you generate special methods which create instances of classes with automatic 
dependency injection. These methods will be helpful when constructing widgets and will avoid 
constantly specifying dependencies in certain classes. Basically, the package is aimed at replacing 
arguments having the type described in the same project.

## Installation

With Dart:
```shell
dart pub add dep_gen
```

With Flutter:

```shell
flutter pub add dep_gen
```

## Usage

**Step 1** Describe the map of available dependencies and how their communications.

```dart
class CartRepository {}

class UserRepository {}

class Environment {
  static Map<Type, Object> prepare() =>
      {
        CartRepository: CartRepository(),
        UserRepository: UserRepository(),
      };
}
```

**Step 2** Integrate *`Dependencies`* widget on top of other widgets. The code of that widget and
its type name will be generated afterwards.

```dart
class Example extends StatelessWidget {
  const Example({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dependencies(
      environment: Environment.prepare(),
      child: Application(),
    );
  }
}
```

**Step 3** Describe the class for whose constructors build methods will be generated.

*@DepGen()* is an annotation indicating which class to perform code generation for.

*@DepArg()* is an annotation indicating which arguments will be automatically substituted by the
code generator.

```dart
@DepGen()
class SomeBloc {
  SomeBloc({
    @DepArg() required this.cartRepository,
    @DepArg() required this.userRepository,
  });

  final CartRepository cartRepository;
  final UserRepository userRepository;
}
```

The *DepArg* annotation can only be used for named and optional constructor's arguments.

**Step 4**
Run code generator from project directory.

```shell
 flutter pub run dep_gen:generate -o Dependencies
```

By default, the generated class is called *Di*, it is generated in the *builder.dep_gen.dart* file
and is located in the *lib/generated* folder. But these parameters can be configured using command
line parameters. You can view the description of the settings by calling the code

```shell
 flutter pub run dep_gen:generate -h
```

**Step 4**
If there are no syntax errors, a file will be generated. This file will contain the constructor 
methods for all designated classes with auto-dependency injections.

You can use the resulting code as follows:

```dart
class Application extends StatelessWidget {
  const Application({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SomeBloc>(
      create: (context) => Dependencies.of(context).buildSomeBloc(),
      child: SomeBlocConsumer(),
    );
  }
}
```

## Arguments combination

You can combine positional, named, and optional arguments together with automatically substituted
arguments. For example, for a constructor that has this set of parameters:

```dart
@DepGen()
class UserDetails {
  const UserDetails(final int id,
      String? username, {
        @DepArg() required this.api,
        int? userGroup,
        @DepArg() required this.cartRepository,
        @DepArg() StoreRepository storeRepository,
      }) :_storeRepository = storeRepository;
  final Api api;
  final CartRepository cartRepository;
  final StoreRepository _storeRepository;
}
```

this build method will be generated:

```dart
class Application extends StatelessWidget {
  const Application({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SomeBloc>(
      create: (context) =>
          Dependencies.of(context).buildUserDetails(
            id, username, userGroup: userGroup,
          ),
      child: SomeBlocConsumer(),
    );
  }
}
```
