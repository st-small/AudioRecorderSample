import ComposableArchitecture
import Foundation

extension DependencyValues {
    public var temporaryDirectory: @Sendable () -> URL {
        get { self[TemporaryDirectoryKey.self] }
        set { self[TemporaryDirectoryKey.self] = newValue }
    }
    
    private enum TemporaryDirectoryKey: DependencyKey {
        static var liveValue: @Sendable () -> URL = { URL(fileURLWithPath: NSTemporaryDirectory()) }
    }
}

