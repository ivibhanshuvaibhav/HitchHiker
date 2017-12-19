//
//  MainVC.swift
//  HitchHiker
//
//  Created by Vibhanshu Vaibhav on 06/12/17.
//  Copyright © 2017 Vibhanshu Vaibhav. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import Firebase
import RevealingSplashView

let currentUserId = Auth.auth().currentUser?.uid

class MainVC: UIViewController,  Alertable {

    @IBOutlet weak var actionButton: RoundedShadowButton!
    @IBOutlet weak var menuButton: UIButton!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var centerMapButton: UIButton!
    @IBOutlet weak var topView: GradientView!
    @IBOutlet weak var destinationTextField: UITextField!
    @IBOutlet weak var destinationCircle: RoundImageView!
    
    let locationManager = CLLocationManager()
    let authorizationStatus = CLLocationManager.authorizationStatus()
    let regionRadius: CLLocationDistance = 500
    
    let tableView = UITableView()
    var route: MKRoute?
    
    var matchingItems = [MKMapItem]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        locationManager.delegate = self
        destinationTextField.delegate = self
        
        configureLocationServices()
        centerMapOnUserLocation()
        
        if Auth.auth().currentUser != nil {
            if userIsDriver {
                DataService.instance.REF_DRIVERS.child(currentUserId!).child("isPickupModeEnabled").observe(.value, with: { (snapshot) in
                    if snapshot.value as! Bool {
                        DataService.instance.REF_USERS.observe(.value) { (snapshot) in
                            self.loadPassengerAnnotation()
                        }
                    } else {
                        DataService.instance.REF_USERS.removeAllObservers()
                        for annotation in self.mapView.annotations {
                            if annotation.isKind(of: PassengerAnnotation.self) {
                                self.mapView.removeAnnotation(annotation)
                            }
                        }
                    }
                })
            } else {
                DataService.instance.REF_DRIVERS.observe(.value) { (snapshot) in
                    self.loadDriverAnnotation()
                }
            }
        }
        
