//
//  HistoryViewController.swift
//  Attendance
//
//  Created by ODU Webadmin on 6/24/18.
//  Copyright © 2018 Old Dominion University. All rights reserved.
//

import UIKit
import SQLite3

class HistoryViewController: UIViewController, UITableViewDelegate,UITableViewDataSource{
    struct Objects {
        var sectionName : String!
        var sectionObjects : String!
    }
    let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    var dateString =  ""
    var attendanceHistoryList = [AttendanceHistory]()
    var midas = ""
    var db: OpaquePointer?
    
    @IBAction func back(_ sender: Any) {
        self.performSegue(withIdentifier: "back", sender: self)
    }

    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var dateField: UITextField!
    
    let picker = UIDatePicker()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        self.tableView.rowHeight = 170.0
        self.tableView.setNeedsLayout()
        self.tableView.layoutIfNeeded()
        createDatePicker()
        let oduAttendanceDbUrl = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("OduAttendanceDb.sqlite")
        if sqlite3_open(oduAttendanceDbUrl.path, &db) != SQLITE_OK {
            print("Error opening database")
        }
        let date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let result = formatter.string(from: date)
        fetchUserAttendanceHistory(midas: self.midas, date: result)
         dateField.text = "\(result)"
    }
    
    func fetchUserAttendanceHistory(midas:String, date: String) {
        attendanceHistoryList.removeAll()
        let queryString = "SELECT * FROM AttendanceHistory WHERE midas = ? AND date = ?"
        // Statement pointer
        var stmt:OpaquePointer?
        
        if sqlite3_prepare(db, queryString, -1, &stmt, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("Error preparing reading: \(errmsg)")
            return
        }
        
        //binding the midas param
        if sqlite3_bind_text(stmt, 1, String(utf8String: midas.cString(using: .utf8)!), -1, SQLITE_TRANSIENT) != SQLITE_OK{
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("Failure binding midas: \(errmsg)")
            return
        }
        //binding timeStamp param
        if sqlite3_bind_text(stmt, 2, String(utf8String: date.cString(using: .utf8)!), -1, SQLITE_TRANSIENT) != SQLITE_OK{
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("Failure binding date: \(errmsg)")
            return
        }
    
        while (sqlite3_step(stmt) == SQLITE_ROW) {
            let midas = String(cString: sqlite3_column_text(stmt, 1))
            let timeStamp = String(cString: sqlite3_column_text(stmt, 2))
            let messageCode = sqlite3_column_int(stmt, 3)
            let message = String(cString: sqlite3_column_text(stmt, 4))
            let responseCode = sqlite3_column_int(stmt, 5)
            attendanceHistoryList.append(AttendanceHistory(midas: midas, timeStamp: timeStamp, messageCode: messageCode, message: message, responseCode: responseCode, date:date))
        }
        sqlite3_finalize(stmt)
        self.tableView.reloadData()
    }


    func convertToDictionary(text: String) -> [String: Any]? {
        if let data = text.data(using: .utf8) {
            do {
                return try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            } catch {
                print ("nil found")
                //print(error.localizedDescription)
            }
        }
        return nil
    }
    
    func createDatePicker() {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let done = UIBarButtonItem(barButtonSystemItem: .done, target: nil, action: #selector(donebuttom))
        toolbar.setItems([done], animated: false)
        dateField.inputAccessoryView = toolbar
        dateField.inputView = picker
        picker.datePickerMode = .date
    }
    
    @objc func donebuttom() {
        // format date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        dateString = formatter.string(from: picker.date)
        dateField.text = "\(dateString)"
        self.fetchUserAttendanceHistory(midas: self.midas, date: dateString)
        self.view.endEditing(true)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 150.0
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return attendanceHistoryList.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell =  tableView.dequeueReusableCell(withIdentifier: "customCell", for: indexPath) as! CustomTableViewCell
        let attendaceHistoy: AttendanceHistory
        attendaceHistoy = attendanceHistoryList[indexPath.row]
        cell.message.text = attendaceHistoy.message
        cell.date.text = attendaceHistoy.timeStamp
        let messageCode = attendaceHistoy.messageCode
        if messageCode == 1 {
            cell.response.text = "Present"
            let yourImage: UIImage = UIImage(named: "present.png")!
            cell.statusImageView?.image = yourImage
        } else if messageCode == 2 {
            let yourImage: UIImage = UIImage(named: "absent.png")!
            cell.response.text = "Absent"
            cell.statusImageView?.image = yourImage
        } else if messageCode == 3 {
            let yourImage: UIImage = UIImage(named: "tardy.png")!
            cell.response.text = "Tardy"
            cell.statusImageView?.image = yourImage
        } else if messageCode == 99 {
            let yourImage: UIImage = UIImage(named: "invalid.png")!
            cell.response.text = "Invalid"
            cell.statusImageView?.image = yourImage
        } else {
            let yourImage: UIImage = UIImage(named: "invalid.png")!
            cell.response.text = "Invalid"
            cell.statusImageView?.image = yourImage
        }
        return cell
    }
}
