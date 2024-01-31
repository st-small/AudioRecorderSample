import AudioRecorderCore
import ComposableArchitecture
import Helpers
import SwiftUI

public struct AudioRecorderView: View {
    
    private let store: StoreOf<AudioRecorderCore>
    
    @State private var geoProxySize: CGSize = .zero
    @State private var recordButtonPosition: CGSize = .zero
    
    public init(store: StoreOf<AudioRecorderCore>) {
        self.store = store
    }
    
    public var body: some View {
        GeometryReader { geo in
            VStack {
                Spacer()
                
                ZStack {
                    Rectangle()
                        .fill(.gray.opacity(0.5))
                        .frame(width: geo.size.width, height: 48)
                    
                    if let _ = store.state.recordingAudio {
                        HStack {
                            Text(dateComponentsFormatter.string(from: store.state.duration) ?? "")
                                .monospacedDigit()
                            Spacer()
                            Text("Cancellation")
                                .opacity(0.5)
                            Spacer()
                            Spacer()
                        }.padding(.horizontal)
                    }
                    
                    if let track = store.state.playAudio {
                        Text("Track for play \(track.duration)")
                    }
                    
                    recordButton
                        .alert(store: store.scope(state: \.$alert, action: \.alert))
                }
                .overlay {
                    HStack {
                        Spacer()
                        
                        if store.recordingAudio != nil {
                            Capsule()
                                .fill(.purple)
                                .frame(width: 36, height: 61)
                                .offset(y: -72)
                        }
                    }
                    .padding(.horizontal, 6)
                }
            }
            .onAppear {
                geoProxySize = geo.size
                recordButtonPosition = CGSize(width: geoProxySize.width / 2 - 22, height: 0)
            }
        }
    }
    
    private var recordButton: some View {
        RecordAudioButton(
            store: store,
            viewState: $recordButtonPosition,
            magicOffsetFirst: topHelperCircleOffset,
            magicOffsetSecond: leadingHelperCircleOffset
        )
    }
    
    private var topHelperCircleOffset: OffsetModel {
        .init(id: UUID(), width: geoProxySize.width / 2 - 22, height: -81)
    }
    
    private var leadingHelperCircleOffset: OffsetModel {
        .init(id: UUID(), width: 0, height: 0)
    }
}

#Preview {
    AudioRecorderView(
        store: .init(
            initialState: AudioRecorderCore.State(),
            reducer: { AudioRecorderCore() }
        )
    )
}
