import Foundation

public protocol SetupStepPerforming {
    func perform(_ step: SetupStep) async throws
}

public struct SetupFailure: Error {
    public let step: SetupStep
    public let underlying: Error
    public var message: String { String(describing: underlying) }
}

public final class SetupEngine {
    let stateURL: URL
    let performer: SetupStepPerforming
    let progress: (SetupStep, Int, Int) -> Void

    public init(stateURL: URL, performer: SetupStepPerforming,
                progress: @escaping (SetupStep, Int, Int) -> Void = { _, _, _ in }) {
        self.stateURL = stateURL
        self.performer = performer
        self.progress = progress
    }

    public func runPending() async throws {
        var state = SetupState.load(from: stateURL)
        let steps = SetupStep.allCases
        for (i, step) in steps.enumerated() where !state.completed.contains(step) {
            progress(step, i + 1, steps.count)
            do {
                try await performer.perform(step)
            } catch {
                throw SetupFailure(step: step, underlying: error)
            }
            state = SetupState.load(from: stateURL)   // performer may have saved options
            state.completed.append(step)
            try state.save(to: stateURL)
        }
    }

    public func reset(_ steps: [SetupStep]) throws {
        var state = SetupState.load(from: stateURL)
        state.completed.removeAll { steps.contains($0) }
        try state.save(to: stateURL)
    }
}
