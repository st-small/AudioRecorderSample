import AudioRecorderCore
import ComposableArchitecture
import SwiftUI

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
    
    let store: StoreOf<AudioRecorderCore>
    
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
                    store.send(.startRecordTapped)
                    
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
                        print("<<< onLock")
//                        onTrash()
                        break
                    case magicOffsetSecond.id:
                        store.send(.cancelRecord)
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
//                print("<<< newValue \(newValue)")
                guard newValue == .inactive else { return }
                store.send(.stopRecordTapped)
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
