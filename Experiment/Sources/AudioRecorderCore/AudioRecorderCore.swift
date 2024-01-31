import AudioRecorderClient
import ComposableArchitecture
import TemporaryDirectory
import UIKit

@Reducer
public struct AudioRecorderCore {
    
    public init() { }
    
    @ObservableState
    public struct State: Equatable {
        @Presents public var alert: AlertState<Action.Alert>?
        var audioRecordPermission = RecorderPermission.undetermined
        public var recordingAudio: AudioRecord?
        public var playAudio: AudioTrack?
        public var duration: TimeInterval = 0
        
        enum RecorderPermission {
            case denied
            case allowed
            case undetermined
        }
        
        public init() { }
    }
    
    public enum Action: Equatable {
        case alert(PresentationAction<Alert>)
        case startRecordTapped
        case stopRecordTapped
        case recordPermissionResponse(Bool)
        case startRecord
        case stopRecord(AudioTrack)
        case timerUpdated
        case cancelRecord
        
        public enum Alert: Equatable {
            case cancelTapped
            case openSettingsButtonTapped
        }
    }
    
    @Dependency(\.audioRecorder) private var audioRecorder
    @Dependency(\.continuousClock) private var clock
    @Dependency(\.temporaryDirectory) private var temporaryDirectory
    @Dependency(\.uuid) private var uuid
    
    public enum TimerID {
        case timer
    }
    
    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .alert(.presented(.openSettingsButtonTapped)):
                return .run { send in
                    await MainActor.run {
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                    }
                }
            case .alert:
                return .none
            case .startRecordTapped:
                switch state.audioRecordPermission {
                case .denied:
                    state.alert = deniedPermissionsState
                    return .none
                case .allowed:
                    return .run { send in
                        await send(.startRecord)
                    }
                case .undetermined:
                    return .run { send in
                        await send(.recordPermissionResponse(await audioRecorder.permissions()))
                    }
                }
            case .stopRecordTapped:
                state.recordingAudio = nil
                state.duration = 0
                return .run { send in
                    await audioRecorder.stopRecord(false)
                }
            case .recordPermissionResponse(let isAllowed):
                state.audioRecordPermission = isAllowed ? .allowed : .denied
                
                if isAllowed {
                    return .run { send in
                        await send(.startRecord)
                    }
                } else {
                    state.alert = deniedPermissionsState
                    return .none
                }
                
            case .startRecord:
                let newRecord = newAudioRecord
                state.playAudio = nil
                state.recordingAudio = newRecord
                
                return .run { send in
                    await withThrowingTaskGroup(of: Void.self) { group in
                        group.addTask {
                            for await _ in clock.timer(interval: .seconds(1)) {
                                await send(.timerUpdated)
                            }
                        }
                        
                        group.addTask {
                            for await action in await audioRecorder.startRecord(newRecord.url) {
                                switch action {
                                case let .recordingComplete(duration, url):
                                    let track = AudioTrack(duration: duration, url: url)
                                    await send(.stopRecord(track))
                                }
                            }
                        }
                    }
                }
                .cancellable(id: TimerID.timer)
            case let .stopRecord(track):
                state.playAudio = track
                return .cancel(id: TimerID.timer)
            case .timerUpdated:
                state.duration += 1
                return .none
            case .cancelRecord:
                /// Данное действие должно:
                /// 1. Остановить запись звука
                /// 2. Вернуть начальное состояние без к.-л. изменений
                /// просто отмена записи, для пользователя ничего не произошло
                return .none
            }
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
    
    private var newAudioRecord: AudioRecord {
        AudioRecord(
            date: .now,
            url: temporaryDirectory()
                .appendingPathComponent(uuid().uuidString)
                .appendingPathExtension("m4a")
        )
    }
}

// TODO: Replace this logic into separate library
public struct AudioRecord: Equatable {
    var date: Date
    var url: URL
}

public struct AudioTrack: Equatable {
    public let duration: TimeInterval
    public let url: URL
}
