final class FooTest14 {
    // weaver: fii <= String

    // weaver: fuu = FuuTest14<String>
}

final class FuuTest14<T> {
    // weaver: fii <= T
    
    init(injecting _: FuuTest14DependencyResolver<T>) {
    }
}
