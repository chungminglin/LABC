package android_neverstand.api

import android_neverstand.CartRanking
import android_neverstand.model.*
import com.google.gson.Gson
import com.google.gson.reflect.TypeToken
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

class ApiService {
    private val client = OkHttpClient()
    private val gson = Gson()
    private val username = "012702318@ntnu.edu.tw"
    private val password = "LkClcVXp"
    private val cartRanking = CartRanking()

    suspend fun fetchBeaconInfo(uuid: String, major: String, minor: String): Result<BeaconInfo> = withContext(Dispatchers.IO) {
        try {
            val url = "https://ws.metro.taipei/TRTCBeaconBE/BeaconControl.asmx/GetBeaconInfo"
            val beaconRequest = BeaconRequest(
                username = username,
                password = password,
                beacon = BeaconData(uuid, major, minor, "1")
            )
            val json = gson.toJson(beaconRequest)
            val requestBody = json.toRequestBody("application/json; charset=utf-8".toMediaType())
            
            val request = Request.Builder()
                .url(url)
                .post(requestBody)
                .build()
                
            val response = client.newCall(request).execute()
            if (!response.isSuccessful) throw Exception("Unexpected code $response")
            
            val responseData = response.body?.string() ?: throw Exception("No data")
            val beaconResponse = gson.fromJson(responseData, BeaconResponse::class.java)
            Result.success(beaconResponse.d)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun fetchCarWeight(beaconStationID: String): Result<List<RankedCarWeight>> = withContext(Dispatchers.IO) {
        try {
            val url = "https://api.metro.taipei/metroapi/CarWeight.asmx"
            val soapBody = """
            <?xml version="1.0" encoding="utf-8"?>
            <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                           xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                           xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
              <soap:Body>
                <getCarWeightByInfoEx xmlns="http://tempuri.org/">
                  <userName>$username</userName>
                  <passWord>$password</passWord>
                </getCarWeightByInfoEx>
              </soap:Body>
            </soap:Envelope>
            """.trimIndent()
            
            val requestBody = soapBody.toRequestBody("text/xml; charset=utf-8".toMediaType())
            val request = Request.Builder()
                .url(url)
                .post(requestBody)
                .build()
                
            val response = client.newCall(request).execute()
            if (!response.isSuccessful) throw Exception("Unexpected code $response")
            
            val rawString = response.body?.string() ?: throw Exception("No data")
            val jsonEndIndex = rawString.indexOf("<")
            val jsonString = if (jsonEndIndex != -1) rawString.substring(0, jsonEndIndex) else rawString
            
            val listType = object : TypeToken<List<CarWeightData>>() {}.type
            val carWeights: List<CarWeightData> = gson.fromJson(jsonString, listType)
            
            val filteredData = filterRelevantStations(carWeights, beaconStationID)
            val rankedResults = cartRanking.rankCarWeights(filteredData)
            
            Result.success(rankedResults)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    private fun filterRelevantStations(carWeights: List<CarWeightData>, beaconStationID: String): List<CarWeightData> {
        val beaconPrefix = beaconStationID.takeWhile { it.isLetter() }
        val beaconNumber = beaconStationID.dropWhile { it.isLetter() }.toIntOrNull() ?: return emptyList()
        
        val prefixes = listOf("R", "BL", "B", "G", "O")
        val result = mutableListOf<CarWeightData>()
        
        for (prefix in prefixes) {
            val matchingWeights = carWeights.filter { it.stationID.startsWith(prefix) }
            if (matchingWeights.isEmpty()) continue
            
            var cid1Closest: CarWeightData? = null
            var cid2Closest: CarWeightData? = null
            
            for (weight in matchingWeights) {
                val stationNumber = weight.stationID.dropWhile { it.isLetter() }.toIntOrNull() ?: continue
                val referenceNumber = if (prefix == beaconPrefix) beaconNumber else stationNumber
                
                if (weight.cid == "1" && stationNumber < referenceNumber) {
                    val cid1StationNum = cid1Closest?.stationID?.dropWhile { it.isLetter() }?.toIntOrNull() ?: 0
                    if (cid1Closest == null || stationNumber > cid1StationNum) {
                        cid1Closest = weight
                    }
                } else if (weight.cid == "2" && stationNumber > referenceNumber) {
                    val cid2StationNum = cid2Closest?.stationID?.dropWhile { it.isLetter() }?.toIntOrNull() ?: Int.MAX_VALUE
                    if (cid2Closest == null || stationNumber < cid2StationNum) {
                        cid2Closest = weight
                    }
                }
            }
            
            if (cid1Closest != null) result.add(cid1Closest)
            if (cid2Closest != null) result.add(cid2Closest)
        }
        
        return result
    }
}
