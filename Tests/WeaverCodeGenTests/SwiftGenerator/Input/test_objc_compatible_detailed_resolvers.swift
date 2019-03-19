import Foundation

@objc final class FooTest20: NSObject {
}

@objc final class FuuTest20: NSObject {
}

extension FooTest20: FooTest16ObjCDependencyInjectable {
    // weaver: fuu = FuuTest20
    // weaver: fuu.objc = true
}
