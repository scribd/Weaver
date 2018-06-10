// Generated using Sourcery 0.11.2 — https://github.com/krzysztofzablocki/Sourcery
// DO NOT EDIT

// swiftlint:disable file_length
fileprivate func compareOptionals<T>(lhs: T?, rhs: T?, compare: (_ lhs: T, _ rhs: T) -> Bool) -> Bool {
    switch (lhs, rhs) {
    case let (lValue?, rValue?):
        return compare(lValue, rValue)
    case (nil, nil):
        return true
    default:
        return false
    }
}

fileprivate func compareArrays<T>(lhs: [T], rhs: [T], compare: (_ lhs: T, _ rhs: T) -> Bool) -> Bool {
    guard lhs.count == rhs.count else { return false }
    for (idx, lhsItem) in lhs.enumerated() {
        guard compare(lhsItem, rhs[idx]) else { return false }
    }

    return true
}


// MARK: - AutoEquatable for classes, protocols, structs
// MARK: - AnyDeclaration AutoEquatable
extension AnyDeclaration: Equatable {}
public func == (lhs: AnyDeclaration, rhs: AnyDeclaration) -> Bool {
    guard lhs.description == rhs.description else { return false }
    return true
}
// MARK: - ConfigurationAnnotation AutoEquatable
extension ConfigurationAnnotation: Equatable {}
public func == (lhs: ConfigurationAnnotation, rhs: ConfigurationAnnotation) -> Bool {
    guard lhs.attribute == rhs.attribute else { return false }
    guard lhs.target == rhs.target else { return false }
    return true
}
// MARK: - EndOfAnyDeclaration AutoEquatable
extension EndOfAnyDeclaration: Equatable {}
public func == (lhs: EndOfAnyDeclaration, rhs: EndOfAnyDeclaration) -> Bool {
    guard lhs.description == rhs.description else { return false }
    return true
}
// MARK: - EndOfInjectableType AutoEquatable
extension EndOfInjectableType: Equatable {}
public func == (lhs: EndOfInjectableType, rhs: EndOfInjectableType) -> Bool {
    guard lhs.description == rhs.description else { return false }
    return true
}
// MARK: - FileLocation AutoEquatable
extension FileLocation: Equatable {}
internal func == (lhs: FileLocation, rhs: FileLocation) -> Bool {
    guard compareOptionals(lhs: lhs.line, rhs: rhs.line, compare: ==) else { return false }
    guard compareOptionals(lhs: lhs.file, rhs: rhs.file, compare: ==) else { return false }
    return true
}
// MARK: - InjectableType AutoEquatable
extension InjectableType: Equatable {}
public func == (lhs: InjectableType, rhs: InjectableType) -> Bool {
    guard lhs.name == rhs.name else { return false }
    guard lhs.accessLevel == rhs.accessLevel else { return false }
    guard lhs.doesSupportObjc == rhs.doesSupportObjc else { return false }
    return true
}
// MARK: - ParameterAnnotation AutoEquatable
extension ParameterAnnotation: Equatable {}
public func == (lhs: ParameterAnnotation, rhs: ParameterAnnotation) -> Bool {
    guard lhs.name == rhs.name else { return false }
    guard lhs.typeName == rhs.typeName else { return false }
    return true
}
// MARK: - PrintableDependency AutoEquatable
extension PrintableDependency: Equatable {}
internal func == (lhs: PrintableDependency, rhs: PrintableDependency) -> Bool {
    guard lhs.fileLocation == rhs.fileLocation else { return false }
    guard lhs.name == rhs.name else { return false }
    guard compareOptionals(lhs: lhs.typeName, rhs: rhs.typeName, compare: ==) else { return false }
    return true
}
// MARK: - PrintableResolver AutoEquatable
extension PrintableResolver: Equatable {}
internal func == (lhs: PrintableResolver, rhs: PrintableResolver) -> Bool {
    guard lhs.fileLocation == rhs.fileLocation else { return false }
    guard compareOptionals(lhs: lhs.typeName, rhs: rhs.typeName, compare: ==) else { return false }
    return true
}
// MARK: - ReferenceAnnotation AutoEquatable
extension ReferenceAnnotation: Equatable {}
public func == (lhs: ReferenceAnnotation, rhs: ReferenceAnnotation) -> Bool {
    guard lhs.name == rhs.name else { return false }
    guard lhs.typeName == rhs.typeName else { return false }
    return true
}
// MARK: - RegisterAnnotation AutoEquatable
extension RegisterAnnotation: Equatable {}
public func == (lhs: RegisterAnnotation, rhs: RegisterAnnotation) -> Bool {
    guard lhs.name == rhs.name else { return false }
    guard lhs.typeName == rhs.typeName else { return false }
    guard compareOptionals(lhs: lhs.protocolName, rhs: rhs.protocolName, compare: ==) else { return false }
    return true
}
// MARK: - ScopeAnnotation AutoEquatable
extension ScopeAnnotation: Equatable {}
public func == (lhs: ScopeAnnotation, rhs: ScopeAnnotation) -> Bool {
    guard lhs.name == rhs.name else { return false }
    guard lhs.scope == rhs.scope else { return false }
    return true
}
// MARK: - Token AutoEquatable
public func == (lhs: Token, rhs: Token) -> Bool {
    return true
}

