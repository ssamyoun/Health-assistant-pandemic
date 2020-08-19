//
//  AllReminders.swift
//  WatchPandemic WatchKit Extension
//
//  Created by Sirat Samyoun on 8/17/20.
//  Copyright © 2020 Sirat Samyoun. All rights reserved.
//

import Foundation

class AllReminders {
    
    static var regularReminders = [Int : NSMutableDictionary]()
    static var contextualReminders = [Int : NSMutableDictionary]()
    
    static public func getSpecificReminder(activityId: Int) -> NSMutableDictionary {
        loadAllReminders()
        if (activityId < 4){
            return regularReminders[activityId]!
        }else{
            return contextualReminders[activityId]!
        }
    }
    
    
    static public func getAllRegularReminders()->[Int : NSMutableDictionary]{
        loadAllReminders()
        return regularReminders
    }
    
    static func loadAllReminders(){
        if (regularReminders.count == 0){
            if let path = Bundle.main.path(forResource: "activities", ofType: "json") {
                do {
                    let jsonData = try NSData(contentsOfFile: path, options: NSData.ReadingOptions.mappedIfSafe)
                    do {
                        let jsonResult: NSDictionary = try JSONSerialization.jsonObject(with: jsonData as Data, options: JSONSerialization.ReadingOptions.mutableContainers) as! NSDictionary
                        let allRegularReminders = jsonResult["regular"] as? [NSMutableDictionary]
                        for item in allRegularReminders! {
                            let activityId: Int = (item["id"] as? Int)!
                            regularReminders[activityId] = item as? NSDictionary as! NSMutableDictionary
                        }
                        let allContextualReminders = jsonResult["contextual"] as? [NSMutableDictionary]
                        for item in allContextualReminders! {
                            let activityId: Int = (item["id"] as? Int)!
                            contextualReminders[activityId] = item as? NSDictionary as! NSMutableDictionary
                        }
                    } catch {}
                } catch {}
            }
        }
    }

}
