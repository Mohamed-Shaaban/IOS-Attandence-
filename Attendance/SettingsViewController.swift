//
//  SettingsViewController.swift
//  Attendance
//
//  Created by ODU Webadmin on 8/3/18.
//  Copyright © 2018 Old Dominion University. All rights reserved.
//

import UIKit
import SQLite3

class SettingsViewController: UIViewController {

    var db: OpaquePointer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let oduAttendanceDbUrl = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("OduAttendanceDb.sqlite")
        
        if sqlite3_open(oduAttendanceDbUrl.path, &db) != SQLITE_OK {
            print("Error opening database")
        }
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func signout(_ sender: UIButton) {
        if self.inactiveAllUsers() {
            let cstorage = HTTPCookieStorage.shared
            if let cookies = cstorage.cookies {
                for cookie in cookies {
                    cstorage.deleteCookie(cookie)
                }
            }
            self.navigationController?.popToRootViewController(animated: true)
        } else {
            let alert = UIAlertController(title: "Logout error", message: "Please try again", preferredStyle: UIAlertControllerStyle.alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.destructive, handler: { action in
            }))
            // show the alert
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    func inactiveAllUsers() -> Bool {
        let queryString = "Update Users SET is_active = 0"
        
        // Statement pointer
        var stmt:OpaquePointer?
        
        if sqlite3_prepare(db, queryString, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_DONE {
                //print("Successfully updated row.")
                sqlite3_finalize(stmt)
                return true
            } else {
                //print("Could not update row.")
                sqlite3_finalize(stmt)
                return false
            }
        } else {
            //let errmsg = String(cString: sqlite3_errmsg(db)!)
            //print("Error preparing reading: \(errmsg)")
            sqlite3_finalize(stmt)
            return false
        }
        
    }
}
