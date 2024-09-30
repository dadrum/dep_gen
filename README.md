# DepGen

In short, this package allows you to implement dependency injection in a project.

## Features

This package lets you generate special methods which create instances of classes with automatic
substitution of dependencies from the environment. Looking ahead, we can immediately show what such
methods do:

Instead of specifying dependencies manually:

```dart
// Some example class with dependencies
class MyPet{
    MyPet({
        required String name,
        required IPetsRepository petsRepository,
        required IShopRepository shopRepository,
    }) {
        … some magic…
    }
}

void main() {
    …
    final pet = MyPet(
        name: 'Lucky',
        petsRepository: context.read<IPetsRepository>(),
        shopRepository: context.read<IShopRepository>(),
    );
    …
}
```

You won’t have to worry about delivering dependencies and just call a special method, specifying the
missing parameters (if any):

```dart
@DepGen()
class MyPet{
    MyPet({
        required String name,
        @DepArg() required IPetsRepository petsRepository,
        @DepArg() required IShopRepository shopRepository,
    }) {
        … some magic…
    }
}

void main() {
    …
    final pet = context.depGen().buildMyPet(name: 'Lucky');
    …
}
```

## How to start

Steps to get started

- Import the package
- Annotations placement
- Code generation
- Description of the environment
- Integration into widget hierarchy
- Using build methods

_Some of these steps are performed only once during the design phase, so using this package should
not cause any inconvenience_

### Import the package

With Dart:

```shell
dart pub add dep_gen
```

With Flutter:

```shell
flutter pub add dep_gen
```

### Annotations placement

To perform code generation, special annotations are used - **@DepGen** and **@DepArg**. The 
first (*DepGen*) annotation is used to indicate the class for which the build method will be 
created. The second annotation (*DepArg*) serves to indicate which dependencies need to be 
substituted automatically.

> 💡 Annotations in Dart are a way of adding metadata to code elements such as classes, methods, variables, and parameters. Annotations are used to provide additional information about the code element, such as its intended use, expected behavior, or implementation details.
> Dart annotations are represented using the '@' symbol followed by the name of the annotation.

Example code

```dart
@DepGen()
class MyPet{
    MyPet({
        required String name,
        @DepArg() required IPetsRepository petsRepository,
        @DepArg() required IShopRepository shopRepository,
    }) {
        … some magic…
    }
}
```

❗️ **Important. Only named parameters can be marked with this annotation**

This example uses two dependencies *petsRepository* and *shopRepository* to construct an instance of
the class. Let's mark them with a special *@DepArg* annotation so that we can generate a constructor
for an instance of this class without explicitly specifying these parameters. The class itself must
also be marked with the *@DepGen* annotation. That's all, we just added three words.

### Code generation

Run code generator from project directory.

```shell
 flutter pub run dep_gen:generate -p lib/domain/environment
```

On the command line, as a parameter, we specify the path to the file that will be generated:

**-p lib/domain/environment**

By default the generated file will be named:

**builders.dep_gen.dart**

> 💡 To convenience, the command to run code generation can be bound, since to create new or change old build methods you need to run it again (as is any case where code generation is used).

At this stage, everything is ready - we have generated code that allows us to describe the
environment and create instances of classes with automatic substitution of dependencies.

### Description of the environment

Those instances of classes that will be substituted as dependencies cannot come from nowhere. We
need to describe the so-called environment in which instances of these classes will be registered.
The file generated in the previous step contains the **DepGenEnvironment** class, which allows you to
register the necessary dependencies. For this he has a special method:

```dart
void registry<T>(Object instance)
```

If you need to lock your environment settings, there is a special method for this. It creates a new
instance of the environment.

```dart
DepGenEnvironment lock()
```

A simple way to describe the environment.

```dart
class Environment extends DepGenEnvironment {
  void prepare() {
    registry<IPetsRepository>(PetsRepository());
    registry<IShopRepository>(ShopRepository());
  }
}
```

> 💡 To keep the code clean, you can also extend the *DepGenEnvironment* class and place the entire implementation of the environment logic into it. There is a code example in the package description.

### Integration into widget hierarchy

To be able to use the generated methods using the context, you need to embed the DepProvider 
instance into the widget hierarchy.

```dart
void main() {
  final environment = Environment()..prepare();
  runApp(
    DepProvider(
      environment: environment.lock(),
      child: Application(),
    ),
  );
}
```

That's all, now you can use build methods to create class instances.

### Using build methods

To create instances of classes with injected dependencies, we need context. There are two ways:

```dart
final myPetLucky = DepProvider.of(context).buildMyPet(name: 'Lucky');
```

```dart
final myPetChester = context.depGen().buildMyPet(name: 'Lucky');
```

🔥 Congratulations, you have added dependency injection to your project.

### Example of parameter combination

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
}
```

This build method will be generated:

```dart
{
    DepProvider.of(context).buildUserDetails(
        id,
        username,
        userGroup: userGroup,
    )
}
```

Other parameters marked with a special annotation will be substituted automatically from the
environment.



