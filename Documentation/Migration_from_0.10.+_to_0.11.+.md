# Migration from v0.10.+ to v0.11.+

Weaver 0.11.0 comes with few breaking changes.

## New command line structure

Weaver command line structure changed quite a bit. It is now separated into two commands, as shown below.

```bash
$ weaver --help
Usage:

    $ weaver

Commands:

    + generate
    + export
```

The `generate` command is the same than the only command previously supported. It generates the boilerplate code.

```bash
$ weaver generate --help
Usage:

    $ weaver generate <input_paths>

Arguments:

    input_paths - Swift files to parse.

Options:
    --output_path [default: .] - Where the swift files will be generated.
    --template_path - Custom template path.
    --unsafe [default: false]
```

The `export` command is a new command which outputs the dependency graph as a JSON.

```bash
$ weaver export --help
Usage:

    $ weaver export <input_paths>

Arguments:

    input_paths - Swift files to parse.

Options:
    --pretty [default: false]
```

## Build phase

### With 0.10.+:

The command to add to the build phase looked like the following:

```bash
weaver --output_path ${SOURCE_ROOT}/output/path `find ${SOURCE_ROOT} -name '*.swift' | xargs -0`
```

### With 0.11.+:

The command `generate` should now be added to get it to work:

```bash
weaver generate --output_path ${SOURCE_ROOT}/output/path `find ${SOURCE_ROOT} -name '*.swift' | xargs -0`
```

## Replacement of the `customRef` annotation by the `builder` annotation

### With 0.10.+:

In the example below, in order to customize the way Weaver is building `AnotherDependency`, the `customRef` annotation
needs to be set to `true` and the `anotherDependencyCustomRef()` method needs to be implemented.

```swift
class ADependency {
  // weaver: anotherDependency = AnotherDependency
  // weaver: anotherDependency.customRef = true
}

extension ADependencyDependencyResolver {
  func anotherDependencyCustomRef() { ... }
}
```

### With 0.11.+:

As shown below, the `customRef` annotation is replaced by the `builder` annotation which is set to the custom builder function.
This builder function can be implemented anywhere, but needs to match the prototype `func typeBuilder(_ dependencies: TypeInputDependencyResolver) -> Type`.

```swift
class ADependency {
  // weaver: anotherDependency = AnotherDependency
  // weaver: anotherDependency.builder = AnotherDependency.make
}

class AnotherDependency {
  static func make(_ dependencies: AnotherDependencyInputDependencyResolver) -> AnotherDependency { ... }
}
```