// MARK: - AutoEquatable for Enums
// MARK: - ConfigurationAttribute AutoEquatable
extension ConfigurationAttribute: Equatable {}
internal func == (lhs: ConfigurationAttribute, rhs: ConfigurationAttribute) -> Bool {
    switch (lhs, rhs) {
    case (.isIsolated(let lhs), .isIsolated(let rhs)):
        return lhs == rhs
    case (.customRef(let lhs), .customRef(let rhs)):
        return lhs == rhs
    default: return false
    }
}
// MARK: - ConfigurationAttributeTarget AutoEquatable
extension ConfigurationAttributeTarget: Equatable {}
internal func == (lhs: ConfigurationAttributeTarget, rhs: ConfigurationAttributeTarget) -> Bool {
    switch (lhs, rhs) {
    case (.`self`, .`self`):
        return true
    case (.dependency(let lhs), .dependency(let rhs)):
        return lhs == rhs
    default: return false
    }
}
// MARK: - Expr AutoEquatable
extension Expr: Equatable {}
public func == (lhs: Expr, rhs: Expr) -> Bool {
    switch (lhs, rhs) {
    case (.file(let lhs), .file(let rhs)):
        if lhs.types != rhs.types { return false }
        if lhs.name != rhs.name { return false }
        return true
    case (.typeDeclaration(let lhs), .typeDeclaration(let rhs)):
        if lhs.0 != rhs.0 { return false }
        if lhs.children != rhs.children { return false }
        return true
    case (.registerAnnotation(let lhs), .registerAnnotation(let rhs)):
        return lhs == rhs
    case (.scopeAnnotation(let lhs), .scopeAnnotation(let rhs)):
        return lhs == rhs
    case (.referenceAnnotation(let lhs), .referenceAnnotation(let rhs)):
        return lhs == rhs
    case (.parameterAnnotation(let lhs), .parameterAnnotation(let rhs)):
        return lhs == rhs
    case (.configurationAnnotation(let lhs), .configurationAnnotation(let rhs)):
        return lhs == rhs
    default: return false
    }
}
// MARK: - GeneratorError AutoEquatable
extension GeneratorError: Equatable {}
internal func == (lhs: GeneratorError, rhs: GeneratorError) -> Bool {
    switch (lhs, rhs) {
    case (.invalidTemplatePath(let lhs), .invalidTemplatePath(let rhs)):
        return lhs == rhs
    }
}
// MARK: - InspectorAnalysisError AutoEquatable
extension InspectorAnalysisError: Equatable {}
internal func == (lhs: InspectorAnalysisError, rhs: InspectorAnalysisError) -> Bool {
    switch (lhs, rhs) {
    case (.cyclicDependency(let lhs), .cyclicDependency(let rhs)):
        return lhs == rhs
    case (.unresolvableDependency(let lhs), .unresolvableDependency(let rhs)):
        return lhs == rhs
    case (.isolatedResolverCannotHaveReferents(let lhs), .isolatedResolverCannotHaveReferents(let rhs)):
        if lhs.typeName != rhs.typeName { return false }
        if lhs.referents != rhs.referents { return false }
        return true
    default: return false
    }
}
// MARK: - InspectorAnalysisHistoryRecord AutoEquatable
extension InspectorAnalysisHistoryRecord: Equatable {}
internal func == (lhs: InspectorAnalysisHistoryRecord, rhs: InspectorAnalysisHistoryRecord) -> Bool {
    switch (lhs, rhs) {
    case (.foundUnaccessibleDependency(let lhs), .foundUnaccessibleDependency(let rhs)):
        return lhs == rhs
    case (.dependencyNotFound(let lhs), .dependencyNotFound(let rhs)):
        return lhs == rhs
    case (.triedToBuildType(let lhs), .triedToBuildType(let rhs)):
        if lhs.0 != rhs.0 { return false }
        if lhs.stepCount != rhs.stepCount { return false }
        return true
    case (.triedToResolveDependencyInType(let lhs), .triedToResolveDependencyInType(let rhs)):
        if lhs.0 != rhs.0 { return false }
        if lhs.stepCount != rhs.stepCount { return false }
        return true
    default: return false
    }
}
// MARK: - InspectorError AutoEquatable
extension InspectorError: Equatable {}
internal func == (lhs: InspectorError, rhs: InspectorError) -> Bool {
    switch (lhs, rhs) {
    case (.invalidAST(let lhs), .invalidAST(let rhs)):
        if lhs.0 != rhs.0 { return false }
        if lhs.unexpectedExpr != rhs.unexpectedExpr { return false }
        return true
    case (.invalidGraph(let lhs), .invalidGraph(let rhs)):
        if lhs.0 != rhs.0 { return false }
        if lhs.underlyingError != rhs.underlyingError { return false }
        return true
    default: return false
    }
}
// MARK: - LexerError AutoEquatable
extension LexerError: Equatable {}
internal func == (lhs: LexerError, rhs: LexerError) -> Bool {
    switch (lhs, rhs) {
    case (.invalidAnnotation(let lhs), .invalidAnnotation(let rhs)):
        if lhs.0 != rhs.0 { return false }
        if lhs.underlyingError != rhs.underlyingError { return false }
        return true
    }
}
// MARK: - ParserError AutoEquatable
extension ParserError: Equatable {}
internal func == (lhs: ParserError, rhs: ParserError) -> Bool {
    switch (lhs, rhs) {
    case (.unexpectedToken(let lhs), .unexpectedToken(let rhs)):
        return lhs == rhs
    case (.unexpectedEOF(let lhs), .unexpectedEOF(let rhs)):
        return lhs == rhs
    case (.unknownDependency(let lhs), .unknownDependency(let rhs)):
        return lhs == rhs
    case (.depedencyDoubleDeclaration(let lhs), .depedencyDoubleDeclaration(let rhs)):
        return lhs == rhs
    case (.configurationAttributeDoubleAssignation(let lhs), .configurationAttributeDoubleAssignation(let rhs)):
        if lhs.0 != rhs.0 { return false }
        if lhs.attribute != rhs.attribute { return false }
        return true
    default: return false
    }
}
// MARK: - TokenError AutoEquatable
extension TokenError: Equatable {}
internal func == (lhs: TokenError, rhs: TokenError) -> Bool {
    switch (lhs, rhs) {
    case (.invalidAnnotation(let lhs), .invalidAnnotation(let rhs)):
        return lhs == rhs
    case (.invalidScope(let lhs), .invalidScope(let rhs)):
        return lhs == rhs
    case (.invalidConfigurationAttributeValue(let lhs), .invalidConfigurationAttributeValue(let rhs)):
        if lhs.value != rhs.value { return false }
        if lhs.expected != rhs.expected { return false }
        return true
    case (.invalidConfigurationAttributeTarget(let lhs), .invalidConfigurationAttributeTarget(let rhs)):
        if lhs.name != rhs.name { return false }
        if lhs.target != rhs.target { return false }
        return true
    case (.unknownConfigurationAttribute(let lhs), .unknownConfigurationAttribute(let rhs)):
        return lhs == rhs
    default: return false
    }
}
