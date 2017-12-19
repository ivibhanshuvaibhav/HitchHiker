//
//  GradientView.swift
//  HitchHiker
//
//  Created by Vibhanshu Vaibhav on 07/12/17.
//  Copyright © 2017 Vibhanshu Vaibhav. All rights reserved.
//

import UIKit

class GradientView: UIView {

    let gradient = CAGradientLayer()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupGradientView()
    }

    override func layoutSubviews() {
        gradient.frame = self.bounds
    }
    
    func setupGradientView() {
        gradient.colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0.0).cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 0, y: 1)
        gradient.locations = [0.8, 1.0]
        self.layer.insertSublayer(gradient, at: 0)
    }
    
}
