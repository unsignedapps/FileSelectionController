//
//  FileSelectionView.swift
//  FileSelectionController
//
//  Created by Robert Amos on 10/11/2015.
//  Copyright © 2015 Unsigned Apps. All rights reserved.
//

import UIKit

class FileSelectionView: UIView
{
    fileprivate var didLoadInitialConstraints = false
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder);
        self.translatesAutoresizingMaskIntoConstraints = false
    }
    
    override func updateConstraints()
    {
        super.updateConstraints();
        
        if !self.didLoadInitialConstraints
        {
            self.superview?.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|[view]|", options: [], metrics: nil, views: ["view": self]))
            self.superview?.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:[view]|", options: [], metrics: nil, views: ["view": self]))
            self.didLoadInitialConstraints = true;
        }
    }
}

@IBDesignable
extension UIView {
    @IBInspectable var cornerRadius: CGFloat {
        get {
            return layer.cornerRadius
        }
        set {
            layer.cornerRadius = newValue
            layer.masksToBounds = newValue > 0
            layer.allowsEdgeAntialiasing = newValue > 0
        }
    }
}
