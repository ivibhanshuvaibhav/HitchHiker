//
//  LoginVC.swift
//  HitchHiker
//
//  Created by Vibhanshu Vaibhav on 09/12/17.
//  Copyright © 2017 Vibhanshu Vaibhav. All rights reserved.
//

import UIKit
import Firebase

class LoginVC: UIViewController {

    @IBOutlet weak var segmentedController: UISegmentedControl!
    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    @IBOutlet weak var authButton: RoundedShadowButton!
    @IBOutlet weak var displayErrorBottomLayout: NSLayoutConstraint!
    @IBOutlet weak var displayView: RoundView!
    
    var isDriver = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        emailTextField.delegate = self
        passwordTextField.delegate = self
        
        view.bindToKeyboard()
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(handleTap)))
    }
    
    @objc func handleTap() {
        self.view.endEditing(true)
    }
    
    func showError() {
        self.authButton.animate(shouldLoad: false, withMessage: "SIGN UP/ LOGIN")
        self.emailTextField.isUserInteractionEnabled = true
        self.passwordTextField.isUserInteractionEnabled = true
        UIView.animate(withDuration: 0, animations: {
            self.displayErrorBottomLayout.constant = 45
        }) { (complete) in
            self.displayView.isHidden = false
            self.displayView.alpha = 0.5
            self.displayErrorBottomLayout.constant = -125
            UIView.animate(withDuration: 0.2, animations: {
                self.view.layoutIfNeeded()
            }, completion: { (complete) in
                UIView.animate(withDuration: 4, animations: {
                    self.displayView.alpha = 0.0
                })
            })
        }
    }
    
    @IBAction func segmentedControllerChanged(_ sender: Any) {
        if segmentedController.selectedSegmentIndex == 0 {
            isDriver = false
        } else {
            isDriver = true
        }
    }
    
    @IBAction func authButtonPressed(_ sender: Any) {
        if emailTextField.text != "" && passwordTextField.text != "" {
            authButton.animate(shouldLoad: true, withMessage: nil)
            displayView.isHidden = true
            handleTap()
            emailTextField.isUserInteractionEnabled = false
            passwordTextField.isUserInteractionEnabled = false
            
            if let email = emailTextField.text, let password = passwordTextField.text {
                AuthService.instance.loginUser(withEmail: email, andPassword: password, loginComplete: { (success, loginError) in
                    if success {
                        self.dismiss(animated: true, completion: nil)
                        print("Login Successful")
                    } else {
                        let error = loginError! as NSError
                        print("Could not login: \(error.localizedDescription)")
                        if error.code == AuthErrorCode.userNotFound.rawValue {
                            AuthService.instance.registerUser(withEmail: email, andPassword: password, isDriver: self.isDriver, userCreationComplete: { (success, registrationError) in
                                if success {
                                    self.dismiss(animated: true, completion: nil)
                                    print("Registration Successful")
                                } else {
                                    let error = registrationError! as NSError
                                    print("Could not register: \(error.localizedDescription)")
                                    self.showError()
                                }
                            })
                        } else {
                            self.showError()
                        }
                    }
                })
            }
        }
    }
    
    @IBAction func cancelButtonPressed(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
}

extension LoginVC: UITextFieldDelegate {
    
}
