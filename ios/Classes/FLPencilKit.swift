import Flutter
import UIKit
import PencilKit
import Foundation
// import photokit
// import PhotosUI
import Photos
// import PHPhotoLibrary

class FLPencilKitFactory: NSObject, FlutterPlatformViewFactory{
	private var messenger: FlutterBinaryMessenger
	
	init(messenger: FlutterBinaryMessenger) {
		self.messenger = messenger
		super.init()
	}
	
	func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
		return FlutterStandardMessageCodec.sharedInstance()
	}
	
	func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
		return FLPencilKit(
			frame: frame,
			viewIdentifier: viewId,
			arguments: args,
			binaryMessenger: messenger
		)
	}
}

class FLPencilKit: NSObject, FlutterPlatformView {
	private var _view: UIView
	private var methodChannel: FlutterMethodChannel
	func view() -> UIView { 
		return _view 
	}
	
	init(
		frame: CGRect,
		viewIdentifier viewId: Int64,
		arguments args: Any?,
		binaryMessenger messenger: FlutterBinaryMessenger?
	) {
		methodChannel = FlutterMethodChannel(name: "plugins.mjstudio/flutter_pencil_kit_\(viewId)", binaryMessenger: messenger!)
		if #available(iOS 13.0, *) {
			_view = PencilKitView(frame: frame, methodChannel: methodChannel)
		} else {
			_view = UIView(frame: frame)
		}
		super.init()
		methodChannel.setMethodCallHandler(onMethodCall)
	}
	
	
	private func onMethodCall(call: FlutterMethodCall, result: @escaping FlutterResult) {
		if #available(iOS 13.0, *) {
			guard let pencilKitView = _view as? PencilKitView else { return }
			switch(call.method){
				case "clear":
					pencilKitView.clear()
				case "dataRepresentation":
					result(pencilKitView.dataRepresentation())
				case "saveAndGet":
					let albumName = call.arguments as! String
					pencilKitView.saveAndGet(albumName, result)
				case "save":
					let albumName = call.arguments as! String
					pencilKitView.save(albumName, result)
				case "applyProperties":
					pencilKitView.applyProperties(properties: call.arguments as! [String : Any?]);
				default:
					break
			}
		}
	}
}

