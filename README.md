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

**Very important ; move your build phase above the `Compile Source` phase since `beaverdi` needs to check the dependency graph and generate the boilerplate code before compilation happens.**