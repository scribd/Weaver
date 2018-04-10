# BeaverDI

`beaverdi` is a fully typesafe dependency injection framework for Swift based on annotated code.

## Features

- [x] Pure Swift support
- [ ] ObjC support
- [x] Dependency Container autogeneration
- [x] **Compile time type & graph safety, which means non optional resolution**!
- [x] Injection with arguments
- [x] Registration Scopes
- [x] Container hierarchy
- [ ] Thread safety

## Dependency Injection?

In software engineering, dependency injection is a technique whereby one object supplies the dependencies of another object. A dependency is an object that can be used (a service). An injection is the passing of a dependency to a dependent object (a client) that would use it.

This pattern is essential to keep a light coupling between objects. It makes unit testing a lot easier since a mock or a stub of a dependency can be very easily injected into the object being tested. The inversion of control also help making your code more modular and scalable.

`beaverdi` implements the dependency container pattern and generates the boiler plate code for you, which makes objects' initialisation easier and standardized over the codebase. It is also able to check at compile time if the dependency graph is valid, preventing any runtime crash to happen.

## How does it work?

Even though `beaverdi` generates the boiler plate code for you, it is important that you know what it does under the hood. There are two phases to be aware of ; compile time and run time.

### At compile time

```
                                                        |--> buildDependencyGraph() --> dependency graph --> validate() --> valid/invalid 
swift files --> scan() --> [Token] --> parse() --> AST -| 
                                                        |--> generateCode() --> source code 

```

The `beaverdi` command line tool scans the Swift sources of the project, looking for annotations and generates an AST (abstract syntax tree). 

This AST is then used to generate the dependency graph on which a bunch of safety checks are peformed in order to make sure the code won't crash at run time. It checks for unresolvable dependencies and unsolvable cyclic dependencies. If any issue is found, no code is being generated, meaning the project will fail to compile.

The same AST is also used to generate the boilerplate code. It generates one dependency container per class/struct with injectable dependencies. It also generates a bunch of extensions and protocols in order to make the dependency injection almost transparent for the developer.

### At run time

The `beaverdi` framework implements a lightweight dependency container class which allows you to register and resolve dependencies based on their scope, protocol or concrete type, name and parameters. Each container can have a parent, allowing to resolve dependencies throughout a containers hierarchy.

## Installation

`beaverdi` comes in 3 parts:
1. A Swift framework to include into your project
2. A command line tool to install on your machine
3. A build phase to your project

### (1) - BeaverDI framework installation

The `beaverdi` Swift framework is available with `CocoaPods`, `Carthage` and `Swift Package Manager`.

#### CocoaPods

Add `pod 'BeaverDI', '~> 0.9.0'` to your `Podfile`.

#### Carthage

Add `github "scribd/BeaverDI" ~> 0.9.0` to your `Cartfile`.

#### SwiftPM

Add `.package(url: "https://github.com/scribd/BeaverDI.git", from: "0.9.0")` to the dependencies section of your `Package.swift` file.

### (2) - BeaverDI command line tool installation

The `beaverdi` command line tool can be installed using `Homebrew` or manually.

#### Homebrew (coming soon)

`brew install BeaverDI`

#### Manually

```bash
$ git clone https://github.com/scribd/BeaverDI.git
$ cd BeaverDI
$ make install
$ beaverdi --help

Usage:

    $ beaverdi <input_paths>

Arguments:

    input_paths - Swift files to parse.

Options:
    --output_path [default: .] - Where the swift files will be generated.
    --template_path - Custom template path.
    --safe [default: true]
```

It will build and install the `beaverdi` command line tool in `/usr/local/bin`.

### (3) - BeaverDI build phase

In Xcode, add the following command to a command line build phase: 

```
beaverdi --output_path ${SOURCE_ROOT}/generated/files/directory/path ${SOURCE_ROOT}/**/*.swift
```

**Important - move your build phase above the `Compile Source` phase since `beaverdi` needs to check the dependency graph and generate the boilerplate code before compilation happens.**

**Warning - Using `--safe false` is not recommended. It will deactivate the graph validation, meaning the generated code could crash if the dependency graph is invalid.** Only set it to false if the graph validation prevents your project from compiling even though it should not. If you find yourself in that situation, please, feel free to file a bug.



#### Scope

The `scope` defines a dependency's access level and caching strategy. Four scopes are available:
- `transient`: Always creates a new instance when resolved. Can't be accessed from children.
- `graph`: A new instance is created when resolved the first time and then lives for the time the container lives. Can't be accessed from children.
- `weak`: A new instance is created when resolved the first time and then lives for the time its strong references are living. Accessible from children.
- `container`: Like graph, but accessible from children.