        addRevealViewController()
        addSplashView()
    }
    
    func addRevealViewController() {
        menuButton.addTarget(self.revealViewController(), action: #selector(SWRevealViewController.revealToggle(_:)), for: .touchUpInside)
        self.view.addGestureRecognizer(self.revealViewController().panGestureRecognizer())
        self.view.addGestureRecognizer(self.revealViewController().tapGestureRecognizer())
    }
    
    func addSplashView() {
        let revealingSplashView = RevealingSplashView(iconImage: UIImage(named: "launchScreenIcon")!, iconInitialSize: CGSize(width: 80, height: 80), backgroundColor: .white)
        self.view.addSubview(revealingSplashView)
        revealingSplashView.animationType = .heartBeat
        revealingSplashView.startAnimation()
        
        revealingSplashView.heartAttack = true
    }
    
    func loadPassengerAnnotation() {
        DataService.instance.REF_USERS.observeSingleEvent(of: .value) { (snapshot) in
            guard let passengerSnapshot = snapshot.children.allObjects as? [DataSnapshot] else { return }
            
            for user in passengerSnapshot {
                guard let userLocation = user.childSnapshot(forPath: "coordinates").value as? NSArray else { return }
                let userCoordinates = CLLocationCoordinate2D(latitude: userLocation[0] as! CLLocationDegrees, longitude: userLocation[1] as! CLLocationDegrees)
                
                let isVisible = self.mapView.annotations.contains(where: { (annotation) -> Bool in
                    if let userAnnotation = annotation as? PassengerAnnotation {
                        if userAnnotation.key == user.key {
                            userAnnotation.update(annotationPosition: userAnnotation, withCoordinate: userCoordinates)
                            return true
                        }
                    }
                    return false
                })
                
                if !isVisible {
                    let userAnnotation = PassengerAnnotation(coordinate: userCoordinates, key: user.key)
                    self.mapView.addAnnotation(userAnnotation)
                }
            }
        }
    }
    
    func loadDriverAnnotation() {
        DataService.instance.REF_DRIVERS.observeSingleEvent(of: .value, with: { (snapshot) in
            guard let driverSnapshot = snapshot.children.allObjects as? [DataSnapshot] else { return }
            
            for driver in driverSnapshot {
                if driver.childSnapshot(forPath: "isPickupModeEnabled").value as! Bool == true {
                    guard let driverLocation = driver.childSnapshot(forPath: "coordinates").value as? NSArray else { return }
                    let driverCoordinates = CLLocationCoordinate2D(latitude: driverLocation[0] as! CLLocationDegrees, longitude: driverLocation[1] as! CLLocationDegrees)
                    
                    let isVisible = self.mapView.annotations.contains(where: { (annotation) -> Bool in
                        if let driverAnnotation = annotation as? DriverAnnotation {
                            if driverAnnotation.key == driver.key {
                                driverAnnotation.update(annotationPosition: driverAnnotation, withCoordinate: driverCoordinates)
                                return true
                            }
                        }
                        return false
                    })
                    
                    if !isVisible {
                        let driverAnnotation = DriverAnnotation(coordinate: driverCoordinates, key: driver.key)
                        self.mapView.addAnnotation(driverAnnotation)
                    }
                } else {
                    for annotation in self.mapView.annotations {
                        if annotation.isKind(of: DriverAnnotation.self) {
                            guard let annotation = annotation as? DriverAnnotation else { return }
                            if annotation.key == driver.key {
                                self.mapView.removeAnnotation(annotation)
                            }
                        }
                    }
                }
            }
        })
    }
    
    @IBAction func centerMapButtonPressed(_ sender: Any) {
        DataService.instance.REF_USERS.child(currentUserId!).observeSingleEvent(of: .value) { (snapshot) in
            if snapshot.hasChild("destinationCoordinates") {
                 self.zoomToFitAnnotations(fromMapView: self.mapView)
            } else {
                self.centerMapOnUserLocation()
            }
        }
        centerMapButton.fadeTo(alphaValue: 0.0, withDuration: 0.2)
    }
    
    @IBAction func actionButtonPressed(_ sender: Any) {
        actionButton.animate(shouldLoad: true, withMessage: nil)
    }
    
}

// MKMapView Delegates

