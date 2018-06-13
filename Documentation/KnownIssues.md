# Known Issues

This is a list of common (somtimes confusing) issues developers regularly run into when using Weaver.

### 1. Ambiguous reference to member 'register(_:scope:name:builder:)'

This usually happen when a dependency is registered correctly and access via a protocol without implementing it.

For example:

```swift
final class AppDelegate {
    // weaver: apiManager = APIManager <- APIManaging
}

final class MovieManager { // `: MovieManaging` is missing here.
    // weaver: apiManager <- APIManaging
}
```

Weaver doesn't catch this, but the project will fail with a compilation error in `Weaver.AppDelegate.swift`:

```
Ambiguous reference to member 'register(_:scope:name:builder:)'
```
