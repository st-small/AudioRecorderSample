import ComposableArchitecture
import Foundation

@Reducer
struct AudioRecorder {
    @ObservableState
    struct State: Equatable {
        @PresentationState var alert: AlertState<Action.Alert>?
        var audioRecordPermission = RecorderPermission.undetermined
        var recordingAudio: AudioRecord.State?
        
        enum RecorderPermission {
            case allowed
            case denied
            case undetermined
        }
    }
    
    enum Action {
        case alert(PresentationAction<Alert>)
        case recordButtonTapped
        case recordButtonReleased
        case recordPermissionResponse(Bool)
        case recordingAudio(AudioRecord.Action)
        
        enum Alert: Equatable {
            case cancelTapped
            case openSettingsButtonTapped
        }
    }
    
    @Dependency(\.openSettings) var openSettings
    @Dependency(\.audioRecorder.requestRecordPermission) var requestRecordPermission
    @Dependency(\.temporaryDirectory) var temporaryDirectory
    @Dependency(\.uuid) var uuid
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .alert(.presented(.openSettingsButtonTapped)):
                return .run { _ in
                  await self.openSettings()
                }
            case .alert:
                return .none
            case .recordButtonTapped:
                switch state.audioRecordPermission {
                case .allowed:
                    state.recordingAudio = newAudioRecord
                    return .none
                case .denied:
                    state.alert = deniedPermissionsState
                    return .none
                case .undetermined:
                    return .run { send in
                        await send(.recordPermissionResponse(requestRecordPermission()))
                    }
                }
            case .recordButtonReleased:
                print("<<< 0. recordButtonReleased \(Date.now)")
                return .run { send in
                    print("<<< -1. .recordingAudio(.stopButtonTapped) \(Date.now)")
                    await send(.recordingAudio(.stopButtonTapped))
                }
            case let .recordPermissionResponse(permission):
                state.audioRecordPermission = permission ? .allowed : .denied
                
                if permission {
                    state.recordingAudio = newAudioRecord
                    return .none
                } else {
                    state.alert = deniedPermissionsState
                    return .none
                }
            case let .recordingAudio(.delegate(.didFinish(.success(recordAudio)))):
                state.recordingAudio = nil
                return .none
            case .recordingAudio(.delegate(.didFinish(.failure))):
                state.alert = AlertState(title: { TextState("Audio recording failed.") })
                state.recordingAudio = nil
                return .none
            case .recordingAudio:
                return .none
            }
        }
        .ifLet(\.alert, action: \.alert)
        .ifLet(\.recordingAudio, action: \.recordingAudio) {
            AudioRecord()
        }
    }
    
    private var deniedPermissionsState: AlertState<Action.Alert> {
        AlertState(
            title: { TextState("Error") },
            actions: {
                ButtonState(action: .send(.openSettingsButtonTapped)) {
                    TextState("Settings")
                }
                
                ButtonState(role: .cancel) {
                    TextState("Cancel")
                }
            },
            message: { TextState("Permission is required to record voice.") }
        )
    }
    
    private var newAudioRecord: AudioRecord.State {
        AudioRecord.State(
            date: .now,
            url: temporaryDirectory()
                .appendingPathComponent(uuid().uuidString)
                .appendingPathExtension("m4a")
        )
    }
}
