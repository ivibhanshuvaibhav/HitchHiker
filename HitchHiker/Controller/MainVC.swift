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

let appDelegate = UIApplication.shared.delegate as? AppDelegate
let currentUserId = Auth.auth().currentUser?.uid

class MainVC: UIViewController, Alertable {
    
    @IBOutlet weak var actionButton: RoundedShadowButton!
    @IBOutlet weak var menuButton: UIButton!
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var centerMapButton: UIButton!
    @IBOutlet weak var topView: GradientView!
    @IBOutlet weak var destinationTextField: UITextField!
    @IBOutlet weak var destinationCircle: RoundImageView!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var userImage: RoundImageView!
    
    let locationManager = CLLocationManager()
    let authorizationStatus = CLLocationManager.authorizationStatus()
    let regionRadius: CLLocationDistance = 500
    
    let tableView = UITableView()
    var route: MKRoute?
    
    var initialLoad = true
    var matchingItems = [MKMapItem]()
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        for subview in view.subviews {
            if subview.tag == 21 {
                subview.removeFromSuperview()
            }
        }
        cancelButton.fadeTo(alphaValue: 0.0, withDuration: 0.0)

        if Auth.auth().currentUser != nil {
            userImage.isHidden = false
            if userIsDriver {
                userImage.image = UIImage(named: "driverAnnotation")
                
                DataService.instance.REF_TRIPS.observe(.childRemoved, with: { (removedTripSnapshot) in
                    guard let removedDriverKey = removedTripSnapshot.childSnapshot(forPath: "driverKey").value as? String else {
                        return
                    }
                    if removedDriverKey == currentUserId! {
                        self.removeAnnotationAndOverlays()
                        DataService.instance.REF_USERS.observe(.value) { (snapshot) in
                            self.loadPassengerAnnotation()
                        }
                        self.cancelButton.fadeTo(alphaValue: 0.0, withDuration: 0.2)
                    }
                })
                
                DataService.instance.REF_DRIVERS.child(currentUserId!).child("driverIsOnTrip").observeSingleEvent(of: .value, with: { (snapshot) in
                    if snapshot.value as! Bool == true {
                        DataService.instance.REF_TRIPS.observeSingleEvent(of: .value, with: { (tripsSnapshot) in
                            guard let tripsSnapshot = tripsSnapshot.children.allObjects as?   [DataSnapshot] else { return }
                            for trip in tripsSnapshot {
                                if trip.childSnapshot(forPath: "driverKey").value as! String == currentUserId! {
                                    let pickupCoordinateArray = trip.childSnapshot(forPath: "pickupCoordinates").value as! NSArray
                                    let pickupCoordinate = CLLocationCoordinate2D(latitude: pickupCoordinateArray[0] as! CLLocationDegrees, longitude: pickupCoordinateArray[1] as! CLLocationDegrees)
                                    let pickupPlacemark = MKPlacemark(coordinate: pickupCoordinate)
                                    
                                    self.dropPin(forPlacemark: pickupPlacemark)
                                    self.showRoute(forOriginMapItem: nil, andDestinationMapItem: MKMapItem(placemark: pickupPlacemark))
                                    
                                    self.cancelButton.fadeTo(alphaValue: 1.0, withDuration: 0.2)
                                    DataService.instance.REF_USERS.removeAllObservers()
                                    for annotation in self.mapView.annotations where annotation.isKind(of: PassengerAnnotation.self) {
                                        self.mapView.removeAnnotation(annotation)
                                    }
                                }
                            }
                        })
                    }
                })
            } else {
                userImage.image = UIImage(named: "currentLocationAnnotation")
                
                connectUserAndDriver()
                
                DataService.instance.REF_TRIPS.observe(.childRemoved, with: { (removedTripSnapshot) in
                    if removedTripSnapshot.key == currentUserId! {
                        self.removeAnnotationAndOverlays()
                        DataService.instance.REF_DRIVERS.observe(.value) { (snapshot) in
                            self.loadDriverAnnotation()
                        }
                        self.matchingItems = []
                        self.tableView.reloadData()
                        
                        self.destinationTextField.text = ""
                        self.destinationTextField.isUserInteractionEnabled = true
                        
                        self.cancelButton.fadeTo(alphaValue: 0.0, withDuration: 0.2)
                        self.actionButton.animate(shouldLoad: false, withMessage: "REQUEST RIDE")
                    }
                })
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        locationManager.delegate = self
        destinationTextField.delegate = self
        
        configureLocationServices()
        
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
                
                DataService.instance.driverIsAvailable(handler: { (available) in
                    if available {
                        DataService.instance.observeTrips(handler: { (tripDict) in
                            guard let tripDict = tripDict else { return }
                            let pickupCoordinates = tripDict["pickupCoordinates"] as! NSArray
                            let passengerKey = tripDict["passengerId"] as! String
                            let pickupVC = self.storyboard?.instantiateViewController(withIdentifier: "PickupVC") as! PickupVC
                            pickupVC.initData(pickupCoordinate: CLLocationCoordinate2DMake(pickupCoordinates[0] as! CLLocationDegrees, pickupCoordinates[1] as! CLLocationDegrees), passengerKey: passengerKey)
                            self.present(pickupVC, animated: true, completion: nil)
                        })
                    }
                })
            } else {
                DataService.instance.REF_DRIVERS.observe(.value) { (snapshot) in
                    DataService.instance.REF_TRIPS.child(currentUserId!).observeSingleEvent(of: .value, with: { (snapshot) in
                        if !snapshot.hasChild("driverKey") {
                            self.loadDriverAnnotation()
                        }
                    })
                }
            }
        }
        addRevealViewController()
        addSplashView()
    }
    
    func removeAnnotationAndOverlays() {
        self.mapView.removeOverlays(self.mapView.overlays)
        self.centerMapOnUserLocation()
        for annotation in self.mapView.annotations where annotation.isKind(of: MKPointAnnotation.self) {
            self.mapView.removeAnnotation(annotation)
        }
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
                    for annotation in self.mapView.annotations where annotation.isKind(of: DriverAnnotation.self) {
                        guard let annotation = annotation as? DriverAnnotation else { return }
                        if annotation.key == driver.key {
                            self.mapView.removeAnnotation(annotation)
                        }
                    }
                }
            }
        })
    }
    
    func connectUserAndDriver() {
        DataService.instance.REF_TRIPS.child(currentUserId!).observe(.value) { (tripSnapshot) in
            guard let tripDict = tripSnapshot.value as? Dictionary<String, Any> else { return }
            
            if tripDict["tripIsAccepted"] as! Bool == true {
                let pickupCoordinateArray = tripDict["pickupCoordinates"] as! NSArray
                let pickupCoordinates = CLLocationCoordinate2D(latitude: pickupCoordinateArray[0] as! CLLocationDegrees, longitude: pickupCoordinateArray[1] as! CLLocationDegrees)
                let driverKey = tripDict["driverKey"] as! String
                let pickupPlacemark = MKPlacemark(coordinate: pickupCoordinates)
                
                DataService.instance.REF_DRIVERS.child(driverKey).child("coordinates").observeSingleEvent(of: .value, with: { (snapshot) in
                    let driverCoordinateArray = snapshot.value as! NSArray
                    let driverCoordinates = CLLocationCoordinate2D(latitude: driverCoordinateArray[0] as! CLLocationDegrees, longitude: driverCoordinateArray[1] as! CLLocationDegrees)
                    let driverPlacemark = MKPlacemark(coordinate: driverCoordinates)
                    let driverAnnotation = DriverAnnotation(coordinate: driverCoordinates, key: "driver")

                    self.mapView.addAnnotation(driverAnnotation)
                    self.showRoute(forOriginMapItem: MKMapItem(placemark: driverPlacemark), andDestinationMapItem: MKMapItem(placemark: pickupPlacemark))
                    
                    self.actionButton.animate(shouldLoad: false, withMessage: "DRIVING COMING")
                    self.actionButton.isUserInteractionEnabled = false
                })
            }
        }
    }
    
    @IBAction func centerMapButtonPressed(_ sender: Any) {
        if mapView.overlays.count > 0 {
            self.zoomToFitAnnotations(fromMapView: self.mapView)
        } else {
            self.centerMapOnUserLocation()
        }
    }
    
    @IBAction func actionButtonPressed(_ sender: Any) {
        DataService.instance.updateTripWithCoordinates()
        cancelButton.fadeTo(alphaValue: 1.0, withDuration: 0.2)
        destinationTextField.isUserInteractionEnabled = false
        actionButton.animate(shouldLoad: true, withMessage: nil)
    }
    
    @IBAction func cancelTripButtonPressed(_ sender: Any) {
        actionButton.isUserInteractionEnabled = true
        centerMapOnUserLocation()
        if userIsDriver {
            DataService.instance.REF_DRIVERS.child(currentUserId!).child("driverIsOnTrip").observeSingleEvent(of: .value, with: { (snapshot) in
                if snapshot.value as! Bool {
                    DataService.instance.REF_TRIPS.observeSingleEvent(of: .value, with: { (tripsSnapshot) in
                        guard let tripsSnapshot = tripsSnapshot.children.allObjects as? [DataSnapshot] else { return }
                        
                        for trip in tripsSnapshot {
                            if trip.childSnapshot(forPath: "driverKey").value as! String == currentUserId! {
                                let passengerId = trip.childSnapshot(forPath: "passengerId").value as! String
                                DataService.instance.cancelTrip(withPassengerKey: passengerId, andDriverKey: currentUserId!)
                            }
                        }
                    })
                }
            })
            self.cancelButton.fadeTo(alphaValue: 0.0, withDuration: 0.2)
        } else {
            DataService.instance.REF_TRIPS.child(currentUserId!).observeSingleEvent(of: .value, with: { (tripSnapshot) in
                guard let driverKey = tripSnapshot.childSnapshot(forPath: "driverKey").value as? String else {
                    DataService.instance.cancelTrip(withPassengerKey: currentUserId!, andDriverKey: nil)
                    return
                }
                DataService.instance.cancelTrip(withPassengerKey: currentUserId!, andDriverKey: driverKey)
            })
            
            matchingItems = []
            tableView.reloadData()
            
            destinationTextField.text = ""
            destinationTextField.isUserInteractionEnabled = true
            
            cancelButton.fadeTo(alphaValue: 0.0, withDuration: 0.2)
            actionButton.animate(shouldLoad: false, withMessage: "REQUEST RIDE")
        }
    }
}

