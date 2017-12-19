//
//  DataService.swift
//  HitchHiker
//
//  Created by Vibhanshu Vaibhav on 09/12/17.
//  Copyright © 2017 Vibhanshu Vaibhav. All rights reserved.
//

import Foundation
import Firebase
import CoreLocation

let DB_BASE = Database.database().reference()

class DataService {
    
    static let instance = DataService()
    
    public private(set) var REF_BASE = DB_BASE
    public private(set) var REF_USERS = DB_BASE.child("users")
    public private(set) var REF_DRIVERS = DB_BASE.child("drivers")
    public private(set) var REF_TRIPS = DB_BASE.child("trips")
    
    func createDBUser(uid: String, userData: Dictionary<String, Any>, isDriver: Bool) {
        if isDriver {
            REF_DRIVERS.child(uid).updateChildValues(userData)
        } else {
            REF_USERS.child(uid).updateChildValues(userData)
        }
    }
    
    func updateUserLocation(uid: String, withCoordinates coordinate: CLLocationCoordinate2D) {
        if userIsDriver {
            if pickupIsEnabled {
                self.createDBUser(uid: uid, userData: ["coordinates": [coordinate.latitude, coordinate.longitude]], isDriver: true)
            } else {
                self.REF_DRIVERS.child(uid).child("coordinates").removeValue()
            }
        } else {
            self.createDBUser(uid: uid, userData: ["coordinates": [coordinate.latitude, coordinate.longitude]], isDriver: false)
        }
    }
    
}
