import ComposableArchitecture
import NumbersClient

@Reducer
public struct NumbersCore {
    
    @Dependency(\.numbers) private var numbers
    
    public init() { }
    
    public struct State: Equatable {
        public var number: Int = 0
        public var isCompleted = false
        
        public init() { }
    }
    
    public enum Action: Equatable {
        case onAppear
        case numbersClient(NumbersClient.Action)
        case reloadStreamTapped
        case onDisappear
    }
    
    enum CancelID { case stream }
    
    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear, .reloadStreamTapped:
                state.isCompleted = false
                
                return .run { send in
                    for await action in await numbers.start() {
                        await send(.numbersClient(action))
                    }
                }
                .cancellable(id: CancelID.stream)
            case .numbersClient(.number(let value)):
                state.number = value
                return .none
            case .numbersClient(.finish):
                state.isCompleted = true
                return .none
            case .onDisappear:
                return .cancel(id: CancelID.stream)
            }
        }
    }
}
