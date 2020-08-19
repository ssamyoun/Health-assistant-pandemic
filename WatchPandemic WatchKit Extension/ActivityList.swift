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
    
    var activityId: Int = 0
    @IBOutlet weak var activityBtn: WKInterfaceButton!
    @IBAction func activityClick() {
        let iDelegate = WKExtension.shared().rootInterfaceController as! InterfaceController
        iDelegate.setaReminderAfter(seconds: 5, activityId: activityId)
        //iDelegate.setCurrentActivityAndNotifyUser(activityId: activityId)
    }
    
    
}
