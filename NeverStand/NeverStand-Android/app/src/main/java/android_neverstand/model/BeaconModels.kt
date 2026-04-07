package android_neverstand.model

import com.google.gson.annotations.SerializedName

data class BeaconRequest(
    val username: String,
    val password: String,
    val beacon: BeaconData
)

data class BeaconData(
    @SerializedName("UUID") val uuid: String,
    @SerializedName("MAJOR") val major: String,
    @SerializedName("MINOR") val minor: String,
    @SerializedName("POWER") val power: String
)

data class BeaconResponse(
    val d: BeaconInfo
)

data class BeaconInfo(
    @SerializedName("BID") val bid: String,
    @SerializedName("SID") val sid: String,
    @SerializedName("LID") val lid: String,
    @SerializedName("POSINO") val posino: String,
    @SerializedName("POSITION") val position: String,
    @SerializedName("STATION_ID") val stationID: String,
    @SerializedName("STATION_NAME") val stationName: String
)
