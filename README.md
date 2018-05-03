<p align="center">
  <img src="./weaver.png" width=520>
</p>

<p align="center">A painless dependency injection framework for Swift (iOS/macOS/Linux).</p>

## Features

- [x] Pure Swift support
- [x] Container generation
- [x] Dependency Graph compile time check
- [x] Non-optional dependency resolution
- [x] Type safety
- [x] Injection with arguments
- [x] Registration Scopes
- [x] Container hierarchy

## Dependency Injection?

In software engineering, dependency injection is a technique whereby one object supplies the dependencies of another object. A dependency is an object that can be used (a service). An injection is the passing of a dependency to a dependent object (a client) that would use it. ([wikipedia](https://en.wikipedia.org/wiki/Dependency_injection))

This pattern is essential to keep a light coupling between objects. It makes unit testing a lot easier since a mock or a stub of a dependency can be very easily injected into the object being tested. The inversion of control also help making your code more modular and scalable.

## What does it do?

`weaver` implements the dependency container pattern and generates the boiler plate code for you, which makes objects' initialisation easier and standardized over the codebase. It is also able to check at compile time if the dependency graph is valid, preventing any dependency resolution runtime crash to happen.

## How does it work?

Even though `weaver` generates the boiler plate code for you, it is important that you know what it does under the hood. There are two phases to be aware of ; compile time and run time.

### At compile time

```
                                                        |--> link() --> dependency graph --> validate() --> valid/invalid 
swift files --> scan() --> [Token] --> parse() --> AST -| 
                                                        |--> generate() --> source code 

```

The `weaver` command line tool scans the Swift sources of the project, looking for annotations, and generates an AST (abstract syntax tree). It uses [SourceKitten](https://github.com/jpsim/SourceKitten) which is backed by Apple's [SourceKit](https://github.com/apple/swift/tree/master/tools/SourceKit), making this step pretty reliable.

This AST is then used to generate the dependency graph on which a bunch of safety checks are peformed in order to make sure the code won't crash at run time. It checks for unresolvable dependencies and unsolvable cyclic dependencies. If any issue is found, no code is being generated, meaning the project will fail to compile.

The same AST is also used to generate the boilerplate code. It generates one dependency container per class/struct with injectable dependencies. It also generates a bunch of extensions and protocols in order to make the dependency injection almost transparent for the developer.

### At run time

The `weaver` framework implements a lightweight dependency container class which allows you to register and resolve dependencies based on their scope, protocol or concrete type, name and parameters. Each container can have a parent, allowing to resolve dependencies throughout a containers hierarchy.

When an object registers a dependency, its associated dependency container stores a builder (and sometimes an instance). When another object declares a reference to this same dependency, its associated container declares an accessor, which tries to resolve the dependency. Resolving a dependency basically means ; looking for a builder/instance while backtracking the containers' hierachy. If no dependency is found or if this process gets trapped into an infinite recursion, it will crash, which is why checking the dependency graph at compile time is extremely important.

## Installation

`weaver` comes in 3 parts:
1. A Swift framework to include into your project
2. A command line tool to install on your machine
3. A build phase to add to your project

### (1) - Weaver framework installation

The `weaver` Swift framework is available with `CocoaPods`, `Carthage` and `Swift Package Manager`.

#### CocoaPods

Add `pod 'Weaver', '~> 0.9.0'` to your `Podfile`.

#### Carthage

Add `github "scribd/Weaver" ~> 0.9.0` to your `Cartfile`.

#### SwiftPM

Add `.package(url: "https://github.com/scribd/Weaver.git", from: "0.9.0")` to the dependencies section of your `Package.swift` file.

### (2) - Weaver command line tool installation

The `weaver` command line tool can be installed using `Homebrew` or manually.

#### Homebrew (coming soon)

`brew install Weaver`

#### Manually

```bash
$ git clone https://github.com/scribd/Weaver.git
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
    --safe [default: true]
```

It will build and install the `weaver` command line tool in `/usr/local/bin`.

### (3) - Weaver build phase

In Xcode, add the following command to a command line build phase: 

```
weaver --output_path ${SOURCE_ROOT}/generated/files/directory/path ${SOURCE_ROOT}/**/*.swift
```

**Important - move your build phase above the `Compile Source` phase since `weaver` needs to check the dependency graph and generate the boilerplate code before compilation happens.**

**Warning - Using `--safe false` is not recommended. It will deactivate the graph validation, meaning the generated code could crash if the dependency graph is invalid.** Only set it to false if the graph validation prevents your project from compiling even though it should not. If you find yourself in that situation, please, feel free to file a bug.

## Basic Usage

*For a more complete usage example, please check out the [sample project](./Sample).*

Let's implement a very basic app displaying a list of movies. Our app will be composed of three noticeable objects: 
- `AppDelegate` where our dependencies are registered.
- `MovieManager` providing the movies.
- `MoviesViewController` showing a list of movies at the screen.

Let's get into the code.

`AppDelegate`:
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

        window?.rootViewController = UINavigationController(rootViewController: dependencies.moviesViewController)
        window?.makeKeyAndVisible()
        
        return true
    }
}
```

`MovieManager`:
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

`MoviesViewController`:
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

## API

### Code Annotations

`weaver` allows you to declare dependencies by annotating your Swift code in comments like so `// weaver: ...`. It currently supports the following annotations:

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

Adds the method `dependencyNameCustomRef(_ dependencyContainer:)` to the container's resolver `protocol`. The default value being `false`. This method is left unimplemented by `weaver`, meaning you'll need to implement it yourself and resolve/build the dependency manually.

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

## Credits

The DI container features of `weaver` are inspired by [Swinject](https://github.com/Swinject/Swinject).

## License

MIT license. See the [LICENSE file](./LICENSE) for details.
