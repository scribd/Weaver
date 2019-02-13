public final class FuuTest7 {
}

public final class FiiTest7 {
}

public final class FeeTest7 {
}

public final class FooTest7 {
    // weaver: fuu = FuuTest7
    
    // weaver: fii <- FiiTest7
    
    // weaver: fee <= FeeTest7
    
    init(injecting _: FooTest7DependencyResolver) {
    }
}
