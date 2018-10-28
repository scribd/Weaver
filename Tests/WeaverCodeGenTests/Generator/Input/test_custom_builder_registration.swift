protocol FooProtocolTest4 {
}

final class FuuTest4: FuuProtocolTest4 {
}

protocol FuuProtocolTest4 {
}

final class FooTest4: FooProtocolTest4 {
    // weaver: fuu = FuuTest4 <- FuuProtocolTest4
    // weaver: fuu.builder = FuuTest4.make
}

extension FuuTest4 {
    
    static func make(_: FooTest4DependencyResolver) -> FuuProtocolTest4 {
        return FuuTest4()
    }
}
