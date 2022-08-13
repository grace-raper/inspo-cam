//
//  ViewController.swift
//  inspo-cam
//
//  Created by Grace Raper on 8/8/22.
//

import AVFoundation
import Foundation
import Combine
import UIKit
import Photos
import PhotosUI
import CoreLocation

class ViewController: UIViewController {
    private let sessionQueue = DispatchQueue(label: "session queue")
    
    // Photo Output
    let output = AVCapturePhotoOutput()
    let photoOutput = AVCapturePhotoOutput()
    
    // Video Preview
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
    let previewLayer = AVCaptureVideoPreviewLayer()
    let videoOrientation = AVCaptureVideoOrientation.portrait
    
    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera], mediaType: .video, position: .unspecified)
    
    var InspoCgImage =  UIImage(named: "test-image")?.cgImage
    
    private let inspoLayer: CALayer = {
        let inspo = CALayer()
        inspo.contents = UIImage(named: "test-image")?.cgImage
        inspo.opacity = 0.35
        inspo.contentsGravity = CALayerContentsGravity.resizeAspect;
        return inspo
    }()
    
    func correctImageOrientation(cgImage: CGImage?, orienation: UIImage.Orientation) -> CGImage? {
        guard let cgImage = cgImage else { return nil }
        var orientedImage: CGImage?

        let originalWidth = cgImage.width
        let originalHeight = cgImage.height
        let bitsPerComponent = cgImage.bitsPerComponent
        let bytesPerRow = cgImage.bytesPerRow
        let bitmapInfo = cgImage.bitmapInfo

        guard let colorSpace = cgImage.colorSpace else { return nil }

        let degreesToRotate = orienation.getDegree()
        let mirrored = orienation.isMirror()

        var width = originalWidth
        var height = originalHeight

        let radians = degreesToRotate * Double.pi / 180.0
        let swapWidthHeight = Int(degreesToRotate / 90) % 2 != 0

        if swapWidthHeight {
            swap(&width, &height)
        }

        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo.rawValue)

        context?.translateBy(x: CGFloat(width) / 2.0, y: CGFloat(height) / 2.0)
        if mirrored {
            context?.scaleBy(x: -1.0, y: 1.0)
        }
        context?.rotate(by: CGFloat(radians))
        if swapWidthHeight {
            swap(&width, &height)
        }
        context?.translateBy(x: -CGFloat(width) / 2.0, y: -CGFloat(height) / 2.0)

        context?.draw(cgImage, in: CGRect(x: 0.0, y: 0.0, width: CGFloat(originalWidth), height: CGFloat(originalHeight)))
        orientedImage = context?.makeImage()

        return orientedImage
    }

    // Opacity Slider
    private let opacitySlider: UISlider = {
        let slider = UISlider(frame:CGRect(x: 0, y: 0, width: 300, height: 20))
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.value = 0.35
        slider.isContinuous = true
        return slider
    }()
    
    // Shutter Button
    private let shutterButton: UIButton = {
        let button = UIButton(frame: CGRect(x: 0, y:0, width: 80, height: 80))
        button.layer.cornerRadius = 40
        button.layer.borderWidth = 10
        button.layer.borderColor = UIColor.white.cgColor
        return button
    }()
    
    // pick inspo button
    private let pickInspoPhotoButton: UIButton = {
        let button = UIButton(frame: CGRect(x: 0, y:0, width: 60, height: 60))
        button.layer.cornerRadius = 15
        button.layer.borderWidth = 4
        button.layer.borderColor = UIColor.white.cgColor
        let buttonIcon = UIImage(systemName: "tray.and.arrow.up")
        button.setImage(buttonIcon, for: .normal)
        button.tintColor = UIColor.white
        return button
    }()
    
    // flip camera button
    private let flipCameraButton: UIButton = {
        let button = UIButton(frame: CGRect(x: 0, y:0, width: 60, height: 60))
        button.layer.cornerRadius = 15
        button.layer.borderWidth = 4
        button.layer.borderColor = UIColor.white.cgColor
        let buttonIcon = UIImage(systemName: "camera.rotate.fill")
        button.setImage(buttonIcon, for: .normal)
        button.tintColor = UIColor.white
        return button
    }()
    
    private let mirrorImageButton: UIButton = {
        let button = UIButton(frame: CGRect(x: 0, y: 0, width: 36, height: 36))
        button.layer.cornerRadius = 9
        button.layer.borderWidth = 2
        button.layer.borderColor = UIColor.white.cgColor
        let buttonIcon = UIImage(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
        button.setImage(buttonIcon, for: .normal)
        button.tintColor = UIColor.white
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.addSubview(shutterButton)
        view.addSubview(pickInspoPhotoButton)
        view.addSubview(opacitySlider)
        checkCameraPermissions()
        view.layer.addSublayer(previewLayer)
        view.layer.addSublayer(inspoLayer)
        view.addSubview(flipCameraButton)
        view.addSubview(mirrorImageButton)
        shutterButton.addTarget(self, action: #selector(didTapTakePhoto), for: .touchUpInside)
        pickInspoPhotoButton.addTarget(self, action: #selector(pickPhotos), for: .touchUpInside)
        flipCameraButton.addTarget(self, action: #selector(changeCamera), for: .touchUpInside)
        opacitySlider.addTarget(self, action: #selector(self.sliderValueDidChange(_:)), for: .valueChanged)
        mirrorImageButton.addTarget(self, action: #selector(mirrorInspoImage), for: .touchUpInside)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = CGRect(origin: CGPoint(), size: CGSize(width: view.frame.size.width, height: view.frame.size.height-80)) // works but idk how
        inspoLayer.frame = previewLayer.frame
        shutterButton.center = CGPoint(x: view.frame.size.width/2, y: view.frame.size.height - 80)
        pickInspoPhotoButton.center = CGPoint(x: view.frame.size.width/2 - 130, y: view.frame.size.height - 80)
        flipCameraButton.center = CGPoint(x: view.frame.size.width/2 + 130, y: view.frame.size.height - 80)
        opacitySlider.center = CGPoint(x: view.frame.size.width/2, y: view.frame.size.height - 145)
        mirrorImageButton.center = CGPoint(x: view.frame.size.width/2 + 175, y: view.frame.size.height - 250)
    }
    
    private func checkCameraPermissions() {
        // Request camera access - REQUIRED in order to set up camera
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) {
                [weak self] granted in guard granted else {
                    return
                }
                DispatchQueue.main.async {
                    self?.setUpCamera()
                }
            }
        case .restricted:
            break;
        case .denied:
            break;
        case .authorized:
            setUpCamera()
        @unknown default:
            break
        }
    }
    
    private func setUpCamera() {
        let session = AVCaptureSession()
        session.beginConfiguration()
        session.sessionPreset = .photo
        // Add video input.
        do {
            var defaultVideoDevice: AVCaptureDevice?
            if let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .back) {
                defaultVideoDevice = dualCameraDevice
                print("default video set to dualCameraDevice")
            }
            guard let videoDevice = defaultVideoDevice else {
                print("default video device is unavailable.")
                return
            }
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            if session.canAddInput(videoDeviceInput) {
                print("video device input")
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                self.previewLayer.connection?.videoOrientation = videoOrientation
            } else {
                print("Couldn't add video device input to the session.")
                return
            }
        } catch {
            print("Couldn't create video device input: \(error)")
            return
        }
        
        // Add the photo output.
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.isHighResolutionCaptureEnabled = true
            output.maxPhotoQualityPrioritization = .quality
        } else {
            print("Could not add photo output to the session")
            return
        }
        session.commitConfiguration()
        session.startRunning()
        previewLayer.session = session
    }

    @objc private func sliderValueDidChange(_ sender:UISlider!){
        print("Slider value changed")
        inspoLayer.opacity = sender.value
    }
    
    @objc private func didTapTakePhoto() {
        print("shutter triggered")
        output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }
    
    // todo: understand better...
    @objc func pickPhotos(){
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = PHPickerFilter.images
        let pickerViewController = PHPickerViewController(configuration: config)
        pickerViewController.delegate = self
        self.present(pickerViewController, animated: true, completion: nil)
    }
    
    @objc func mirrorInspoImage() {
        InspoCgImage = correctImageOrientation(cgImage: InspoCgImage, orienation: UIImage.Orientation.upMirrored)
        inspoLayer.contents = InspoCgImage
    }
    
    
    @objc private func changeCamera() {
        sessionQueue.async {
            let currentVideoDevice = self.videoDeviceInput.device
            let currentPosition = currentVideoDevice.position
            let preferredPosition: AVCaptureDevice.Position
            let preferredDeviceType: AVCaptureDevice.DeviceType
            
            switch currentPosition {
            case .unspecified, .front:
                preferredPosition = .back
                preferredDeviceType = .builtInWideAngleCamera
                
            case .back:
                preferredPosition = .front
                preferredDeviceType = .builtInWideAngleCamera
                
            @unknown default:
                print("Unknown capture position. Defaulting to back, dual-camera.")
                preferredPosition = .back
                preferredDeviceType = .builtInWideAngleCamera
            }
            
            let devices = self.videoDeviceDiscoverySession.devices
            var newVideoDevice: AVCaptureDevice? = nil
            
            // First, seek a device with both the preferred position and device type. Otherwise, seek a device with only the preferred position.
            if let device = devices.first(where: { $0.position == preferredPosition && $0.deviceType == preferredDeviceType }) {
                newVideoDevice = device
            } else if let device = devices.first(where: { $0.position == preferredPosition }) {
                newVideoDevice = device
            }
            
            if let videoDevice = newVideoDevice {
                do {
                    let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
                    self.previewLayer.session!.beginConfiguration()
                    
                    self.previewLayer.session!.removeInput(self.videoDeviceInput) // remove existing device
                    if self.previewLayer.session!.canAddInput(videoDeviceInput) {
                        self.previewLayer.session!.addInput(videoDeviceInput)
                        self.videoDeviceInput = videoDeviceInput
                    } else {
                        self.previewLayer.session!.addInput(self.videoDeviceInput)
                    }
                    
                    if let connection = self.photoOutput.connection(with: .video) {
                        if connection.isVideoStabilizationSupported {
                            connection.preferredVideoStabilizationMode = .auto
                        }
                    }
                    self.photoOutput.maxPhotoQualityPrioritization = .quality
                    self.previewLayer.session!.commitConfiguration()
                } catch {
                    print("Error occurred while creating video device input: \(error)")
                }
            }
        }
    }
}

extension ViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation() else {
            return
        }
        self.saveToPhotoLibrary(data)
    }
    
    func saveToPhotoLibrary(_ photoData: Data) {
        PHPhotoLibrary.requestAuthorization { status in
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges({
                    let options = PHAssetResourceCreationOptions()
                    let creationRequest = PHAssetCreationRequest.forAsset()
                    creationRequest.addResource(with: .photo, data: photoData, options: options)
                }, completionHandler: { _, error in
                    if let error = error {
                        print("Error occurred while saving photo to photo library: \(error)")
                    }
                })
            }
        }
    }
}

// todo: understand better...
extension ViewController: PHPickerViewControllerDelegate {
    public func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true, completion: nil)
        print(picker)
        print(results)
        
        for result in results {
           result.itemProvider.loadObject(ofClass: UIImage.self, completionHandler: { (object, error) in
              if let image = object as? UIImage {
                 DispatchQueue.main.async {
                     self.InspoCgImage = image.cgImage
                     self.inspoLayer.contents = self.InspoCgImage
                     self.inspoLayer.contentsGravity = CALayerContentsGravity.resizeAspect;
                    //print("Selected image: \(image)")
                 }
              }
           })
        }
    }
}

extension UIImage.Orientation {
    func getDegree() -> Double {
        switch self {
        case .up, .upMirrored:
            return 0.0
        case .right, .rightMirrored:
            return 90.0
        case .down, .downMirrored:
            return 180.0
        case .left, .leftMirrored:
            return -90.0
        default:
            return 0
        }
    }

    func isMirror() -> Bool {
        switch self {
        case .up, .right, .down, .left:
            return false
        case .leftMirrored, .upMirrored, .downMirrored, .rightMirrored:
            return true
        default:
            return false
        }
    }
}
