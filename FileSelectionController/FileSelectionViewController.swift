//
//  FileSelectionViewController.swift
//  FileSelectionController
//
//  Created by Robert Amos on 10/11/2015.
//  Copyright © 2015 Unsigned Apps. All rights reserved.
//

import UIKit
import Photos

open class FileSelectionViewController: UIViewController
{
    var completion: (([UIImage], NSError?) -> ())?
    
    open var selectMultiple: Bool = false
    {
        didSet {
            self.collectionView?.allowsMultipleSelection = self.selectMultiple;
        }
    }
    
    open var uploadButtonTitle: String?
    {
        didSet
        {
            self.uploadButton?.setTitle(self.uploadButtonTitle, for: UIControlState());
        }
    }
    
    open var highlightColor: UIColor?
    {
        didSet
        {
            self.uploadButton?.backgroundColor = self.highlightColor;
        }
    }
    
    open var highlightTextColor: UIColor?
    {
        didSet
        {
            self.uploadButton?.setTitleColor(self.highlightColor, for: UIControlState());
        }
    }
    
    fileprivate var hideStatusBar: Bool = false
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
    
    var recentlyAddedAssets: PHFetchResult<PHAsset>?
    var singlePhotoSelectionAsset: PHFetchResult<PHAsset>?
    
    var imageManager:PHCachingImageManager?
    var photoAlbumPlaceholder:PHObjectPlaceholder?
    var recentlyAddedPhotoLocalIdentifier: PHObjectPlaceholder?
    open var photoAlbumName: NSString?
    
    // Selection
    var selectionOrder: [IndexPath] = []
    
    deinit
    {
        PHPhotoLibrary.shared().unregisterChangeObserver(self);
    }
    
    open override func loadView()
    {
        let nib = UINib(nibName: "FileSelectionView", bundle: Bundle(for: type(of: self)));
        self.view = UIView();
        self.view.addSubview(nib.instantiate(withOwner: self, options: nil)[0] as! UIView)
        
        if let title = self.uploadButtonTitle
        {
            self.uploadButton?.setTitle(title, for: UIControlState());
        }
        if let color = self.highlightColor
        {
            self.uploadButton?.backgroundColor = color;
        }
        if let titleColor = self.highlightTextColor
        {
            self.uploadButton?.setTitleColor(titleColor, for: UIControlState());
        }
    }
    
