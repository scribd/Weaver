//
//  RuntimeTreeInspector.swift
//  WeaverCodeGen
//
//  Created by Stephane Magne on 12/14/21.
//

import Foundation

// MARK: - RuntimeTreeInspector

public final class RuntimeTreeInspector {

    public let rootNode: TreeNode

    init(rootContainer: DependencyContainer,
         dependencyGraph: DependencyGraph) {
        self.rootNode = TreeNode(rootContainer: rootContainer, dependencyGraph: dependencyGraph)
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

        var history: [InspectorAnalysisHistoryRecord] = []

        enum EarlyReturn {
            case empty
            case history
        }

        let resolveStep: (Int, DependencyContainer) -> EarlyReturn? = { step, dependencyContainer in
            history.append(.triedToResolveDependencyInType(dependency, in: dependencyContainer, stepCount: step))

            guard let matchingDependency = dependencyContainer.dependencies[dependency.dependencyName] else {
                return nil
            }

            switch matchingDependency.kind {
            case .parameter:
                return .empty
            case .registration:
                history.append(.invalidContainerScope(dependency))
                return .history
            case .reference:
                return nil
            }
        }

        // root
        if let earlyReturn = resolveStep(0, node.inspectingContainer) {
            switch earlyReturn {
            case .empty:
                return nil
            case .history:
                return history
            }
        }

        // dependencyChain
        var stepCount = 1
        var _parent = node.parent
        while let parent = _parent {
            if let earlyReturn = resolveStep(stepCount, parent.inspectingContainer) {
                switch earlyReturn {
                case .empty:
                    return nil
                case .history:
                    return history
                }
            }

            _parent = parent.parent
            stepCount += 1
        }

        history.append(.dependencyNotFound(dependency, in: rootNode.inspectingContainer))

        return history
    }
}

// MARK: - Full Tree Iterator

public final class TreeNode: Sequence, IteratorProtocol {

    let inspectingContainer: DependencyContainer

    private(set) var children: [TreeNode] = []

    weak var parent: TreeNode?

    // do not encode
    private(set) var dependencyPointer: Dependency?

    private(set) var previousDependencyPointer: Dependency?

    let dependencyGraph: DependencyGraph

    convenience init(rootContainer: DependencyContainer,
                     dependencyGraph: DependencyGraph) {
        self.init(inspectingContainer: rootContainer,
                  dependencyGraph: dependencyGraph,
                  dependencyPointer: rootContainer.dependencies.orderedValues.first,
                  previousDependencyPointer: nil,
                  parent: nil)
    }

    private init(inspectingContainer: DependencyContainer,
                 dependencyGraph: DependencyGraph,
                 dependencyPointer: Dependency?,
                 previousDependencyPointer: Dependency?,
                 parent: TreeNode?) {
        self.inspectingContainer = inspectingContainer
        self.dependencyGraph = dependencyGraph
        self.dependencyPointer = dependencyPointer
        self.previousDependencyPointer = previousDependencyPointer
        self.parent = parent
    }

    /*
     This will return the next node in the tree until the entire tree has been traversed.

     The ordering will be, starting from the first dependency of the root node:
     - The next node down the tree for the current dependency
     - If none, then move to the next sibling dependency in the current node
     - If none, then pop up to the parent node
     */
    public func next() -> TreeNode? {

        guard let dependencyPointer = dependencyPointer else {
            return nextByPopping()
        }

        guard dependencyPointer.kind.isRegistration,
              let nextContainer = try? dependencyGraph.dependencyContainer(for: dependencyPointer) else {
                  return nextByIterating(after: dependencyPointer)
        }

        let node = TreeNode(inspectingContainer: nextContainer,
                            dependencyGraph: dependencyGraph,
                            dependencyPointer: nextContainer.dependencies.orderedValues.first,
                            previousDependencyPointer: dependencyPointer,
                            parent: self)

        children.append(node)

        return node
    }

    private func nextByIterating(after dependency: Dependency) -> TreeNode? {

        let values = inspectingContainer.dependencies.orderedValues

        guard let firstIndex = values.firstIndex(where: { $0 === dependency}) else {
            return nextByPopping()
        }

        let nextIndex = values.index(after: firstIndex)
        dependencyPointer = nextIndex < values.count ? values[nextIndex] : nil
        return next()
    }

    private func nextByPopping() -> TreeNode? {

        guard let parent = parent,
              let parentDependency = parent.inspectingContainer.dependencies.orderedValues.first(where: { $0 === previousDependencyPointer }) else {
            return nil
        }

        return parent.nextByIterating(after: parentDependency)
    }
}
