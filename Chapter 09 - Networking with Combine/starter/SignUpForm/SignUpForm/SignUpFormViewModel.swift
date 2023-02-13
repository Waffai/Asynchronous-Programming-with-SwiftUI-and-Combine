//
//  SignUpFormViewModel.swift
//  SignUpForm
//
//  Created by AF WU on 2023/2/13.
//

import SwiftUI
import Combine
import Navajo_Swift



// MARK: - View Model
class SignUpFormViewModel: ObservableObject {
    private var authenticationService = AuthenticationService()
    
    // MARK: Input
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var passwordConfirmation: String = ""
    
    // MARK: Output
    @Published var usernameMessage: String = ""
    @Published var passwordMessage: String = ""
    @Published var passwordStrengthValue: Double = 0.0
    @Published var passwordStrengthColor: Color = .red
    @Published var isValid: Bool = false
    
    
    init() {
        isFormValidPublisher
            .assign(to: &$isValid) // eveluate all conditions for form validation
        
        Publishers.CombineLatest(isUsernameLengthValidPublisher, isUsernameAvailablePublisher)
            .map {
                if !$0 {
                    return "Username too short. Needs to be at least 3 characters."
                } else if !$1 {
                    return "Username has been used, please choose another name"
                }
                return ""
            }
            .assign(to: &$usernameMessage) // username message assigning
        
        passwordStrengthPublisher
            .map {
                switch $0 {
                case .veryWeak: return 0.25
                case .weak: return 0.35
                case .reasonable: return 0.5
                case .strong: return 0.75
                case .veryStrong: return 1
                }
            }
            .assign(to: &$passwordStrengthValue) // password strength value assigning
        
        passwordStrengthPublisher
            .map {
                switch $0 {
                case .veryWeak: return .red
                case .weak: return .red
                case .reasonable: return .orange
                case .strong: return .yellow
                case .veryStrong: return .green
                }
            }
            .assign(to: &$passwordStrengthColor) // password strength color assignning
        
        
        Publishers.CombineLatest4(isPasswordEmptyPublisher, isPasswordLengthValidPublisher, isPasswordStrongEnoughPublisher, isPasswordMatchingPublisher)
            .map { isPasswordEmpty, isPasswordLengthValid, isPasswordStrongEnough, isPasswordMatching in
                if isPasswordEmpty {
                    return "Password must not be empty"
                }
                else if !isPasswordLengthValid {
                    return "Password needs to be at least 8 characters"
                }
                else if !isPasswordStrongEnough {
                    return "Password not strong enough"
                }
                else if !isPasswordMatching {
                    return "Passwords do not match"
                }
                return ""
            }
            .assign(to: &$passwordMessage)
    }
    
    
    // MARK: Username validattion
    private lazy var isUsernameLengthValidPublisher: AnyPublisher<Bool, Never> = {
        $username
            .map { $0.count >= 3 }
            .eraseToAnyPublisher()
    }()
    
    private lazy var isUsernameAvailablePublisher: AnyPublisher<Bool, Never> = {
        $username
            .filter{$0.count >= 3}
            .debounce(for: 0.8, scheduler: DispatchQueue.main)
            .removeDuplicates()
            .print("username print:")
            .flatMap { username in
                self.authenticationService.checkUserNameAvailable(userName: username)
            }
            .receive(on: DispatchQueue.main)
            .share()
            .print("username share print: ")
            .eraseToAnyPublisher()
    }()
    
    private lazy var isUsernameValidPublisher: AnyPublisher<Bool, Never> = {
        Publishers.CombineLatest(isUsernameLengthValidPublisher, isUsernameAvailablePublisher)
            .map { $0 && $1 }
            .eraseToAnyPublisher()
    }()
    
    // MARK: Password validation
    private lazy var isPasswordEmptyPublisher: AnyPublisher<Bool, Never> = {
        $password
            .map(\.isEmpty)
        // equivalent to
        // .map { $0.isEmpty }
            .eraseToAnyPublisher()
    }()
    
    private lazy var isPasswordLengthValidPublisher: AnyPublisher<Bool, Never> = {
        $password
            .map { $0.count >= 8 }
            .eraseToAnyPublisher()
    } ()
    
    private lazy var isPasswordMatchingPublisher: AnyPublisher<Bool, Never> = {
        Publishers.CombineLatest($password, $passwordConfirmation)
            .map(==)
        // equivalent to
        // .map { $0 == $1 }
            .eraseToAnyPublisher()
    }()
    
    private lazy var passwordStrengthPublisher: AnyPublisher<PasswordStrength, Never> = {
        $password
            .map(Navajo.strength(ofPassword:))
            .eraseToAnyPublisher()
    }()
    
    private lazy var isPasswordStrongEnoughPublisher: AnyPublisher<Bool, Never> = {
        passwordStrengthPublisher
            .map { passwordStrength in
                switch passwordStrength {
                case .veryWeak, .weak:
                    return false
                case .reasonable, .strong, .veryStrong:
                    return true
                }
            }
            .eraseToAnyPublisher()
    }()
    
    private lazy var isPasswordValidPublisher: AnyPublisher<Bool, Never> = {
        Publishers.CombineLatest4(isPasswordEmptyPublisher, isPasswordLengthValidPublisher, isPasswordStrongEnoughPublisher, isPasswordMatchingPublisher)
            .map { !$0 && $1 && $2 && $3 }
            .eraseToAnyPublisher()
    }()
    
    // MARK: Form validation
    private lazy var isFormValidPublisher: AnyPublisher<Bool, Never> = {
        Publishers.CombineLatest(isUsernameValidPublisher, isPasswordValidPublisher)
            .map { $0 && $1 }
            .eraseToAnyPublisher()
    }()
    
    
}
