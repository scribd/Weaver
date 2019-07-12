enum Test21Nest {
    enum Test21Type {
        case bar
        case baz
    }
}

final class FooTest21 {
    // weaver: foo <= Test21Nest.Test21Type
}
