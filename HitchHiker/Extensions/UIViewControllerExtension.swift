//
//  UIViewControllerExtension.swift
//  HitchHiker
//
//  Created by Vibhanshu Vaibhav on 17/12/17.
//  Copyright © 2017 Vibhanshu Vaibhav. All rights reserved.
//

import Foundation

extension UIViewController {
    
    func shouldPresent(_ status: Bool) {
        if status {
            let fadeView = UIView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height))
            fadeView.backgroundColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            fadeView.alpha = 0.0
            fadeView.tag = 25
            
            let spinner = UIActivityIndicatorView()
            spinner.color = #colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)
            spinner.activityIndicatorViewStyle = .whiteLarge
            spinner.center = view.center
            
            view.addSubview(fadeView)
            fadeView.addSubview(spinner)
            
            spinner.startAnimating()
            
            fadeView.fadeTo(alphaValue: 0.7, withDuration: 0.2)
        } else {
            for subview in view.subviews {
                if subview.tag == 25 {
                    UIView.animate(withDuration: 0.2, animations: {
                        subview.alpha = 0.0
                    }, completion: { (complete) in
                        subview.removeFromSuperview()
                    })
                }
            }
        }
    }
    
}
