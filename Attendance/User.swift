//
//  Users.swift
//  Attendance
//
//  Created by ODU Webadmin on 8/2/18.
//  Copyright © 2018 Old Dominion University. All rights reserved.
//

class User {
    
    var userId: Int32
    var midas: String
    var firstName: String
    var lastName: String
    var isStudent: Bool
    var isActive: Bool
    
    init(userId: Int32, midas: String, firstName: String, lastName: String, isStudent: Bool, isActive: Bool) {
        self.userId = userId
        self.midas = midas
        self.firstName = firstName
        self.lastName = lastName
        self.isStudent = isStudent
        self.isActive = isActive
    }
}