    open override func viewDidLoad()
    {
        super.viewDidLoad();
        
        guard let collection = self.collectionView else { return; }
        
        collection.allowsMultipleSelection = self.selectMultiple;
        collection.register(FileSelectionCollectionViewCell.nib, forCellWithReuseIdentifier: FileSelectionCollectionViewCell.reuseIdentifier);

        let layout = collection.collectionViewLayout as? UICollectionViewFlowLayout
        layout?.sectionInset = UIEdgeInsetsMake(0, 0, 0, 10)
        
        PHPhotoLibrary.shared().register(self);
        
        adjustOptions()
        
        // do we have access to the photos?
        if PHPhotoLibrary.authorizationStatus() != .authorized
        {
            self.hideCollectionView(false, completion: nil);
            PHPhotoLibrary.requestAuthorization
            {
                status in
                if status == .authorized
                {
                    DispatchQueue.main.async
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
    
    open override var preferredStatusBarUpdateAnimation : UIStatusBarAnimation {
        return .fade
    }
    
    open override var prefersStatusBarHidden : Bool {
        return hideStatusBar
    }
    
    fileprivate func hideCollectionView (_ animated: Bool, completion: ((Bool) -> ())?)
    {
        guard let height = self.collectionViewHeight, let padding = self.collectionViewPadding, let buttonHeight = self.uploadButtonHeight else { return; }
        
        height.constant = 0;
        padding.constant = 5;
        buttonHeight.constant = 0;
        let animations: () -> () =
        {
            self.view.layoutIfNeeded();
        }
        
        if animated
        {
            UIView.animate(withDuration: self.animationDuration, animations: animations, completion: completion);

        } else
        {
            animations();
        }
    }
    
    fileprivate func showCollectionView (_ animated: Bool, completion: ((Bool) -> ())?)
    {
        guard let height = self.collectionViewHeight, let padding = self.collectionViewPadding else { return; }
        
        height.constant = 100;
        padding.constant = 15;
        let animations: () -> () =
        {
            self.view.layoutIfNeeded();
        }
        
        if animated
        {
            UIView.animate(withDuration: self.animationDuration, animations: animations, completion: completion);

        } else
        {
            animations();
        }
    }
    
    fileprivate func hideUploadButton (_ animated: Bool)
    {
        guard let height = self.uploadButtonHeight else { return; }
        
        height.constant = 0
        let animations: () -> () =
        {
            self.view.layoutIfNeeded();
        }
        
        if animated
        {
            UIView.animate(withDuration: self.animationDuration, animations: animations);
        
        } else
        {
            animations();
        }
    }
    
    fileprivate func showUploadButton (_ animated: Bool)
    {
        guard let height = self.uploadButtonHeight else { return; }
        
        height.constant = 40;
        let animations: () -> () =
        {
            self.view.layoutIfNeeded();
        }
        
        if animated
        {
            UIView.animate(withDuration: self.animationDuration, animations: animations);
            
        } else
        {
            animations();
        }
    }
    
    fileprivate func isCollectionViewHidden () -> Bool
    {
        guard let height = self.collectionViewHeight else { return false; }
        return height.constant == 0;
    }
    
    fileprivate func loadPhotos ()
    {
        guard PHPhotoLibrary.authorizationStatus() == .authorized else { return }

        if (imageManager == nil) {
            imageManager = PHCachingImageManager()
        }
        
        let options = PHFetchOptions();
        options.fetchLimit = 100;
        
        // find the most recent album
        let recent = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .smartAlbumRecentlyAdded, options: options)

        options.sortDescriptors = [ NSSortDescriptor(key: "creationDate", ascending: false) ]
        self.recentlyAddedAssets = PHAsset.fetchAssets(in: recent[0] , options: options)
        self.collectionView?.reloadData();

        // if it is hidden we need to show it
        if self.isCollectionViewHidden()
        {
            self.showCollectionView(true, completion:nil);
        }
    }

    open static func present (_ multiple: Bool = false, completion: (([UIImage], NSError?) -> ())?) throws
    {
        let controller = FileSelectionViewController();
        try controller.present(multiple, completion: completion)
    }
    
    open func present (_ multiple: Bool = false, completion: (([UIImage], NSError?) -> ())?) throws
    {
        guard let window = UIApplication.shared.keyWindow, let root = window.rootViewController else { throw FileSelectionViewControllerError.noKeyWindow
        }

        let presenter = root.presentedViewController ?? root
        self.completion = completion
        self.modalPresentationStyle = .overFullScreen
        self.selectMultiple = multiple;
        self.modalPresentationCapturesStatusBarAppearance = true
        presenter.present(self, animated: true, completion: nil)
    }
    
    open func hide ()
    {
        self.presentingViewController?.dismiss(animated: true)
        {
            if let completion = self.completion
            {
                completion([], nil)
            }
        };
    }
    
    fileprivate func adjustOptions ()
    {
        guard let library = self.libraryButton, let photo = self.photoButton else { return; }
        
        if !UIImagePickerController.isSourceTypeAvailable(.camera)
        {
            photo.isHidden = true;
        }
        
        if !UIImagePickerController.isSourceTypeAvailable(.photoLibrary)
        {
            library.isHidden = true;
        }
    }
    
    @IBAction func chooseFromLibraryButtonPressed(_ sender: UIButton)
    {
        let controller = UIImagePickerController();
        controller.sourceType = .photoLibrary;
        controller.delegate = self;
        self.present(controller, animated: true, completion: nil);
    }
 
    @IBAction func takePhotoButtonPressed(_ sender: UIButton)
    {
        hideStatusBar = true
        
        let controller = UIImagePickerController()
        controller.sourceType = .camera
        controller.modalPresentationStyle = .fullScreen
        controller.delegate = self
        self.present(controller, animated: true, completion: nil)
    }

    @IBAction func cancelButtonPressed(_ sender: UIButton)
    {
        self.hide();
    }
    
    @IBAction func uploadPhotosButtonPressed(_ sender: UIButton)
    {
        if let completion = self.completion
        {
            self.selectedImages(completion);
            self.presentingViewController?.dismiss(animated: true, completion: nil);
        }
    }
    
    fileprivate func selectedImages (_ completion: @escaping (([UIImage], NSError?) -> ()))
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
                self.imageManager?.requestImage(for: asset, targetSize: PHImageManagerMaximumSize, contentMode: .aspectFill, options: nil)
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

public enum FileSelectionViewControllerError: Error
{
    case noKeyWindow
}

// MARK: - UIIimagePickerControllerDelegate Methods

extension FileSelectionViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate
{
    public func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any])
    {
        if let image = info[UIImagePickerControllerOriginalImage] as? UIImage {
            // there's a case below where we've reset the list of assets to a single image.
            // The main case of .Camera or a recent photo selection requires the original recent photos
            // so we're going to get those back here. There's probably another way to do this, and that's
            // store the results as different intance variables.
            
            // if we've come from the camera, 
            if (picker.sourceType == .camera)
            {
                self.saveImage(image)

                self.hideStatusBar = false
                picker.dismiss(animated: true) {}
            }
            else
            {
                // you picked an image from the camera roll, you didn't take it just then
                let url = info[UIImagePickerControllerReferenceURL] as! URL
                let result = PHAsset.fetchAssets(withALAssetURLs: [url], options: nil)
                if let photoObject = result.firstObject {
                    if let assets = self.recentlyAddedAssets {
                        let idx = assets.index(of: photoObject)
                        
                        // if the image is in the list we already have, select it
                        if idx != NSNotFound {
                            
                            // clear collection view collection (lazy way)
                            collectionView?.reloadData();
                            self.clearSelectionOrder();
                            
                            let indexPath = IndexPath(item: idx, section: 1)
                            self.addToSelectionOrder(indexPath)
                            
                            self.hideStatusBar = false
                            picker.dismiss(animated: true) {
                                self.collectionView?.selectItem(at: indexPath, animated: true, scrollPosition: .centeredHorizontally)
                            }
                        } else {
                            //photo not available, lets just replace the photos and select it.
                            self.singlePhotoSelectionAsset = result

                            collectionView?.reloadData();
                            self.clearSelectionOrder();
                            
                            let indexPath = IndexPath(item: 0, section: 0)
                            self.addToSelectionOrder(indexPath)
                            self.collectionView?.selectItem(at: indexPath, animated: true, scrollPosition: .left)
                            picker.dismiss(animated: true) {}
                        }
                    }
                }
            }
        }
    }
    
    public func imagePickerControllerDidCancel(_ picker: UIImagePickerController)
    {
        self.hideStatusBar = false
        picker.dismiss(animated: true) {}
    }
}

extension FileSelectionViewController
{
    fileprivate func fetchPhotoAlbum(_ completion:@escaping (_ assetCollection: PHAssetCollection?) -> ())
    {
        guard let albumName = self.photoAlbumName else {
            completion(nil)
            return
        }
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let collection : PHFetchResult = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        
        if let firstObj = collection.firstObject 
        {
            completion(firstObj)
        }
        else
        {
            PHPhotoLibrary.shared().performChanges({
                let createAlbumRequest : PHAssetCollectionChangeRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName as String)
                self.photoAlbumPlaceholder = createAlbumRequest.placeholderForCreatedAssetCollection
                
                }, completionHandler: { success, error in
                    DispatchQueue.main.async(execute: {
                        if (success)
                        {
                            let collectionFetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [self.photoAlbumPlaceholder!.localIdentifier], options: nil)
                            completion(collectionFetchResult.firstObject )
                        }
                        else
                        {
                            completion(nil)
                        }
                    });
            })
        }
    }
    
