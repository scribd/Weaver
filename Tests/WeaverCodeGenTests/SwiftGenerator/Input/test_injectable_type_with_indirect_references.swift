final class FuuTest11 {
}

final class FooTest11 {
    // weaver: fuu = FuuTest11
    // weaver: fuu.scope = .container
    
    // weaver: faa = FaaTest11
}

final class FaaTest11 {
    // weaver: fee = FeeTest11
    // weaver: fee.scope = .transient
    
    init(injecting _: FaaTest11DependencyResolver) {
    }
}

final class FeeTest11 {
    // weaver: fii = FiiTest11
    // weaver: fii.scope = .transient

    init(injecting _: FeeTest11DependencyResolver) {
    }
}

final class FiiTest11 {
    // weaver: fuu <- FuuTest11

    init(injecting _: FiiTest11DependencyResolver) {
    }
}
