import CoreLocation
import UIKit
import UserNotifications

class BeaconManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var isScanning: Bool {
        didSet {
            // 每次 isScanning 改變時保存到 UserDefaults
            UserDefaults.standard.set(isScanning, forKey: "isScanning")
            toggleScanning()
        }
    }
    @Published var statusMessage = "Ready to scan"
    @Published var suggestions: [String] = []
    
    private let beaconUUID = UUID(uuidString: "c344d58e-4dc5-4be0-9c90-a953cf7f6e7e")!
    private var scanTimer: Timer?
    private var pauseUntil: Date?
    private let beaconAPIService = BeaconAPIService()
    private let carWeightAPIService = CarWeightAPIService()
    
    override init() {
        // 從 UserDefaults 讀取保存的狀態，若無則預設為 false
        self.isScanning = UserDefaults.standard.bool(forKey: "isScanning")
        super.init()
        locationManager.delegate = self
        locationManager.requestAlwaysAuthorization()
        
        // 設置背景執行能力
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        
        // Request notification permissions
//        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
//            if granted {
//                print("Notification permission granted")
//            } else if let error = error {
//                print("Notification permission error: \(error)")
//            }
//        }
        let options: UNAuthorizationOptions = [.alert, .sound, .badge, .providesAppNotificationSettings]
            UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, _ in
                print("通知權限狀態: \(granted ? "已授權" : "未授權")")
            }

        
        // 如果初始化時 isScanning 為 true，啟動掃描
        if isScanning {
            startScanning()
        }
    }
    
    func toggleScanning() {
        if isScanning {
            if let pauseDate = pauseUntil, Date() < pauseDate {
                statusMessage = "Paused until \(pauseDate.formatted(date: .abbreviated, time: .shortened))"
                return
            }
            
            startScanning()
            statusMessage = "Scanning for beacons..."
        } else {
            stopScanning()
            statusMessage = "開啟右上開關，找到車廂空位"
        }
    }
    
    func startScanning() {
        // Check if we're in a pause period
        if let pauseDate = pauseUntil, Date() < pauseDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            statusMessage = "Scanning paused until \(formatter.string(from: pauseDate))"
            
            // Schedule a timer to resume after pause ends
            DispatchQueue.main.asyncAfter(deadline: .now() + pauseDate.timeIntervalSinceNow) { [weak self] in
                if self?.isScanning == true {
                    self?.startPeriodicScanning()
                    self?.statusMessage = "Scanning resumed"
                }
            }
            return
        }
        
        startPeriodicScanning()
    }
    
    private func startPeriodicScanning() {
        scanTimer?.invalidate()
        scanTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.performSingleScan()
        }
        performSingleScan() // Start first scan immediately
    }
    
    private func performSingleScan() {
        let beaconConstraint = CLBeaconIdentityConstraint(uuid: beaconUUID)
        let beaconRegion = CLBeaconRegion(beaconIdentityConstraint: beaconConstraint, identifier: "TRTCBeacon")
        beaconRegion.notifyOnEntry = true
        beaconRegion.notifyOnExit = true
        beaconRegion.notifyEntryStateOnDisplay = true // 螢幕關閉時仍通知

        locationManager.startMonitoring(for: beaconRegion)
        locationManager.startRangingBeacons(satisfying: beaconConstraint)

//        let region = CLBeaconRegion(uuid: beaconUUID, identifier: "TRTCBeacon")
//        region.notifyEntryStateOnDisplay = true
        
//        locationManager.startMonitoring(for: region)
//        locationManager.startRangingBeacons(satisfying: CLBeaconIdentityConstraint(uuid: beaconUUID))
        print("Scanning for beacons at: \(Date())")
        
        // Stop the scanning after 2 seconds to save battery
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            self.locationManager.stopRangingBeacons(satisfying: CLBeaconIdentityConstraint(uuid: self.beaconUUID))
//            self.locationManager.stopMonitoring(for: region)
        }
    }
    
    private func stopScanning() {
        scanTimer?.invalidate()
        scanTimer = nil
        locationManager.stopRangingBeacons(satisfying: CLBeaconIdentityConstraint(uuid: beaconUUID))
        locationManager.stopMonitoring(for: CLBeaconRegion(uuid: beaconUUID, identifier: "TRTCBeacon"))
        print("Scanning stopped")
    }
    
    private func pauseScanning(for duration: TimeInterval) {
        pauseUntil = Date().addingTimeInterval(duration)
        stopScanning()
        
        // Schedule scanning to resume after pause
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self = self else { return }
            if self.isScanning {
                self.pauseUntil = nil
                self.startScanning()
                self.statusMessage = "Scanning resumed after pause"
            }
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        statusMessage = "Scanning paused until \(formatter.string(from: pauseUntil!))"
    }
    
    // MARK: - CLLocationManagerDelegate Methods
    
    func locationManager(_ manager: CLLocationManager, didRange beacons: [CLBeacon], satisfying beaconConstraint: CLBeaconIdentityConstraint) {
        guard !beacons.isEmpty else {
            statusMessage = "請於刷卡進站後再次確認"
            return
        }
        
        for beacon in beacons {
            if beacon.uuid == beaconUUID {
                statusMessage = "Found beacon: Major \(beacon.major), Minor \(beacon.minor)"
                print("Found beacon: UUID: \(beacon.uuid), Major: \(beacon.major), Minor: \(beacon.minor), RSSI: \(beacon.rssi)")
                
                processBeacon(beacon)
                break
            }
        }
    }
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid

    private func processBeacon(_ beacon: CLBeacon) {
        
        // 開始背景任務
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        beaconAPIService.fetchBeaconInfo(uuid: beacon.uuid.uuidString,
                                         major: beacon.major.stringValue,
                                         minor: beacon.minor.stringValue) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let info):
                    self.statusMessage = "Station: \(info.stationName)"
                    print("目前位置： \(info.stationName)")
                    // Check if position contains "PAO"
                    if info.position.contains("PAO") {
                        self.statusMessage = "Platform detected at \(info.stationName)"
                        
                        // Pause scanning for 90 minutes but keep isScanning true
                        self.pauseScanning(for: 90 * 60)
                        
                        // Fetch car weight data
                        self.fetchCarWeightData(stationID: info.sid, stationName: info.stationName)
                    }
                    
                case .failure(let error):
                    self.statusMessage = "API error: \(error.localizedDescription)"
                }
            }
        }
        self.endBackgroundTask()
    }
    private func endBackgroundTask() {
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
    }

    
    private func fetchCarWeightData(stationID: String,stationName: String) {
        carWeightAPIService.fetchCarWeight(beaconStationID: stationID) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let rankedCarWeights):
                    print("車廂擁擠度：\(rankedCarWeights)")
                    // Generate suggestions
                    self.suggestions = rankedCarWeights.map { ranked in
                        let direction = self.getDirectionText(stationID: ranked.originalData.stationID, cid: ranked.originalData.cid)
                        return "\(direction)第\(ranked.selectedCar)車廂上車"
                    }
                    
                    // Send notification
                    if !self.suggestions.isEmpty {
                        self.sendNotification(title: "搭乘建議\(stationName)站(\(stationID))", body: self.suggestions.joined(separator: "\n"))
                    }
                    
                case .failure(let error):
                    self.statusMessage = "Car data error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func getDirectionText(stationID: String, cid: String) -> String {
        let prefix = String(stationID.prefix(while: { $0.isLetter }))
        switch prefix {
        case "R":
            return cid == "1" ? "往象山方向建議請至" : "往淡水方向建議請至"
        case "B", "BL":
            return cid == "1" ? "往頂埔方向建議請至" : "往南港方向建議請至"
        case "G":
            return cid == "1" ? "往新店方向建議請至" : "往松山方向建議請至"
        case "O":
            return cid == "1" ? "往南勢角方向建議請至" : "往新莊蘆洲方向建議請至"
        default:
            return "建議請至"
        }
    }
    
    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        // 重要：設定 categoryIdentifier 以支援背景觸發
        content.categoryIdentifier = "BEACON_ALERT"
        
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                           content: content,
                                           trigger: nil) // nil trigger = immediate delivery
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            }
        }
    }
    
    // Additional delegate methods
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            statusMessage = "開啟右上開關，找到車廂空位"
            if isScanning {
                startScanning()
            }
        case .denied:
            statusMessage = "Location access denied. Please enable in Settings."
        case .restricted:
            statusMessage = "Location services restricted."
        case .notDetermined:
            statusMessage = "Waiting for location permission..."
        @unknown default:
            statusMessage = "Unknown authorization status"
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        statusMessage = "Location error: \(error.localizedDescription)"
    }
}
