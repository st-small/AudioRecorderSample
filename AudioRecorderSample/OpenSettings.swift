import Dependencies
import UIKit

extension DependencyValues {
    var openSettings: @Sendable () async -> Void {
        get { self[OpenSettingsKey.self] }
        set { self[OpenSettingsKey.self] = newValue }
    }
    
    private enum OpenSettingsKey: DependencyKey {
        static var liveValue: @Sendable () async -> Void = {
            await MainActor.run {
                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
            }
        }
    }
}
