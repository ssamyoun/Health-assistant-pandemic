//
//  InterfaceController.swift
//  WatchPandemic WatchKit Extension
//
//  Created by Sirat Samyoun on 8/3/20.
//  Copyright © 2020 Sirat Samyoun. All rights reserved.
//

import WatchKit
import Foundation
import AVFoundation
import UserNotifications
import WatchConnectivity
import HealthKit
import CoreLocation
import CoreBluetooth
import CoreML


class InterfaceController: WKInterfaceController,UNUserNotificationCenterDelegate, AVSpeechSynthesizerDelegate,WorkoutManagerDelegate,CBCentralManagerDelegate {
    

 //------------ btn actions, btn names, all other variables
    override func awake(withContext context: Any?) {
        activateNotificationsOnWatch()
        setAllRegularReminders()
        loadAllActivitiesIntoView()
        fetchCovidInformation()
        switchView(activityListShow: true)
        super.awake(withContext: context)
    }
    
    override func willActivate() {
        super.willActivate()
    }
    
    override func didDeactivate() {
        super.didDeactivate()
    }
    
    @IBAction func actionwashHands() {
    }
    
    @IBAction func actionStopWashing() {
    }

    @IBAction func menuNotify() {
        let randomRegularActivityId = Int.random(in: 1...3)
        setaReminderAfter(seconds: testNotifyAfterSec, activityId: randomRegularActivityId)
    }
    
    @IBAction func menuTalk() {
        InitiateDictation(textChoices: [])
    }
    
    @IBAction func menuScan() {
        startBeaconSensingAndRemind()
    }
    
    @IBAction func menuStopScan() {
        beaconSensingTimer?.invalidate()
        centralManager.stopScan()
    }
    
    @IBOutlet var activityTable: WKInterfaceTable!
    @IBOutlet var notifyingActivityTitle: WKInterfaceLabel!
    @IBOutlet var notifyingActivityImage: WKInterfaceImage!

    @IBOutlet weak var btnStartWash: WKInterfaceButton!
    @IBOutlet weak var btnStopWash: WKInterfaceButton!
    
    let remindlaterDefaultMinutes: Int = 5
    //public var noResponseRepeatMins: Int = 3
    let testNotifyAfterSec: Int = 2
    //public var PatientId: Int = 3001
    
    var currentReminder: NSMutableDictionary?
    //public var remindersDictionary = [Int : NSMutableDictionary]()
    //public var serialDictionary = [Int : Int]()
    
    //public var currentConversation: String = ""
    //public var currentResponseResult: Int = 0 // final state
    var currentActivityId: Int = 0
    var currentResponseText = ""
//    var currentAskedDetails: Int = 0 // intermediate state
//    var currentAskedtoRepeat: Int = 0 // intermediate state
//    var currentBatteryLevel:Int {
//        return Int(roundf(WKInterfaceDevice.current().batteryLevel * 100))
//    }
//    var dontExit: Bool = false
    var conversationFinished = false
    
//    public enum ResponseType: Int {
//        case noResponse = 0
//        case notified = 1
//        case clicked = 2
//        case respondedNotUnderstood = 3
//        case respondedWithStop = 4
//        case respondedWithPostpone = 5 //count as accept later
//        case respondedWithConfirmedTaking = 6
//        case respondedWithAskedDetails = 7
//        case respondedWithRepeat = 8
//    }
    let serviceIds = [CBUUID(string: "FE9A")]
    let primaryBeaconId: String = "114ebf586b0579cba35"//"114ebf586b0579cba35f32869f538c9b1ec101-coco1-2de17af2" //-45(closest) -65(closer) -75(close)
    let hwModel = quality_model()
    let samplingrate:Int = 50 //let bunch_size = 30  # 30*9 = 270 for one pred   let window_len = 2 //100 samples a window let sliding_len =  1 //50 samples
    let totalColsSens:Int = 16
    let totalRowsSens:Int = 3000//3000 =60 seconds *50 samples
    var sensorReadings:[[Double?]] = Array(repeating: Array(repeating: 0.0, count: 16), count: 3000)  //print(tempA[2999][12]) //83.423
    var sensorReadingIndex:Int = 0
    
