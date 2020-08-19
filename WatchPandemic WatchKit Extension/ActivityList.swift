//
//  ActivityList.swift
//  WatchPandemic WatchKit Extension
//
//  Created by Sirat Samyoun on 8/10/20.
//  Copyright © 2020 Sirat Samyoun. All rights reserved.
//

import Foundation
import WatchKit


class ActivityList: NSObject {
    
    @IBOutlet weak var activityBtn: WKInterfaceButton!
    @IBAction func activityClick() {
        //let activityId: Int = activityBtn!.value(forKey: "activityId") as! Int
        let iDelegate = WKExtension.shared().rootInterfaceController as! InterfaceController
        iDelegate.setaReminderAfter(seconds: 2, activityId: 2)
    }
    
    
}
