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
    
    func isDriverAvailable(handler: @escaping(_ status: Bool) -> ()) {
        DataService.instance.REF_DRIVERS.child(currentUserId!).observeSingleEvent(of: .value) { (snapshot) in
            if snapshot.childSnapshot(forPath: "isPickupModeEnabled").value as! Bool {
                if snapshot.childSnapshot(forPath: "driverIsOnTrip").value as! Bool {
                    handler(false)
                } else {
                    handler(true)
                }
            } else {
                handler(false)
            }
        }
    }
    
    func observeTrips(handler: @escaping(_ coordinateDict: Dictionary<String,Any>?) -> ()) {
        DataService.instance.REF_TRIPS.observe(.value) { (snapshot) in
            guard let snapshot = snapshot.children.allObjects as?  [DataSnapshot] else { return }
            
            for trip in snapshot {
                if trip.childSnapshot(forPath: "tripIsAccepted").value as! Bool == false {
                    guard let tripDict = trip.value as? Dictionary<String, Any> else { return }
                    handler(tripDict)
                }
                handler(nil)
            }
        }
    }
    
    func updateTripWithCoordinates() {
        DataService.instance.REF_USERS.child(currentUserId!).observeSingleEvent(of: .value) { (snapshot) in
            let userData = snapshot.value as! Dictionary<String, Any>
            let pickupArray = userData["coordinates"] as! NSArray
            let destinationArray = userData["destinationCoordinates"] as! NSArray
            DataService.instance.REF_TRIPS.child(currentUserId!).updateChildValues(["pickupCoordinates": pickupArray, "destinationCoordinates": destinationArray, "passengerId": currentUserId!, "tripIsAccepted": false])
        }
    }
    
}
