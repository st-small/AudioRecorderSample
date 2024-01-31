public final class NumbersGenerator {
    let onValueUpdate: @Sendable (Int) -> Void
    let onComplete: @Sendable (Bool) -> Void
    
    public init(
        onValueUpdate: @escaping @Sendable (Int) -> Void,
        onComplete: @escaping @Sendable (Bool) -> Void
    ) {
        self.onValueUpdate = onValueUpdate
        self.onComplete = onComplete
    }
    
    public func start() async throws {
        for try await _ in AsyncArray(elements: Array(0...10)) {
            onValueUpdate(randomNumber())
            try? await Task.sleep(for: .seconds(Int.random(in: 1...3)))
        }
        
        onComplete(true)
    }
    
    private func randomNumber() -> Int {
        Int.random(in: 1000...9999)
    }
}
