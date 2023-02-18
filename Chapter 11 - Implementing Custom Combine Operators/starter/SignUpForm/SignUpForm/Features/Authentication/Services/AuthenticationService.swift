//
//  AuthenticationService.swift
//  SignUpForm
//
//  Created by Peter Friese on 04.01.22.
//

import Foundation
import Combine
import UIKit

struct UserNameAvailableMessage: Codable {
  var isAvailable: Bool
  var userName: String
}

struct APIErrorMessage: Decodable {
  var error: Bool
  var reason: String
}

enum APIError: LocalizedError {
  /// Invalid request, e.g. invalid URL
  case invalidRequestError(String)
  
  /// Indicates an error on the transport layer, e.g. not being able to connect to the server
  case transportError(Error)
  
  /// Received an invalid response, e.g. non-HTTP result
  case invalidResponse
  
  /// Server-side validation error
  case validationError(String)
  
  /// The server sent data in an unexpected format
  case decodingError(Error)
  
  /// General server-side error. If `retryAfter` is set, the client can send the same request after the given time.
  case serverError(statusCode: Int, reason: String? = nil, retryAfter: String? = nil)

  var errorDescription: String? {
    switch self {
    case .invalidRequestError(let message):
      return "Invalid request: \(message)"
    case .transportError(let error):
      return "Transport error: \(error)"
    case .invalidResponse:
      return "Invalid response"
    case .validationError(let reason):
      return "Validation Error: \(reason)"
    case .decodingError:
      return "The server returned data in an unexpected format. Try updating the app."
    case .serverError(let statusCode, let reason, let retryAfter):
      return "Server error with code \(statusCode), reason: \(reason ?? "no reason given"), retry after: \(retryAfter ?? "no retry after provided")"
    }
  }
}

struct AuthenticationService {
  
  func checkUserNameAvailablePublisher(userName: String) -> AnyPublisher<Bool, Error> {
    guard let url = URL(string: "http://127.0.0.1:8080/isUserNameAvailable?userName=\(userName)") else {
      return Fail(error: APIError.invalidRequestError("URL invalid"))
        .eraseToAnyPublisher()
    }
    
    let dataTaskPublisher = URLSession.shared.dataTaskPublisher(for: url)
      // handle URL errors (most likely not able to connect to the server)
      .mapError { error -> Error in
        return APIError.transportError(error)
      }
    
      // handle all other errors
      .tryMap { (data, response) -> (data: Data, response: URLResponse) in
        print("Received response from server, now checking status code")
        
        guard let urlResponse = response as? HTTPURLResponse else {
          throw APIError.invalidResponse
        }
        
        if (200..<300) ~= urlResponse.statusCode {
        }
        else {
          let decoder = JSONDecoder()
          let apiError = try decoder.decode(APIErrorMessage.self, from: data)
          
          if urlResponse.statusCode == 400 {
            throw APIError.validationError(apiError.reason)
          }
          
          if (500..<600) ~= urlResponse.statusCode {
            let retryAfter = urlResponse.value(forHTTPHeaderField: "Retry-After")
            throw APIError.serverError(statusCode: urlResponse.statusCode, reason: apiError.reason, retryAfter: retryAfter)
          }

        }
        return (data, response)
      }

    return dataTaskPublisher
          .retry(10, withDelay: 3) {
            if case APIError.serverError = $0 {
              return true
            }
            return false
          }
//      .tryCatch { error -> AnyPublisher<(data: Data, response: URLResponse), Error> in
//        if case APIError.serverError = error {
//          return Just(Void())
//            .delay(for: 3, scheduler: DispatchQueue.global())
//            .flatMap { _ in
//              return dataTaskPublisher
//            }
//            .print("before retry")
//            .retry(10)
//            .eraseToAnyPublisher()
//        }
//        throw error
//      }
      .map(\.data)
//      .decode(type: UserNameAvailableMessage.self, decoder: JSONDecoder())
      .tryMap { data -> UserNameAvailableMessage in
        let decoder = JSONDecoder()
        do {
          return try decoder.decode(UserNameAvailableMessage.self, from: data)
        }
        catch {
          throw APIError.decodingError(error)
        }
      }
      .map(\.isAvailable)
//      .replaceError(with: false)
      .eraseToAnyPublisher()
  }
  
}


extension Publisher {
    func retry<T, E>(_ retries: Int,
                     withBackoff initialBackoff: Int,
                     condition: ((E) -> Bool)? = nil)
    -> Publishers.TryCatch<Self, AnyPublisher<T, E>>
    where T == Self.Output, E == Self.Failure {
        
        return self.tryCatch { error -> AnyPublisher<T, E> in
            // 如果错误满足条件，则重试
            if condition?(error) ?? true {
                // 初始的 backoff 值
                var backoff = initialBackoff
                
                // 发出一个空元素，然后延迟指定的时间，重试原始 Publisher，得到一个新的 Publisher
                return Just(Void())
                    .flatMap({ _ -> AnyPublisher<T, E>  in
                        // 延迟一段时间后重新订阅原始 Publisher，得到新的 Publisher
                        let result  = Just(Void())
                            .delay(for: .init(integerLiteral: backoff), scheduler: DispatchQueue.global())
                            .flatMap{ _ in
                                return self
                            }
                        // 将 backoff 乘以 2，以便下一次增加重试时间
                        backoff = backoff * 2
                        // 返回得到的新的 Publisher
                        return result.eraseToAnyPublisher()
                    })
                    
                    // 将新的 Publisher 再次进行重试，最多尝试 retries - 1 次
                    .retry(retries - 1)
                    // 将最终的 Publisher 转换为 AnyPublisher<T, E> 类型
                    .eraseToAnyPublisher()
            }
            // 如果错误不满足条件，则直接抛出错误
            else {
                throw error
            }
        }
    }
}