extension MainVC: MKMapViewDelegate {
    func centerMapOnUserLocation() {
        guard let coordinate = locationManager.location?.coordinate else { return }
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(coordinate, regionRadius * 2.0, regionRadius * 2.0)
        mapView.setRegion(coordinateRegion, animated: false)
        mapView.setUserTrackingMode(.follow, animated: true)
    }
    
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        if Auth.auth().currentUser != nil {
            DataService.instance.updateUserLocation(uid: currentUserId!, withCoordinates: userLocation.coordinate)
            if userIsDriver {
                let isVisible = self.mapView.annotations.contains(where: { (annotation) -> Bool in
                    if let driverAnnotation = annotation as? DriverAnnotation {
                        if driverAnnotation.key == currentUserId! {
                            driverAnnotation.update(annotationPosition: driverAnnotation, withCoordinate: userLocation.coordinate)
                            return true
                        }
                    }
                    return false
                })

                if !isVisible {
                    let driverAnnotation = DriverAnnotation(coordinate: userLocation.coordinate, key: currentUserId!)
                    self.mapView.addAnnotation(driverAnnotation)
                    }
            } else {
                let isVisible = self.mapView.annotations.contains(where: { (annotation) -> Bool in
                    if let userAnnotation = annotation as? PassengerAnnotation {
                        if userAnnotation.key == currentUserId! {
                            userAnnotation.update(annotationPosition: userAnnotation, withCoordinate: userLocation.coordinate)
                            return true
                        }
                    }
                    return false
                })

                if !isVisible {
                    let userAnnotation = PassengerAnnotation(coordinate: userLocation.coordinate, key: currentUserId!)
                    self.mapView.addAnnotation(userAnnotation)
                }
            }
        } else {
            for annotation in mapView.annotations {
                mapView.removeAnnotation(annotation)
            }
        }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
          if let annotation = annotation as? DriverAnnotation {
            guard let dequeuedDriverAnnotation = mapView.dequeueReusableAnnotationView(withIdentifier: "driver") else {
                let driverAnnotation = MKAnnotationView(annotation: annotation, reuseIdentifier: "driver")
                driverAnnotation.image = UIImage(named: "driverAnnotation")
                if annotation.key == currentUserId! {
                    driverAnnotation.layer.zPosition = 10
                }
                return driverAnnotation
            }
            return dequeuedDriverAnnotation
        } else if let annotation = annotation as? PassengerAnnotation {
            guard let dequeuedPassengerAnnotation = mapView.dequeueReusableAnnotationView(withIdentifier: "passenger") else {
                let passengerAnnotation = MKAnnotationView(annotation: annotation, reuseIdentifier: "passenger")
                passengerAnnotation.image = UIImage(named: "currentLocationAnnotation")
                if annotation.key == currentUserId! {
                    passengerAnnotation.layer.zPosition = 10
                }
                return passengerAnnotation
            }
            return dequeuedPassengerAnnotation
        } else if let annotation = annotation as? MKPointAnnotation {
            guard let dequeuedDestinationAnnotation = mapView.dequeueReusableAnnotationView(withIdentifier: "destination") else {
                let destinationAnnotation = MKAnnotationView(annotation: annotation, reuseIdentifier: "destination")
                destinationAnnotation.image = UIImage(named: "destinationAnnotation")
                return destinationAnnotation
            }
            return dequeuedDestinationAnnotation
        }
        return nil
    }
    
    func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
        view.layer.zPosition = 5
    }
    
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        centerMapButton.fadeTo(alphaValue: 1.0, withDuration: 0.2)
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        let lineRenderer = MKPolylineRenderer(polyline: (route?.polyline)!)
        lineRenderer.strokeColor = #colorLiteral(red: 0.8470588235, green: 0.2784313725, blue: 0.1176470588, alpha: 1)
        lineRenderer.lineWidth = 3.0
        
        zoomToFitAnnotations(fromMapView: mapView)
        
        return lineRenderer
    }
    
    func performSearch() {
        matchingItems = []
        let request = MKLocalSearchRequest()
        request.naturalLanguageQuery = destinationTextField.text
        request.region = mapView.region
        
        let search = MKLocalSearch(request: request)
        search.start { (response, error) in
            if error != nil {
                self.showAlert((error?.localizedDescription)!)
                self.shouldPresent(false)
                print("Error in searching: \(error.debugDescription)")
            } else if response?.mapItems.count == 0 {
                print("No results for the query")
            } else {
                for mapItems in response!.mapItems {
                    self.matchingItems.append(mapItems)
                    self.shouldPresent(false)
                    self.tableView.reloadData()
                }
            }
        }
    }
    
    func dropPin(forPlacemark placemark: MKPlacemark) {
        for annotation in mapView.annotations {
            if annotation.isKind(of: MKPointAnnotation.self) {
                mapView.removeAnnotation(annotation)
            }
        }
        
        let destinationAnnotation = MKPointAnnotation()
        destinationAnnotation.coordinate = placemark.coordinate
        mapView.addAnnotation(destinationAnnotation)
    }
    
    func showRoute(forMapItem mapItem: MKMapItem) {
        mapView.removeOverlays(mapView.overlays)
        let request = MKDirectionsRequest()
        request.source = MKMapItem.forCurrentLocation()
        request.destination = mapItem 
        request.transportType = .automobile
        request.requestsAlternateRoutes = true
        
        let directions = MKDirections(request: request)
        directions.calculate { (response, error) in
            guard let response = response else {
                self.showAlert((error?.localizedDescription)!)
                self.shouldPresent(false)
                print("Error in calculating route: \(error.debugDescription)")
                return
            }
            self.route = response.routes[0]
            self.mapView.add((self.route?.polyline)!)
            self.shouldPresent(false)
        }
    }
    
    func zoomToFitAnnotations(fromMapView mapView: MKMapView) {
        if mapView.annotations.count == 0 {
            return
        }
        
        mapView.setVisibleMapRect((route?.polyline.boundingMapRect)!, edgePadding: UIEdgeInsetsMake(40, 60, 40, 60), animated: true)
    }
}

