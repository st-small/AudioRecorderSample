import Combine
import ComposableArchitecture
import Dependencies
import Foundation
import Helpers

public struct NumbersClient {
    public var start: @Sendable () async -> AsyncStream<Action>
    
    @CasePathable
    public enum Action: Equatable {
        case number(Int)
        case finish(Bool)
    }
}

extension DependencyValues {
    public var numbers: NumbersClient {
        get { self[NumbersClient.self] }
        set { self[NumbersClient.self] = newValue }
    }
}

extension NumbersClient: DependencyKey {
    public static var liveValue: Self {
        let actor = MiddlewareActor()
        
        return NumbersClient(
            start: { await actor.start() }
        )
    }
    
    private actor MiddlewareActor {
        var generator: NumbersGenerator?
        
        func start() async -> AsyncStream<Action> {
            let stream = AsyncStream<Action> { continuation in
                let generator = NumbersGenerator(
                    onValueUpdate: { value in
                        continuation.yield(.number(value))
                    },
                    onComplete: { complete in
                        continuation.yield(.finish(true))
                        continuation.finish()
                    }
                )
                self.generator = generator
                
                Task {
                    do {
                        try await generator.start()
                    } catch {
                        preconditionFailure(error.localizedDescription)
                    }
                }
            }
            
            return stream
        }
    }
}
