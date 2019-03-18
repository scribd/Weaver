final class FuuTest19 {
}

protocol BarTest19Protocol {}
final class BarTest19: BarTest19Protocol {
}

final class FiiTest19 {
}

final class FooTest19 {
    // weaver: fuu = FuuTest19
    // weaver: bar = BarTest19 <- BarTest19Protocol
    // weaver: foo <- FiiTest19
}