    var workoutManager = WorkoutManager()
    var centralManager : CBCentralManager!
    var scannedPeripheral: CBPeripheral!
    var beaconSensingTimer : Timer? //also for scan
    let beaconSensingInterval: Double = 1.0 //5sec
    
    var hwResultsArray = [Int]()//[[Double]]()
    var hwFeedbackArray = [String]()
    var hwStartTime = 0.0
    var hwEndTime = 0.0
    var remindedHandwashing:Bool = false
    var remindedMask:Bool = false
    
    struct CovidInfo: Codable {
        var dailycases: Int
        var totalcases: Int
        var usadaily: Int
        var usatotal: Int
        var cdc: String
    }
    
    var covidInfoDownloaded: Bool = false
    var covidTracker: CovidInfo = CovidInfo(dailycases: 0, totalcases: 0, usadaily:0 , usatotal:0, cdc:"")
    
   //------------ //view parts
    
    func switchView(activityListShow: Bool){
        notifyingActivityTitle.setHidden(!activityListShow)
        notifyingActivityImage.setHidden(!activityListShow)
        
        activityTable.setHidden(activityListShow)
        btnStartWash.setHidden(activityListShow)
        btnStopWash.setHidden(activityListShow)
    }
    
    func loadAllActivitiesIntoView(){
        activityTable.setNumberOfRows(AllReminders.getAllRegularReminders().count, withRowType: "ActivityList")
        var index: Int = 0
        for item in AllReminders.getAllRegularReminders().values{
            let row = activityTable.rowController(at: index) as! ActivityList
            let txt = (item["time"] as! String) + " " + (item["display_text"] as! String)
            row.activityBtn.setTitle(txt)
            //row.activityBtn.setValue(1, forKey: "activityId")
            index = index + 1
        }
    }
    
    
   //------------//////////covid interaction
    //URL(string: "https://covidtracking.com/api/us")! //URL(string: "http://covidtracking.com/api/v1/states/va/current.json")!
    func fetchCovidInformation(){
        if(covidInfoDownloaded == false){
            downloadUpdatedCovidInformation(url: URL(string: "https://covidtracking.com/api/us")!)
            downloadUpdatedCovidInformation(url: URL(string: "http://covidtracking.com/api/v1/states/va/current.json")!)
            covidInfoDownloaded = true
        }
    }
    
