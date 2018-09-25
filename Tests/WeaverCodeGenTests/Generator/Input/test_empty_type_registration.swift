typealias LogEngineTest1 = String

final class LoggerTest1 {
    // weaver: logEngine = LogEngineTest1
    
    init(injecting: LoggerTest1DependencyResolver) {}
}

final class ManagerTest1 {
    // weaver: logger = LoggerTest1
}
