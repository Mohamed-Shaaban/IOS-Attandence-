//
//  secondViewController.swift
//  Attendance
//
//  Created by ODU Webadmin on 5/21/18.
//  Copyright © 2018 Old Dominion University. All rights reserved.
//

import UIKit
import SQLite3
import AVFoundation

class MainViewController: UIViewController {

    var midas:String = ""
    var db: OpaquePointer?
    @IBOutlet var label2: UILabel!
    
    @IBAction func qrcode(_ sender: Any) {
        if Reachability.isConnectedToNetwork(){
            print("Internet Connection Available!")
            proceedWithCameraAccess(identifier: "qrcode")
        }else{
            // Create Alert
            let alert = UIAlertController(title: "Internet Connection", message: "Internet access is absolutely necessary to use this app", preferredStyle: .alert)
            
            // Add "OK" Button to alert, pressing it will bring you to the settings app
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { saction in
                //UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!)
                return
            }))
            // Show the alert with animation
            self.present(alert, animated: true)
        }
    }
    
    @IBAction func gotoHistory(_ sender: Any) {
        self.performSegue(withIdentifier: "tablview", sender: self)
    }
   
    @IBAction func setting(_ sender: UIButton) {
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //To change Navigation Bar Background Color
        let myColor = UIColor(red: 6.0/255.0, green: 55.0/255.0, blue: 88.0/255.0, alpha: 1.0)

        UINavigationBar.appearance().barTintColor = myColor
        let oduAttendanceDbUrl = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("OduAttendanceDb.sqlite")
        
        if sqlite3_open(oduAttendanceDbUrl.path, &db) != SQLITE_OK {
            print("Error opening database")
        }
        
        if let user:User = fetchActiveUser() {
            self.label2.text = "Welcome, " + user.firstName
            midas = user.midas
        }
    }
    
    func proceedWithCameraAccess(identifier: String){
        // handler in .requestAccess is needed to process user's answer to our request
        AVCaptureDevice.requestAccess(for: .video) { success in
            if success { // if request is granted (success is true)
                DispatchQueue.main.async {
                    self.performSegue(withIdentifier: identifier, sender: nil)
                }
            } else { // if request is denied (success is false)
                // Create Alert
                let alert = UIAlertController(title: "Camera", message: "Camera access is absolutely necessary to use this app", preferredStyle: .alert)
                
                // Add "OK" Button to alert, pressing it will bring you to the settings app
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
                    UIApplication.shared.open(URL(string: UIApplicationOpenSettingsURLString)!)
                }))
                // Show the alert with animation
                self.present(alert, animated: true)
            }
        }
    }
    
    func fetchActiveUser() -> User? {
        let queryString = "SELECT * FROM Users WHERE is_active = 1"
        
        // Statement pointer
        var stmt:OpaquePointer?
        
        if sqlite3_prepare(db, queryString, -1, &stmt, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("Error preparing reading: \(errmsg)")
            return nil
        }
        var user: User?
        var counter = 0
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            counter += 1
            let userId = sqlite3_column_int(stmt, 0)
            let midas = String(cString: sqlite3_column_text(stmt, 1))
            let firstName = String(cString: sqlite3_column_text(stmt, 2))
            let lastName = String(cString: sqlite3_column_text(stmt, 3))
            let isStudent = sqlite3_column_int(stmt, 4)
            let isActive = sqlite3_column_int(stmt, 5)
            user = User(userId: userId, midas: midas, firstName: firstName, lastName: lastName, isStudent: isStudent != 0, isActive: isActive != 0)
        }
        if counter > 1 {
            print("More than one user is active")
            return nil
        }
        sqlite3_finalize(stmt)
        return user
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        navigationController?.setNavigationBarHidden(true, animated: true)
    }
    @objc func thumbsUpButtonPressed() {
        performSegue(withIdentifier: "qrcode", sender: self)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "qrcode"{
            let vc = segue.destination as! QRCodeViewController
            vc.midas=self.midas
        }
        if segue.identifier == "tablview"{
            let vc = segue.destination as! HistoryViewController
            vc.midas = self.midas
        }
    }


}
