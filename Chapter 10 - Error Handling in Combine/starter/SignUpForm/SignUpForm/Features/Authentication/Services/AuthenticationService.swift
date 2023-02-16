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
    case transportError(Error)
}

struct AuthenticationService {
  
  /// 1: Fetching data using URLSession *without* using Combine
  func checkUserNameAvailableWithCLosure(userName: String, completion: @escaping (Result<Bool, NetworkError>) -> Void) {
    let url = URL(string: "http://127.0.0.1:8080/isUserNameAvailable?userName=\(userName)")!
    
    let task = URLSession.shared.dataTask(with: url) { data, response, error in
      if let error = error {
        completion(.failure(.transportError(error)))
        return
      }
      
      if let response = response as? HTTPURLResponse, !(200...299).contains(response.statusCode) {
        completion(.failure(.serverError(statusCode: response.statusCode)))
        return
      }
      
      guard let data = data else {
        completion(.failure(.noData))
        return
      }
      
      do {
        let decoder = JSONDecoder()
        let userAvailableMessage = try decoder.decode(UserNameAvailableMessage.self, from: data)
        completion(.success(userAvailableMessage.isAvailable))
      }
      catch {
        completion(.failure(.decodingError(error)))
      }
    }
    
    task.resume()
  }
  
  /// 2: The same code, refactored to make use of Combine to fetch data. Mapping data and decoding are not optimised at this stage.
  func checkUserNameAvailableNaive(userName: String) -> AnyPublisher<Bool, Never> {
    guard let url = URL(string: "http://127.0.0.1:8080/isUserNameAvailable?userName=\(userName)") else {
      return Just(false).eraseToAnyPublisher()
    }
    
    return URLSession.shared.dataTaskPublisher(for: url)
      .map { data, response in
        do {
          let decoder = JSONDecoder()
          let userAvailableMessage = try decoder.decode(UserNameAvailableMessage.self, from: data)
          return userAvailableMessage.isAvailable
        }
        catch {
          return false
        }
      }
      .replaceError(with: false)
      .eraseToAnyPublisher()
  }

  /// 3: The same code, making full use of Combine's capabilities for mapping data
  func checkUserNameAvailable(userName: String) -> AnyPublisher<Bool, Error> { // 仍然返回AnyPublisher<Book, Error>
    guard let url = URL(string: "http://127.0.0.1:8080/isUserNameAvailable?userName=\(userName)") else {
        return Fail(error: APIError.invalidRequestError("URL invalid")) // 如果网址不正确，返回Fail Publisher，返回错误 error参数中指定的错误
            .eraseToAnyPublisher()
    }
    
    return URLSession.shared.dataTaskPublisher(for: url)
      .mapError(APIError.transportError)
      .map(\.data)
      .decode(type: UserNameAvailableMessage.self, decoder: JSONDecoder())
      .map(\.isAvailable)
      .eraseToAnyPublisher()
  }
}

typealias Available = Result<Bool, Error>


extension Publisher {
    func asResult() -> AnyPublisher<Result<Output, Failure>, Never> {
        self
            .map(Result.success) // 如果没有错误，则转换成Result枚举变量Result.success(output)
//            .catch { error in
//                Just(.failure(error)) // 否则，如果上游有任何错误，转换成Result.failure(error)
//            }
            .mapError{ error in error}
            .eraseToAnyPublisher()
    }
}

extension Publisher {
    func asResult2() -> AnyPublisher<Result<Output, Failure>, Never> {
        self
            .map(Result.success) // 如果没有错误，则转换成Result枚举变量Result.success(output)
            .mapError(Result.failure) // 如果有错误，则转换成Result枚举变量Result.failure(error)
            .eraseToAnyPublisher()
    }
}
