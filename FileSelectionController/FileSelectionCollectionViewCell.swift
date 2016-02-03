//
//  FileSelectionCollectionViewCell.swift
//  FileSelectionController
//
//  Created by Robert Amos on 10/11/2015.
//  Copyright © 2015 Unsigned Apps. All rights reserved.
//

import UIKit

@IBDesignable
class FileSelectionCollectionViewCell: UICollectionViewCell
{
    @IBInspectable var selectedBorderColor: UIColor = UIColor.blueColor()
    @IBInspectable var selectedBorderWidth: Float = 1.0
    @IBInspectable var selectedCornerRadius: Float = 8.0
    @IBInspectable var selectedTextColor: UIColor = UIColor.whiteColor()
    
    var selectedOrder: Int?
    {
        didSet
        {
            self.selectedOrderLabel?.text = self.selectedOrder != nil ? String(self.selectedOrder!) : nil;
        }
    }

    @IBOutlet var selectedOrderLabel: UILabel?
    @IBOutlet var imageView: UIImageView?
    var image: UIImage? = nil
    {
        didSet
        {
            guard let imageView = self.imageView else { return; }
            imageView.image = self.image;
        }
    }
    
    override var selected: Bool
    {
        didSet
        {
            if self.selected
            {
                self.layer.borderColor = self.selectedBorderColor.CGColor;
                self.layer.borderWidth = CGFloat(self.selectedBorderWidth);
                self.cornerRadius = CGFloat(self.selectedCornerRadius);
                self.selectedOrderLabel?.hidden = false;
                self.clipsToBounds = true;
                self.contentView.clipsToBounds = true;

                self.selectedOrderLabel?.backgroundColor = self.selectedBorderColor;
                self.selectedOrderLabel?.textColor = self.selectedTextColor;
                
            } else
            {
                self.layer.borderWidth = 0.0;
                self.layer.borderColor = nil;
                self.cornerRadius = 0.0;
                self.selectedOrderLabel?.hidden = true;
                self.clipsToBounds = true;
                self.contentView.clipsToBounds = true;
            }
        }
    }
    
    override func awakeFromNib()
    {
        super.awakeFromNib();
        
        guard let label = self.selectedOrderLabel else { return; }
        
        // we want to round only a couple of corners in self.selectedOrderLabel
        label.translatesAutoresizingMaskIntoConstraints = false;
        let layer = CAShapeLayer();
        let radius = CGSizeMake(CGFloat(self.selectedCornerRadius), CGFloat(self.selectedCornerRadius));
        layer.path = UIBezierPath(roundedRect: label.bounds, byRoundingCorners: [.TopRight, .BottomLeft], cornerRadii: radius).CGPath;
        label.layer.mask = layer;
    }
    
    override func prepareForReuse()
    {
        super.prepareForReuse();
        self.selectedOrder = nil;
    }
    
    static var nib: UINib
    {
        return UINib(nibName: String(FileSelectionCollectionViewCell), bundle: NSBundle(forClass: self));
    }
    
    static var reuseIdentifier: String
    {
        return String(FileSelectionCollectionViewCell);
    }
}
