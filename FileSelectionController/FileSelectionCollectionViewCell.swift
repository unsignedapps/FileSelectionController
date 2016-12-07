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
    @IBInspectable var selectedBorderColor: UIColor = UIColor.blue
    @IBInspectable var selectedBorderWidth: Float = 1.0
    @IBInspectable var selectedCornerRadius: Float = 8.0
    @IBInspectable var selectedTextColor: UIColor = UIColor.white
    
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
    
    override var isSelected: Bool
    {
        didSet
        {
            if self.isSelected
            {
                self.layer.borderColor = self.selectedBorderColor.cgColor;
                self.layer.borderWidth = CGFloat(self.selectedBorderWidth);
                self.cornerRadius = CGFloat(self.selectedCornerRadius);
                self.selectedOrderLabel?.isHidden = false;
                self.clipsToBounds = true;
                self.contentView.clipsToBounds = true;

                self.selectedOrderLabel?.backgroundColor = self.selectedBorderColor;
                self.selectedOrderLabel?.textColor = self.selectedTextColor;
                
            } else
            {
                self.layer.borderWidth = 0.0;
                self.layer.borderColor = nil;
                self.cornerRadius = 0.0;
                self.selectedOrderLabel?.isHidden = true;
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
        let radius = CGSize(width: CGFloat(self.selectedCornerRadius), height: CGFloat(self.selectedCornerRadius));
        layer.path = UIBezierPath(roundedRect: label.bounds, byRoundingCorners: [.topRight, .bottomLeft], cornerRadii: radius).cgPath;
        label.layer.mask = layer;
    }
    
    override func prepareForReuse()
    {
        super.prepareForReuse();
        self.selectedOrder = nil;
    }
    
    static var nib: UINib
    {
        return UINib(nibName: String(describing: FileSelectionCollectionViewCell.self), bundle: Bundle(for: self));
    }
    
    static var reuseIdentifier: String
    {
        return String(describing: FileSelectionCollectionViewCell.self);
    }
}
