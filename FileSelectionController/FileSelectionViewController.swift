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
    
    var selectMultiple: Bool = false
    {
        didSet {
            self.collectionView?.allowsMultipleSelection = self.selectMultiple;
        }
    }
    
    @IBOutlet var libraryButton: UIButton?
    @IBOutlet var photoButton: UIButton?
    @IBOutlet var stackView: UIStackView?
    @IBOutlet var collectionView: UICollectionView?
    @IBOutlet var collectionViewPadding: NSLayoutConstraint?
    @IBOutlet var collectionViewHeight: NSLayoutConstraint?
    
    let animationDuration = 0.34;
    
    // Photos
    var assets: PHFetchResult?
    var imageManager = PHCachingImageManager()
    
    // Selection
    var selectionOrder: [NSIndexPath] = []
    
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
        
        collection.allowsMultipleSelection = self.selectMultiple;
        
        collection.registerNib(FileSelectionCollectionViewCell.nib, forCellWithReuseIdentifier: FileSelectionCollectionViewCell.reuseIdentifier);
        PHPhotoLibrary.sharedPhotoLibrary().registerChangeObserver(self);
        
        // do we have access to the photos?
        if PHPhotoLibrary.authorizationStatus() != .Authorized
        {
            self.hideCollectionView(false, completion: nil);
            PHPhotoLibrary.requestAuthorization
            {
                status in
                if status == .Authorized
                {
                    dispatch_async(dispatch_get_main_queue())
                    {
                        self.loadPhotos();
                    }
                }
            }

        } else
        {
            self.loadPhotos();
        }
    }
    
    public func selectedImages (completion: ([UIImage] -> ()))
    {
        guard self.selectionOrder.count > 0 else { completion([]); return; }
        
        var images: [UIImage] = [];
        var count = self.selectionOrder.count;
        self.selectionOrder.forEach
        {
            path in
            if let asset = self.assets?[path.row] as? PHAsset
            {
                self.imageManager.requestImageForAsset(asset, targetSize: PHImageManagerMaximumSize, contentMode: .AspectFill, options: nil)
                {
                    (image, info) in
                    if let image = image
                    {
                        images.append(image);
                    }
                    count -= 1;
                    if count <= 0
                    {
                        completion(images);
                    }
                }
            }
        }
    }
    
    private func hideCollectionView (animated: Bool, completion: ((Bool) -> ())?)
    {
        guard let height = self.collectionViewHeight, padding = self.collectionViewPadding else { return; }
        
        height.constant = 0;
        padding.constant = 5;
        let animations: () -> () =
        {
            self.view.layoutIfNeeded();
        }
        
        if animated
        {
            UIView.animateWithDuration(self.animationDuration, animations: animations, completion: completion);

        } else
        {
            animations();
        }
    }
    
    private func showCollectionView (animated: Bool, completion: ((Bool) -> ())?)
    {
        guard let height = self.collectionViewHeight, padding = self.collectionViewPadding else { return; }
        
        height.constant = 100;
        padding.constant = 15;
        let animations: () -> () =
        {
            self.view.layoutIfNeeded();
        }
        
        if animated
        {
            UIView.animateWithDuration(self.animationDuration, animations: animations, completion: completion);

        } else
        {
            animations();
        }
    }
    
    private func isCollectionViewHidden () -> Bool
    {
        guard let height = self.collectionViewHeight else { return false; }
        return height.constant == 0;
    }
    
    private func loadPhotos ()
    {
        let options = PHFetchOptions();
        options.fetchLimit = 100;
        
        // find the most recent album
        let recent = PHAssetCollection.fetchAssetCollectionsWithType(.SmartAlbum, subtype: .SmartAlbumRecentlyAdded, options: options);

        options.sortDescriptors = [ NSSortDescriptor(key: "creationDate", ascending: false) ];
        self.assets = PHAsset.fetchAssetsInAssetCollection(recent[0] as! PHAssetCollection, options: options);
        self.collectionView?.reloadData();

        // if it is hidden we need to show it
        if self.isCollectionViewHidden()
        {
            self.showCollectionView(true, completion:nil);
        }
    }

    public static func present (multiple: Bool = false, completion: (UIImage?, NSError?) -> ()) throws
    {
        guard let window = UIApplication.sharedApplication().keyWindow, root = window.rootViewController else { throw FileSelectionViewControllerError.NoKeyWindow; }

        let presenter = root.presentedViewController ?? root;
        let controller = FileSelectionViewController();
        controller.completion = completion;
        controller.modalPresentationStyle = .OverFullScreen;
        controller.adjustOptions();
        controller.selectMultiple = multiple;
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
        self.selectionOrder.append(indexPath);
        
        guard collectionView.allowsMultipleSelection == false else
        {
            self.updateSelectionOrder();
            return;
        }
        
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
    
    public func collectionView(collectionView: UICollectionView, didDeselectItemAtIndexPath indexPath: NSIndexPath)
    {
        if let index = self.selectionOrder.indexOf(indexPath)
        {
            self.selectionOrder.removeAtIndex(index);
            self.updateSelectionOrder();
        }
    }
    
    func updateSelectionOrder ()
    {
        guard let paths = self.collectionView?.indexPathsForVisibleItems() else { return; }
        for path in paths
        {
            var index = self.selectionOrder.indexOf(path) ?? -1;
            index += 1;
            (self.collectionView?.cellForItemAtIndexPath(path) as? FileSelectionCollectionViewCell)?.selectedOrderLabel?.text = String(index)
        }
    }
}

// MARK: - PHPhotoLibraryChangeObserver

extension FileSelectionViewController: PHPhotoLibraryChangeObserver
{
    public func photoLibraryDidChange(changeInstance: PHChange)
    {
        dispatch_async(dispatch_get_main_queue())
        {
            // did it change?
            guard let assets = self.assets, collection = self.collectionView else { return };
            if let details = changeInstance.changeDetailsForFetchResult(assets)
            {
                self.assets = details.fetchResultAfterChanges;
                collection.reloadData();
            }
        }
    }
}