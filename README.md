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

In software engineering, dependency injection is a technique whereby one object supplies the dependencies of another object. A dependency is an object that can be used (a service). An injection is the passing of a dependency to a dependent object (a client) that would use it. ([wikipedia](https://en.wikipedia.org/wiki/Dependency_injection))

This pattern is essential to keep a light coupling between objects. It makes unit testing a lot easier since a mock or a stub of a dependency can be very easily injected into the object being tested. The inversion of control also help making your code more modular and scalable.

`beaverdi` implements the dependency container pattern and generates the boiler plate code for you, which makes objects' initialisation easier and standardized over the codebase. It is also able to check at compile time if the dependency graph is valid, preventing any runtime crash to happen.

## How does it work?

Even though `beaverdi` generates the boiler plate code for you, it is important that you know what it does under the hood. There are two phases to be aware of ; compile time and run time.

### At compile time

```
                                                        |--> link() --> dependency graph --> validate() --> valid/invalid 
swift files --> scan() --> [Token] --> parse() --> AST -| 
                                                        |--> generate() --> source code 

```

The `beaverdi` command line tool scans the Swift sources of the project, looking for annotations, and generates an AST (abstract syntax tree). It uses [SourceKitten](https://github.com/jpsim/SourceKitten) which is backed by Apple's [SourceKit](https://github.com/apple/swift/tree/master/tools/SourceKit), making this step pretty reliable.

This AST is then used to generate the dependency graph on which a bunch of safety checks are peformed in order to make sure the code won't crash at run time. It checks for unresolvable dependencies and unsolvable cyclic dependencies. If any issue is found, no code is being generated, meaning the project will fail to compile.

The same AST is also used to generate the boilerplate code. It generates one dependency container per class/struct with injectable dependencies. It also generates a bunch of extensions and protocols in order to make the dependency injection almost transparent for the developer.

### At run time

The `beaverdi` framework implements a lightweight dependency container class which allows you to register and resolve dependencies based on their scope, protocol or concrete type, name and parameters. Each container can have a parent, allowing to resolve dependencies throughout a containers hierarchy.

When an object registers a dependency, its associated dependency container stores a builder (and sometimes an instance). When another object declares a reference to this same dependency, its associated container declares an accessor, which tries to resolve the dependency. Resolving a dependency basically means ; looking for a builder/instance while backtracking the containers' hierachy. If no dependency is found or if this process gets trapped into an infinite recursion, it will crash, which is why checking the dependency graph at compile time is extremely important.

## Installation

`beaverdi` comes in 3 parts:
1. A Swift framework to include into your project
2. A command line tool to install on your machine
3. A build phase to add to your project

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
import BeaverDI

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    private let dependencies = AppDelegateDependencyContainer()
    
    // beaverdi: movieManager = MovieManager <- MovieManaging
    // beaverdi: movieManager.scope = .container
    
    // beaverdi: moviesViewController = MoviesViewController <- UIViewController
    // beaverdi: moviesViewController.scope = .container
    
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
    
    // beaverdi: movieManager <- MovieManaging
    
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

`beaverdi` allows you to declare dependencies by annotating your Swift code in comments like so `// beaverdi: ...`. It currently supports the following annotations:

#### - Dependency Registration Annotation

- Adds a the dependency builder to the container.
- Adds an accessor for the dependency to the container's resolver protocol.

Example:
```swift
// beaverdi: dependencyName = DependencyConcreteType <- DependencyProtocol
```
or 
```swift
// beaverdi: dependencyName = DependencyConcreteType
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
// beaverdi: dependencyName.scope = .scopeValue
```

`scopeValue`: Value of the scope. It can be one of the values described above.

#### - Dependency Reference Annotation

Adds an accessor for the dependency to the container's protocol.

Example:
```swift
// beaverdi: dependencyName <- DependencyType
```

`DependencyType`: Either the concrete or abstract type of the dependency. This also defines the type the dependency's accessor returns.

#### - Custom Reference Annotation

Adds a the method `dependencyNameCustomRef(_ dependencyContainer:)` to the container's resolver `protocol`. The default value being `false`. This method is left unimplemented by `beaverdi`, meaning you'll need to implement it yourself and resolve/build the dependency manually.

Works along with registration and reference annotations.

**Warning - Make sure you don't do anything unsafe with the `dependencyContainer` parameter passed down in this method since it won't be caught by the dependency graph validator.**

Example:
```swift
// beaverdi: dependencyName.customRef = aBoolean
```

`aBoolean`: Boolean definining if the dependency should have a custom reference or not. Can take the value `true` or `false`.

#### - Parameter Annotation

Adds a parameter to the container's resolver protocol. This means that the generated container needs to take these parameter at initialisation. It also means that all the concerned dependency accessors need to take this parameter.

Example:
```swift
// beaverdi: parameterName <= ParameterType
```

## Credits

The DI container features of `beaverdi` are inspired by [Swinject](https://github.com/Swinject/Swinject).

## License

MIT license. See the [LICENSE file](./LICENSE) for details.
