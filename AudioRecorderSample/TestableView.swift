import AVFAudio
import ConcurrencyExtras
import Dependencies
import SwiftUI

struct TestableView: View {
    
    @Dependency(\.uuid) var uuid
    @Dependency(\.temporaryDirectory) var temporaryDirectory
    
    @State private var isRecording = false
    private let audioRecorder = AudioRecorderActor2()
    
    var body: some View {
        Button(isRecording ? "Stop recording" : "Start") {
            print("<<< 7. Button tapped \(Date.now)")
            if isRecording {
                audioRecorder.stop()
            } else {
                Task {
                    try? await audioRecorder.start(url: newURL)
                }
            }
            
            isRecording.toggle()
        }
    }
    
    private var newURL: URL {
        temporaryDirectory()
            .appendingPathComponent(uuid().uuidString)
            .appendingPathExtension("m4a")
    }
}

#Preview {
    TestableView()
}

final class AudioRecorderActor2 {
    var delegate: Delegate2?
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
                delegate = Delegate2(
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

final class Delegate2: NSObject, AVAudioRecorderDelegate, Sendable {
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
