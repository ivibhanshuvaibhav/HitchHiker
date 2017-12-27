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
    
    func driverIsAvailable(key: String, handler: @escaping(_ status: Bool) -> ()) {
        REF_DRIVERS.child(key).observe(.value) { (snapshot) in
            if snapshot.childSnapshot(forPath: "isPickupModeEnabled").value as! Bool == true {
                if snapshot.childSnapshot(forPath: "driverIsOnTrip").value as! Bool == true {
                    handler(false)
                } else {
                    handler(true)
                }
            } else {
                handler(false)
            }
        }
    }
    
    func driverPickupEnabled(driverKey: String, handler: @escaping (_ status: Bool) -> ()) {
        REF_DRIVERS.child(driverKey).child("isPickupModeEnabled").observe(.value) { (status) in
            if status.value as! Bool == true {
                handler(true)
            } else {
                handler(false)
            }
        }
    }
    
    func driverIsOnTrip(driverKey: String, handler: @escaping (_ status: Bool, _ driverKey: String?, _ tripKey: String?) -> ()) {
        REF_DRIVERS.child(driverKey).child("driverIsOnTrip").observeSingleEvent(of: .value) { (driverTripStatusSnapshot) in
            guard let driverTripStatus = driverTripStatusSnapshot.value as? Bool else { return }
            if driverTripStatus {
                self.REF_TRIPS.observeSingleEvent(of: .value, with: { (tripSnapshot) in
                    guard let tripSnapshot = tripSnapshot.children.allObjects as? [DataSnapshot] else { return }
                    
                    for trip in tripSnapshot {
                        if trip.childSnapshot(forPath: "driverKey").value as! String == currentUserId! {
                            handler(true, driverKey, trip.key)
                        }
                    }
                })
            } else {
                handler(false, nil, nil)
            }
        }
    }
    
    func passengerIsOnTrip(passengerKey: String, handler: @escaping (_ status: Bool, _ driverKey: String?, _ tripKey: String?) -> ()) {
        REF_TRIPS.observeSingleEvent(of: .value) { (tripSnapshot) in
            if tripSnapshot.hasChild(passengerKey) {
                let trip = tripSnapshot.childSnapshot(forPath: passengerKey)
                if trip.childSnapshot(forPath: "tripIsAccepted").value as! Bool {
                    let driverKey = trip.childSnapshot(forPath: "driverKey").value as! String
                    handler(true, driverKey, trip.key)
                } else {
                    handler(true, nil, trip.key)
                }
            } else {
                handler(false, nil, nil)
            }
        }
    }
    
    func observeTrips(handler: @escaping(_ coordinateDict: Dictionary<String,Any>?) -> ()) {
        REF_TRIPS.observe(.value) { (snapshot) in
            guard let snapshot = snapshot.children.allObjects as? [DataSnapshot] else { return }
            
            for trip in snapshot {
                if trip.childSnapshot(forPath: "tripIsAccepted").value as! Bool == false {
                    guard let tripDict = trip.value as? Dictionary<String, Any> else { return }
                    handler(tripDict)
                }
                handler(nil)
            }
        }
    }
    
    func updateTripWithCoordinates(forPassengerKey passengerKey: String) {
        REF_USERS.child(passengerKey).observeSingleEvent(of: .value) { (snapshot) in
            let userData = snapshot.value as! Dictionary<String, Any>
            let pickupArray = userData["coordinates"] as! NSArray
            let destinationArray = userData["destinationCoordinates"] as! NSArray
            self.REF_TRIPS.child(passengerKey).updateChildValues(["pickupCoordinates": pickupArray, "destinationCoordinates": destinationArray, "passengerId": currentUserId!, "tripIsAccepted": false])
        }
    }
    
    func acceptTrip(withPassengerKey passengerKey: String, andDriverKey driverKey: String) {
        REF_TRIPS.child(passengerKey).child("tripIsAccepted").observeSingleEvent(of: .value) { (snapshot) in
            if snapshot.value as! Bool == false {
                self.REF_TRIPS.child(passengerKey).updateChildValues(["driverKey": driverKey, "tripIsAccepted": true])
                self.REF_DRIVERS.child(driverKey).updateChildValues(["driverIsOnTrip": true])
            }
        }
    }
    
    func cancelTrip(withPassengerKey passengerKey: String, andDriverKey driverKey: String?) {
        REF_TRIPS.child(passengerKey).removeValue()
        REF_USERS.child(passengerKey).child("destinationCoordinates").removeValue()
        if driverKey != nil {
            REF_DRIVERS.child(driverKey!).updateChildValues(["driverIsOnTrip": false])
        }
    }
    
}
