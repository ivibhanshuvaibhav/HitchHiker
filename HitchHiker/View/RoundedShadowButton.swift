//
//  RoundedShadowButton.swift
//  HitchHiker
//
//  Created by Vibhanshu Vaibhav on 07/12/17.
//  Copyright © 2017 Vibhanshu Vaibhav. All rights reserved.
//

import UIKit

class RoundedShadowButton: UIButton {

    override func awakeFromNib() {
        super.awakeFromNib()
        setupView()
    }
    
    func setupView() {
        self.layer.cornerRadius = 5.0
        self.layer.shadowRadius = 10.0
        self.layer.shadowColor = UIColor.darkGray.cgColor
        self.layer.shadowOffset = CGSize.zero
        self.layer.shadowOpacity = 0.3
    }
    
    func animate(shouldLoad: Bool, withMessage message: String?) {
        let spinner = UIActivityIndicatorView()
        spinner.activityIndicatorViewStyle = .whiteLarge
        spinner.color = UIColor.darkGray
        spinner.alpha = 0.0
        spinner.hidesWhenStopped = true
        spinner.tag = 21
        
        self.setTitle(message, for: .normal)
        if shouldLoad {
            UIView.animate(withDuration: 0.2, animations: {
                self.layer.cornerRadius = self.frame.height / 2
                self.frame = CGRect(x: self.frame.midX - (self.frame.height / 2), y: self.frame.origin.y, width: self.frame.height, height: self.frame.height)
            }, completion: { (finished) in
                if finished {
                    self.addSubview(spinner)
                    spinner.startAnimating()
                    spinner.center = CGPoint(x: (self.frame.width / 2) + 2, y: (self.frame.height / 2) + 2)
                    spinner.alpha = 1.0
                }
            })
            self.isUserInteractionEnabled = false
        } else {
            self.isUserInteractionEnabled = true
            for subview in self.subviews {
                if subview.tag == 21 {
                    subview.removeFromSuperview()
                }
            }
            UIView.animate(withDuration: 0.2, animations: {
                self.layer.cornerRadius = 5.0
                self.frame = CGRect(x: 20, y: 0, width: UIScreen.main.bounds.width - 40, height: self.frame.height)
            })
        }
    }
    
}