@available(iOS 13.0, *)
fileprivate class PencilKitView: UIView {
	private lazy var canvasView: PKCanvasView = {
		let v = PKCanvasView()
		v.translatesAutoresizingMaskIntoConstraints = false
		v.delegate = self
		v.drawing = PKDrawing()
		v.alwaysBounceVertical = false
		v.allowsFingerDrawing = true
		v.backgroundColor = .clear
		v.isOpaque = false
		return v
	}()
	var identifier: String? = nil
	private var toolPickerForIos14: PKToolPicker? = nil
	private var toolPicker: PKToolPicker? {
		get {
			if #available(iOS 14.0, *) {
				if toolPickerForIos14 == nil {
					toolPickerForIos14 = PKToolPicker()
				}
				return toolPickerForIos14!
			} else {
				guard let window = UIApplication.shared.windows.first, let toolPicker = PKToolPicker.shared(for: window) else { return nil }
				return toolPicker;
			}
		}
	}
	
	private let channel: FlutterMethodChannel
	
	required init?(coder: NSCoder) {
		fatalError("Not Implemented")
	}
	
	override init(frame: CGRect) {
		fatalError("Not Implemented")
	}
	
	init(frame: CGRect, methodChannel: FlutterMethodChannel) {
		channel = methodChannel
		super.init(frame: frame)

		// layout
		self.addSubview(canvasView)
		NSLayoutConstraint.activate([
			canvasView.widthAnchor.constraint(equalTo: self.widthAnchor),
			canvasView.heightAnchor.constraint(equalTo: self.heightAnchor),
			canvasView.centerXAnchor.constraint(equalTo: self.centerXAnchor),
			canvasView.centerYAnchor.constraint(equalTo: self.centerYAnchor),
		])
		
		toolPicker?.addObserver(canvasView)
		toolPicker?.addObserver(self)
		toolPicker?.setVisible(true, forFirstResponder: canvasView)
		canvasView.becomeFirstResponder()
	}
	
	deinit {
		toolPicker?.removeObserver(canvasView)
		toolPicker?.removeObserver(self)
	}
	
	func clear(){
		canvasView.drawing = PKDrawing()
	}

	func dataRepresentation() -> Data {
		return canvasView.drawing.dataRepresentation()
	}

	/// Returns the user-domain directory of the given type.
	private func getDirectory(ofType directory: FileManager.SearchPathDirectory) -> String? {
		let paths = NSSearchPathForDirectoriesInDomains(
			directory,
			FileManager.SearchPathDomainMask.userDomainMask,
			true)
		return paths.first
	}

	func saveAndGet(_ albumName: String, _ result: @escaping FlutterResult) {		
		let drawing = canvasView.drawing
		let image = drawing.image(from: drawing.bounds, scale: UIScreen.main.scale)
		PHPhotoLibrary.saveImage(image: image, albumName: albumName) { (assert) in
			let localIdentifier = assert!.localIdentifier
			self.identifier = localIdentifier
			// result(localIdentifier)
			print("\(localIdentifier)")
		}
		let imageData = image.jpegData(compressionQuality: 1.0)
		let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        // let temporaryDirectory = FileManager.default.urls(for: .temporaryDirectory, in: .userDomainMask).first!
        let fileURL = temporaryDirectory.appendingPathComponent("wa_pencilkit_\(UUID().uuidString).jpg")
        try? imageData?.write(to: fileURL)
		result(fileURL.path)
	}

	func _del(_ identifier: String) {
		let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject
		PHPhotoLibrary.shared().performChanges({
			PHAssetChangeRequest.deleteAssets([asset] as NSArray)
		}, completionHandler: { success, error in
			if success {
				self.identifier = nil
				print("Image deleted from gallery")
			}
		})
	}

	func save(_ albumName: String, _ result: @escaping FlutterResult) {
		let drawing = canvasView.drawing		
		let image = drawing.image(from: drawing.bounds, scale: UIScreen.main.scale)

		PHPhotoLibrary.saveImage(image: image, albumName: albumName) { (assert) in
			let localIdentifier = assert!.localIdentifier
			self.identifier = localIdentifier
			result(localIdentifier)
			print("\(localIdentifier)")
		}
	}

	func applyProperties(properties: [String:Any?]) {
		if let alwaysBounceVertical = properties["alwaysBounceVertical"] as? Bool {
			canvasView.alwaysBounceVertical = alwaysBounceVertical
		}
		if let alwaysBounceHorizontal = properties["alwaysBounceHorizontal"] as? Bool {
			canvasView.alwaysBounceHorizontal = alwaysBounceHorizontal
		}
		if let isRulerActive = properties["isRulerActive"] as? Bool {
			canvasView.isRulerActive = isRulerActive
		}
		if #available(iOS 14.0, *), let drawingPolicy = properties["drawingPolicy"] as? Int {
			canvasView.drawingPolicy = PKCanvasViewDrawingPolicy.init(rawValue: UInt(drawingPolicy)) ?? .default
		}
		if let isOpaque = properties["isOpaque"] as? Bool {
			canvasView.isOpaque = isOpaque
		}
		if let backgroundColor = properties["backgroundColor"] as? Int {
			canvasView.backgroundColor = UIColor(hex: backgroundColor)
		}
	}
}

@available(iOS 13.0, *)
extension PencilKitView: PKCanvasViewDelegate {
	func toolPickerIsRulerActiveDidChange(_ toolPicker: PKToolPicker) {
		channel.invokeMethod("toolPickerIsRulerActiveDidChange", arguments: toolPicker.isRulerActive)
	}
	func toolPickerVisibilityDidChange(_ toolPicker: PKToolPicker) {
		channel.invokeMethod("toolPickerVisibilityDidChange", arguments: toolPicker.isVisible)
	}
	func toolPickerFramesObscuredDidChange(_ toolPicker: PKToolPicker) {
		
	}
	func toolPickerSelectedToolDidChange(_ toolPicker: PKToolPicker) {
		
	}
}

