import ComposableArchitecture
import AVFAudio

struct AudioRecorderClient {
    var currentTime: @Sendable () async -> TimeInterval?
    var requestRecordPermission: @Sendable () async -> Bool = { false }
    var startRecording: @Sendable (_ url: URL) async throws -> Bool
    var stopRecording: @Sendable () async -> Void
}

extension AudioRecorderClient: DependencyKey {
    static var liveValue: Self {
        let audioRecorder = AudioRecorderActor()
        return Self(
            currentTime: { await audioRecorder.currentTime },
            requestRecordPermission: { await AudioRecorderActor.requestPermission() },
            startRecording: { url in try await audioRecorder.start(url: url) },
            stopRecording: { await audioRecorder.stop() }
        )
    }
    
    static var previewValue: Self {
        let isRecording = ActorIsolated(false)
        let currentTime = ActorIsolated(0.0)
        
        return Self(
            currentTime: { await currentTime.value },
            requestRecordPermission: { true },
            startRecording: { _ in
                await isRecording.setValue(true)
                while await isRecording.value {
                    try await Task.sleep(for: .seconds(1))
                    await currentTime.withValue { $0 += 1 }
                }
                
                return true
            },
            stopRecording: { 
                await isRecording.setValue(false)
                await currentTime.setValue(0)
            }
        )
    }
}

extension DependencyValues {
    var audioRecorder: AudioRecorderClient {
        get { self[AudioRecorderClient.self] }
        set { self[AudioRecorderClient.self] = newValue }
    }
}

private actor AudioRecorderActor {
    var delegate: Delegate?
    var recorder: AVAudioRecorder?
    
    var currentTime: TimeInterval? {
        guard let recorder, recorder.isRecording else { return nil }
        return recorder.currentTime
    }
    
    static func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }
    
    func stop() {
        recorder?.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
    }
    
    func start(url: URL) async throws -> Bool {
        stop()
        
        print("<<< 1. before stream \(Date.now)")
        let stream = AsyncThrowingStream<Bool, Error> { continuation in
            do {
                delegate = Delegate(
                    didFinishRecording: { flag in
                        print("<<< 2a. didFinishRecording \(Date.now)")
                        continuation.yield(flag)
                        print("<<< 2b. didFinishRecording \(Date.now)")
                        continuation.finish()
                        print("<<< 2c. didFinishRecording \(Date.now)")
                        try? AVAudioSession.sharedInstance().setActive(false)
                        print("<<< 2d. didFinishRecording \(Date.now)")
                    },
                    encodeErrorDidOccur: { error in
                        continuation.finish(throwing: error)
                        try? AVAudioSession.sharedInstance().setActive(false)
                        print("<<< 3. encodeErrorDidOccur \(Date.now)")
                    }
                )
                let recorder = try AVAudioRecorder(
                    url: url,
                    settings: [
                        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                        AVSampleRateKey: 44100,
                        AVNumberOfChannelsKey: 1,
                        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                    ])
                self.recorder = recorder
                recorder.delegate = self.delegate
                
                continuation.onTermination = { [recorder = UncheckedSendable(recorder)] _ in
                    recorder.wrappedValue.stop()
                    print("<<< 4. onTermination \(Date.now)")
                }
                
                try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
                try AVAudioSession.sharedInstance().setActive(true)
                self.recorder?.record()
                
            } catch {
                continuation.finish(throwing: error)
                print("<<< 5. catch continuation \(Date.now)")
            }
        }
        
        for try await didFinish in stream {
            print("<<< 6. didFinish \(Date.now)")
            return didFinish
        }
        
        throw CancellationError()
    }
}

private final class Delegate: NSObject, AVAudioRecorderDelegate, Sendable {
    let didFinishRecording: @Sendable (Bool) -> Void
    let encodeErrorDidOccur: @Sendable (Error?) -> Void
    
    init(
        didFinishRecording: @escaping @Sendable (Bool) -> Void,
        encodeErrorDidOccur: @escaping @Sendable (Error?) -> Void
    ) {
        self.didFinishRecording = didFinishRecording
        self.encodeErrorDidOccur = encodeErrorDidOccur
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        didFinishRecording(flag)
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        encodeErrorDidOccur(error)
    }
}
