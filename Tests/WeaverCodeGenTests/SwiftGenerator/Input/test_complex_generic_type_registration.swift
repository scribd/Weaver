final class FooTest14 {
    // weaver: fii <= String

    // weaver: fuu = FuuTest14<String>
}

final class FuuTest14<T> {
    // weaver: fii <= T
    
    let resolver: FuuTest14DependencyContainer<T>
    
    init(injecting resolver: FuuTest14DependencyContainer<T>) {
        self.resolver = resolver
    }
}
