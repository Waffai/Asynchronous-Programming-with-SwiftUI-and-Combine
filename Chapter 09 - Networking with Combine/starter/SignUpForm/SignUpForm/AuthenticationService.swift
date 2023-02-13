//
//  CheckNameAvailable.swift
//  SignUpForm
//
//  Created by AF WU on 2023/2/13.
//

import Foundation
import Combine

class AuthenticationService {
    
    func checkUserNameAvailable(userName: String) -> AnyPublisher<Bool, Never> {
        guard let url = URL(string: "http://127.0.0.1:8080/isUserNameAvailable?userName=\(userName)") else {
            return Just(false).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: UserNameAvailableMessage.self, decoder: JSONDecoder())
            .map(\.isAvailable)
            .replaceError(with: false)
            .share()
            .eraseToAnyPublisher()
    }
}