// CLLocationManager Delegates

extension MainVC: CLLocationManagerDelegate {
    func configureLocationServices() {
        if authorizationStatus == .notDetermined || authorizationStatus == .denied {
            locationManager.requestAlwaysAuthorization()
        } else {
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.startUpdatingLocation()
        }
    }
}

// UITextField Delegates

extension MainVC: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        tableView.frame = CGRect(x: 20, y: view.frame.height, width: view.frame.width - 40, height: view.frame.height - 160)
        tableView.layer.cornerRadius = 5.0
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "locationCell")
        
        tableView.delegate = self
        tableView.dataSource = self
        
        tableView.tag = 18
        tableView.rowHeight = 60
        
        view.addSubview(tableView)
        animateTableView(shouldShow: true)
        
        UIView.animate(withDuration: 0.2) {
            self.destinationCircle.backgroundColor = .red
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        view.endEditing(true)
        shouldPresent(true)
        performSearch()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField.text == "" {
            UIView.animate(withDuration: 0.2) {
                self.destinationCircle.backgroundColor = #colorLiteral(red: 0.8235294118, green: 0.8235294118, blue: 0.8235294118, alpha: 1)
            }
        }
    }
    
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        matchingItems = []
        tableView.reloadData()
        
        DataService.instance.REF_USERS.child(currentUserId!).child("destinationCoordinates").removeValue()
        
        mapView.removeOverlays(mapView.overlays)
        for annotation in mapView.annotations {
            if annotation.isKind(of: MKPointAnnotation.self) {
                mapView.removeAnnotation(annotation)
            }
        }
        
        centerMapOnUserLocation()
        return true
    }
    
    func animateTableView(shouldShow: Bool) {
        if shouldShow {
            UIView.animate(withDuration: 0.2) {
                self.tableView.frame = CGRect(x: 20, y: 160, width: self.view.frame.width - 40, height: self.view.frame.height - 160)
            }
        } else {
            UIView.animate(withDuration: 0.2, animations: {
                self.tableView.frame = CGRect(x: 20, y: self.view.frame.height, width: self.view.frame.width - 40, height: self.view.frame.height - 200)
            }, completion: { (complete) in
                for subview in self.view.subviews {
                    if subview.tag == 18 {
                        subview.removeFromSuperview()
                    }
                }
            })
        }
    }
}

// UITableView Delegates

extension MainVC: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return matchingItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "locationCell")
        let mapItem = matchingItems[indexPath.row]
        cell.textLabel?.text = mapItem.name
        cell.detailTextLabel?.text = mapItem.placemark.title
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        shouldPresent(true)
        let selectedItem = matchingItems[indexPath.row]
        let destinationPlacemark = matchingItems[indexPath.row].placemark
        dropPin(forPlacemark: destinationPlacemark)
        showRoute(forMapItem: selectedItem)
        DataService.instance.REF_USERS.child(currentUserId!).updateChildValues(["destinationCoordinates": [destinationPlacemark.coordinate.latitude, destinationPlacemark.coordinate.longitude]])
        
        view.endEditing(true)
        destinationTextField.text = tableView.cellForRow(at: indexPath)?.textLabel?.text
        animateTableView(shouldShow: false)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        view.endEditing(true)
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        if destinationTextField.text == "" {
            animateTableView(shouldShow: false)
        }
    }
}
