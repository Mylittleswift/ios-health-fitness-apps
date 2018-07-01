import Foundation
import HealthKit

class HealthKitSetupAssistant {    
    private enum HealhKitError: Error {
        case notAvailableOnDevice  
        case dataTypeNotAvailable 
    }
    
    func authHealthKit(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, HealhKitError.notAvailableOnDevice)
            return
        }
    
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
    
        let healthKitWriteTypes: Set<HKSampleType> = [bodyMassIndex, activeEnergy, HKObjectType.workoutType()]
    
        let healthKitReadTypes: Set<HKObjectType> = [dateOfBirth, bloodType, biologicalSex, bodyMassIndex, height, bodyMass, HKObjectType.workoutType()]
    
        HKHealthStore().requestAuthorization(toShare: healthKitWriteTypes, read: healthKitReadTypes, completion: { (success, error) in
            completion(success, error)
            })
    }
}
