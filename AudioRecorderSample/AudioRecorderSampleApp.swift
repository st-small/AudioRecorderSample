import AudioRecorderCore
import AudioRecorderView
import NumbersCore
import NumbersView
import Dependencies
import SwiftUI

@main
struct AudioRecorderSampleApp: App {
    
    @Dependency(\.temporaryDirectory) var directory
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                Form {
                    NavigationLink("Numbers stream") {
                        NumbersView(
                            store: .init(
                                initialState: NumbersCore.State(),
                                reducer: { NumbersCore() }
                            )
                        )
                    }
                    
                    NavigationLink("Audio recorder") { 
                        AudioRecorderView(
                            store: .init(
                                initialState: AudioRecorderCore.State(),
                                reducer: { AudioRecorderCore() }
                            )
                        )
                    }
                }
                .navigationTitle("Cases")
            }
        }
    }
}
