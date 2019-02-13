protocol FuuProtocolTest6 {
}

final class FuuTest6: FuuProtocolTest6 {
}

final class FooTest6 {
    // weaver: fuu = FuuTest6? <- FuuProtocolTest6?
}