    func downloadUpdatedCovidInformation(url:URL){
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.dataTask(with: request) {
            data, response, error in
            if error == nil {
                do {
                    let json = try JSONSerialization.jsonObject(with: data!, options: [])
                    if let object = json as? [String: Any] {
                        self.covidTracker.dailycases = object["positiveIncrease"] as! Int
                        self.covidTracker.totalcases = object["positive"] as! Int
                    }
                    else if let object = json as? [Any] {
                        for anItem in object as! [Dictionary<String, AnyObject>] {
                            self.covidTracker.usadaily = anItem["positiveIncrease"] as! Int
                            self.covidTracker.usatotal = anItem["positive"] as! Int
                        }
                    }
                } catch {
                    print(error.localizedDescription)
                }
            }
        }
        task.resume()
    }
    
    
//------------notification functions-----------
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.sound,.alert])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {//clicked
        let userInfo = response.notification.request.content.userInfo
        currentActivityId = (userInfo["id"] as? Int)!
        currentReminder = AllReminders.getSpecificReminder(activityId: currentActivityId)
        do {
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        } catch {
        }
        completionHandler()
        loadNotifyingActivityInView()
    }
    
    func loadNotifyingActivityInView() {
        WKInterfaceDevice.current().play(.success)
        WKInterfaceDevice.current().play(.click)
        currentResponseText = ""
        conversationFinished = false
        notifyingActivityImage.setImage(UIImage(named: (currentReminder!["image"] as? String)!))
        notifyingActivityTitle.setText((currentReminder!["display_text"] as? String)!)
    
        switchView(activityListShow: false)
        //let user see the activity name for 1 sec
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: {
            self.utterSentence(line: (self.currentReminder!["query"] as? String)!)
        })
    }
    
    func setAllRegularReminders(){
        for item in AllReminders.getAllRegularReminders().values {
            let dateStr: String = (item["time"] as? String)!
            let dateStrArr = dateStr.components(separatedBy: ":")
            var date = DateComponents()
            date.hour = Int(dateStrArr[0])!
            date.minute = Int(dateStrArr[1])!
            let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
            registerReminderNotification(trigger: trigger, activityId: (item["id"] as? Int)!)
        }
    }
    
    public func setaReminderAfter(seconds: Int, activityId: Int){
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        registerReminderNotification(trigger: trigger, activityId: activityId)
    }
    
    func registerReminderNotification(trigger: UNNotificationTrigger, activityId:Int){
        let content = getNotificationContent(activityId: activityId)
        let uuId = HelperMethods.stringWithUUID()
        let request = UNNotificationRequest(identifier: uuId, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { (notificationError) in
            if(notificationError == nil){
            }
        }
    }

    func getNotificationContent(activityId: Int) -> UNMutableNotificationContent{
        let content = UNMutableNotificationContent()
        content.title = "Reminder"
        let reminder = AllReminders.getSpecificReminder(activityId: activityId)
        content.subtitle = (reminder["display_text"] as? String)!
        content.body = HelperMethods.currentTime24AsString()
        var info = [String:Any]()
        info["id"] = activityId
        content.userInfo = info
        content.sound = UNNotificationSound.default
        content.categoryIdentifier = "activity.category"
        
        return content
    }
    
    func activateNotificationsOnWatch(){
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.sound,.alert]) { (granted, error) in
            if granted == false {
                print("Launch Notification Error: \(error?.localizedDescription)")
            }
        }
        let notificationCategory = UNNotificationCategory(identifier: "activity.category", actions: [], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([notificationCategory])
    }

    
//------------text-to-speech and speech-text functions-----------
    private var synth: AVSpeechSynthesizer?
    var myUtterance = AVSpeechUtterance(string: "")
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if(conversationFinished == false){
            self.currentResponseText = ""
            InitiateDictation(textChoices:[])
        }
        else{
            self.switchView(activityListShow: true)
        }
    }
    
    func utterSentence(line: String ){
        synth = AVSpeechSynthesizer()
        myUtterance = AVSpeechUtterance(string: line)
        synth?.delegate = self
        myUtterance.rate = 0.5
        synth?.speak(myUtterance)
    }
    
    func InitiateDictation(textChoices: [String]){
        presentTextInputController(withSuggestions: textChoices, allowedInputMode:WKTextInputMode.plain, completion: {(results) -> Void in
            if results != nil && results!.count > 0 {
                self.currentResponseText = (results?[0] as? String)!
                self.handleFirstResponse()
            }
        })
    }
    
    
