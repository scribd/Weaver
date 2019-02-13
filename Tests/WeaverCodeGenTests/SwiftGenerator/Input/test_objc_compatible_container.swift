import Foundation

@objc final class FooTest16: NSObject {
}

@objc final class FuuTest16: NSObject {
}

extension FooTest16: FooTest16ObjCDependencyInjectable {
    // weaver: fuu = FuuTest16
}
