Dart package with basic support for tokenization and syntax highlighting of
various programming languages and data formats.

This package is currently experimental, untested, and
expected to change heavily.

## Installation

To use `package:opal` and access its language tokenization support,
first add it as a dependency in your `pubspec.yaml` file:

```shell
dart pub add opal
```

## Usage

The package contains one library:

- `package:opal/opal.dart`

### Supported languages

Currently the following languages are supported with
the specified default and alternative IDs:

- Dart (`dart`)
- Groovy (`groovy`, `gradle`)
- HTML (`html`)
- Java (`java`)
- JavaScript (`javascript`, `js`)
- JSON (`json`)
- Kotlin (`kotlin`, `kt`)
- Markdown (`markdown`, `md`)
- Objective-C (`objective-c`, `objectivec`, `obj-c`, `objc`)
- Swift (`swift`)
- Text (`text`, `plaintext`, `none`, `txt`)
- XML (`xml`, `xhtml`)
- YAML (`yaml`, `yml`)
