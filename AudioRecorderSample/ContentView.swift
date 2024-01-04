import ComposableArchitecture
import SwiftUI

struct ContentView: View {
    let store: StoreOf<AudioRecorder>
    
    @GestureState private var isDetectingLongPress = false
    @State private var completedLongPress = false
    @State private var scaleFactor: CGFloat = 1
    
    var body: some View {
        VStack {
            if let recording = store.scope(state: \.recordingAudio, action: \.recordingAudio) {
                AudioRecordView(store: recording)
            }
            
            recordButton
            .alert(store: store.scope(state: \.$alert, action: \.alert))
        }
    }
    
    private var recordButton: some View {
        Image(systemName: "mic.fill")
            .imageScale(.large)
            .foregroundStyle(scaleFactor == 1 ? .blue : .pink)
            .padding()
            .background {
                Circle()
                    .fill(.white)
                    .shadow(radius: 5)
            }
            .scaleEffect(scaleFactor)
            .gesture(longPress)
            .onChange(of: isDetectingLongPress) { _, value in
                if value == false {
                    withAnimation {
                        scaleFactor = 1
                        store.send(.recordButtonReleased)
                    }
                }
            }
    }
    
    var longPress: some Gesture {
        LongPressGesture(minimumDuration: 0.01)
            .sequenced(before: LongPressGesture(minimumDuration: .infinity))
            .updating($isDetectingLongPress) { currentState, gestureState, transaction in
                switch currentState {
                case .second(true, nil):
                    gestureState = true
                    DispatchQueue.main.async {
                        withAnimation {
                            self.scaleFactor = 0.75
                            self.store.send(.recordButtonTapped)
                        }
                    }
                default:
                    break
                }
            }
    }
}

#Preview {
    ContentView(
        store: .init(
            initialState: AudioRecorder.State(),
            reducer: {
                AudioRecorder()
            }
        )
    )
}
