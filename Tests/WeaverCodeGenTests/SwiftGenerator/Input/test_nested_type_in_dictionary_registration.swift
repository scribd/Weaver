final class FooTest23 {
	// weaver: fuu <= [FuuTest23.Key<String>: FuuTest23.Params<String>]
}

final class FuuTest23 {
    final class Key<T>: Hashable {

        static func == (lhs: FuuTest23.Key<T>, rhs: FuuTest23.Key<T>) -> Bool {
            fatalError()
        }

        func hash(into hasher: inout Hasher) {
            fatalError()
        }
    }

    final class Params<T> {
    }
}