// MKMapView Delegates

extension MainVC: MKMapViewDelegate {
    
    func centerMapOnUserLocation() {
        guard let coordinate = locationManager.location?.coordinate else { return }
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(coordinate, regionRadius * 2.0, regionRadius * 2.0)
        mapView.setRegion(coordinateRegion, animated: false)
        mapView.setUserTrackingMode(.follow, animated: true)
        self.centerMapButton.fadeTo(alphaValue: 0.0, withDuration: 0.2)
    }
    
    func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
        if initialLoad {
            centerMapOnUserLocation()
            initialLoad = false
        }
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
                return driverAnnotation
            }
            return dequeuedDriverAnnotation
        } else if let annotation = annotation as? PassengerAnnotation {
            guard let dequeuedPassengerAnnotation = mapView.dequeueReusableAnnotationView(withIdentifier: "passenger") else {
                let passengerAnnotation = MKAnnotationView(annotation: annotation, reuseIdentifier: "passenger")
                passengerAnnotation.image = UIImage(named: "currentLocationAnnotation")
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
        for view in views {
            if userIsDriver {
                if view.reuseIdentifier == "driver" {
                    view.layer.zPosition = 100
                } else {
                    view.layer.zPosition = -100
                }
            } else {
                if view.reuseIdentifier == "passenger" {
                    view.layer.zPosition = 100
                } else {
                    view.layer.zPosition = -100
                }
            }
        }
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
    
    func showRoute(forOriginMapItem originMapItem: MKMapItem?, andDestinationMapItem destinationMapItem: MKMapItem) {
        mapView.removeOverlays(mapView.overlays)
        let request = MKDirectionsRequest()
        if originMapItem == nil {
            request.source = MKMapItem.forCurrentLocation()
        } else {
            request.source = originMapItem
        }
        request.destination = destinationMapItem
        request.transportType = .automobile
        request.requestsAlternateRoutes = true
        
        let directions = MKDirections(request: request)
        directions.calculate { (response, error) in
            guard let response = response else {
                self.showAlert((error?.localizedDescription)!)
                self.shouldPresent(false)
                self.centerMapOnUserLocation()
                self.mapView.removeOverlays(self.mapView.overlays)
                for annotation in self.mapView.annotations where annotation.isKind(of: MKPointAnnotation.self) {
                    self.mapView.removeAnnotation(annotation)
                }
                appDelegate?.window?.rootViewController?.shouldPresent(false)
                print("Error in calculating route: \(error.debugDescription)")
                return
            }
            self.route = response.routes[0]
            self.mapView.add((self.route?.polyline)!)
            self.shouldPresent(false)
            appDelegate?.window?.rootViewController?.shouldPresent(false)
        }
    }
    
    func zoomToFitAnnotations(fromMapView mapView: MKMapView) {
        if mapView.annotations.count == 0 {
            return
        }
        
        guard let mapRect = route?.polyline.boundingMapRect else {
            centerMapOnUserLocation()
            return
        }
        mapView.setVisibleMapRect(mapRect, edgePadding: UIEdgeInsetsMake(180, 60, 180, 60), animated: true)
        centerMapButton.fadeTo(alphaValue: 0.0, withDuration: 0.2)
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
        for annotation in mapView.annotations where annotation.isKind(of: DriverAnnotation.self) {
            mapView.removeAnnotation(annotation)
        }
        dropPin(forPlacemark: destinationPlacemark)
        showRoute(forOriginMapItem: nil, andDestinationMapItem: selectedItem)
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
