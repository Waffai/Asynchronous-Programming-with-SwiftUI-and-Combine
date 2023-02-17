//
//  Publisher+Extension.swift
//  SignUpForm
//
//  Created by AF WU on 2023/2/16.
//

import Foundation
import Combine


extension Publisher {
    func asResult() -> AnyPublisher<Result<Output, Failure>, Never> {
        map(Result.success)
            .catch { Just(.failure($0)) }
            .eraseToAnyPublisher()
    }
}
