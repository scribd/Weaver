open class FuuTest17 {
}

open class FiiTest17 {
}

open class FeeTest17 {
}

open class FooTest17 {
    // weaver: fuu = FuuTest17
    
    // weaver: fii <- FiiTest17
    
    // weaver: fee <= FeeTest17
    
    init(injecting _: FooTest17DependencyResolver) {
    }
}