@available(iOS 13.0, *)
extension PencilKitView: PKToolPickerObserver {
	
}

extension UIColor {
	convenience init(hex: Int) {
		let alpha = Double((hex >> 24) & 0xff) / 255
		let red = Double((hex >> 16) & 0xff) / 255
		let green = Double((hex >> 8) & 0xff) / 255
		let blue = Double((hex >> 0) & 0xff) / 255
		
		self.init(red: red, green: green, blue: blue, alpha: alpha)
	}
}


public extension PHPhotoLibrary {
    
    typealias PhotoAsset = PHAsset
    typealias PhotoAlbum = PHAssetCollection
    
    static func saveImage(image: UIImage, albumName: String, completion: @escaping (PHAsset?)->()) {
        if let album = self.findAlbum(albumName: albumName) {
            saveImage(image: image, album: album, completion: completion)
            return
        }
        createAlbum(albumName: albumName) { album in 
            if let album = album {
                self.saveImage(image: image, album: album, completion: completion)
            }
            else {
                assert(false, "Album is nil")
            }
        }
    }
    
    static private func saveImage(image: UIImage, album: PhotoAlbum, completion: @escaping (PHAsset?)->()) {
        var photoPlaceholder: PHObjectPlaceholder?
        PHPhotoLibrary.shared().performChanges({
				// Request creating an asset from the image
				let createAssetRequest = PHAssetChangeRequest.creationRequestForAsset(from: image)
				// Request editing the album
				guard let albumChangeRequest = PHAssetCollectionChangeRequest(for: album) else {
					assert(false, "Album change request failed")
					return
				}
				guard let placeholder = createAssetRequest.placeholderForCreatedAsset else {
					assert(false, "photoPlaceholder is nil")
					return
				}
				
				photoPlaceholder = placeholder
				albumChangeRequest.addAssets([photoPlaceholder] as NSArray)
            }, completionHandler: { (success, error) in
                guard let assetID = photoPlaceholder?.localIdentifier else {
                    assert(false, "Placeholder is nil")
                    completion(nil)
                    return
                }
                
                if success {
					let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil).firstObject
					completion(asset)
                } else {
                    print(error)
                    completion(nil)
                }
        })
    }

    static func findAlbum(albumName: String) -> PhotoAlbum? {
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)
        let fetchResult = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: fetchOptions)
        guard let photoAlbum = fetchResult.firstObject as? PHAssetCollection else {
            return nil
        }
        return photoAlbum
    }
    
    static func createAlbum(albumName: String, completion: @escaping (PhotoAlbum?)->()) {
        var albumPlaceholder: PHObjectPlaceholder?
        PHPhotoLibrary.shared().performChanges({
				// Request creating an album with parameter name
				let createAlbumRequest = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
				// Get a placeholder for the new album
				albumPlaceholder = createAlbumRequest.placeholderForCreatedAssetCollection
            }, completionHandler: { (success, error) in
                guard let placeholder = albumPlaceholder else {
                    assert(false, "Album placeholder is nil")
                    completion(nil)
                    return
                }
                
                let fetchResult = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [placeholder.localIdentifier], options: nil)
                guard let album = fetchResult.firstObject as? PhotoAlbum else {
                    assert(false, "FetchResult has no PHAssetCollection")
                    completion(nil)
                    return
                }
                
                if success {
                    completion(album)
                }
                else {
                    print(error)
                    completion(nil)
                }
        })
    }
    
    static func loadThumbnailFromLocalIdentifier(localIdentifier: String, completion: @escaping (UIImage?)->()) {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil).firstObject else {
            completion(nil)
            return
        }
        loadThumbnailFromAsset(asset, completion: completion)
    }
    
    static func loadThumbnailFromAsset(_ asset: PhotoAsset, completion: @escaping (UIImage?)->()) {
        PHImageManager.default().requestImage(for: asset, targetSize: CGSize(width: 100.0, height: 100.0), contentMode: .aspectFit, options: PHImageRequestOptions(), resultHandler: { result, info in
            completion(result)
        })
    }
    
}