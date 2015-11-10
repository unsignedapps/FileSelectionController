//
//  FileSelectionCollectionViewCell.swift
//  FileSelectionController
//
//  Created by Robert Amos on 10/11/2015.
//  Copyright © 2015 Unsigned Apps. All rights reserved.
//

import UIKit

class FileSelectionCollectionViewCell: UICollectionViewCell
{
    @IBOutlet var imageView: UIImageView?
    var image: UIImage? = nil
    {
        didSet
        {
            guard let imageView = self.imageView else { return; }
            imageView.image = self.image;
        }
    }

    static var nib: UINib
    {
        return UINib(nibName: "FileSelectionCollectionViewCell", bundle: NSBundle(forClass: self));
    }
    
    static var reuseIdentifier: String
    {
        return "FileSelectionCollectionViewCell";
    }
}
