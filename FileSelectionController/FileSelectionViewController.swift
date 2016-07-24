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
    var completion: (([UIImage], NSError?) -> ())?
    
    public var selectMultiple: Bool = false
    {
        didSet {
            self.collectionView?.allowsMultipleSelection = self.selectMultiple;
        }
    }
    
    public var uploadButtonTitle: String?
    {
        didSet
        {
            self.uploadButton?.setTitle(self.uploadButtonTitle, forState: .Normal);
        }
    }
    
    public var highlightColor: UIColor?
    {
        didSet
        {
            self.uploadButton?.backgroundColor = self.highlightColor;
        }
    }
    
    public var highlightTextColor: UIColor?
    {
        didSet
        {
            self.uploadButton?.setTitleColor(self.highlightColor, forState: .Normal);
        }
    }
    
    private var hideStatusBar: Bool = false
    {
        didSet(newValue)
        {
            if (newValue != hideStatusBar) {
                self.setNeedsStatusBarAppearanceUpdate()
            }
        }
    }
    
    @IBOutlet var libraryButton: UIButton?
    @IBOutlet var photoButton: UIButton?
    @IBOutlet var stackView: UIStackView?
    @IBOutlet var collectionView: UICollectionView?
    @IBOutlet var collectionViewPadding: NSLayoutConstraint?
    @IBOutlet var collectionViewHeight: NSLayoutConstraint?
    @IBOutlet var uploadButton: UIButton?
    @IBOutlet var uploadButtonHeight: NSLayoutConstraint?

    let animationDuration = 0.34;
    
    var recentlyAddedAssets: PHFetchResult?
    var singlePhotoSelectionAsset: PHFetchResult?
    
    var imageManager:PHCachingImageManager?
    var photoAlbumPlaceholder:PHObjectPlaceholder?
    var recentlyAddedPhotoLocalIdentifier: PHObjectPlaceholder?
    public var photoAlbumName: NSString?
    
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
        
        if let title = self.uploadButtonTitle
        {
            self.uploadButton?.setTitle(title, forState: .Normal);
        }
        if let color = self.highlightColor
        {
            self.uploadButton?.backgroundColor = color;
        }
        if let titleColor = self.highlightTextColor
        {
            self.uploadButton?.setTitleColor(titleColor, forState: .Normal);
        }
    }
    
    public override func viewDidLoad()
    {
        super.viewDidLoad();
        
        guard let collection = self.collectionView else { return; }
        
        collection.allowsMultipleSelection = self.selectMultiple;
        collection.registerNib(FileSelectionCollectionViewCell.nib, forCellWithReuseIdentifier: FileSelectionCollectionViewCell.reuseIdentifier);

        let layout = collection.collectionViewLayout as? UICollectionViewFlowLayout
        layout?.sectionInset = UIEdgeInsetsMake(0, 0, 0, 10)
        
        PHPhotoLibrary.sharedPhotoLibrary().registerChangeObserver(self);
        
        adjustOptions()
        
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
    
    public override func preferredStatusBarUpdateAnimation() -> UIStatusBarAnimation {
        return .Fade
    }
    
    public override func prefersStatusBarHidden() -> Bool {
        return hideStatusBar
    }
    
    private func hideCollectionView (animated: Bool, completion: ((Bool) -> ())?)
    {
        guard let height = self.collectionViewHeight, padding = self.collectionViewPadding, buttonHeight = self.uploadButtonHeight else { return; }
        
        height.constant = 0;
        padding.constant = 5;
        buttonHeight.constant = 0;
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
    
    private func hideUploadButton (animated: Bool)
    {
        guard let height = self.uploadButtonHeight else { return; }
        
        height.constant = 0
        let animations: () -> () =
        {
            self.view.layoutIfNeeded();
        }
        
        if animated
        {
            UIView.animateWithDuration(self.animationDuration, animations: animations);
        
        } else
        {
            animations();
        }
    }
    
    private func showUploadButton (animated: Bool)
    {
        guard let height = self.uploadButtonHeight else { return; }
        
        height.constant = 40;
        let animations: () -> () =
        {
            self.view.layoutIfNeeded();
        }
        
        if animated
        {
            UIView.animateWithDuration(self.animationDuration, animations: animations);
            
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
        guard PHPhotoLibrary.authorizationStatus() == .Authorized else { return }

        if (imageManager == nil) {
            imageManager = PHCachingImageManager()
        }
        
        let options = PHFetchOptions();
        options.fetchLimit = 100;
        
        // find the most recent album
        let recent = PHAssetCollection.fetchAssetCollectionsWithType(.SmartAlbum, subtype: .SmartAlbumRecentlyAdded, options: options);

        options.sortDescriptors = [ NSSortDescriptor(key: "creationDate", ascending: false) ];
        self.recentlyAddedAssets = PHAsset.fetchAssetsInAssetCollection(recent[0] as! PHAssetCollection, options: options);
        self.collectionView?.reloadData();

        // if it is hidden we need to show it
        if self.isCollectionViewHidden()
        {
            self.showCollectionView(true, completion:nil);
        }
    }

    public static func present (multiple: Bool = false, completion: (([UIImage], NSError?) -> ())?) throws
    {
        let controller = FileSelectionViewController();
        try controller.present(multiple, completion: completion)
    }
    
    public func present (multiple: Bool = false, completion: (([UIImage], NSError?) -> ())?) throws
    {
        guard let window = UIApplication.sharedApplication().keyWindow, root = window.rootViewController else { throw FileSelectionViewControllerError.NoKeyWindow
        }

        let presenter = root.presentedViewController ?? root
        self.completion = completion
        self.modalPresentationStyle = .OverFullScreen
        self.selectMultiple = multiple;
        self.modalPresentationCapturesStatusBarAppearance = true
        presenter.presentViewController(self, animated: true, completion: nil)
    }
    
    public func hide ()
    {
        self.presentingViewController?.dismissViewControllerAnimated(true)
        {
            if let completion = self.completion
            {
                completion([], nil)
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
        hideStatusBar = true
        
        let controller = UIImagePickerController()
        controller.sourceType = .Camera
        controller.modalPresentationStyle = .FullScreen
        controller.delegate = self
        self.presentViewController(controller, animated: true, completion: nil)
    }

    @IBAction func cancelButtonPressed(sender: UIButton)
    {
        self.hide();
    }
    
    @IBAction func uploadPhotosButtonPressed(sender: UIButton)
    {
        if let completion = self.completion
        {
            self.selectedImages(completion);
            self.presentingViewController?.dismissViewControllerAnimated(true, completion: nil);
        }
    }
    
    private func selectedImages (completion: (([UIImage], NSError?) -> ()))
    {
        guard self.selectionOrder.count > 0 else { completion([], nil); return; }
        
        var images: [UIImage] = [];
        var count = self.selectionOrder.count;
        self.selectionOrder.forEach
        {
            path in
            
            var asset: AnyObject?
            
            switch path.section {
            case 0:
                asset = self.singlePhotoSelectionAsset?[path.row]
            default:
                asset = self.recentlyAddedAssets?[path.row]
            }
            
            if let asset = asset as? PHAsset
            {
                self.imageManager?.requestImageForAsset(asset, targetSize: PHImageManagerMaximumSize, contentMode: .AspectFill, options: nil)
                {
                    (image, info) in
                    if let image = image
                    {
                        images.append(image);
                    }
                    count -= 1;
                    if count <= 0
                    {
                        completion(images, nil);
                    }
                }
            }
        }
    }
}

public enum FileSelectionViewControllerError: ErrorType
{
    case NoKeyWindow
}

// MARK: - UIIimagePickerControllerDelegate Methods

extension FileSelectionViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate
{
    public func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]?)
    {
        if let info = info, let image = info[UIImagePickerControllerOriginalImage] as? UIImage
        {
            // there's a case below where we've reset the list of assets to a single image.
            // The main case of .Camera or a recent photo selection requires the original recent photos
            // so we're going to get those back here. There's probably another way to do this, and that's
            // store the results as different intance variables.
            
            // if we've come from the camera, 
            if (picker.sourceType == .Camera)
            {
                self.saveImage(image)

                self.hideStatusBar = false
                picker.dismissViewControllerAnimated(true) {}
            }
            else
            {
                // you picked an image from the camera roll, you didn't take it just then
                let url = info[UIImagePickerControllerReferenceURL] as! NSURL
                let result = PHAsset.fetchAssetsWithALAssetURLs([url], options: nil)
                if let photoObject = result.firstObject as? PHAsset {
                    
                    if let assets = self.recentlyAddedAssets {
                        let idx = assets.indexOfObject(photoObject)
                        
                        // if the image is in the list we already have, select it
                        if idx != NSNotFound {
                            
                            // clear collection view collection (lazy way)
                            collectionView?.reloadData();
                            self.clearSelectionOrder();
                            
                            let indexPath = NSIndexPath(forItem: idx, inSection: 1)
                            self.addToSelectionOrder(indexPath)
                            
                            self.hideStatusBar = false
                            picker.dismissViewControllerAnimated(true) {
                                self.collectionView?.selectItemAtIndexPath(indexPath, animated: true, scrollPosition: .CenteredHorizontally)
                            }
                        } else {
                            //photo not available, lets just replace the photos and select it.
                            self.singlePhotoSelectionAsset = result

                            collectionView?.reloadData();
                            self.clearSelectionOrder();
                            
                            let indexPath = NSIndexPath(forItem: 0, inSection: 0)
                            self.addToSelectionOrder(indexPath)
                            self.collectionView?.selectItemAtIndexPath(indexPath, animated: true, scrollPosition: .Left)
                            picker.dismissViewControllerAnimated(true) {}
                        }
                    }
                }
            }
        }
    }
    
    public func imagePickerControllerDidCancel(picker: UIImagePickerController)
    {
        self.hideStatusBar = false
        picker.dismissViewControllerAnimated(true) {}
    }
}

extension FileSelectionViewController
{
    private func fetchPhotoAlbum(completion:(assetCollection: PHAssetCollection?) -> ())
    {
        guard let albumName = self.photoAlbumName else {
            completion(assetCollection: nil)
            return
        }
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collection : PHFetchResult = PHAssetCollection.fetchAssetCollectionsWithType(.Album, subtype: .Any, options: fetchOptions)
        
        if let firstObj = collection.firstObject as! PHAssetCollection?
        {
            completion(assetCollection: firstObj)
        }
        else
        {
            PHPhotoLibrary.sharedPhotoLibrary().performChanges({
                var createAlbumRequest : PHAssetCollectionChangeRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollectionWithTitle(albumName as String)
                self.photoAlbumPlaceholder = createAlbumRequest.placeholderForCreatedAssetCollection
                
                }, completionHandler: { success, error in
                    dispatch_async(dispatch_get_main_queue(), {
                        if (success)
                        {
                            var collectionFetchResult = PHAssetCollection.fetchAssetCollectionsWithLocalIdentifiers([self.photoAlbumPlaceholder!.localIdentifier], options: nil)
                            completion(assetCollection:collectionFetchResult.firstObject as! PHAssetCollection?)
                        }
                        else
                        {
                            completion(assetCollection: nil)
                        }
                    });
            })
        }
    }
    
    private func saveImage(image: UIImage)
    {
        // try and sav it in the album we have created
        fetchPhotoAlbum(){ assetCollection in
            PHPhotoLibrary.sharedPhotoLibrary().performChanges({

                let createAssetRequest = PHAssetChangeRequest.creationRequestForAssetFromImage(image)
                let assetPlaceholder = createAssetRequest.placeholderForCreatedAsset
                dispatch_async(dispatch_get_main_queue(), { 
                    self.recentlyAddedPhotoLocalIdentifier = assetPlaceholder
                })
                if let assetCollection = assetCollection, let assetPlaceholder = assetPlaceholder
                {
                    let albumChangeRequest = PHAssetCollectionChangeRequest(forAssetCollection: assetCollection)!
                    albumChangeRequest.addAssets([assetPlaceholder])
                }
                }, completionHandler: { success, error in
//                    dispatch_async(dispatch_get_main_queue(), { 
//                        print("SaveImage completion", success, error)
//                    });
            })
        }
    }
}

// MARK: - UICollectionViewDataSource Methods

extension FileSelectionViewController: UICollectionViewDataSource
{
    public func numberOfSectionsInCollectionView(collectionView: UICollectionView) -> Int
    {
        return 2;
    }
    
    public func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        switch section {
        case 0:
            return self.singlePhotoSelectionAsset?.count ?? 0
        default:
            return self.recentlyAddedAssets?.count ?? 0
        }
    }
    
    public func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier(FileSelectionCollectionViewCell.reuseIdentifier, forIndexPath: indexPath) as! FileSelectionCollectionViewCell;
        
        var asset:AnyObject?
        
        switch indexPath.section {
        case 0:
            asset = self.singlePhotoSelectionAsset?[indexPath.row]
        default:
            asset = self.recentlyAddedAssets?[indexPath.row]
        }
        
        if let asset = asset as? PHAsset
        {
            self.imageManager?.requestImageForAsset(asset, targetSize: cell.frame.size, contentMode: .AspectFill, options: nil)
            {
                image, info in
                cell.image = image;
                if let order = self.selectionOrder.indexOf(indexPath)
                {
                    cell.selectedOrder = order + 1;
                }
                
                if let color = self.highlightColor { cell.selectedBorderColor = color; }
                if let textColor = self.highlightTextColor { cell.selectedTextColor = textColor; }
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
        self.addToSelectionOrder(indexPath)
    }
    
    public func collectionView(collectionView: UICollectionView, didDeselectItemAtIndexPath indexPath: NSIndexPath)
    {
        self.removeFromSelectionOrder(indexPath)
    }
    
    func updateSelectionOrder ()
    {
        guard let paths = self.collectionView?.indexPathsForVisibleItems() else { return; }
        for path in paths
        {
            var index = self.selectionOrder.indexOf(path) ?? -1;
            index += 1;
            (self.collectionView?.cellForItemAtIndexPath(path) as? FileSelectionCollectionViewCell)?.selectedOrder = index
        }
    }
    
    private func removeFromSelectionOrder(indexPath: NSIndexPath)
    {
        if let index = self.selectionOrder.indexOf(indexPath)
        {
            self.selectionOrder.removeAtIndex(index);
            self.updateSelectionOrder();
            if self.selectionOrder.count == 0
            {
                self.hideUploadButton(true);
            }
        }
    }
    
    private func addToSelectionOrder(indexPath: NSIndexPath)
    {
        let shouldShow = self.selectionOrder.count == 0;
        
        if self.selectionOrder.indexOf(indexPath) == nil
        {
            self.selectionOrder.append(indexPath)
            self.updateSelectionOrder();
            if shouldShow
            {
                self.showUploadButton(true);
            }
        }
    }
    
    private func clearSelectionOrder()
    {
        self.selectionOrder.removeAll()
        self.hideUploadButton(false);
    }
}

// MARK: - PHPhotoLibraryChangeObserver

extension FileSelectionViewController: PHPhotoLibraryChangeObserver
{
    public func photoLibraryDidChange(changeInstance: PHChange)
    {
        dispatch_async(dispatch_get_main_queue())
        {
            guard let assets = self.recentlyAddedAssets, collection = self.collectionView else { return };
            if let details = changeInstance.changeDetailsForFetchResult(assets)
            {
                self.recentlyAddedAssets = details.fetchResultAfterChanges;

                guard details.hasIncrementalChanges else {
                    self.clearSelectionOrder();
                    collection.reloadData();
                    return
                }
                
                if let removed = details.removedIndexes {
                    let indexPaths = removed.map { NSIndexPath(forRow: $0, inSection: 1) };
                    indexPaths.map(self.removeFromSelectionOrder)
                    collection.deleteItemsAtIndexPaths(indexPaths)
                }
                
                if let added = details.insertedIndexes {
                    if let selectedIndexes = collection.indexPathsForSelectedItems() {
                        selectedIndexes.map(self.removeFromSelectionOrder)
                    }
                    
                    collection.insertItemsAtIndexPaths(added.map { NSIndexPath(forRow: $0, inSection: 1)})
                    
                    if let selectedIndexes = collection.indexPathsForSelectedItems() {
                        selectedIndexes.map(self.addToSelectionOrder)
                    }
                }
                
                if let changed = details.changedIndexes {
                    let selectedIndexes = collection.indexPathsForSelectedItems()
                    collection.reloadItemsAtIndexPaths(changed.map { NSIndexPath(forRow: $0, inSection: 1)})
                    
                    // Reselect afer refresh. No need to add/remove from selectionOrder, indexes wont change
                    if let selectedIndexes = selectedIndexes {
                        for index in selectedIndexes {
                            collection.selectItemAtIndexPath(index, animated: false, scrollPosition: .None)
                        }
                    }
                }
                
                details.enumerateMovesWithBlock { from, to in
                    if let selectedIndexes = collection.indexPathsForSelectedItems() {
                        selectedIndexes.map(self.removeFromSelectionOrder)
                    }
                    collection.moveItemAtIndexPath(NSIndexPath(forRow: from, inSection: 1), toIndexPath: NSIndexPath(forRow: to, inSection: 1))
                    
                    if let selectedIndexes = collection.indexPathsForSelectedItems() {
                        selectedIndexes.map(self.addToSelectionOrder)
                    }
                }
                
                // If we have a recently added image from the camera we iterate over the assets from fetchResultAfterChanges
                // and attempt to select it in the collectionView.
                if let newImage = self.recentlyAddedPhotoLocalIdentifier {
                    if let selectedIndexes = collection.indexPathsForSelectedItems() {
                        for indexPath in selectedIndexes {
                            collection.deselectItemAtIndexPath(indexPath, animated: false)
                            self.removeFromSelectionOrder(indexPath)
                        }
                    }

                    assets.enumerateObjectsUsingBlock() { obj, index, stop in
                        guard let obj = obj as? PHObject else { return }
                        if obj.localIdentifier == newImage.localIdentifier {
                            self.recentlyAddedPhotoLocalIdentifier = nil
                            stop.memory = true
                            
                            let indexPath = NSIndexPath(forRow: index, inSection: 1)
                            collection.selectItemAtIndexPath(indexPath, animated: true, scrollPosition: .CenteredHorizontally)
                            self.addToSelectionOrder(indexPath)
                        }
                    }
                }
            }
        }
    }
}