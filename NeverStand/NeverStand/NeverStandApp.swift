//
//  NeverStandApp.swift
//  NeverStand
//
//  Created by JK Lin on 2025/3/22.
//

import SwiftUI

@main
struct NeverStandApp: App {
    @StateObject private var beaconManager = BeaconManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(beaconManager)
        }
    }
}
