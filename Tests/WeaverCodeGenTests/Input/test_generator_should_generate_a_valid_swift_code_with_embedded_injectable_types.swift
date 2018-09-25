protocol FiiProtocolTest5 {
}

final class FiiTest5: FiiProtocolTest5 {
}

final class FooTest5 {
    // weaver: fii = FiiTest5
    
    final class FuuTest5 {
        // weaver: fii = FiiTest5? <- FiiProtocolTest5?
        // weaver: fii.scope = .container
    }
}
