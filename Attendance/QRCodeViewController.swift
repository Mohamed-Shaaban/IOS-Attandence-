//
//  LoginViewController.swift
//  Attendance
//
//  Created by ODU Webadmin on 5/21/18.
//  Copyright © 2018 Old Dominion University. All rights reserved.
//

import AVFoundation
import UIKit

class QRCodeViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var sendqr = ""
    var timestamp: Date?
    var captureSession:AVCaptureSession!
    var videoPreviewLayer:AVCaptureVideoPreviewLayer?
    var qrCodeFrameView:UIView?
    var zoomFactor: Float = 1.0
    var midas=""
    var formattedDateInString = ""

    

    @IBAction func back(_ sender: UIBarButtonItem) {
        self.performSegue(withIdentifier: "back", sender: self)

    }
    @objc func back(sender: UIBarButtonItem) {
        // Perform your custom actions
        // ...
        // Go back to the previous ViewController
        _ = navigationController?.popViewController(animated: true)
    }
    @IBOutlet var sq: UIImageView!
    let supportedCodeTypes = [AVMetadataObject.ObjectType.qr]
    var resultString = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let pgr = UIPinchGestureRecognizer(target: self, action: #selector(zoom))
        view.addGestureRecognizer(pgr)
        guard let captureDevice = AVCaptureDevice.default(for: AVMediaType.video) else {return}
        
        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            captureSession = AVCaptureSession()
            captureSession?.addInput(input)
            let captureMetadataOutput = AVCaptureMetadataOutput()
            captureSession?.addOutput(captureMetadataOutput)
            
            captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            captureMetadataOutput.metadataObjectTypes = supportedCodeTypes
            
            videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
            videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
            videoPreviewLayer?.frame = view.layer.bounds
            view.layer.insertSublayer(videoPreviewLayer!, at: 0)
            // need to change this and add square to capture
            qrCodeFrameView = UIImageView()
            
            qrCodeFrameView = UIView()
            
            if let qrCodeFrameView = qrCodeFrameView {
                qrCodeFrameView.layer.borderColor = UIColor.green.cgColor
                qrCodeFrameView.layer.borderWidth = 2
                view.addSubview(qrCodeFrameView)
                view.bringSubview(toFront: qrCodeFrameView)
            }
            captureSession?.startRunning()
            
        } catch {
            // If any error occurs, simply print it out and don't continue any more.
            print(error)
            return
        }
    }

    @objc public func zoom(pinch: UIPinchGestureRecognizer) {
        guard let device = AVCaptureDevice.default(for: AVMediaType.video) else {return}
        func minMaxZoom(_ factor: CGFloat) -> CGFloat { return min(max(factor, 1.0), device.activeFormat.videoMaxZoomFactor) }
        
        func update(scale factor: CGFloat) {
            do {
                try device.lockForConfiguration()
                defer { device.unlockForConfiguration() }
                device.videoZoomFactor = factor
            } catch {
                debugPrint(error)
            }
        }
        
        let newScaleFactor = minMaxZoom(pinch.scale * CGFloat(zoomFactor))
        
        switch pinch.state {
        case .began: fallthrough
        case .changed: update(scale: newScaleFactor)
        case .ended:
            zoomFactor = Float(minMaxZoom(newScaleFactor))
            update(scale: CGFloat(zoomFactor))
        default: break
        }
    }
    

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession.stopRunning()
        if metadataObjects.count == 0 {
            qrCodeFrameView?.frame = CGRect.zero
            print("No QR/barcode is detected")
            return
        }
        
        let metadataObj = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
        
        if supportedCodeTypes.contains(metadataObj.type) {
            
            let barCodeObject = videoPreviewLayer?.transformedMetadataObject(for: metadataObj)
            qrCodeFrameView?.frame = barCodeObject!.bounds
            
            if metadataObj.stringValue != nil {
                sendqr = metadataObj.stringValue!
                timestamp = Date()
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                formattedDateInString = formatter.string(from: timestamp!)
                print ("Here is file \(formattedDateInString)")
                self.performSegue(withIdentifier: "check", sender: self)
                dismiss(animated: true)
            }
        }
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "check" {
            let vc = segue.destination as! CheckedInViewController
            vc.qrrec = self.sendqr
            vc.timest = self.formattedDateInString
            vc.midas = self.midas
        }
        
    }
}
