//
//  GlucoseViewController.swift
//  CandyMountain
//
//  Created by Jan on 28.05.24.
//  Copyright © 2024 Doug Williams. All rights reserved.
//

import UIKit
import HealthKit
import ConnectIQ

class GlucoseViewController: UIViewController, IQDeviceEventDelegate, IQAppMessageDelegate {
    var appInfo = AppInfo()
    var tableEntries = [TableEntry]()
    var logMessages = [String]()
    
    var device: IQDevice {
        return self.appInfo.app.device
    }
    
    convenience init(_ appInfo: AppInfo) {
        self.init()
        self.appInfo = appInfo
    }
    
    @IBOutlet weak var glucoseValueLabel: UILabel! // IBOutlet for the UITextView
    @IBOutlet weak var glucoseDateLabel: UILabel!
    @IBOutlet weak var glucoseTrendLabel: UILabel!
    @IBOutlet weak var logView: UITextView!
    
    let healthStore = HKHealthStore()
    let glucoseType = HKQuantityType.quantityType(forIdentifier: .bloodGlucose)

    private var latestBloodGlucoseSample: HKQuantitySample?

    override func viewWillAppear(_ animated: Bool) {
        ConnectIQ.sharedInstance().register(forDeviceEvents: self.device, delegate: self)
        ConnectIQ.sharedInstance().register(forAppMessages: self.appInfo.app, delegate: self)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        ConnectIQ.sharedInstance().unregister(forAllDeviceEvents: self)
        ConnectIQ.sharedInstance().unregister(forAllAppMessages: self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        glucoseValueLabel.text = "Loading Glucose..."
        // Do any additional setup after loading the view.
    }
    override func viewDidAppear(_ animated: Bool) {
        requestAuthorization()
    }
    
    // add a button handler
    @IBAction func sendButtonPressed(_ sender: Any) {
        sendBloodGlucoseData()
    }

    private func formatTimestamp(_ timestamp: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    private func requestAuthorization() {
        let healthTypesToRead: Set<HKObjectType> = [HKObjectType.quantityType(forIdentifier: .bloodGlucose)!]
        
        healthStore.requestAuthorization(toShare: nil, read: healthTypesToRead) { (success, error) in
            if success {
                print("HealthKit authorization granted")
                self.startObservingBloodGlucose()
            } else {
                if let error = error {
                    let text = "HealthKit authorization failed with error: \(error.localizedDescription)"
                    print(text)
                }
            }
        }
    }
    
    private func startObservingBloodGlucose() {
        guard let bloodGlucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) else {
            print("Blood glucose type is not available")
            return
        }
        
        let query = HKObserverQuery(sampleType: bloodGlucoseType, predicate: nil) { (query, completionHandler, error) in
            if let error = error {
                print("Error observing blood glucose changes: \(error.localizedDescription)")
                return
            }
            
            self.fetchLatestBloodGlucose()
            completionHandler()
        }
        
        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: bloodGlucoseType, frequency: .immediate) { (success, error) in
            if success {
                print("Background delivery enabled for blood glucose updates")
            } else {
                if let error = error {
                    print("Error enabling background delivery: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func fetchLatestBloodGlucose() {
        logMessage("fetchLatestBloodGlucose() was invoked()")
        // Define the sample type for blood glucose
        guard let bloodGlucoseType = HKObjectType.quantityType(forIdentifier: .bloodGlucose) else {
            // Handle the case when the blood glucose type is not available
            return
        }

        // Create a query to fetch the latest blood glucose sample
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: bloodGlucoseType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
            guard let samples = samples as? [HKQuantitySample], let firstSample = samples.first else {
                if let error = error {
                    print("Error fetching blood glucose data: \(error.localizedDescription)")
                }
                return
            }
            self.latestBloodGlucoseSample = firstSample
            self.sendBloodGlucoseData()
            DispatchQueue.main.async {
                self.updateGlucoseView()
            }
        }

        // Execute the query
        HKHealthStore().execute(query)
    }
    // function to send the latestBloodGlucoseSample to the watch
    private func sendBloodGlucoseData() {
        // Check if the latestBloodGlucoseSample is not nil
        if let bloodGlucoseSample = latestBloodGlucoseSample {
            let bloodGlucose = bloodGlucoseSample.quantity.doubleValue(for: HKUnit(from: "mg/dL"))
            let timestamp = bloodGlucoseSample.startDate.timeIntervalSince1970
            
            //check for trend
            //set glucose trend as double to -1
            var glucoseTrend = -1.0
            if let bloodGlucoseSampleMetadata = bloodGlucoseSample.metadata,
               let trend = bloodGlucoseSampleMetadata["com.LoopKit.GlucoseKit.HKMetadataKey.GlucoseTrend"] as? String {
                //set glucoseTrend to the value of bloodGlucoseSampleMetadata["com.LoopKit.GlucoseKit.HKMetadataKey.GlucoseTrendRateValue"] if available
                if let trendRate = bloodGlucoseSampleMetadata["com.LoopKit.GlucoseKit.HKMetadataKey.GlucoseTrendRateValue"] as? Double {
                    glucoseTrend = trendRate
                }
                
            }
            let message = ["glucose": bloodGlucose, "trend": glucoseTrend, "timestamp": Int(timestamp)] as [String : Any]
            self.sendMessage(message)
        }
    }
    
    
    private func updateGlucoseView() {
        if let bloodGlucoseSample = latestBloodGlucoseSample {
            let bloodGlucose = bloodGlucoseSample.quantity.doubleValue(for: HKUnit(from: "mg/dL"))
            let date = bloodGlucoseSample.startDate
            glucoseValueLabel.text = String(format: "%.0f", bloodGlucose)
            glucoseDateLabel.text = formatTimestamp(date)
            if let bloodGlucoseSampleMetadata = bloodGlucoseSample.metadata,
               let trendLabel = bloodGlucoseSampleMetadata["com.LoopKit.GlucoseKit.HKMetadataKey.GlucoseTrend"] as? String {
                glucoseTrendLabel.text = trendLabel
            }
        }
    }
    private func updateLogView() {
        self.logView.text = (self.logMessages as NSArray).componentsJoined(by: "\n")
        //self.logView.layoutManager.ensureLayout(for: self.logView.textContainer)
        self.logView.scrollRangeToVisible(NSRange(location: self.logView.text.count - 1, length: 1))
    }
    
    // --------------------------------------------------------------------------------
    // MARK: - METHODS (IQDeviceEventDelegate)
    // --------------------------------------------------------------------------------
    
    func deviceStatusChanged(_ device: IQDevice, status: IQDeviceStatus) {
        // We've only registered to receive status updates for one device, so we don't
        // need to check the device parameter here. We know it's our device.
        if status != .connected {
            // This page's device is no longer connected. Pop back to the device list.
            ConnectIQ.sharedInstance().unregister(forAllAppMessages: self)
            if let navigationController = self.navigationController {
                navigationController.popToRootViewController(animated: true)
            }
        }
    }
    
    // --------------------------------------------------------------------------------
    // MARK: - METHODS (IQAppMessageDelegate)
    // --------------------------------------------------------------------------------
    
    func receivedMessage(_ message: Any, from app: IQApp) {
        // We've only registered to receive messages from our app, so we don't need to
        // check the app parameter here. We know it's our app.
        logMessage("<<<<< Received message: \(message)")
    }
    // --------------------------------------------------------------------------------
    // MARK: - METHODS
    // --------------------------------------------------------------------------------
    
    func sendMessage(_ message: Any) {
        logMessage("> Sending message: \(message)")
        ConnectIQ.sharedInstance().sendMessage(message, to: self.appInfo.app, progress: {(sentBytes: UInt32, totalBytes: UInt32) -> Void in
            let percent: Double = 100.0 * Double(sentBytes / totalBytes)
            print("Progress: \(percent)% sent \(sentBytes) bytes of \(totalBytes)")
            }, completion: {(result: IQSendMessageResult) -> Void in
                self.logMessage("Send message finished with result: \(NSStringFromSendMessageResult(result))")
        })
    }
    
    func logMessage(_ message: String) {
        //get the current time of day as string
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let time = formatter.string(from: Date())
        print("\(time) \(message)")
        self.logMessages.append("\(time) \(message)")
        while self.logMessages.count > kMaxLogMessages {
            self.logMessages.remove(at: 0)
        }
        //when in foreground mode update the logview on the main thread
        DispatchQueue.main.async {
            self.updateLogView()
        }
    }


}
