//
//  ViewController.swift
//  Attendance
//
//  Created by ODU Webadmin on 5/21/18.
//  Copyright © 2018 Old Dominion University. All rights reserved.
//

import UIKit
import SwiftECP
import XCGLogger
import SQLite3

class ViewController: UIViewController {
    var timer = Timer()
    var db: OpaquePointer?
    let LOGIN_URL = *****
    let CREATE_USER_TABLE = ****
    let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    @IBOutlet weak var pleasewait: UILabel!
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        navigationController?.setNavigationBarHidden(true, animated: true)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(true)
        navigationController?.setNavigationBarHidden(false, animated: false)
    }
    @IBOutlet var UsernameField: UITextField!
    @IBOutlet var passwordField: UITextField!
    @IBOutlet weak var login: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let oduAttendanceDbUrl = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("OduAttendanceDb.sqlite")
        
        if sqlite3_open(oduAttendanceDbUrl.path, &db) != SQLITE_OK {
            print("Error opening database")
        }
        //dropUserTable()
        if sqlite3_exec(db, CREATE_USER_TABLE, nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("Error creating table: \(errmsg)")
        }
        if Reachability.isConnectedToNetwork(){
            print("Internet Connection Available!")
            if let user:User = fetchActiveUser() {
                print("Active User is fetched : \(user.firstName)")
                self.performSegue(withIdentifier: "gotowelcome", sender: self)
            } else {
                UsernameField.attributedPlaceholder = NSAttributedString(string: " Enter MIDAS ID", attributes: [NSAttributedStringKey.foregroundColor : UIColor.white])
                passwordField.attributedPlaceholder = NSAttributedString(string: " Enter Password", attributes: [NSAttributedStringKey.foregroundColor : UIColor.white])
                login.layer.cornerRadius = login.frame.height / 2
            }
        }else{
            // Create Alert
            let alert = UIAlertController(title: "Internet Connection not Available", message: "Internet access is absolutely necessary to use this app", preferredStyle: .alert)
            // Add "OK" Button to alert, pressing it will bring you to the settings app
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { saction in
                self.login.setTitle("LOGIN", for: .normal)
            }))
            // Show the alert with animation
            self.present(alert, animated: true)
        }
    }
    
    @IBAction func Login(_ sender: UIButton) {
        if Reachability.isConnectedToNetwork(){
            print("Internet Connection Available!")
            let isFirstNameValid = checker(textField:UsernameField)
            let ispasswordValid = checker(textField:passwordField)
            
            DispatchQueue.main.asyncAfter(deadline: .now()) {
                self.login.setTitle("Please wait ", for: .normal)
                //            self.pleasewait.isHidden = false
            }
            
            if isFirstNameValid && ispasswordValid {
                self.authenticate()
            } else {
                let alert1 = UIAlertController(title: "Login error", message: "Please enter your username and password", preferredStyle: UIAlertControllerStyle.alert)
                self.login.setTitle("LOGIN", for: .normal)
                // add an action (button)
                alert1.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler:{ action in
                }))
                self.present(alert1, animated: true, completion: nil)
            }
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
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func convertStringToObject(string: String) -> Dictionary<String, Any>? {
        let data = string.data(using: .utf8)!
        do {
            if let jsonObj = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? Dictionary<String, Any>
            {
                return jsonObj
            } else {
                print("Bad JSON")
                return nil
            }
        } catch let error as NSError {
            print("Error \(error.localizedDescription)")
            return nil
        }
    }
    
    func activateUser(midas: String) -> User? {
        if self.inactiveAllUsers() {
            let queryString = "Update Users SET is_active = 1 WHERE midas = ?"
            
            // Statement pointer
            var stmt:OpaquePointer?
            
            if sqlite3_prepare(db, queryString, -1, &stmt, nil) == SQLITE_OK {
                //binding the midas param
                if sqlite3_bind_text(stmt, 1, String(utf8String: midas.cString(using: .utf8)!), -1, SQLITE_TRANSIENT) != SQLITE_OK{
                    let errmsg = String(cString: sqlite3_errmsg(db)!)
                    print("Failure binding midas: \(errmsg)")
                    return nil
                }
                if sqlite3_step(stmt) == SQLITE_DONE {
                    print("Successfully updated row.")
                    sqlite3_finalize(stmt)
                    return self.fetchActiveUser()
                } else {
                    print("Could not update row.")
                    sqlite3_finalize(stmt)
                    return nil
                }
            } else {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("Error preparing reading: \(errmsg)")
                sqlite3_finalize(stmt)
                return nil
            }
        } else {
            return nil
        }
    }
    
    func insertUser(userjson: String, isActive: Int32) -> Bool {
        var userData = convertStringToObject(string: userjson)!
        let midasid = userData["midas"] as! String
        if let user:User = self.fetchUser(midas: midasid) {
            if  user.isActive == false {
                if let activatedUser = self.activateUser(midas: midasid) {
                    print("User \(activatedUser.midas) is activated")
                    return true
                } else {
                    return false
                }
            } else {
                return true
            }
        } else {
            let midas = userData["midas"] as! NSString
            let firstName = userData["firstName"] as! NSString
            let lastName = userData["lastName"] as! NSString
            let isStudent = userData["isStudent"] as! NSString
            
            //creating a statement
            var stmt: OpaquePointer?
            // the insert query statement
            let queryString = "INSERT INTO Users (midas, first_name, last_name, is_student, is_active) VALUES (?,?,?,?,?)"
            
            //preparing the query
            if sqlite3_prepare(db, queryString, -1, &stmt, nil) != SQLITE_OK{
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("Error preparing insert: \(errmsg)")
                return false
            }
            
            //binding the midas param
            if sqlite3_bind_text(stmt, 1, midas.utf8String, -1, SQLITE_TRANSIENT) != SQLITE_OK{
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("Failure binding midas: \(errmsg)")
                return false
            }
            
            //binding the firstName param
            if sqlite3_bind_text(stmt, 2, firstName.utf8String, -1, SQLITE_TRANSIENT) != SQLITE_OK{
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("Failure binding fistName: \(errmsg)")
                return false
            }
            
            //binding the lastName param
            if sqlite3_bind_text(stmt, 3, lastName.utf8String, -1, SQLITE_TRANSIENT) != SQLITE_OK{
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("Failure binding lastName: \(errmsg)")
                return false
            }
            
            // binding the isStudent param
            if sqlite3_bind_int(stmt, 4, isStudent.intValue) != SQLITE_OK{
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("Failure binding isStudent: \(errmsg)")
                return false
            }
            
            // binding the isActive param
            if sqlite3_bind_int(stmt, 5, isActive) != SQLITE_OK{
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("Failure binding isStudent: \(errmsg)")
                return false
            }
            
            //executing the query to insert values
            if sqlite3_step(stmt) != SQLITE_DONE {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("Failure inserting user: \(errmsg)")
                return false
            }
            //displaying a success message
            print("User saved successfully")
            sqlite3_finalize(stmt)
            return true
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
    
    func fetchUser(midas: String) -> User? {
        let queryString = "SELECT * FROM Users WHERE midas = ?"
        
        // Statement pointer
        var stmt:OpaquePointer?
        
        if sqlite3_prepare(db, queryString, -1, &stmt, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("Error preparing reading: \(errmsg)")
            return nil
        }
        
        //binding the midas param
        if sqlite3_bind_text(stmt, 1, String(utf8String: midas.cString(using: .utf8)!), -1, SQLITE_TRANSIENT) != SQLITE_OK{
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("Failure binding midas: \(errmsg)")
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
    
    func inactiveAllUsers() -> Bool {
        let queryString = "Update Users SET is_active = 0"
        
        // Statement pointer
        var stmt:OpaquePointer?
        
        if sqlite3_prepare(db, queryString, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_DONE {
                print("Successfully updated row.")
                sqlite3_finalize(stmt)
                return true
            } else {
                print("Could not update row.")
                sqlite3_finalize(stmt)
                return false
            }
        } else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("Error preparing reading: \(errmsg)")
            sqlite3_finalize(stmt)
            return false
        }
        
    }
    
    func dropUserTable() -> Bool {
        if sqlite3_exec(db, "DROP TABLE IF EXISTS Users", nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("Error dropping Users table: \(errmsg)")
            return false
        } else {
            print("Dropped Users table Successfully")
            return true
        }
    }
    
    func authenticate() {
        let username1: String = UsernameField.text!.trimmingCharacters(in: .whitespacesAndNewlines)
        let password1: String = passwordField.text!.trimmingCharacters(in: .whitespacesAndNewlines)
        let protectedURL = URL(
            string: LOGIN_URL
            )!
        let logger = XCGLogger()
        logger.setup(level: .debug)
        
        ECPLogin(
            protectedURL: protectedURL,
            username: username1,
            password: password1,
            logger: logger
            ).start { event in
                switch event {
                    
                case let .value(body) :
                    // If the request was successful, the protected resource will
                    // be available in 'body'. Make sure to implement a mechanism to
                    // detect authorization timeouts.
                    let result = "\(body)" //just a text
                    if self.insertUser(userjson: result, isActive: 1) == true {
                        self.UsernameField.text=""
                        self.passwordField.text=""
                        self.view.endEditing(true)
                        // The Shibboleth auth cookie is now stored in the sharedHTTPCookieStorage.
                        // Attach this cookie to subsequent requests to protected resources.
                        // You can access the cookie with the following code:
                        if let cookies = HTTPCookieStorage.shared.cookies {
                            let shibCookie = cookies.filter { (cookie: HTTPCookie) in
                                cookie.name.range(of: "shibsession") != nil
                                }[0]
                            print(shibCookie)
                            self.performSegue(withIdentifier: "gotowelcome", sender: self)
                            self.login.setTitle("LOGIN ", for: .normal)
                        }
                    }
                    
                case let .failed(error):
                    // This is an AnyError that wraps the error thrown.
                    // This can help diagnose problems with your SP, your IdP, or even this library :)
                    switch error.cause {
                    case let ecpError as ECPError:
                        // Error with ECP
                        // User-friendly error message
                        print(ecpError.userMessage)
                        
                        // Technical/debug error message
                        print(ecpError.description)
                    case let alamofireRACError as AlamofireRACError:
                        // Error with the networking layer
                        print(alamofireRACError.description)
                    default:
                        print("Unknown error!")
                        print(error)
                    }
                    self.login.setTitle("LOGIN", for: .normal)
                    let alert = UIAlertController(title: "Login error", message: "Wrong Username or password.", preferredStyle: UIAlertControllerStyle.alert)
                    alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.destructive, handler: { action in
                        self.UsernameField.text=""
                        self.passwordField.text=""
                    }))
                    // show the alert
                    self.present(alert, animated: true, completion: nil)
                default:
                    break
                }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    func checker(textField: UITextField) -> Bool {
        guard (!textField.text!.isEmpty) else {
            return false
        }
        return true
    }
}


