# ObjC Support

Since v0.9.1, Weaver can inject dependencies into plain ObjC classes. 

It doesn't mean that Weaver can be used in ObjC directly. The project needs to mix ObjC & Swift to make this functionality work.

## How does it work?

To activate the ObjC Support, the concerned ObjC class needs to implement the protocol `ClassNameObjCDependencyInjectable` in a Swift extension. Weaver can detect this and generate the appropriate code to make the `ClassNameDependencyResolver` protocol compatible with ObjC.

The `ClassNameObjCDependencyInjectable` protocol requires to implement `init(injecting: ClassNameDependencyResolver)`. Since it can't be implemented in the Swift extension, it has to be implemented in the ObjC class directly. So keep an ObjC friendly style, the use of `NS_SWIFT_NAME` is recommended.

## Example

For an example, checkout these files from the sample:

- [WSReviewViewController+Injectable.swift](../Sample/Sample/View/WSReviewViewController+Injectable.swift)
- [WSReviewViewController.h](../Sample/Sample/View/WSReviewViewController.h)
- [WSReviewViewController.m](../Sample/Sample/View/WSReviewViewController.m)