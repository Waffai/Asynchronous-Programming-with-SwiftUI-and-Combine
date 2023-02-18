import Combine
import Foundation


extension Publisher {
    
    func dump() -> AnyPublisher<Output, Failure> {
        handleEvents(receiveOutput: { value in
            Swift.dump(value)
        })
        .eraseToAnyPublisher()
    }
}


Just(Date())
    .dump()
    .sink {
        print("\($0)")
    }


    
