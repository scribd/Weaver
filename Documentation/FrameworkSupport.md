# Framework Support

Since v0.9.10, Weaver can be used to develop frameworks without exposing any of the DI Containers' logic.

## How does it work?

As soon as an injected type is declared `public`, Weaver generates a public convenience initializer which allows the framework's end users to initialize it from outside as a regular type.

Note that a public injected type can also be injected internally.

## Example

For an example, checkout these files from the sample:

- [MovieManager](../Sample/API/Manager/MovieManager.swift)
- [Weaver.MovieManager](../Sample/API/Generated/Weaver.MovieManager.swift)
- [AppDelegate](../Sample/Sample/AppDelegate.swift)

## Known limitations

A public injected type taking parameters cannot be used both internally and externally of the framework.