//=============handwashing,mask============
    
    func startBeaconSensingAndRemind(){
        WKInterfaceDevice.current().play(.success)
        WKInterfaceDevice.current().play(.click)
        remindedHandwashing = false
        remindedMask = false
        beaconSensingTimer = Timer.scheduledTimer(timeInterval: beaconSensingInterval, target: self, selector: #selector(onKeepAliveTimerTick), userInfo: nil, repeats: true)
        RunLoop.current.add(beaconSensingTimer!, forMode: RunLoop.Mode.common)
    }
    
    func startCollectIMU(){
        WKInterfaceDevice.current().play(.success)
        WKInterfaceDevice.current().play(.click)
        
        sensorReadings = Array(repeating: Array(repeating: 0.0, count: totalColsSens), count: totalRowsSens)  //print(tempA[2999][12]) //83.423
        sensorReadingIndex = 0
        workoutManager.startWorkout()
    }
    
    @objc func onKeepAliveTimerTick() -> Void {
        if centralManager.state == .poweredOn && !centralManager.isScanning{
            centralManager.scanForPeripherals(withServices: serviceIds, options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
        }
    }
    
    func getDataAndProcessInModel(){ //3000*16 to *9
        hwResultsArray = [Int]()
        var dataToCheckHW = sensorReadings //func here
        var maxIdx = sensorReadingIndex //dataToCheckHW.count
        var startIdx = 0, endIdx = 49
        while true{
            if (endIdx >= maxIdx){
                break
            }
            //one prediction from 50*16
            var mlArray = try? MLMultiArray(shape:[800],dataType:MLMultiArrayDataType.double)
            var mlIdx = 0
            for k in startIdx...endIdx {
                let tmp = dataToCheckHW[k]
                for elem in tmp
                {
                    mlArray![mlIdx] = NSNumber(floatLiteral: elem!)
                    mlIdx += 1
                }
            }
            let outputLabel = PredictLabel(mlMultiArrayInput: mlArray!)
            hwResultsArray.append(outputLabel)
            //
            endIdx = min(maxIdx,endIdx+25)
            startIdx = endIdx-49
        }
    }
    
    func PredictLabel(mlMultiArrayInput:MLMultiArray)->Int{
        let prediction = try? hwModel.prediction(imu: mlMultiArrayInput, bidirectional_2_h_in: nil, bidirectional_2_c_in: nil, bidirectional_2_h_in_rev: nil, bidirectional_2_c_in_rev: nil)
        print("prediction:",prediction?.output)
        var maxIdx = 0
        var maxVal = -1.0
        for n in 0...9 {
            let v = Double(((prediction?.output[n])!))
            if(v>maxVal){
                maxVal = v
                maxIdx = n
            }
        }
        return (maxIdx + 1)
    }
    
    func callformalAndFeedback(){
        print("resultsArray-->", hwResultsArray)
        hwFeedbackArray = [String]()
        let duration = hwEndTime - hwStartTime
        if (duration < 20){
            hwFeedbackArray.append("Didn't wash for 20 seconds")
        }
        //if (!(resultsArray.first == 1 || resultsArray.first == 9)){
        if (!checkRubbinginFirst10Results()){
            hwFeedbackArray.append("Didn't rub hands properly at first")
        }
        if (!(hwResultsArray.contains(2)) && !(hwResultsArray.contains(3))){
            hwFeedbackArray.append("Didn't put palm over hands properly")
        }
        if (!(hwResultsArray.contains(4))){
            hwFeedbackArray.append("Didn't interlace fingers properly")
        }
        if (!(hwResultsArray.contains(5)) && !(hwResultsArray.contains(6))){
            hwFeedbackArray.append("Didn't clean fingertips properly")
        }
        if (!(hwResultsArray.contains(7)) && !(hwResultsArray.contains(8))){
            hwFeedbackArray.append("Didn't rub thumbs properly")
        }
        //if (!(resultsArray.contains(9)) && !(resultsArray.contains(10))){
        if (!checkFingerPalminLast10Results()){
            hwFeedbackArray.append("Didn't rotationally rub fingers on palms properly")
        }
        if(hwFeedbackArray.isEmpty){
            hwFeedbackArray.append("Great Job! You washed hands perfectly")
        }
        let utter = hwFeedbackArray.joined(separator: ", ")
        utterSentence(line: utter)
    }
    
    func checkRubbinginFirst10Results()->Bool{
        for n in 0...9 {
            if(hwResultsArray[n] == 1 || hwResultsArray[n] == 9){
                return true
            }
        }
        return false
    }
    
    func checkFingerPalminLast10Results()->Bool{
        let lastIdx = hwResultsArray.count - 1
        for n in stride(from: lastIdx, to: lastIdx-10, by: -1) {
            if(hwResultsArray[n] == 9 || hwResultsArray[n] == 10){
                return true
            }
        }
        return false
    }
    
    func didUpdateMotion(_ manager: WorkoutManager, magnX:Double?, magnY:Double?, magnZ:Double?, gravX:Double?, gravY:Double?, gravZ:Double?, rotatX:Double?, rotatY:Double?, rotatZ:Double?, useraccX:Double?, useraccY:Double?, useraccZ:Double?, attdW:Double?, attdX:Double?, attdY:Double?, attdZ:Double?, timestamp: Int64) {
        DispatchQueue.main.async {
            self.sensorReadings[self.sensorReadingIndex][0] = useraccX
            self.sensorReadings[self.sensorReadingIndex][1] = useraccY
            self.sensorReadings[self.sensorReadingIndex][2] = useraccZ
            self.sensorReadings[self.sensorReadingIndex][3] = gravX
            self.sensorReadings[self.sensorReadingIndex][4] = gravY
            self.sensorReadings[self.sensorReadingIndex][5] = gravZ
            self.sensorReadings[self.sensorReadingIndex][6] = rotatX
            self.sensorReadings[self.sensorReadingIndex][7] = rotatY
            self.sensorReadings[self.sensorReadingIndex][8] = rotatZ
            self.sensorReadings[self.sensorReadingIndex][9] = attdW
            self.sensorReadings[self.sensorReadingIndex][10] = attdX
            self.sensorReadings[self.sensorReadingIndex][11] = attdY
            self.sensorReadings[self.sensorReadingIndex][12] = attdZ
            self.sensorReadings[self.sensorReadingIndex][13] = magnX
            self.sensorReadings[self.sensorReadingIndex][14] = magnY
            self.sensorReadings[self.sensorReadingIndex][15] = magnZ
            
            self.sensorReadingIndex = self.sensorReadingIndex + 1
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        var advertisementDataString = ""
        var adId = ""
        let adDictionary = advertisementData as NSDictionary
        if let val = adDictionary["kCBAdvDataServiceData"] {
            advertisementDataString = ((val as AnyObject).description).replacingOccurrences(of: "\n", with: "")
            adId = getAdvertisementIds(adStr: (val as AnyObject).description)
        }
        //print("Beacon: ", adId)
        if (adId.contains(primaryBeaconId)){ //and DBB //starts with
            print("desired beacon found", primaryBeaconId, RSSI.stringValue)
            if(Int(RSSI.stringValue)! > -65 && remindedHandwashing == false){
                //start interact
                setaReminderAfter(seconds: testNotifyAfterSec, activityId: 4)
                remindedHandwashing = true
                centralManager.stopScan()
            }
            else if(Int(RSSI.stringValue)! > -55 && remindedMask == false){
                //start interact
                setaReminderAfter(seconds: testNotifyAfterSec, activityId: 5)
                remindedMask = true
                centralManager.stopScan()
            }
        }
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services! {
            let thisService = service as CBService
            peripheral.discoverCharacteristics(nil, for: thisService)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for charateristic in service.characteristics! {
            let thisCharacteristic = charateristic as CBCharacteristic
            self.scannedPeripheral.setNotifyValue(true, for: thisCharacteristic)
        }
    }
    
    func getAdvertisementIds(adStr: String) -> String{ //(String, String)
        var serviceId = ""
        var advertisementId = ""
        do {
            let advString = adStr.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "{", with: "")
            let strs = advString.components(separatedBy: "=")
            if(strs.count == 2){
                serviceId = strs[0]
                let str2 = strs[1]
                let regex = try NSRegularExpression(pattern:"<(.*)>")
                if let match = regex.firstMatch(
                    in: str2, range:NSMakeRange(0,str2.utf16.count)) {
                    advertisementId = (str2 as NSString).substring(with: match.range(at:1))
                }
            }
        } catch {
            print("error")
        }
        return (advertisementId) //serviceId,
    }
    
    
    //------------////response part
    
    func handleFirstResponse(){
        if (currentResponseText.isEmpty == false) {
            var responseStr = currentResponseText.lowercased()
            currentResponseText = ""
            if (responseStr.contains("yes") || responseStr.contains("done") || responseStr.contains("did")
                || responseStr.contains("yeah") || responseStr.contains("sure") || responseStr.contains("taken") || responseStr.contains("took")
                ){
                conversationFinished = true
                if(currentActivityId == 3)
                {
                    utterSentence(line: "Ok. Press the crown to go to Apps, tap on the ECG app, and follow the instructions.")
                } else if (responseStr.contains("thank")){
                    utterSentence(line: "You are welcome.");
                } else{
                    utterSentence(line: "Ok. Thank you.");
                }
            }
            else if (responseStr.contains("remind")) {
                if (responseStr.contains("don't") || responseStr.contains("do not")){
                    conversationFinished = true
                }
                else if (responseStr.contains("later")){
                    let mins: Int = remindlaterDefaultMinutes
                    utterSentence(line: "Ok. Remind you after \(mins) minutes");
                    setaReminderAfter(seconds: mins*60, activityId: currentActivityId)
                }
                else if (responseStr.contains("minute")){
                    let wordsArr = responseStr.components(separatedBy: " ")
                    var indexOfMin: Int = 0
                    for (idx, str) in wordsArr.enumerated(){
                        if(str.contains("minute")){
                            indexOfMin = idx - 1
                            break
                        }
                    }
                    if(indexOfMin >= 0){
                        if(CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: wordsArr[indexOfMin]))){
                            let mins: Int = Int(wordsArr[indexOfMin])!
                            utterSentence(line: "Ok. Remind you after \(mins) minutes");
                            setaReminderAfter(seconds: mins*60, activityId: currentActivityId)
                        } else{
                            let mins: Int = HelperMethods.wordToNumber(word: wordsArr[indexOfMin])//2  //extensiveLater
                            utterSentence(line: "Ok. Remind you after \(mins) minutes");
                            setaReminderAfter(seconds: mins*60, activityId: currentActivityId)
                        }
                    }
                } else if (responseStr.contains("thank")){ //"thanks for reminding" type response
                    conversationFinished = true //currentResponseResult unchnaged
                    utterSentence(line: "You are welcome.")
                }
            }
            else if (responseStr.contains("pandemic") || responseStr.contains("cases")){
                var pstr = ""
                if (responseStr.contains("United States") || responseStr.contains("USA")){
                    if (responseStr.contains("new")){
                        pstr = "Today there are " + String(covidTracker.usadaily) + " new cases in the United States"
                    }
                    else if (responseStr.contains("total")){
                        pstr = "As of today, there are total " + String(covidTracker.usatotal) + " cases in the United States"
                    }
                    else {
                        pstr = "As of today, In the United States, there are total " + String(covidTracker.usatotal) + " cases, and " + String(covidTracker.usadaily) + " new cases"
                    }
                }
                else { //if (responseStr.contains("around")){
                    if (responseStr.contains("new")){
                        pstr = "Today there are " + String(covidTracker.dailycases) + " new cases in Virginia"
                    }
                    else if (responseStr.contains("total")){
                        pstr = "As of today, there are total " + String(covidTracker.totalcases) + " cases in Virginia"
                    } else {
                        pstr = "As of today, In Virginia, there are total " + String(covidTracker.totalcases) + " cases, and " + String(covidTracker.dailycases) + " new cases"
                    }
                }
                utterSentence(line: pstr)
            }
//            else if (responseStr.contains("CDC") || responseStr.contains("recommendations")){
//                utterSentence(line: "Currently CDC recommends to avoid close contact, clean your hands often, cover coughs and sneezes, stay home if you are sick")
//            }
            else if (responseStr.contains("thank")){
                conversationFinished = true
                utterSentence(line: "You are welcome.")
            }
            else if(responseStr.contains("ok")||responseStr.contains("ll do") || responseStr.contains("ll check") || responseStr.contains("ll take")){
                conversationFinished = true
                utterSentence(line: "Ok. Thank you.")
            }
            else{
                //said other than keywords, what now?
                conversationFinished = true
            }
        }
        else{
            //said nothing, pressed done, what now?
            conversationFinished = true
        }
        if (conversationFinished == true){
            switchView(activityListShow: true)
        }
    }
    
}
