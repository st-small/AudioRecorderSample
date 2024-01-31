final class AsyncArray: AsyncSequence, AsyncIteratorProtocol {
    typealias Element = Int
    
    private var elements: [Int]
    
    init(elements: [Int]) {
        self.elements = elements
    }
    
    func makeAsyncIterator() -> AsyncArray { self }
    
    func next() async throws -> Int? {
        await getNextElement()
    }
    
    private func getNextElement() async -> Int? {
        guard !elements.isEmpty else { return nil }
        return elements.removeFirst()
    }
}
