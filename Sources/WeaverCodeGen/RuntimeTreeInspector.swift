//
//  RuntimeTreeInspector.swift
//  WeaverCodeGen
//
//  Created by Stephane Magne on 12/14/21.
//

import Foundation

// MARK: - RuntimeTreeInspector

public final class RuntimeTreeInspector {

    private let rootNode: TreeNode

    init(rootContainer: DependencyContainer,
         dependencyGraph: DependencyGraph) throws {
        self.rootNode = try TreeNode(rootContainer: rootContainer,
                                     dependencyGraph: dependencyGraph)
    }

    public func validate() throws {
        try validate(node: rootNode)
    }

    private func validate(node: TreeNode?) throws {
        guard let node = node else { return }

        for dependency in node.inspectingContainer.dependencies.orderedValues {
            try validateConfiguration(of: dependency, node: node)
        }

        try validate(node: node.next())
    }
}

// MARK: - Configuration check

private extension RuntimeTreeInspector {

    func validateConfiguration(of dependency: Dependency, node: TreeNode) throws {
        switch dependency.configuration.scope {
        case .container where dependency.kind.isResolvable:
            let container = try node.dependencyGraph.dependencyContainer(for: dependency)
            if let historyRecord = containerDependencyError(container, dependency, node) {
                throw InspectorError.invalidDependencyGraph(dependency, underlyingError:.unresolvableDependency(history: historyRecord))
            }
        case .weak:
            if dependency.kind == .parameter && dependency.type.anyType.isOptional == false {
                throw InspectorError.weakParameterHasToBeOptional(dependency)
            }
        case .lazy,
             .transient,
             .container:
            break
        }
    }

    private func containerDependencyError(_ container: DependencyContainer, _ dependency: Dependency, _ node: TreeNode) -> [InspectorAnalysisHistoryRecord]? {

        guard container.parameters.isEmpty == false else { return nil }

        var stepCount = 0
        var history: [InspectorAnalysisHistoryRecord] = [.triedToResolveDependencyInType(dependency, in: node.inspectingContainer, stepCount: stepCount)]

        for parentContainer in node.dependencyChain.reversed() {
            stepCount += 1
            history.append(.triedToResolveDependencyInType(dependency, in: parentContainer, stepCount: stepCount))

            guard let matchingDependency = parentContainer.dependencies[dependency.dependencyName] else { continue }

            switch matchingDependency.kind {
            case .parameter:
                return nil
            case .registration:
                history.append(.invalidContainerScope(dependency))
                return history
            case .reference:
                continue
            }
        }

        if let rootContainer = node.dependencyChain.first {
            history.append(.dependencyNotFound(dependency, in: rootContainer))
        }
        return history
    }
}

// MARK: - Full Tree Iterator

final class TreeNode: Sequence, IteratorProtocol {

    let inspectingContainer: DependencyContainer

    let dependencyChain: [DependencyContainer]

    let dependencyGraph: DependencyGraph

    let dependencyPointer: Dependency

    convenience init(rootContainer: DependencyContainer,
                     dependencyGraph: DependencyGraph) throws {
        guard let firstDependency = rootContainer.dependencies.orderedValues.first else {
            throw InspectorError.missingRootDependency
        }

        self.init(inspectingContainer: rootContainer,
                  dependencyChain: [],
                  dependencyGraph: dependencyGraph,
                  dependencyPointer: firstDependency)
    }

    private init(inspectingContainer: DependencyContainer,
                dependencyChain: [DependencyContainer],
                dependencyGraph: DependencyGraph,
                dependencyPointer: Dependency) {
        self.inspectingContainer = inspectingContainer
        self.dependencyChain = dependencyChain
        self.dependencyGraph = dependencyGraph
        self.dependencyPointer = dependencyPointer
    }

    /*
     This will return the next node in the tree until the entire tree has been traversed.

     The ordering will be, starting from the first dependency of the root node:
     - The next node down the tree for the current dependency
     - If none, then move to the next sibling dependency in the current node
     - If none, then pop up to the parent node
     */
    func next() -> TreeNode? {

        guard dependencyPointer.kind.isRegistration,
              let nextContainer = try? dependencyGraph.dependencyContainer(for: dependencyPointer),
              let firstNestedDependency = nextContainer.dependencies.orderedValues.first else {
            return nextByIterating(after: dependencyPointer)
        }

        return TreeNode(inspectingContainer: nextContainer,
                        dependencyChain: dependencyChain + [inspectingContainer],
                        dependencyGraph: dependencyGraph,
                        dependencyPointer: firstNestedDependency)
    }

    private func nextByIterating(after dependency: Dependency) -> TreeNode? {

        let values = inspectingContainer.dependencies.orderedValues

        guard let firstIndex = values.firstIndex(where: { $0 === dependency}) else {
            return nextByPopping()
        }

        let nextIndex = values.index(after: firstIndex)
        guard nextIndex < values.count else {
            return nextByPopping()
        }

        let nextDependency: Dependency = values[nextIndex]
        return TreeNode(inspectingContainer: inspectingContainer,
                        dependencyChain: dependencyChain,
                        dependencyGraph: dependencyGraph,
                        dependencyPointer: nextDependency).next()
    }

    private func nextByPopping() -> TreeNode? {
        guard let parentContainer: DependencyContainer = dependencyChain.last else {
            return nil
        }

        guard let dependencyNames = parentContainer.dependencyNamesByConcreteType[inspectingContainer.type] else {
            return nil
        }

        guard let dependencyName = dependencyNames.first(where: { parentContainer.dependencies[$0] != nil }),
              let parentDependency = parentContainer.dependencies[dependencyName] else {
            return nil
        }

        return TreeNode(inspectingContainer: parentContainer,
                        dependencyChain: dependencyChain.dropLast(),
                        dependencyGraph: dependencyGraph,
                        dependencyPointer: parentDependency).nextByIterating(after: parentDependency)
    }
}
