//
//  RoundView.swift
//  HitchHiker
//
//  Created by Vibhanshu Vaibhav on 09/12/17.
//  Copyright © 2017 Vibhanshu Vaibhav. All rights reserved.
//

import UIKit

class RoundView: UIView {
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.layer.opacity = 0.5
        self.layer.cornerRadius = self.frame.height / 2
    }
    
}
