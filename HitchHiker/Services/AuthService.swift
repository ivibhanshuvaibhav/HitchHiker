//
//  AuthService.swift
//  HitchHiker
//
//  Created by Vibhanshu Vaibhav on 09/12/17.
//  Copyright © 2017 Vibhanshu Vaibhav. All rights reserved.
//

import Foundation
import Firebase

typealias completion = (_ status: Bool, _ error: Error?) -> ()

let defaults = UserDefaults.standard

var userIsDriver: Bool {
    get {
        return defaults.bool(forKey: "isDriver")
    }
    set {
        defaults.set(newValue, forKey: "isDriver")
    }
}

var pickupIsEnabled: Bool {
    get {
        return defaults.bool(forKey: "isEnabled")
    }
    set {
        defaults.set(newValue, forKey: "isEnabled")
    }
}

class AuthService {
    
    static let instance = AuthService()
    
    func registerUser(withEmail email: String, andPassword password: String, isDriver: Bool, userCreationComplete: @escaping completion) {
        Auth.auth().createUser(withEmail: email, password: password) { (user, error) in
            guard let user = user else {
                userCreationComplete(false, error)
                return
            }
            if isDriver {
                userIsDriver = true
                pickupIsEnabled = false
                let userData = ["provider": user.providerID, DRIVER_PICKUP_ENABLED: false, DRIVER_ON_TRIP: false] as [String: Any]
                DataService.instance.createDBUser(uid: user.uid, userData: userData, isDriver: true)
            } else {
                userIsDriver = false
                let userData = ["provider": user.providerID] as [String: Any]
                DataService.instance.createDBUser(uid: user.uid, userData: userData, isDriver: false)
            }
           userCreationComplete(true, nil)
        }
    }
    
    func loginUser(withEmail email: String, andPassword password: String, loginComplete: @escaping completion) {
        Auth.auth().signIn(withEmail: email, password: password) { (user, error) in
            if error == nil {
                guard let user = user else { return }
                DataService.instance.REF_DRIVERS.observeSingleEvent(of: .value) { (snapshot) in
                    if snapshot.hasChild(user.uid) {
                        userIsDriver = true
                        pickupIsEnabled = false
                        let userData = [DRIVER_PICKUP_ENABLED: false, DRIVER_ON_TRIP: false] as [String: Any]
                        DataService.instance.createDBUser(uid: user.uid, userData: userData, isDriver: true)
                        loginComplete(true, nil)
                    } else {
                        userIsDriver = false
                        loginComplete(true, nil)
                    }
                }
            } else {
                loginComplete(false, error)
            }
        }
    }
    
}
