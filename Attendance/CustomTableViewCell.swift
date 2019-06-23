//
//  CustomTableViewCell.swift
//  Attendance
//
//  Created by ODU Webadmin on 6/24/18.
//  Copyright © 2018 Old Dominion University. All rights reserved.
//

import UIKit

class CustomTableViewCell: UITableViewCell {

    @IBOutlet weak var cellView: UIView!
    @IBOutlet weak var statusImageView: UIImageView!
    
    @IBOutlet weak var response: UILabel!
    
    @IBOutlet weak var date: UILabel!
    
    @IBOutlet weak var message: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        sizeToFit()
        layoutIfNeeded()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
