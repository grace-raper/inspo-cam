//
//  ViewController.swift
//  inspo-cam
//
//  Created by Grace Raper on 8/8/22.
//

import AVFoundation
import UIKit
import PhotosUI

class ViewController: UIViewController {
        
    // Capture Session
    var session: AVCaptureSession?
    // Photo Output
    let output = AVCapturePhotoOutput()
    // Video Preview
    let previewLayer = AVCaptureVideoPreviewLayer()
    
    // inspiration picture
    private let inspoLayer: CALayer = {
        let inspo = CALayer()
        inspo.contents = UIImage(named: "test-image")?.cgImage
        inspo.opacity = 0.35
        inspo.contentsGravity = CALayerContentsGravity.resizeAspect;
        return inspo
    }()

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
    
    // Shutter Button
    private let pickInspoPhotoButton: UIButton = {
        let button = UIButton(frame: CGRect(x: 0, y:0, width: 80, height: 80))
        button.layer.cornerRadius = 5
        button.layer.borderWidth = 10
        button.layer.borderColor = UIColor.white.cgColor
        return button
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.layer.addSublayer(previewLayer)
        view.layer.addSublayer(inspoLayer)
        view.addSubview(shutterButton)
        view.addSubview(pickInspoPhotoButton)
        view.addSubview(opacitySlider)
        checkCameraPermissions()
        shutterButton.addTarget(self, action: #selector(didTapTakePhoto), for: .touchUpInside)
        pickInspoPhotoButton.addTarget(self, action: #selector(pickPhotos), for: .touchUpInside)
        opacitySlider.addTarget(self, action: #selector(self.sliderValueDidChange(_:)), for: .valueChanged)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
        inspoLayer.frame = view.bounds
        shutterButton.center = CGPoint(x: view.frame.size.width/2, y: view.frame.size.height - 80)
        pickInspoPhotoButton.center = CGPoint(x: view.frame.size.width/2 - 100, y: view.frame.size.height - 80)
        opacitySlider.center = CGPoint(x: view.frame.size.width/2, y: view.frame.size.height - 145)
    }
    
    private func checkCameraPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard granted else {
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
        if let device = AVCaptureDevice.default(for: .video) {
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(input) {
                    session.addInput(input)
                }
                
                if session.canAddOutput(output) {
                    session.addOutput(output)
                }
                previewLayer.videoGravity = .resizeAspectFill
                previewLayer.session = session
                
                session.startRunning()
                self.session = session
            } catch {
                print(error)
            }
        }
    }

    
    
    @objc func sliderValueDidChange(_ sender:UISlider!){
        print("Slider value changed")
        inspoLayer.opacity = sender.value
        // Use this code below only if you want UISlider to snap to values step by step
        //let roundedStepValue = round(sender.value / step) * step
        //sender.value = roundedStepValue
        //print("Slider step value \(Int(roundedStepValue))")
    }
    
    @objc private func didTapTakePhoto() {
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
}

extension ViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation() else {
            return
        }
        session?.stopRunning()
        
        let image = UIImage(data: data)
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        view.addSubview(imageView)
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
                     self.inspoLayer.contents = image.cgImage
                     self.inspoLayer.contentsGravity = CALayerContentsGravity.resizeAspect;
                    //print("Selected image: \(image)")
                 }
              }
           })
        }
    }
}
