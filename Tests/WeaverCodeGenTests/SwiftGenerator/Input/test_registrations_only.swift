final class FiiTest12 {
}

final class FooTest12 {
    // weaver: fii = FiiTest12
    
    init(injecting _: FooTest12DependencyResolver) {
    }
}

final class FuuTest12 {
    // weaver: foo = FooTest12
    // weaver: foo.scope = .container
}
