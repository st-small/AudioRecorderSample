import Dependencies
import SwiftUI

@main
struct AudioRecorderSampleApp: App {
    
    @Dependency(\.temporaryDirectory) var directory
    
    var body: some Scene {
        WindowGroup {
            ContentView(
                store: .init(
                    initialState: AudioRecorder.State(),
                    reducer: {
                        AudioRecorder()
//                            ._printChanges()
                    }
                )
            )
            .onAppear {
                print(directory())
            }
        }
    }
}
