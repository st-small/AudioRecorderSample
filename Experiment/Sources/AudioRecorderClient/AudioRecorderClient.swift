import AVFoundation
import ComposableArchitecture

public struct AudioRecorderClient {
    public var permissions: @Sendable () async -> Bool
    public var startRecord: @Sendable (URL) async -> AsyncStream<Action>
    public var stopRecord: @Sendable (Bool) async -> Void
    
    public enum Action { 
        case recordingComplete(duration: TimeInterval, url: URL)
    }
}

extension DependencyValues {
    public var audioRecorder: AudioRecorderClient {
        get { self[AudioRecorderClient.self] }
        set { self[AudioRecorderClient.self] = newValue }
    }
}

extension AudioRecorderClient: DependencyKey {
    public static var liveValue: AudioRecorderClient {
        let actor = Recorder()
        
        return .init(
            permissions: { await AVAudioApplication.requestRecordPermission() },
            startRecord: { await actor.start($0) },
            stopRecord: { await actor.stop($0) }
        )
    }
    
    public static var previewValue: AudioRecorderClient {
        .init(
            permissions: { false },
            startRecord: { _ in return .never },
            stopRecord: { _ in }
        )
    }
}

extension AudioRecorderClient {
    private actor Recorder {
        private var recorder: AudioRecorder?
        
        func start(_ url: URL) -> AsyncStream<Action> {
            AsyncStream<Action> { continuation in
                let recorder = AudioRecorder { duration, url in
                    continuation.yield(.recordingComplete(duration: duration, url: url))
                    continuation.finish()
                } onForceFinish: {
                    continuation.finish()
                }
                
                self.recorder = recorder
                
                Task {
                    await recorder.start(url)
                }
            }
        }
        
        func stop(_ force: Bool) async {
            await recorder?.stop(force)
        }
    }
}

public final class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    private var recordingSession: AVAudioSession!
    private var audioRecorder: AVAudioRecorder!
    
    private var onFinish: (@Sendable (TimeInterval, URL) -> Void)?
    private var onForceFinish: (@Sendable () -> Void)?
    
    convenience init(
        onFinish: @Sendable @escaping (TimeInterval, URL) -> Void,
        onForceFinish: @Sendable @escaping () -> Void
    ) {
        self.init()
        self.onFinish = onFinish
        self.onForceFinish = onForceFinish
    }
    
    override init() {
        self.recordingSession = AVAudioSession.sharedInstance()
        
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default)
            try recordingSession.setActive(true)
        } catch {
            preconditionFailure()
        }
    }
    
    public func start(_ url: URL) async {
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder.delegate = self
            audioRecorder.record()
        } catch {
            await finishRecording(.failure(error))
        }
    }
    
    public func stop(_ force: Bool = false) async {
        let duration = audioRecorder.currentTime
        let url = audioRecorder.url
        
        if force {
            await finishRecording(.failure(AudioRecorderError.forceFinish))
        } else {
            await finishRecording(.success((duration, url)))
        }
    }
    
    private func finishRecording(_ result: Result<(TimeInterval, URL), Error>) async {
        audioRecorder.stop()
        audioRecorder = nil
        
        switch result {
        case let .success(result):
            onFinish?(result.0, result.1)
        case let .failure(error):
            print("Error: \(error)")
        }
    }
    
    public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            Task {
                await finishRecording(.failure(AudioRecorderError.didFinishFail))
            }
        }
    }
}

enum AudioRecorderError: Error {
    case didFinishFail
    case forceFinish
}
