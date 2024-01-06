import ComposableArchitecture
import SwiftUI

struct ContentView: View {
    let store: StoreOf<AudioRecorder>
    
    @State private var geoProxySize: CGSize = .zero
    @State private var recordButtonPosition: CGSize = .zero
    
    var body: some View {
        GeometryReader { geo in
            VStack {
                Spacer()
                
                ZStack {
                    Rectangle()
                        .fill(.gray.opacity(0.5))
                        .frame(width: geo.size.width, height: 48)
                    
                    if let recording = store.scope(state: \.recordingAudio, action: \.recordingAudio) {
                        AudioRecordView(store: recording)
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

struct OffsetModel {
    let id: UUID
    let width: CGFloat
    let height: CGFloat
}

struct RecordAudioButton: View {
    enum DragState: Equatable {
        case inactive
        case pressing
        case dragging(translation: CGSize)
        
        var translation: CGSize {
            switch self {
            case .inactive, .pressing:
                return .zero
            case let .dragging(translation):
                return translation
            }
        }
        
        var isActive: Bool {
            switch self {
            case .inactive:
                return false
            case .pressing, .dragging:
                return true
            }
        }
        
        var isDragging: Bool {
            switch self {
            case .inactive, .pressing:
                return false
            case .dragging:
                return true
            }
        }
    }
    
    let store: StoreOf<AudioRecorder>
    
    @Binding var viewState: CGSize
    let magicOffsetFirst: OffsetModel
    let magicOffsetSecond: OffsetModel
    
    // MARK: - Private
    @GestureState private var dragState = DragState.inactive
    private let minimumLongPressDuration = 0.01
    
    var body: some View {
        let longPressDrag = LongPressGesture(minimumDuration: minimumLongPressDuration)
            .sequenced(before: DragGesture())
            .updating($dragState) { value, state, transaction in
                switch value {
                /// Long press begins
                case .first(true):
                    state = .pressing
                    store.send(.recordButtonTapped)
                    
                /// Long press confirmed, dragging may begin
                case .second(true, let drag):
                    state = .dragging(translation: drag?.translation ?? .zero)
                    
                /// Dragging ended or the long press cancelled
                default:
                    state = .inactive
                }
            }
            .onChanged { value in
                guard case .second(true, let drag?) = value else { return }
                let newXPosition = viewState.width + drag.translation.width
                let newYPosition = viewState.height + drag.translation.height
                
                let currentOffset = OffsetModel(id: UUID(), width: newXPosition, height: newYPosition)
                
                if let id = findNearestOffset(
                    currentOffset,
                    from: [magicOffsetFirst, magicOffsetSecond]
                ) {
                    switch id {
                    case magicOffsetFirst.id:
//                        onTrash()
                        break
                    case magicOffsetSecond.id:
//                        onLock()
                        break
                    default:
                        break
                    }
                }
            }
        
        return Circle()
            .fill(.clear)
            .overlay(
                dragState.isDragging
                ? AnyView(recordView)
                : AnyView(micView)
            )
            .animation(.easeInOut, value: dragState.isDragging)
            .frame(
                width: 75,
                height: 75,
                alignment: .center
            )
            .offset(
                x: viewState.width + dragState.translation.width,
                y: viewState.height + dragState.translation.height
            )
            .animation(.snappy(duration: 0.3), value: dragState.isActive)
            .shadow(radius: dragState.isActive ? 8 : 0)
            .animation(.linear(duration: minimumLongPressDuration), value: dragState.isActive)
            .gesture(longPressDrag)
            .overlay {
                VStack {
                    Text("mainOffset \(viewState.width + dragState.translation.width, specifier: "%.2f") \(viewState.height + dragState.translation.height, specifier: "%.2f")")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                    
                    Text("magicOffsetFirst \(magicOffsetFirst.width, specifier: "%.2f") \(magicOffsetFirst.height, specifier: "%.2f")")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        
                    Text("magicOffsetSecond \(magicOffsetSecond.width, specifier: "%.2f") \(magicOffsetSecond.height, specifier: "%.2f")")
                        .font(.system(size: 12))
                        .foregroundStyle(.white)
                        
                }
                .frame(width: 200)
                .background(.black)
                .offset(y: -200)
            }
            .onChange(of: $dragState.wrappedValue) { oldValue, newValue in
                print("<<< newValue \(newValue)")
                guard newValue == .inactive else { return }
                store.send(.recordButtonReleased)
            }
    }
    
    private var micView: some View {
        Image(systemName: "mic.fill")
    }
    
    private var recordView: some View {
        Circle()
            .fill(.purple)
            .overlay(
                Image(systemName: "record.circle")
                    .font(.title)
                    .foregroundStyle(.white)
            )
    }
    
    private func findNearestOffset(_ current: OffsetModel, from: [OffsetModel]) -> UUID? {
        var results: [Int: [OffsetModel]] = [:]
        from.forEach { model in
            let widthDiff = abs(model.width - current.width)
            let heightDiff = abs(model.height - current.height)
            
            if widthDiff <= 10 && heightDiff <= 10 {
                let diffSum = Int(widthDiff + heightDiff)
                if results[diffSum] != nil {
                    results[diffSum]?.append(model)
                } else {
                    results[diffSum] = [model]
                }
            }
        }
        
        return results.sorted(by: { $0.key < $1.key })
            .first?.value.first?.id
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
