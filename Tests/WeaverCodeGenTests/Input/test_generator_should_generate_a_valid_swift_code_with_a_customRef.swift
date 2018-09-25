protocol FooProtocolTest4 {
}

final class FuuTest4: FuuProtocolTest4 {
}

protocol FuuProtocolTest4 {
}

final class FooTest4: FooProtocolTest4 {
    // weaver: fuu = FuuTest4 <- FuuProtocolTest4
    // weaver: fuu.customRef = true
}

extension FooTest4DependencyResolver {
    
    func fuuCustomRef() -> FuuProtocolTest4 {
        return FuuTest4()
    }
}
