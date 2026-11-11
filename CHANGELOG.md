## 1.2.2
### Changed
- Analyzer package dependency updated to support version ^14.0.0

## 1.2.0
### Added
- Detailed error reporting for code parsing issues
- Regeneration instructions added to the generated file header
- Code formatter integrated into the workflow
- Generator code completely refactored for improved performance
### Changed
- Analyzer package dependency updated to support version ^7.7.1

## 1.1.12

- Added automatic removal of unused imports in generated Dart file

## 1.1.11

- Added "-i" command line option to use external packages in the generation

## 1.1.10

- Added the 'useBuilders' parameter in the @DepArg annotation

## 1.1.9

- Updated versions of dependencies

## 1.1.8

- DepGenEnvironment is now available from DepProvider

## 1.1.7

- Updated versions of dependencies

## 1.1.6

- Updated versions of dependencies
 
## 1.1.5

- Fixed generator for a simple formal parameter

## 1.1.4

- Analyzer's version updated.

## 1.1.2

- Removed the "-c" command line option. Now the generated class is always called DepProvider.
- The generated code now contains the DepGenEnvironment class to describe the instances used in the
  environment.
- As settings, DepGen accepts an instance of the DepGenEnvironment class.
- Added extension for context DepGenContextExtension

## 1.0.15

- Collections with typed arguments import fix

## 1.0.14

- Dart 3.0
- Imports updated

## 1.0.12

- DepArg argument 'package' was added to use specific imports.

## 1.0.11

- Fixed a bug specific to windows platforms

## 1.0.10

- Imports updated

## 1.0.9

- Require analyzer 5.0.0

## 1.0.8

- Add logs, bug fix

## 1.0.6

- Code format, bug fix

## 1.0.0

- Initial release.
