<p align="center">
  <img src="./weaver.png" width=520>
</p>

<p align="center">Painless dependency injection framework for Swift (iOS/macOS/Linux)</p>

[![Build Status](https://travis-ci.com/scribd/Weaver.svg?branch=master)](https://travis-ci.com/scribd/Weaver)

## Features

- [x] Dependency declaration via annotations
- [x] DI Container generation
- [x] Dependency Graph compile time validation
- [x] ObjC Support
- [x] Non-optional dependency resolution
- [x] Type safety
- [x] Injection with arguments
- [x] Registration Scopes
- [x] DI Container hierarchy

## Dependency Injection

Dependency Injection basically means "giving an object its instance variables" [¹](#more-reading). It seems like it's not such a big deal, but as soon as a project gets bigger, it gets tricky. Initializers become too complex, passing down dependencies through several layers becomes time consuming and just figuring out where to get a dependency from can be hard enough to give up and finally use a singleton.

However, Dependency Injection is a fundamental aspect of software architecture, and there is no good reason not to do it properly. That's where Weaver can help.

## What is Weaver?

Weaver is a declarative, easy-to-use and safe Dependency Injection framework for Swift.

- **Declarative** because it allows to **declare dependencies via annotations** directly in the Swift code.
- **Easy-to-use** because it **generates the necessary boilerplate code** to inject dependencies into Swift types.
- **Safe** because it **validates the dependency graph at compile time** and outputs a nice Xcode error when something's wrong.

## How does Weaver work?

Even though Weaver makes dependency injection work out of the box, it's important to know what it does under the hood. There are two phases to be aware of; compile time and run time.

### At compile time

```
                                                    |-> link() -> dependency graph -> validate() -> valid/invalid 
swift files -> scan() -> [Token] -> parse() -> AST -| 
                                                    |-> generate() -> source code 

```

Weaver's command line tool scans the Swift sources of the project, looking for annotations, and generates an AST (abstract syntax tree). It uses [SourceKitten](https://github.com/jpsim/SourceKitten) which is backed by Apple's [SourceKit](https://github.com/apple/swift/tree/master/tools/SourceKit), making this step pretty reliable.

This AST is then used to generate a dependency graph on which a bunch of safety checks are peformed in order to make sure the code won't crash at run time. It checks for unresolvable dependencies and unsolvable cyclic dependencies. If any issue is found, no code is being generated, which means that the project will fail to compile.

The same AST is also used to generate the boilerplate code. It generates one dependency container per class/struct with injectable dependencies. It also generates a bunch of extensions and protocols in order to make the dependency injection almost transparent for the developer.

### At run time

Weaver implements a lightweight DI Container object which is able to register and resolve dependencies based on their scope, protocol or concrete type, name and parameters. Each container can have a parent, allowing to resolve dependencies throughout a hierarchy of containers.

When an object registers a dependency, its associated DI Container stores a builder (and sometimes an instance). When another object declares a reference to this same dependency, its associated DI Container declares an accessor, which tries to resolve the dependency. Resolving a dependency basically means to look for a builder/instance while backtracking the hierarchy of containers. If no dependency is found or if this process gets trapped into an infinite recursion, it will crash at runtime, which is why checking the dependency graph at compile time is extremely important.

## Installation

Weaver comes in 3 parts:
1. A Swift framework to include into your project
2. A command line tool to install on your machine
3. A build phase to add to your project

### (1) - Weaver framework installation

Weaver's Swift framework is available with `CocoaPods`, `Carthage` and `Swift Package Manager`.

#### CocoaPods

Add `pod 'Weaver', :git => 'git@github.com:scribd/Weaver.git', :tag => '0.9.0'` to the `Podfile`.

#### Carthage

Add `github "scribd/Weaver" ~> 0.9.0` to the `Cartfile`.

#### SwiftPM

Add `.package(url: "https://github.com/scribd/Weaver.git", from: "0.9.0")` to the dependencies section of the `Package.swift` file.

### (2) - Weaver command line tool installation

The Weaver command line tool can be installed using `Homebrew` or manually.

#### Homebrew (coming soon)

`brew install Weaver`

#### Manually

```bash
$ git clone https://github.com/scribd/Weaver.git
$ git checkout 0.9.0
$ cd Weaver
$ make install
$ weaver --help

Usage:

    $ weaver <input_paths>

Arguments:

    input_paths - Swift files to parse.

Options:
    --output_path [default: .] - Where the swift files will be generated.
    --template_path - Custom template path.
    --unsafe [default: false]
```

It will build and install the Weaver command line tool in `/usr/local/bin`.

### (3) - Weaver build phase

In Xcode, add the following command to a command line build phase: 

```
weaver --output_path ${SOURCE_ROOT}/generated/files/directory/path ${SOURCE_ROOT}/**/*.swift
```

**Important - Move this build phase above the `Compile Source` phase so Weaver can generate the boilerplate code before compilation happens.**

**Warning - Using `--unsafe` is not recommended. It will deactivate the graph validation, meaning the generated code could crash if the dependency graph is invalid.** Only set it to false if the graph validation prevents the project from compiling even though it should not. If you find yourself in that situation, please, feel free to file a bug.

## Basic Usage

*For a more complete usage example, please check out the [sample project](./Sample).*

Let's implement a very basic app displaying a list of movies. It will be composed of three noticeable objects: 
- `AppDelegate` where the dependencies are registered.
- `MovieManager` providing the movies.
- `MoviesViewController` showing a list of movies at the screen.

Let's get into the code.

**`AppDelegate`**:

```swift
import UIKit
import Weaver

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    private let dependencies = AppDelegateDependencyContainer()
    
    // weaver: movieManager = MovieManager <- MovieManaging
    // weaver: movieManager.scope = .container
    
    // weaver: moviesViewController = MoviesViewController <- UIViewController
    // weaver: moviesViewController.scope = .container
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        window = UIWindow()

        let rootViewController = dependencies.moviesViewController
        window?.rootViewController = UINavigationController(rootViewController: rootViewController)
        window?.makeKeyAndVisible()
        
        return true
    }
}
```

`AppDelegate` registers two dependencies:
- `// weaver: movieManager = MovieManager <- MovieManaging`
- `// weaver: moviesViewController = MoviesViewController <- UIViewController`

These dependencies are made accessible to any object built from `AppDelegate` because their scope is set to `container`:
- `// weaver: movieManager.scope = .container`
- `// weaver: moviesViewController.scope = .container`

A dependency registration automatically generates the registration code and one accessor in `AppDelegateDependencyContainer`, which is why the `rootViewController` can be built:
- `let rootViewController = dependencies.moviesViewController`.

**`MovieManager`**:

```swift
protocol MovieManaging {
    
    func getMovies(_ completion: @escaping (Result<Page<Movie>, MovieManagerError>) -> Void)
}

final class MovieManager: MovieManaging {

    func getMovies(_ completion: @escaping (Result<Page<Movie>, MovieManagerError>) -> Void) {
        // fetches movies from the server...
        completion(.success(movies))        
    }
}
```

**`MoviesViewController`**:
```swift
final class MoviesViewController: UIViewController {
    
    private let dependencies: MoviesViewControllerDependencyResolver
    
    private var movies = [Movie]()
    
    // weaver: movieManager <- MovieManaging
    
    required init(injecting dependencies: MoviesViewControllerDependencyResolver) {
        self.dependencies = dependencies
        super.init(nibName: nil, bundle: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Setups the tableview... 
        
        // Fetches the movies
        dependencies.movieManager.getMovies { result in
            switch result {
            case .success(let page):
                self.movies = page.results
                self.tableView.reloadData()
                
            case .failure(let error):
                self.showError(error)
            }
        }
    }

    // ... 
}
```

`MoviesViewController` declares a dependency reference:
- `// weaver: movieManager <- MovieManaging`

This annotation generates an accessor in `MoviesViewControllerDependencyResolver`, but no registration, which means `MovieManager` is not stored in `MoviesViewControllerDependencyContainer`, but in its parent (the container from which it was built). In this case, `AppDelegateDependencyContainer`.

`MoviesViewController` also needs to declare a specific initializer:
- `required init(injecting dependencies: MoviesViewControllerDependencyResolver)`

This initializer is used to inject the DI Container. Note that `MoviesViewControllerDependencyResolver` is a protocol, which means a fake version of the DI Container can be injected when testing.

## API

### Code Annotations

Weaver allows you to declare dependencies by annotating the code with comments like so `// weaver: ...`. 

It currently supports the following annotations:

#### - Dependency Registration Annotation

- Adds the dependency builder to the container.
- Adds an accessor for the dependency to the container's resolver protocol.

Example:
```swift
// weaver: dependencyName = DependencyConcreteType <- DependencyProtocol
```
or 
```swift
// weaver: dependencyName = DependencyConcreteType
```

- `dependencyName`: Dependency's name. Used to make reference to the dependency in other objects and/or annotations.
- `DependencyConcreteType`: Dependency's implementation type. Can be a `struct` or a `class`.
- `DependencyProtocol`: Dependency's `protocol` if any. Optional, you can register a dependency with its concrete type only.

#### - Scope Annotation

Sets the scope of a dependency. The default scope being `graph`. Only works along with a registration annotation.

The `scope` defines a dependency's access level and caching strategy. Four scopes are available:
- `transient`: Always creates a new instance when resolved. Can't be accessed from children.
- `graph`: A new instance is created when resolved the first time and then lives for the time the container lives. Can't be accessed from children.
- `weak`: A new instance is created when resolved the first time and then lives for the time its strong references are living. Accessible from children.
- `container`: Like graph, but accessible from children.

Example:
```swift
// weaver: dependencyName.scope = .scopeValue
```

`scopeValue`: Value of the scope. It can be one of the values described above.

#### - Dependency Reference Annotation

Adds an accessor for the dependency to the container's protocol.

Example:
```swift
// weaver: dependencyName <- DependencyType
```

`DependencyType`: Either the concrete or abstract type of the dependency. This also defines the type the dependency's accessor returns.

#### - Custom Reference Annotation

Adds the method `dependencyNameCustomRef(_ dependencyContainer:)` to the container's resolver `protocol`. The default value being `false`. This method is left unimplemented by Weaver, meaning you'll need to implement it yourself and resolve/build the dependency manually.

Works along with registration and reference annotations.

**Warning - Make sure you don't do anything unsafe with the `dependencyContainer` parameter passed down in this method since it won't be caught by the dependency graph validator.**

Example:
```swift
// weaver: dependencyName.customRef = aBoolean
```

`aBoolean`: Boolean definining if the dependency should have a custom reference or not. Can take the value `true` or `false`.

#### - Parameter Annotation

Adds a parameter to the container's resolver protocol. This means that the generated container needs to take these parameter at initialisation. It also means that all the concerned dependency accessors need to take this parameter.

Example:
```swift
// weaver: parameterName <= ParameterType
```

## More reading...

- [Weaver: A Painless Dependency Injection Framework For Swift](https://medium.com/scribd-data-science-engineering/weaver-a-painless-dependency-injection-framework-for-swift-7c4afad5ef6a)
- [Dependency Injection Demisifyied, James Shore, 03/22/2006](http://www.jamesshore.com/Blog/Dependency-Injection-Demystified.html) ¹

## Credits

The DI container features of Weaver are inspired by [Swinject](https://github.com/Swinject/Swinject).

## Contributing

1. [Fork it](https://github.com/Scribd/weaver/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

MIT license. See the [LICENSE file](./LICENSE) for details.
