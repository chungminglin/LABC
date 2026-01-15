import SwiftUI

struct ContentView: View {
    @EnvironmentObject var beaconManager: BeaconManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Scanning toggle
                Toggle("幫我找到座位 (On/Off)", isOn: $beaconManager.isScanning)
                    .onChange(of: beaconManager.isScanning) { _ in
                        beaconManager.toggleScanning()
                    }
                    .padding()
                    .tint(.green)
                
                // Status message
                Text(beaconManager.statusMessage)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(minHeight: 100)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                
                // Car suggestions
                if !beaconManager.suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("建議車廂")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(beaconManager.suggestions, id: \.self) { suggestion in
                            HStack {
                                Image(systemName: "tram.fill")
                                    .foregroundColor(.blue)
                                Text(suggestion)
                                    .font(.subheadline)
                            }
                            .padding(.vertical, 5)
                            .padding(.horizontal)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                Spacer()
                
                Text("註：刷卡進入月台時提供最佳上車建議")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .navigationTitle("MRT Never Stand")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(BeaconManager())
    }
}
