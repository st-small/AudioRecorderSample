import ComposableArchitecture
import NumbersCore
import SwiftUI

public struct NumbersView: View {
    
    private let store: StoreOf<NumbersCore>
    
    public init(store: StoreOf<NumbersCore>) {
        self.store = store
    }
    
    public var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack {
                Spacer()
                
                Text("Number is")
                    .padding(.bottom, 10)
                Text(verbatim: "\(viewStore.state.number)")
                    .font(.system(.largeTitle, weight: .bold))
                    .padding(.bottom, 100)
                
                if viewStore.state.isCompleted {
                    Text("Stream completed!")
                } else {
                    Text("Stream is in progress...")
                }
                
                Spacer()
                
                Button("Reload stream") {
                    viewStore.send(.reloadStreamTapped)
                }
                .disabled(!viewStore.state.isCompleted)
            }
            .onAppear {
                viewStore.send(.onAppear)
            }
            .onDisappear {
                viewStore.send(.onDisappear)
            }
        }
    }
}

#Preview {
    NumbersView(
        store: Store(
            initialState: NumbersCore.State(),
            reducer: { NumbersCore() },
            withDependencies: { $0.numbers = .previewValue }
        )
    )
}
