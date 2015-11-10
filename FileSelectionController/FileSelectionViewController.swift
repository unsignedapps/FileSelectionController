//
//  FileSelectionViewController.swift
//  FileSelectionController
//
//  Created by Robert Amos on 10/11/2015.
//  Copyright © 2015 Unsigned Apps. All rights reserved.
//

import UIKit
import Photos

public class FileSelectionViewController: UIViewController
{
    var completion: ((UIImage?, NSError?) -> ())?
    
    @IBOutlet var libraryButton: UIButton?
    @IBOutlet var photoButton: UIButton?
    @IBOutlet var stackView: UIStackView?
    @IBOutlet var collectionView: UICollectionView?
    
    // Photos
    var assets: PHFetchResult?
    var imageManager = PHCachingImageManager()
    
    deinit
    {
        PHPhotoLibrary.sharedPhotoLibrary().unregisterChangeObserver(self);
    }
    
    public override func loadView()
    {
        let nib = UINib(nibName: "FileSelectionView", bundle: NSBundle(forClass: self.dynamicType));
        self.view = UIView();
        self.view.addSubview(nib.instantiateWithOwner(self, options: nil)[0] as! UIView)
    }
    
    public override func viewDidLoad()
    {
        super.viewDidLoad();
        
        guard let collection = self.collectionView else { return; }
        
        collection.registerNib(FileSelectionCollectionViewCell.nib, forCellWithReuseIdentifier: FileSelectionCollectionViewCell.reuseIdentifier);
        PHPhotoLibrary.sharedPhotoLibrary().registerChangeObserver(self);
        
        let options = PHFetchOptions();
        options.fetchLimit = 100;
        
        // find the most recent album
        let recent = PHAssetCollection.fetchAssetCollectionsWithType(.SmartAlbum, subtype: .SmartAlbumRecentlyAdded, options: options);
        self.assets = PHAsset.fetchAssetsInAssetCollection(recent[0] as! PHAssetCollection, options: options);
    }

    public static func present (multiple: Bool = false, completion: (UIImage?, NSError?) -> ()) throws
    {
        guard let window = UIApplication.sharedApplication().keyWindow, root = window.rootViewController else { throw FileSelectionViewControllerError.NoKeyWindow; }

        let presenter = root.presentedViewController ?? root;
        let controller = FileSelectionViewController();
        controller.completion = completion;
        controller.modalPresentationStyle = .OverFullScreen;
        controller.adjustOptions();
        presenter.presentViewController(controller, animated: true, completion: nil);
    }
    
    public func hide ()
    {
        self.presentingViewController?.dismissViewControllerAnimated(true)
        {
            if let completion = self.completion
            {
                completion(nil, nil)
            }
        };
    }
    
    private func adjustOptions ()
    {
        guard let library = self.libraryButton, photo = self.photoButton else { return; }
        
        if !UIImagePickerController.isSourceTypeAvailable(.Camera)
        {
            photo.hidden = true;
        }
        
        if !UIImagePickerController.isSourceTypeAvailable(.PhotoLibrary)
        {
            library.hidden = true;
        }
    }
    
    
    @IBAction func chooseFromLibraryButtonPressed(sender: UIButton)
    {
        let controller = UIImagePickerController();
        controller.sourceType = .PhotoLibrary;
        controller.delegate = self;
        self.presentViewController(controller, animated: true, completion: nil);
    }
 
    @IBAction func takePhotoButtonPressed(sender: UIButton)
    {
        let controller = UIImagePickerController();
        controller.sourceType = .Camera;
        controller.delegate = self;
        self.presentViewController(controller, animated: true, completion: nil);
    }

    @IBAction func cancelButtonPressed(sender: UIButton)
    {
        self.hide();
    }
}

public enum FileSelectionViewControllerError: ErrorType
{
    case NoKeyWindow
}

// MARK: - UIIimagePickerControllerDelegate Methods

extension FileSelectionViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate
{
    public func imagePickerController(picker: UIImagePickerController, didFinishPickingImage image: UIImage, editingInfo: [String : AnyObject]?)
    {
        self.presentingViewController?.dismissViewControllerAnimated(true)
        {
            if let completion = self.completion
            {
                completion(image, nil);
            }
        }
    }
    
    public func imagePickerControllerDidCancel(picker: UIImagePickerController)
    {
        self.presentingViewController?.dismissViewControllerAnimated(true)
        {
            if let completion = self.completion
            {
                completion(nil, nil);
            }
        }
    }
}

// MARK: - UICollectionViewDataSource Methods

extension FileSelectionViewController: UICollectionViewDataSource
{
    public func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int
    {
        return 1;
    }
    
    public func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        return self.assets?.count ?? 0;
    }
    
    public func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(FileSelectionCollectionViewCell.reuseIdentifier, forIndexPath: indexPath) as! FileSelectionCollectionViewCell;
        if let asset = self.assets?[indexPath.row] as? PHAsset
        {
            self.imageManager.requestImageForAsset(asset, targetSize: cell.frame.size, contentMode: .AspectFill, options: nil)
            {
                (image, info) in
                cell.image = image;
            }
        }
        
        return cell;
    }
}

// MARK: - UICollectionViewDelegate Methods

extension FileSelectionViewController: UICollectionViewDelegate
{
    public func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath)
    {
        if let completion = self.completion, asset = self.assets?[indexPath.row] as? PHAsset
        {
            self.imageManager.requestImageForAsset(asset, targetSize: PHImageManagerMaximumSize, contentMode: .AspectFill, options: nil)
            {
                (image, info) in
                self.presentingViewController?.dismissViewControllerAnimated(true)
                {
                    completion(image, nil);
                }
            }
        } else
        {
            self.presentingViewController?.dismissViewControllerAnimated(true)
            {
                if let completion = self.completion
                {
                    completion(nil, nil);
                }
            }
        }
    }
}

// MARK: - PHPhotoLibraryChangeObserver

extension FileSelectionViewController: PHPhotoLibraryChangeObserver
{
    public func photoLibraryDidChange(changeInstance: PHChange)
    {
    }
}