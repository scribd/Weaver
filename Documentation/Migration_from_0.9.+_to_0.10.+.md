# Migration from v0.9.+ to v0.10.+

Weaver 0.10.0 doesn't have any API breaking changes, which means the annotations are still the same. **Only the generated code structure changed**.

The major change which happened is the removal of the dependency registration/resolution at runtime. 

## Installation

### With v0.9.+:

- Install the runtime library WeaverDI with either Cocoapods, Carthage or SwiftPM.
- Install the command line tool with either Homebrew, or manually.
- Add Weaver pre-compilation build phase.

### With v0.10.+:

- Install the command line tool with either Homebrew, or manually.
- Add Weaver pre-compilation build phase.

The boilerplate code doesn't need WeaverDI anymore since the registration/resolution of dependencies doesn't happen at runtime anymore.

## Dependency build timeline

### With v0.9.+:

Dependencies were all lazily built. This behavior brought up a lot of retain cycle and thread-safety issues as well as behavioral issues. Not knowing when a dependency is actually built or not makes it harder for developers to control dependencies lifecycle.

### With v0.10.+:

Dependencies are built upfront, which means that when a dependency container is initialized, it also initialize all its contained dependencies with it. When a class is then built with its dependency container, the dependencies are initialized and ready to use.

There are few exceptions:

- Transient dependencies are never stored, which means they are build on demand.
- Weak dependencies are stored weakly, which means they can't be built upfront, since they would get released straight away anyway if they did. They are still lazy loaded, which means the use of weak dependencies in the multi-threaded environment can lead to race conditions.