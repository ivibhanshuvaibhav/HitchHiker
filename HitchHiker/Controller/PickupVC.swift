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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
    }

    @IBAction func AcceptTripButtonPressed(_ sender: Any) {
        
    }
    
    @IBAction func cancelButtonPressed(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
}

extension PickupVC: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        return nil
    }
}
