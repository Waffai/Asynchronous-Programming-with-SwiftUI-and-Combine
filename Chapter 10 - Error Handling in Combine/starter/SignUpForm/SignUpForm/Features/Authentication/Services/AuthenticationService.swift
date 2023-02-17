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

enum NetworkError: Error {
  case transportError(Error)
  case serverError(statusCode: Int)
  case noData
  case decodingError(Error)
  case encodingError(Error)
}

enum APIError: LocalizedError {
    case invalidRequestError(String)
    case invalidResponse
    case transportError(Error)
    case validationError(String)
    case decodingError
    case serverError(statusCode: Int, reason: String, retryAfter: String?)
    
    var errorDescription: String? {
        
        switch self {
        case .invalidRequestError(let message):
            return "Invalid request: \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .transportError(let error):
            return "Transport error: \(error)"
        case .validationError(let message):
            return "Validation error \(message)"
        case .decodingError:
            return "Decoding Error"
        case .serverError(statusCode: let statusCode, reason: let reason, retryAfter: let retryAfter):
            return "Server error: statuscode-\(statusCode), reason-\(reason), retryAfter-\(retryAfter ?? "") "
        }
    }

}


struct APIErrorMessage: Decodable {
    var error: Bool
    var reason: String
}

struct AuthenticationService {
  

  /// 3: The same code, making full use of Combine's capabilities for mapping data
  func checkUserNameAvailable(userName: String) -> AnyPublisher<Bool, Error> { // 仍然返回AnyPublisher<Book, Error>
      let urlString = "http://45.76.50.220:8080/isUserNameAvailable?userName=\(userName)"
    guard let url = URL(string: urlString ) else {
        return Fail(error: APIError.invalidRequestError("URL invalid")) // 如果网址不正确，返回Fail Publisher，返回错误 error参数中指定的错误
            .eraseToAnyPublisher()
    }
    
    let dataTaskPublisher =  URLSession.shared.dataTaskPublisher(for: url)
      .mapError(APIError.transportError)
      .tryMap { (data, response) -> (data: Data, response: URLResponse) in
          print("Receive response from server, now checking status code")
        guard let response = response as? HTTPURLResponse else {
          throw APIError.invalidResponse
        }
        
          if (200..<300) ~= response.statusCode {
              print("Status code is OK")
          }
          else {
              print("Status code is not OK")
              print("Status Code: \(response.statusCode)")
              let decoder = JSONDecoder()
              let error = try decoder.decode(APIErrorMessage.self, from: data)
              if response.statusCode == 400 {
                  throw APIError.validationError(error.reason)
              }
              if (500..<600) ~= response.statusCode {
                  print("500...600, server error, retry")
                  let retryAfter = response.value(forHTTPHeaderField: "RetryAfter")
                  throw APIError.serverError(statusCode: response.statusCode, reason: error.reason, retryAfter: retryAfter)
              }
          }
          return (data, response)

      }
      
      
     return dataTaskPublisher
      .tryCatch { error -> AnyPublisher<(data: Data, response: URLResponse), Error> in
          print("Error occured")
          
          if case APIError.serverError = error {
              return Just(())
                  .delay(for: 3, scheduler: DispatchQueue.global())
                  .flatMap{ _ in
                     return dataTaskPublisher
                  }
                  .retry(10)
                  .eraseToAnyPublisher()
          }
         
         throw error
      }
      .map(\.data)
//      .decode(type: UserNameAvailableMessage.self, decoder: JSONDecoder())
      .tryMap({ data -> UserNameAvailableMessage in
            print("Decoding data")
            let decoder = JSONDecoder()
          do {
              return try decoder.decode(UserNameAvailableMessage.self, from: data)
          } catch  {
              throw APIError.decodingError
          }
              
          }
          )
      .map(\.isAvailable)
      .eraseToAnyPublisher()
  }
}

typealias Available = Result<Bool, Error>




