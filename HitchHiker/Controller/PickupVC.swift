//
//  PickupVC.swift
//  HitchHiker
//
//  Created by Vibhanshu Vaibhav on 20/12/17.
//  Copyright © 2017 Vibhanshu Vaibhav. All rights reserved.
//

import UIKit
import MapKit

class PickupVC: UIViewController {

    @IBOutlet weak var mapView: RoundMapView!
    
    let regionRadius: CLLocationDistance = 2000
    
    var pickupCoordinate: CLLocationCoordinate2D?
    var passengerKey: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        mapView.isUserInteractionEnabled = false
        
        centerMapOnUserLocation(location: CLLocation(latitude: (pickupCoordinate?.latitude)!, longitude: (pickupCoordinate?.longitude)!))
        
        dropPin(forlocation: CLLocation(latitude: (pickupCoordinate?.latitude)!, longitude: (pickupCoordinate?.longitude)!))
        DataService.instance.REF_TRIPS.child(passengerKey!).observe(.value) { (tripSnapshot) in
            if tripSnapshot.exists() {
                if tripSnapshot.childSnapshot(forPath: "tripIsAccepted").value as! Bool == true {
                    self.dismiss(animated: true, completion: nil)
                }
            } else {
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
    
    func initData(pickupCoordinate: CLLocationCoordinate2D, passengerKey: String) {
        self.pickupCoordinate = pickupCoordinate
        self.passengerKey = passengerKey
    }

    @IBAction func acceptTripButtonPressed(_ sender: Any) {
        DataService.instance.acceptTrip(withPassengerKey: passengerKey!, andDriverKey: currentUserId!)
        presentingViewController?.shouldPresent(true)
    }
    
    @IBAction func cancelButtonPressed(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
}

extension PickupVC: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let dequeuedAnnotation = mapView.dequeueReusableAnnotationView(withIdentifier: "userLocation") else {
            let annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: "userLocation")
            annotationView.image = UIImage(named: "currentLocationAnnotation")
            return annotationView
        }
        return dequeuedAnnotation
    }
    
    func centerMapOnUserLocation(location: CLLocation) {
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, regionRadius, regionRadius)
        mapView.setRegion(coordinateRegion, animated: true)
    }
    
    func dropPin(forlocation location: CLLocation) {
        for annotation in mapView.annotations {
            mapView.removeAnnotation(annotation)
        }
        
        let annotation = MKPointAnnotation()
        annotation.coordinate = location.coordinate
        mapView.addAnnotation(annotation)
    }
}
