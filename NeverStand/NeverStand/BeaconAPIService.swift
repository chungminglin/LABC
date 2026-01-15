import Foundation

struct BeaconRequest: Codable {
    let username: String
    let password: String
    let beacon: BeaconData
}

struct BeaconData: Codable {
    let uuid: String
    let major: String
    let minor: String
    let power: String
    
    enum CodingKeys: String, CodingKey {
        case uuid = "UUID"
        case major = "MAJOR"
        case minor = "MINOR"
        case power = "POWER"
    }
}

struct BeaconResponse: Codable {
    let d: BeaconInfo
}

struct BeaconInfo: Codable {
    let bid: String
    let sid: String
    let lid: String
    let posino: String
    let position: String
    let stationID: String
    let stationName: String
    
    enum CodingKeys: String, CodingKey {
        case bid = "BID"
        case sid = "SID"
        case lid = "LID"
        case posino = "POSINO"
        case position = "POSITION"
        case stationID = "STATION_ID"
        case stationName = "STATION_NAME"
    }
}

class BeaconAPIService {
    // Use your own credentials in a real app
    private let username = "012702318@ntnu.edu.tw"
    private let password = "LkClcVXp"
    
    func fetchBeaconInfo(uuid: String, major: String, minor: String, completion: @escaping (Result<BeaconInfo, Error>) -> Void) {
        let url = URL(string: "https://ws.metro.taipei/TRTCBeaconBE/BeaconControl.asmx/GetBeaconInfo")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody = BeaconRequest(
            username: username,
            password: password,
            beacon: BeaconData(uuid: uuid, major: major, minor: minor, power: "1")
        )
        
        do {
            let jsonData = try JSONEncoder().encode(requestBody)
            request.httpBody = jsonData
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let result = try decoder.decode(BeaconResponse.self, from: data)
                completion(.success(result.d))
            } catch {
                print("Decoding error: \(error)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Response: \(responseString)")
                }
                completion(.failure(error))
            }
        }.resume()
    }
}
