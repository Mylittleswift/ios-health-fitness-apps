import Foundation
import HealthKit

class HealthKitSetupAssistant {
    
    private enum HealhKitError: Error {
        case notAvailableOnDevice  /// Happens on Ipdas
        case dataTypeNotAvailable  /// Some Types may be unavail this version
    }

/// Takes no params and has completeion handler that returns true/false
/// and optionla error if theres a problem
class func authHealthKit(completion: @escaping (Bool, Error?) -> Void) {
    
    //Check if Health Kit is available on device
    guard HKHealthStore.isHealthDataAvailable() else {
        completion(false, HealhKitError.notAvailableOnDevice)
        return
    }
    
    /// Single guard to unwrap several optionals
    guard let dateOfBirth = HKObjectType.characteristicType(forIdentifier: .dateOfBirth),
    let bloodType = HKObjectType.characteristicType(forIdentifier: .bloodType),
    let biologicalSex = HKObjectType.characteristicType(forIdentifier: .biologicalSex),
    let bodyMassIndex = HKObjectType.quantityType(forIdentifier: .bodyMassIndex),
    let height = HKObjectType.quantityType(forIdentifier: .height),
    let bodyMass = HKObjectType.quantityType(forIdentifier: .bodyMass),
    let activeEnergy = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            
            completion(false, HealhKitError.dataTypeNotAvailable)
            return
    }
    
    /// List of dataTypes o read and write
    let healthKitWriteTypes: Set<HKSampleType> = [bodyMassIndex, activeEnergy, HKObjectType.workoutType()]
    
    let healthKitReadTypes: Set<HKObjectType> = [dateOfBirth, bloodType, biologicalSex, bodyMassIndex, height, bodyMass, HKObjectType.workoutType()]
    
    /// Authorizing HealthKit
    /// Then call completion handler
    HKHealthStore().requestAuthorization(toShare: healthKitWriteTypes, read: healthKitReadTypes, completion: { (success, error) in
        completion(success, error)
        })
    
    
    }
}
