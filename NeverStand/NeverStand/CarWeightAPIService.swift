import Foundation

class CarWeightAPIService {
    // Use your own credentials in a real app
    private let username = "012702318@ntnu.edu.tw"
    private let password = "LkClcVXp"
    private let cartRanking = CartRanking()
    
    func fetchCarWeight(beaconStationID: String, completion: @escaping (Result<[RankedCarWeight], Error>) -> Void) {
        let url = URL(string: "https://api.metro.taipei/metroapi/CarWeight.asmx")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/xml; charset=utf-8", forHTTPHeaderField: "Content-Type")
        
        let soapBody = """
        <?xml version="1.0" encoding="utf-8"?>
        <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                       xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                       xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Body>
            <getCarWeightByInfoEx xmlns="http://tempuri.org/">
              <userName>\(username)</userName>
              <passWord>\(password)</passWord>
            </getCarWeightByInfoEx>
          </soap:Body>
        </soap:Envelope>
        """
        request.httpBody = soapBody.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data, let rawString = String(data: data, encoding: .utf8) else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                // Extract JSON part (from beginning to first '<')
                let jsonString: String
                if let jsonEndIndex = rawString.firstIndex(of: "<") {
                    jsonString = String(rawString[..<jsonEndIndex])
                } else {
                    jsonString = rawString
                }
                
                guard let jsonData = jsonString.data(using: .utf8) else {
                    throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Invalid JSON string"))
                }
                
                // Decode JSON
                let decoder = JSONDecoder()
                let carWeights = try decoder.decode([CarWeightData].self, from: jsonData)
                
                // Process data based on station ID
                let filteredData = self.filterRelevantStations(carWeights, beaconStationID: beaconStationID)
                print(filteredData)
                let rankedResults = self.cartRanking.rankCarWeights(filteredData)
                
                completion(.success(rankedResults))
            } catch {
                print("Car Weight API Error: \(error)")
                completion(.failure(error))
            }
        }.resume()
    }
    
    // Filter relevant stations based on beacon station ID
    private func filterRelevantStations(_ carWeights: [CarWeightData], beaconStationID: String) -> [CarWeightData] {
        // Extract the letter prefix and number from beacon station ID
        let beaconPrefix = String(beaconStationID.prefix(while: { $0.isLetter }))
        guard let beaconNumber = Int(beaconStationID.drop(while: { $0.isLetter })) else {
            print("Invalid beacon station ID format: \(beaconStationID)")
            return []
        }
        
        // Define the prefixes to check
        let prefixes = ["R", "BL", "B", "G", "O"]
        var result: [CarWeightData] = []
        
        // Process each prefix
        for prefix in prefixes {
            let matchingWeights = carWeights.filter { $0.stationID.hasPrefix(prefix) }
            if matchingWeights.isEmpty { continue }
            
            // Find closest records for CID=1 and CID=2
            var cid1Closest: CarWeightData?
            var cid2Closest: CarWeightData?
            
            for weight in matchingWeights {
                guard let stationNumber = Int(weight.stationID.drop(while: { $0.isLetter })) else { continue }
                let referenceNumber = prefix == beaconPrefix ? beaconNumber : stationNumber
                
                if weight.cid == "1" && stationNumber < referenceNumber {
                    if cid1Closest == nil || stationNumber > (Int(cid1Closest!.stationID.drop(while: { $0.isLetter })) ?? 0) {
                        cid1Closest = weight
                    }
                } else if weight.cid == "2" && stationNumber > referenceNumber {
                    if cid2Closest == nil || stationNumber < (Int(cid2Closest!.stationID.drop(while: { $0.isLetter })) ?? Int.max) {
                        cid2Closest = weight
                    }
                }
            }
            
            if let cid1 = cid1Closest { result.append(cid1) }
            if let cid2 = cid2Closest { result.append(cid2) }
        }
        
        return result
    }
}
