//
//  checkedinViewController.swift
//  Attendance
//
//  Created by ODU Webadmin on 5/22/18.
//  Copyright © 2018 Old Dominion University. All rights reserved.
//

import UIKit
import Alamofire
import CoreStore
import SQLite3
import SwiftyJSON


class CheckedInViewController: UIViewController {
    
    var SUBMIT_URL = *****
    var TOKEN = *****
    
    let PPRD_SUBMIT_URL = ****
    let PPRD_TOKEN = **
    
    let GET_URL = ****
    
    let CREATE_ATTENDANCE_TABLE = *****
    
    var db: OpaquePointer?
    let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
    var qrrec=""
    var midas=""
    var timest=""
    var savestrin = ""
    
    @IBOutlet weak var checkinimages: UIImageView!
    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var messageLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let oduAttendanceDbUrl = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("OduAttendanceDb.sqlite")
        
        if sqlite3_open(oduAttendanceDbUrl.path, &db) != SQLITE_OK {
            print("Error opening database")
        }
        
        if sqlite3_exec(db, CREATE_ATTENDANCE_TABLE, nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("Error creating table: \(errmsg)")
        }
        URLCache.shared.removeAllCachedResponses()

        Alamofire.SessionManager.default
            .requestWithoutCache(GET_URL, method: .get, headers: ["Accept": "application/json"]).responseJSON() {
            response in
            guard response.result.error == nil else {
                // got an error in getting the data, need to handle it
                print("error calling GET status \(self.GET_URL)")
                print(response.result.error!)
                return
            }
            
            if(response.response!.statusCode==200){
                if let data = response.data, let utf8Text = String(data: data, encoding: .utf8) {
                    
                    let statusData = self.convertStringToObject(string: utf8Text)!
                    print("status value: \(statusData["status"]!)")
                    if statusData["status"] as! String == "demo" {
                        self.SUBMIT_URL = self.PPRD_SUBMIT_URL
                        self.TOKEN = self.PPRD_TOKEN
                    }
                }
            }
                
            let parameters:[String:Any] = [
                "timestamp": Date().millisecondsSince1970,
                "token": self.qrrec ,
                "identifier": [
                    "type": "QR",
                    "identifier": self.midas
                ]
            ]
            
            let headers = [
                "Authorization": self.TOKEN,
                "Content-Type": "application/json"
            ]
            
                Alamofire.SessionManager.default
                    .requestWithoutCache(self.SUBMIT_URL, method: .post, parameters: parameters, encoding: JSONEncoding.default,headers: headers)
                .responseJSON() { response in
                    guard response.result.error == nil else {
                        // got an error in getting the data, need to handle it
                        print("error calling POST \(self.SUBMIT_URL)")
                        print(response.result.error!)
                        let yourImage: UIImage = UIImage(named: "invalid.png")!
                        self.checkinimages?.image = yourImage
                        self.statusLabel.text = "Invalid"
                        self.messageLabel.text = "Please try again later!"
                        return
                    }
                    
                    if(response.response!.statusCode==200){
                        if let data = response.data, let utf8Text = String(data: data, encoding: .utf8) {
                            print("Data: \(utf8Text)")
                            self.savestrin = utf8Text
                        }
                        if let attendanceHistory:AttendanceHistory = self.insertAttendaceRecord(attendancejson: self.savestrin, responseCode: Int32(response.response!.statusCode)) {
                            let messageCode = attendanceHistory.messageCode;
                            if messageCode == 1 {
                                let yourImage: UIImage = UIImage(named: "present.png")!
                                self.checkinimages?.image = yourImage
                                self.statusLabel.text = "Marked Present"
                            } else if messageCode == 2 {
                                let yourImage: UIImage = UIImage(named: "absent.png")!
                                self.checkinimages?.image = yourImage
                                self.statusLabel.text = "Marked Absent"
                            } else if messageCode == 3 {
                                let yourImage: UIImage = UIImage(named: "tardy.png")!
                                self.checkinimages?.image = yourImage
                                self.statusLabel.text = "Marked Tardy"
                            } else if messageCode == 99 {
                                let yourImage: UIImage = UIImage(named: "invalid.png")!
                                self.checkinimages?.image = yourImage
                                self.statusLabel.text = "Invalid"
                            } else {
                                let yourImage: UIImage = UIImage(named: "invalid.png")!
                                self.checkinimages?.image = yourImage
                                self.statusLabel.text = "Invalid"
                            }
                            self.messageLabel.text = attendanceHistory.message
                        }
                    } else {
                        print("Status code: \(response.response!.statusCode)")
                        let yourImage: UIImage = UIImage(named: "invalid.png")!
                        self.checkinimages?.image = yourImage
                        self.statusLabel.text = "Invalid"
                        self.messageLabel.text = "Please try again later!"
                    }
            }
        }
    }
    
    func dropHistoryTable() -> Bool {
        if sqlite3_exec(db, "DROP TABLE IF EXISTS AttendanceHistory", nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("Error dropping Users table: \(errmsg)")
            return false
        } else {
            print("Dropped AttendanceHistory table Successful")
            return true
        }
    }
    
    func insertAttendaceRecord(attendancejson: String, responseCode: Int32) -> AttendanceHistory? {
        if let attendaceData:[String:Any] = convertStringToObject(string: attendancejson) {
            
            let messageCode = attendaceData["response"] as! Int32
            let message = attendaceData["message"] as! NSString
            let time = attendaceData["date"] as! NSString
            // First, get a Date from the String
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
            let local = dateFormatter.date(from:time as String)!
            
            // Now, get a new string from the Date in the proper format for the user's locale
            dateFormatter.dateFormat = nil
            dateFormatter.dateStyle = .long // set as desired
            dateFormatter.timeStyle = .medium // set as desired
            let date = dateFormatter.string(from: local)
            
            let today = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let mydate = formatter.string(from: today)
            //creating a statement
            var stmt: OpaquePointer?
            // the insert query statement
            let queryString = "INSERT INTO AttendanceHistory (midas, time_stamp, message_code, message, response_code, date) VALUES (?,?,?,?,?,?)"
            
            //preparing the query
            if sqlite3_prepare(db, queryString, -1, &stmt, nil) != SQLITE_OK{
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("Error preparing insert: \(errmsg)")
                return nil
            }
            let id = self.midas
            //binding the midas param
            if sqlite3_bind_text(stmt, 1, id, -1, SQLITE_TRANSIENT) != SQLITE_OK{
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("Failure binding midas: \(errmsg)")
                return nil
            }
            
            //binding the timeStamp param
            if sqlite3_bind_text(stmt, 2, String(utf8String: date.cString(using: .utf8)!), -1, SQLITE_TRANSIENT) != SQLITE_OK{
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("Failure binding timeStamp: \(errmsg)")
                return nil
            }
            
            //binding the messageCode param
            if sqlite3_bind_int(stmt, 3, messageCode) != SQLITE_OK{
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("Failure binding messageCode: \(errmsg)")
                return nil
            }
            
            // binding the message param
            if sqlite3_bind_text(stmt, 4, message.utf8String, -1, SQLITE_TRANSIENT) != SQLITE_OK{
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("Failure binding message: \(errmsg)")
                return nil
            }
            
            // binding the responseCode param
            if sqlite3_bind_int(stmt, 5, responseCode) != SQLITE_OK{
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("Failure binding responseCode: \(errmsg)")
                return nil
            }
            
            // binding the date param
            if sqlite3_bind_text(stmt, 6, String(utf8String: mydate.cString(using: .utf8)!), -1, SQLITE_TRANSIENT) != SQLITE_OK{
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("Failure binding date: \(errmsg)")
                return nil
            }
            
            //executing the query to insert values
            if sqlite3_step(stmt) != SQLITE_DONE {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("Failure inserting user: \(errmsg)")
                return nil
            }
            //displaying a success message
            print("Attendance saved successfully")
            sqlite3_finalize(stmt)
            return AttendanceHistory(
                midas: self.midas,
                timeStamp: date as String,
                messageCode: messageCode,
                message: message as String,
                responseCode: responseCode,
                date: mydate
            )
        }
        return nil
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
            print("error \(error.localizedDescription)")
            return nil
        }
    }
    
    ///////////////////////////
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    
}

extension Alamofire.SessionManager{
    @discardableResult
    open func requestWithoutCache(
        _ url: URLConvertible,
        method: HTTPMethod = .get,
        parameters: Parameters? = nil,
        encoding: ParameterEncoding = URLEncoding.default,
        headers: HTTPHeaders? = nil)// also you can add URLRequest.CachePolicy here as parameter
        -> DataRequest
    {
        do {
            var urlRequest = try URLRequest(url: url, method: method, headers: headers)
            urlRequest.cachePolicy = .reloadIgnoringCacheData // <<== Cache disabled
            let encodedURLRequest = try encoding.encode(urlRequest, with: parameters)
            return request(encodedURLRequest)
        } catch {
            // TODO: find a better way to handle error
            print(error)
            return request(URLRequest(url: URL(string: "http://example.com/wrong_request")!))
        }
    }
}

extension Date {
    var millisecondsSince1970:Int {
        return Int((self.timeIntervalSince1970 * 1000.0).rounded())
    }
    
    init(milliseconds:Int) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }
}
