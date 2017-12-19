//
//  MenuVC.swift
//  HitchHiker
//
//  Created by Vibhanshu Vaibhav on 08/12/17.
//  Copyright © 2017 Vibhanshu Vaibhav. All rights reserved.
//

import UIKit
import Firebase
import CoreLocation

class MenuVC: UIViewController {

    @IBOutlet weak var pickupModeSwitch: UISwitch!
    @IBOutlet weak var pickupModeLabel: UILabel!
    @IBOutlet weak var userProfileImage: RoundImageView!
    @IBOutlet weak var userEmailLabel: UILabel!
    @IBOutlet weak var userAccountType: UILabel!
    @IBOutlet weak var authButton: UIButton!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let view = UIView()
        view.frame = self.view.frame
        view.backgroundColor = .white
        view.alpha = 0.5
        view.tag = 21
        self.revealViewController().frontViewController.view.addSubview(view)
        
        pickupModeSwitch.isHidden = true
        pickupModeLabel.isHidden = true
        
        if Auth.auth().currentUser != nil {
            userAccountType.text = " "
            userEmailLabel.text = Auth.auth().currentUser?.email
            userProfileImage.isHidden = false
            self.authButton.setTitle("Sign Out", for: .normal)
            observeCurrentUser()
        } else {
            userAccountType.text = " "
            userEmailLabel.text = " "
            userProfileImage.isHidden = true
            self.authButton.setTitle("Sign Up/ Login", for: .normal)
        }
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        for subview in self.revealViewController().frontViewController.view.subviews {
            if subview.tag == 21 {
                subview.removeFromSuperview()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func observeCurrentUser() {
        if userIsDriver {
            self.userAccountType.text = "DRIVER"
            self.pickupModeSwitch.isHidden = false
            self.pickupModeLabel.isHidden = false
            self.pickupModeSwitch.isOn = pickupIsEnabled
            if pickupIsEnabled {
                self.pickupModeLabel.text = "PICKUP MODE ENABLED"
            } else {
                self.pickupModeLabel.text = "PICKUP MODE DISABLED"
            }
        } else {
            self.userAccountType.text = "PASSENGER"
        }
    }
    
    @IBAction func pickupModeChanged(_ sender: Any) {
        if pickupModeSwitch.isOn {
            pickupIsEnabled = true
            pickupModeLabel.text = "PICKUP MODE ENABLED"
            DataService.instance.REF_DRIVERS.child(currentUserId!).updateChildValues(["isPickupModeEnabled": true])
            DataService.instance.updateUserLocation(uid: currentUserId!, withCoordinates: (CLLocationManager().location?.coordinate)!)
        } else {
            pickupIsEnabled = false
            pickupModeLabel.text = "PICKUP MODE DISABLED"
            DataService.instance.REF_DRIVERS.child(currentUserId!).updateChildValues(["isPickupModeEnabled": false])
            DataService.instance.updateUserLocation(uid: currentUserId!, withCoordinates: CLLocationCoordinate2D())
        }
        self.revealViewController().revealToggle(animated: true)
    }
    
    @IBAction func signUpLoginButtonPressed(_ sender: Any) {
        if Auth.auth().currentUser == nil {
            let loginVC = storyboard?.instantiateViewController(withIdentifier: "LoginVC") as! LoginVC
            present(loginVC, animated: true) {
                self.revealViewController().revealToggle(animated: false)
            }
        } else {
            do {
                try Auth.auth().signOut()
                DataService.instance.REF_USERS.removeAllObservers()
                DataService.instance.REF_DRIVERS.removeAllObservers()
                print("Successfully signed out")
                self.revealViewController().revealToggle(animated: false)
            } catch {
                print("Could not sign out: \(error.localizedDescription)")
            }
        }
    }
    
}
