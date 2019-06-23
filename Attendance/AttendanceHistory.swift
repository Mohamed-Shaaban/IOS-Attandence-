//
//  AttendanceHistory.swift
//  Attendance
//
//  Created by ODU Webadmin on 8/3/18.
//  Copyright © 2018 Old Dominion University. All rights reserved.
//
import AVFoundation

class AttendanceHistory {
    var midas: String
    var timeStamp: String
    var messageCode : Int32
    var message: String
    var responseCode: Int32
    var date: String
    
    init(midas: String, timeStamp: String, messageCode: Int32, message: String, responseCode: Int32, date: String) {
        self.midas = midas
        self.timeStamp = timeStamp
        self.messageCode = messageCode
        self.message = message
        self.responseCode = responseCode
        self.date = date
    }
}
