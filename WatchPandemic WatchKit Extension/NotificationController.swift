//
//  NotificationController.swift
//  WatchPandemic WatchKit Extension
//
//  Created by Sirat Samyoun on 8/3/20.
//  Copyright © 2020 Sirat Samyoun. All rights reserved.
//

import WatchKit
import Foundation
import UserNotifications


class NotificationController: WKUserNotificationInterfaceController {
    
    @IBOutlet weak var titleLbl: WKInterfaceLabel!
    @IBOutlet weak var subtitleLbl: WKInterfaceLabel!
    @IBOutlet weak var bodyLbl: WKInterfaceLabel!
    
    override init() {
        // Initialize variables here.
        super.init()
        
        // Configure interface objects here.
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }

    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

    override func didReceive(_ notification: UNNotification, withCompletion completionHandler: @escaping (WKUserNotificationInterfaceType) -> Swift.Void) {
        let content = notification.request.content
        titleLbl.setText(content.title)
        subtitleLbl.setText(content.subtitle)
        bodyLbl.setText(content.body)
        
//        let userInfo = content.userInfo
//        if (userInfo != nil){
//            let activityId = (userInfo["id"] as? Int)!
//            let iDelegate = WKExtension.shared().rootInterfaceController as! InterfaceController
//            iDelegate.setCurrentActivityAndNotifyUser(activityId: activityId)
//        }
        completionHandler(.custom)
    }
}