    fileprivate func saveImage(_ image: UIImage)
    {
        // try and sav it in the album we have created
        fetchPhotoAlbum(){ assetCollection in
            PHPhotoLibrary.shared().performChanges({

                let createAssetRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
                let assetPlaceholder = createAssetRequest.placeholderForCreatedAsset
                DispatchQueue.main.async(execute: { 
                    self.recentlyAddedPhotoLocalIdentifier = assetPlaceholder
                })
                if let assetCollection = assetCollection, let assetPlaceholder = assetPlaceholder
                {
                    let albumChangeRequest = PHAssetCollectionChangeRequest(for: assetCollection)!
                    albumChangeRequest.addAssets([assetPlaceholder] as NSArray)
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
    public func numberOfSections(in collectionView: UICollectionView) -> Int
    {
        return 2;
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int
    {
        switch section {
        case 0:
            return self.singlePhotoSelectionAsset?.count ?? 0
        default:
            return self.recentlyAddedAssets?.count ?? 0
        }
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell
    {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: FileSelectionCollectionViewCell.reuseIdentifier, for: indexPath) as! FileSelectionCollectionViewCell;
        
        var asset:AnyObject?
        
        switch indexPath.section {
        case 0:
            asset = self.singlePhotoSelectionAsset?[indexPath.row]
        default:
            asset = self.recentlyAddedAssets?[indexPath.row]
        }
        
        if let asset = asset as? PHAsset
        {
            self.imageManager?.requestImage(for: asset, targetSize: cell.frame.size, contentMode: .aspectFill, options: nil)
            {
                image, info in
                cell.image = image;
                if let order = self.selectionOrder.index(of: indexPath)
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
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath)
    {
        self.addToSelectionOrder(indexPath)
    }
    
    public func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath)
    {
        self.removeFromSelectionOrder(indexPath)
    }
    
    func updateSelectionOrder ()
    {
        guard let paths = self.collectionView?.indexPathsForVisibleItems else { return; }
        for path in paths
        {
            var index = self.selectionOrder.index(of: path) ?? -1;
            index += 1;
            (self.collectionView?.cellForItem(at: path) as? FileSelectionCollectionViewCell)?.selectedOrder = index
        }
    }
    
    fileprivate func removeFromSelectionOrder(_ indexPath: IndexPath)
    {
        if let index = self.selectionOrder.index(of: indexPath)
        {
            self.selectionOrder.remove(at: index);
            self.updateSelectionOrder();
            if self.selectionOrder.count == 0
            {
                self.hideUploadButton(true);
            }
        }
    }
    
    fileprivate func addToSelectionOrder(_ indexPath: IndexPath)
    {
        let shouldShow = self.selectionOrder.count == 0;
        
        if self.selectionOrder.index(of: indexPath) == nil
        {
            self.selectionOrder.append(indexPath)
            self.updateSelectionOrder();
            if shouldShow
            {
                self.showUploadButton(true);
            }
        }
    }
    
    fileprivate func clearSelectionOrder()
    {
        self.selectionOrder.removeAll()
        self.hideUploadButton(false);
    }
}

// MARK: - PHPhotoLibraryChangeObserver

extension FileSelectionViewController: PHPhotoLibraryChangeObserver
{
    public func photoLibraryDidChange(_ changeInstance: PHChange)
    {
        DispatchQueue.main.async
        {
            guard let assets = self.recentlyAddedAssets, let collection = self.collectionView else { return };
            if let details = changeInstance.changeDetails(for: assets as! PHFetchResult<PHObject>)
            {
                self.recentlyAddedAssets = details.fetchResultAfterChanges as? PHFetchResult<PHAsset>

                guard details.hasIncrementalChanges else {
                    self.clearSelectionOrder();
                    collection.reloadData();
                    return
                }
                
                if let removed = details.removedIndexes {
                    let indexPaths = removed.map { IndexPath(row: $0, section: 1) };
                    _ = indexPaths.map(self.removeFromSelectionOrder)
                    collection.deleteItems(at: indexPaths)
                }
                
                if let added = details.insertedIndexes {
                    if let selectedIndexes = collection.indexPathsForSelectedItems {
                        _ = selectedIndexes.map(self.removeFromSelectionOrder)
                    }
                    
                    collection.insertItems(at: added.map { IndexPath(row: $0, section: 1)})
                    
                    if let selectedIndexes = collection.indexPathsForSelectedItems {
                        _ = selectedIndexes.map(self.addToSelectionOrder)
                    }
                }
                
                if let changed = details.changedIndexes {
                    let selectedIndexes = collection.indexPathsForSelectedItems
                    collection.reloadItems(at: changed.map { IndexPath(row: $0, section: 1)})
                    
                    // Reselect afer refresh. No need to add/remove from selectionOrder, indexes wont change
                    if let selectedIndexes = selectedIndexes {
                        for index in selectedIndexes {
                            collection.selectItem(at: index, animated: false, scrollPosition: UICollectionViewScrollPosition())
                        }
                    }
                }
                
                details.enumerateMoves { from, to in
                    if let selectedIndexes = collection.indexPathsForSelectedItems {
                        _ = selectedIndexes.map(self.removeFromSelectionOrder)
                    }
                    collection.moveItem(at: IndexPath(row: from, section: 1), to: IndexPath(row: to, section: 1))
                    
                    if let selectedIndexes = collection.indexPathsForSelectedItems {
                        _ = selectedIndexes.map(self.addToSelectionOrder)
                    }
                }
                
                // If we have a recently added image from the camera we iterate over the assets from fetchResultAfterChanges
                // and attempt to select it in the collectionView.
                if let newImage = self.recentlyAddedPhotoLocalIdentifier {
                    if let selectedIndexes = collection.indexPathsForSelectedItems {
                        for indexPath in selectedIndexes {
                            collection.deselectItem(at: indexPath, animated: false)
                            self.removeFromSelectionOrder(indexPath)
                        }
                    }

                    assets.enumerateObjects({ obj, index, stop in
                        if obj.localIdentifier == newImage.localIdentifier {
                            self.recentlyAddedPhotoLocalIdentifier = nil
                            stop.pointee = true
                            
                            let indexPath = IndexPath(row: index, section: 1)
                            collection.selectItem(at: indexPath, animated: true, scrollPosition: .centeredHorizontally)
                            self.addToSelectionOrder(indexPath)
                        }
                    })
                }
            }
        }
    }
}
