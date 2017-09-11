/*
Copyright (C) 2016 Apple Inc. All Rights Reserved.
See LICENSE.txt for this sample’s licensing information

Abstract:
The primary controller providing UI and functionality related to begining and ending a workout.
*/

import WatchKit
import HealthKit

class InterfaceController: WKInterfaceController, HKWorkoutSessionDelegate {
    // MARK: Properties
    
    let healthStore = HKHealthStore()
    
    // Used to track the current `HKWorkoutSession`.
    var currentWorkoutSession: HKWorkoutSession?
    
    var workoutBeginDate: Date?
    var workoutEndDate: Date?
    
    var isWorkoutRunning = false
    
    var currentQuery: HKQuery?
    
    var activeEnergySamples = [HKQuantitySample]()
    
    // Start with a zero quantity.
    var currentActiveEnergyQuantity = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: 0.0)
    
    @IBOutlet var workoutButton: WKInterfaceButton!
    @IBOutlet var activeEnergyBurnedLabel: WKInterfaceLabel!

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user.
        super.willActivate()
        
        // Only proceed if health data is available.
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        // We need to be able to write workouts, so they display as a standalone workout in the Activity app on iPhone.
        // We also need to be able to write Active Energy Burned to write samples to HealthKit to later associating with our app.
        let typesToShare = Set([
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned)!])
        
        let typesToRead = Set([
            HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned)!])
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if let error = error, !success {
                print("You didn't allow HealthKit to access these read/write data types. In your app, try to handle this error gracefully when a user decides not to provide access. The error was: \(error.localizedDescription). If you're using a simulator, try it on a device.")
            }
        }
    }
    
    // This will toggle beginning and ending a workout session.
    @IBAction func toggleWorkout() {
        if isWorkoutRunning {
            guard let workoutSession = currentWorkoutSession else { return }
            
            healthStore.end(workoutSession)
            isWorkoutRunning = false
        } else {
            // Begin workout.
            isWorkoutRunning = true
            
            // Clear the local Active Energy Burned quantity when beginning a workout session.
            currentActiveEnergyQuantity = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: 0.0)
            
            currentQuery = nil
            activeEnergySamples = []
            
            // An indoor walk workout session. There are other activity and location types available to you.
            let workoutSession = HKWorkoutSession(activityType: .walking, locationType: .indoor)
            workoutSession.delegate = self
            
            currentWorkoutSession = workoutSession
            
            healthStore.start(workoutSession)
        }
    }
    
    // MARK: Convenience
    
    /*
        Create and save an HKWorkout with the amount of Active Energy Burned we accumulated during the HKWorkoutSession.
    
        Additionally, associate the Active Energy Burned samples to our workout to facilitate showing our app as credited for these samples in the Move graph in the Activity app on iPhone.
    */
    func saveWorkout() {
        // Obtain the `HKObjectType` for active energy burned.
        guard let activeEnergyType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned) else { return }
        
        // Only proceed if both `beginDate` and `endDate` are non-nil.
        guard let beginDate = workoutBeginDate, let endDate = workoutEndDate else { return }
        
        /*
            NOTE: There is a known bug where activityType property of HKWorkoutSession returns 0, as of iOS 9.1 and watchOS 2.0.1. So, rather than set it using the value from the `HKWorkoutSession`, set it explicitly for the HKWorkout object.
        */
        let workout = HKWorkout(activityType: HKWorkoutActivityType.walking, start: beginDate, end: endDate, duration: endDate.timeIntervalSince(beginDate), totalEnergyBurned: currentActiveEnergyQuantity, totalDistance: HKQuantity(unit: HKUnit.meter(), doubleValue: 0.0), metadata: nil)
        
        // Save the array of samples that produces the energy burned total
        let finalActiveEnergySamples = activeEnergySamples
        
        guard healthStore.authorizationStatus(for: activeEnergyType) == .sharingAuthorized && healthStore.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized else { return }
        
        healthStore.save(workout) { [unowned self] success, error in
            if let error = error, !success {
                print("An error occurred saving the workout. The error was: \(error.localizedDescription)")
                return
            }
            
            // Since HealthKit completion blocks may come back on a background queue, please dispatch back to the main queue.
            if success && finalActiveEnergySamples.count > 0 {
                // Associate the accumulated samples with the workout.
                self.healthStore.add(finalActiveEnergySamples, to: workout) { success, error in
                    if let error = error, !success {
                        print("An error occurred adding samples to the workout. The error was: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    func beginWorkout(on beginDate: Date) {
        // Obtain the `HKObjectType` for active energy burned and the `HKUnit` for kilocalories.
        guard let activeEnergyType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned) else { return }
        let energyUnit = HKUnit.kilocalorie()
        
        // Update properties.
        workoutBeginDate = beginDate
        workoutButton.setTitle("End Workout")
        
        // Set up a predicate to obtain only samples from the local device starting from `beginDate`.
        let datePredicate = HKQuery.predicateForSamples(withStart: beginDate, end: nil, options: HKQueryOptions())
        let devicePredicate = HKQuery.predicateForObjects(from: [HKDevice.local()])
        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates:[datePredicate, devicePredicate])
        
        /*
            Create a results handler to recreate the samples generated by a query of active energy samples so that they can be associated with this app in the move graph. It should be noted that if your app has different heuristics for active energy burned you can generate your own quantities rather than rely on those from the watch. The sum of your sample's quantity values should equal the energy burned value provided for the workout.
        */
        let sampleHandler = { [unowned self] (samples: [HKQuantitySample]) -> Void in
            DispatchQueue.main.async { [unowned self] in
                
                let initialActiveEnergy = self.currentActiveEnergyQuantity.doubleValue(for: energyUnit)
                
                let processedResults: (Double, [HKQuantitySample]) = samples.reduce((initialActiveEnergy, [])) { current, sample in
                    let accumulatedValue = current.0 + sample.quantity.doubleValue(for: energyUnit)
                    
                    let ourSample = HKQuantitySample(type: activeEnergyType, quantity: sample.quantity, start: sample.startDate, end: sample.endDate)
                    
                    return (accumulatedValue, current.1 + [ourSample])
                }
                
                // Update the UI.
                self.currentActiveEnergyQuantity = HKQuantity(unit: energyUnit, doubleValue: processedResults.0)
                self.activeEnergyBurnedLabel.setText("\(processedResults.0)")
                
                // Update our samples.
                self.activeEnergySamples += processedResults.1
            }
        }
        
        // Create a query to report new Active Energy Burned samples to our app.
        let activeEnergyQuery = HKAnchoredObjectQuery(type: activeEnergyType, predicate: predicate, anchor: nil, limit: Int(HKObjectQueryNoLimit)) { query, samples, deletedObjects, anchor, error in
            if let error = error {
                print("An error occurred with the `activeEnergyQuery`. The error was: \(error.localizedDescription)")
                return
            }
            // NOTE: `deletedObjects` are not considered in the handler as there is no way to delete samples from the watch during a workout.
            guard let activeEnergySamples = samples as? [HKQuantitySample] else { return }
            sampleHandler(activeEnergySamples)
        }
        
        // Assign the same handler to process future samples generated while the query is still active.
        activeEnergyQuery.updateHandler = { query, samples, deletedObjects, anchor, error in
            if let error = error {
                print("An error occurred with the `activeEnergyQuery`. The error was: \(error.localizedDescription)")
                return
            }
            // NOTE: `deletedObjects` are not considered in the handler as there is no way to delete samples from the watch during a workout.
            guard let activeEnergySamples = samples as? [HKQuantitySample] else { return }
            sampleHandler(activeEnergySamples)
        }
        
        currentQuery = activeEnergyQuery
        healthStore.execute(activeEnergyQuery)
    }
    
    func endWorkout(on endDate: Date) {
        workoutEndDate = endDate
        
        workoutButton.setTitle("Begin Workout")
        activeEnergyBurnedLabel.setText("0.0")
        
        if let query = currentQuery {
            healthStore.stop(query)
        }
        
        saveWorkout()
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        DispatchQueue.main.async { [unowned self] in
            switch toState {
            case .running:
                self.beginWorkout(on: date)
                
            case .ended:
                self.endWorkout(on: date)
                
            default:
                print("Unexpected workout session state: \(toState)")
            }
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("The workout session failed. The error was: \(error.localizedDescription)")
    }
}
