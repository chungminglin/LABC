package android_neverstand.service

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.bluetooth.BluetoothManager
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import android_neverstand.api.ApiService
import kotlinx.coroutines.*
import java.nio.ByteBuffer
import java.util.UUID

class BeaconManagerService : Service() {
    private val TAG = "BeaconManagerService"
    private val CHANNEL_ID = "BeaconServiceChannel"
    private val NOTIFICATION_ID = 1
    
    private var bluetoothLeScanner: BluetoothLeScanner? = null
    private var isScanningActive = false
    private val serviceScope = CoroutineScope(Dispatchers.IO + Job())
    private val apiService = ApiService()
    
    // Beacon UUID to scan
    private val targetUuid = UUID.fromString("c344d58e-4dc5-4be0-9c90-a953cf7f6e7e")
    
    private var pauseUntilMillis = 0L

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        bluetoothLeScanner = bluetoothManager.adapter?.bluetoothLeScanner
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action
        if (action == "START_SCANNING") {
            startForeground(NOTIFICATION_ID, createNotification("Scanning for beacons..."))
            BeaconManagerState.setScanning(true)
            startPeriodicScanning()
        } else if (action == "STOP_SCANNING") {
            stopPeriodicScanning()
            BeaconManagerState.setScanning(false)
            BeaconManagerState.setStatusMessage("開啟右上開關，找到車廂空位")
            stopForeground(STOP_FOREGROUND_REMOVE)
            stopSelf()
        } else if (action == "SIMULATE_MATCH") {
            BeaconManagerState.setStatusMessage("Simulation: Requesting test data for O06...")
            fetchCarWeightData("O06", "大橋頭站")
        }
        return START_STICKY
    }

    private fun startPeriodicScanning() {
        if (isScanningActive) return
        isScanningActive = true
        
        serviceScope.launch {
            while (isScanningActive) {
                if (System.currentTimeMillis() < pauseUntilMillis) {
                    val remainingMins = (pauseUntilMillis - System.currentTimeMillis()) / 60000
                    BeaconManagerState.setStatusMessage("Scanning paused for ${remainingMins} mins")
                } else {
                    performSingleScan()
                }
                delay(10000) // 10 seconds between scans
            }
        }
    }

    private fun stopPeriodicScanning() {
        isScanningActive = false
        stopBleScan()
    }

    private fun performSingleScan() {
        try {
            val filters = listOf(
                ScanFilter.Builder().build() // Broad scan filter for iBeacons
            )
            val settings = ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                .build()

            BeaconManagerState.setStatusMessage("Scanning for beacons...")
            bluetoothLeScanner?.startScan(filters, settings, scanCallback)
            Log.d(TAG, "BLE Scan started")

            // Stop after 2 seconds to save battery
            serviceScope.launch(Dispatchers.Main) {
                delay(2000)
                stopBleScan()
            }
        } catch (e: SecurityException) {
            BeaconManagerState.setStatusMessage("Missing Bluetooth permissions")
        }
    }

    private fun stopBleScan() {
        try {
            bluetoothLeScanner?.stopScan(scanCallback)
            Log.d(TAG, "BLE Scan stopped")
        } catch (e: SecurityException) {
            // Ignore
        }
    }

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult?) {
            super.onScanResult(callbackType, result)
            result?.let {
                val bytes = it.scanRecord?.bytes ?: return
                // Check if it's an iBeacon
                if (bytes.size > 30 && bytes[7].toInt() == 0x02 && bytes[8].toInt() == 0x15) {
                    val uuidBytes = bytes.copyOfRange(9, 25)
                    val bb = ByteBuffer.wrap(uuidBytes)
                    val mostSigBits = bb.long
                    val leastSigBits = bb.long
                    val uuid = UUID(mostSigBits, leastSigBits)
                    
                    if (uuid == targetUuid) {
                        val major = (bytes[25].toInt() and 0xFF) * 256 + (bytes[26].toInt() and 0xFF)
                        val minor = (bytes[27].toInt() and 0xFF) * 256 + (bytes[28].toInt() and 0xFF)
                        
                        BeaconManagerState.setStatusMessage("Found beacon: Major $major, Minor $minor")
                        processBeacon(uuid.toString(), major.toString(), minor.toString())
                        stopBleScan() // Stop early if found
                    }
                }
            }
        }
    }

    private fun processBeacon(uuid: String, major: String, minor: String) {
        serviceScope.launch {
            val infoResult = apiService.fetchBeaconInfo(uuid.uppercase(), major, minor)
            if (infoResult.isSuccess) {
                val info = infoResult.getOrNull()
                if (info != null) {
                    BeaconManagerState.setStatusMessage("Station: ${info.stationName}")
                    
                    if (info.position.contains("PAO")) {
                        BeaconManagerState.setStatusMessage("Platform detected at ${info.stationName}")
                        pauseUntilMillis = System.currentTimeMillis() + 90 * 60 * 1000 // 90 minutes
                        
                        fetchCarWeightData(info.sid, info.stationName)
                    }
                } else {
                    BeaconManagerState.setStatusMessage("Beacon info not found.")
                }
            } else {
                val error = infoResult.exceptionOrNull()
                BeaconManagerState.setStatusMessage("API error: ${error?.localizedMessage}")
            }
        }
    }

    private fun fetchCarWeightData(stationID: String, stationName: String) {
        serviceScope.launch {
            val weightResult = apiService.fetchCarWeight(stationID)
            if (weightResult.isSuccess) {
                val rankedWeights = weightResult.getOrNull() ?: emptyList()
                val suggestionsList = rankedWeights.map {
                    val direction = getDirectionText(it.originalData.stationID, it.originalData.cid)
                    "$direction 第${it.selectedCar}車廂上車"
                }
                BeaconManagerState.setSuggestions(suggestionsList)
                
                if (suggestionsList.isNotEmpty()) {
                    showSuggestionNotification("搭乘建議${stationName}站($stationID)", suggestionsList.joinToString("\n"))
                }
            } else {
                val error = weightResult.exceptionOrNull()
                BeaconManagerState.setStatusMessage("Car data error: ${error?.localizedMessage}")
            }
        }
    }

    private fun getDirectionText(stationID: String, cid: String): String {
        val prefix = stationID.takeWhile { it.isLetter() }
        return when (prefix) {
            "R" -> if (cid == "1") "往象山方向建議請至" else "往淡水方向建議請至"
            "B", "BL" -> if (cid == "1") "往頂埔方向建議請至" else "往南港方向建議請至"
            "G" -> if (cid == "1") "往新店方向建議請至" else "往松山方向建議請至"
            "O" -> if (cid == "1") "往南勢角方向建議請至" else "往新莊蘆洲方向建議請至"
            else -> "建議請至"
        }
    }

    private fun showSuggestionNotification(title: String, body: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        val intent = Intent(this, android_neverstand.MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        val pendingIntent = android.app.PendingIntent.getActivity(
            this, 0, intent, android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        )
        
        val notification = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()
        manager.notify(2, notification)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Beacon Service",
                NotificationManager.IMPORTANCE_HIGH
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(text: String): Notification {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
                .setContentTitle("NeverStand Beacon")
                .setContentText(text)
                .setSmallIcon(android.R.drawable.ic_menu_compass)
                .build()
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
                .setContentTitle("NeverStand Beacon")
                .setContentText(text)
                .setSmallIcon(android.R.drawable.ic_menu_compass)
                .build()
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        serviceScope.cancel()
    }
}
