import Foundation

// Base data structure for car weight information
struct CarWeightData: Codable {
    let trainNumber: String
    let cn1: String
    let cid: String
    let stationID: String
    let cart1L: String
    let cart2L: String
    let cart3L: String
    let cart4L: String
    let cart5L: String
    let cart6L: String
    let utime: String
    
    enum CodingKeys: String, CodingKey {
        case trainNumber = "TrainNumber"
        case cn1 = "CN1"
        case cid = "CID"
        case stationID = "StationID"
        case cart1L = "Cart1L"
        case cart2L = "Cart2L"
        case cart3L = "Cart3L"
        case cart4L = "Cart4L"
        case cart5L = "Cart5L"
        case cart6L = "Cart6L"
        case utime
    }
}

// Structure for ranked car weight data
struct RankedCarWeight {
    let originalData: CarWeightData
    let rankedCarts: [Int: Int] // Key is cart index (1-6), value is rank (1-6)
    let selectedCar: Int        // Selected car (1-6)
}
