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
    
    var tripObserverHandle: UInt = 5
    
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
                self.createDBUser(uid: uid, userData: [COORDINATES: [coordinate.latitude, coordinate.longitude]], isDriver: true)
            } else {
                self.REF_DRIVERS.child(uid).child(COORDINATES).removeValue()
            }
        } else {
            self.createDBUser(uid: uid, userData: [COORDINATES: [coordinate.latitude, coordinate.longitude]], isDriver: false)
        }
    }
    
    
    func driverPickupEnabled(driverKey: String, handler: @escaping (_ status: Bool) -> ()) {
        REF_DRIVERS.child(driverKey).child(DRIVER_PICKUP_ENABLED).observe(.value) { (status) in
            if status.value as! Bool == true {
                handler(true)
            } else {
                handler(false)
            }
        }
    }
    
    func driverIsAvailable(key: String, handler: @escaping(_ status: Bool) -> ()) {
        driverPickupEnabled(driverKey: key) { (enabled) in
            if enabled {
                self.REF_DRIVERS.child(key).child(DRIVER_ON_TRIP).observeSingleEvent(of: .value, with: { (snapshot) in
                    if snapshot.value as! Bool {
                        handler(false)
                    } else {
                        handler(true)
                    }
                })
            } else {
                handler(false)
            }
        }
    }
    
    func driverIsOnTrip(driverKey: String, handler: @escaping (_ status: Bool, _ driverKey: String?, _ tripKey: String?) -> ()) {
        REF_DRIVERS.child(driverKey).child(DRIVER_ON_TRIP).observeSingleEvent(of: .value) { (driverTripStatusSnapshot) in
            guard let driverTripStatus = driverTripStatusSnapshot.value as? Bool else { return }
            if driverTripStatus {
                self.REF_TRIPS.observeSingleEvent(of: .value, with: { (tripSnapshot) in
                    guard let tripSnapshot = tripSnapshot.children.allObjects as? [DataSnapshot] else { return }
                    
                    for trip in tripSnapshot {
                        if trip.childSnapshot(forPath: DRIVER_KEY).value as! String == currentUserId! {
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
                if trip.childSnapshot(forPath: TRIP_IS_ACCEPTED).value as! Bool {
                    let driverKey = trip.childSnapshot(forPath: DRIVER_KEY).value as! String
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
        tripObserverHandle = REF_TRIPS.observe(.value) { (snapshot) in
            guard let snapshot = snapshot.children.allObjects as? [DataSnapshot] else { return }
            
            for trip in snapshot {
                if trip.childSnapshot(forPath: TRIP_IS_ACCEPTED).value as! Bool == false {
                    guard let tripDict = trip.value as? Dictionary<String, Any> else { return }
                    handler(tripDict)
                }
                handler(nil)
            }
        }
    }
    
    func removeTripObserver() {
        REF_TRIPS.removeObserver(withHandle: tripObserverHandle)
    }
    
    func updateTripWithCoordinates(forPassengerKey passengerKey: String) {
        REF_USERS.child(passengerKey).observeSingleEvent(of: .value) { (snapshot) in
            let userData = snapshot.value as! Dictionary<String, Any>
            let pickupArray = userData[COORDINATES] as! NSArray
            let destinationArray = userData[DESTINATION_COORDINATES] as! NSArray
            self.REF_TRIPS.child(passengerKey).updateChildValues([PICKUP_COORDINATES: pickupArray, DESTINATION_COORDINATES: destinationArray, PASSENGER_KEY: currentUserId!, TRIP_IS_ACCEPTED: false, TRIP_IN_PROGRESS: false])
        }
    }
    
    func acceptTrip(withPassengerKey passengerKey: String, andDriverKey driverKey: String) {
        REF_TRIPS.child(passengerKey).child(TRIP_IS_ACCEPTED).observeSingleEvent(of: .value) { (snapshot) in
            if snapshot.value as! Bool == false {
                self.REF_TRIPS.child(passengerKey).updateChildValues([DRIVER_KEY: driverKey, TRIP_IS_ACCEPTED: true])
                self.REF_DRIVERS.child(driverKey).updateChildValues([DRIVER_ON_TRIP: true])
            }
        }
    }
    
    func cancelTrip(withPassengerKey passengerKey: String, andDriverKey driverKey: String?) {
        REF_TRIPS.child(passengerKey).removeValue()
        REF_USERS.child(passengerKey).child(DESTINATION_COORDINATES).removeValue()
        if driverKey != nil {
            REF_DRIVERS.child(driverKey!).updateChildValues([DRIVER_ON_TRIP: false])
        }
    }
    
}
