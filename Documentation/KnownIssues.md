# Known Issues

This is a list of common (somtimes confusing) issues developers regularly run into when using Weaver.

### 1. Ambiguous reference to member 'register(_:scope:name:builder:)'

This usually happens when a dependency is registered correctly with a protocol without implementing it.

For example:

```swift
final class AppDelegate {
    // weaver: apiManager = APIManager <- APIManaging
    // weaver: apiManager.scope = .container
}

protocol APIManaging { ... }

final class APIManager { // `: APIManaging` is missing here.
    ...
}
```

Weaver doesn't catch this, but the project will fail with a compilation error in `Weaver.AppDelegate.swift`:

```
Ambiguous reference to member 'register(_:scope:name:builder:)'
```
