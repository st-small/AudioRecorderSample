import ComposableArchitecture
import SwiftUI

@Reducer
struct AudioRecord {
    @ObservableState
    struct State: Equatable {
        var date: Date
        var duration: TimeInterval = 0
        var mode: Mode = .recording
        var url: URL
    }
    
    enum Mode {
        case recording
        case encoding
    }
    
    enum Action {
        case onTask
        case timerUpdated
        case audioRecorderDidFinish(Result<Bool, Error>)
        case delegate(Delegate)
        case stopButtonTapped
        case finalRecordingTime(TimeInterval)
    }
    
    enum Delegate {
        case didFinish(Result<State, Error>)
    }
    
    struct Failed: Equatable, Error { }
    
    @Dependency(\.audioRecorder) var audioRecorder
    @Dependency(\.continuousClock) var clock
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onTask:
                return .run { [url = state.url] send in
                    async let startRecording: Void = send(
                        .audioRecorderDidFinish(
                            Result { try await audioRecorder.startRecording(url) }
                        )
                    )
                    
                    for await _ in clock.timer(interval: .seconds(1)) {
                        await send(.timerUpdated)
                    }
                    
                    await startRecording
                }
            case .timerUpdated:
                state.duration += 1
                return .none
            case .audioRecorderDidFinish(.success(true)):
                return .send(.delegate(.didFinish(.success(state))))
            case .audioRecorderDidFinish(.success(false)):
                return .send(.delegate(.didFinish(.failure(Failed()))))
            case let .audioRecorderDidFinish(.failure(error)):
                return .send(.delegate(.didFinish(.failure(error))))
            case .delegate:
                return .none
            case .stopButtonTapped:
                state.mode = .encoding
                return .run { send in
                    if let currentTime = await audioRecorder.currentTime() {
                        await send(.finalRecordingTime(currentTime))
                    }
                    
                    await audioRecorder.stopRecording()
                }
            case let .finalRecordingTime(duration):
                state.duration = duration
                return .none
            }
        }
    }
}

struct AudioRecordView: View {
    let store: StoreOf<AudioRecord>
    
    var body: some View {
        Text("\(store.state.duration)")
            .task {
                await store.send(.onTask).finish()
            }
    }
}
