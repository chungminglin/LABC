package android_neverstand.model

import com.google.gson.annotations.SerializedName

data class CarWeightData(
    @SerializedName("TrainNumber") val trainNumber: String,
    @SerializedName("CN1") val cn1: String,
    @SerializedName("CID") val cid: String,
    @SerializedName("StationID") val stationID: String,
    @SerializedName("Cart1L") val cart1L: String,
    @SerializedName("Cart2L") val cart2L: String,
    @SerializedName("Cart3L") val cart3L: String,
    @SerializedName("Cart4L") val cart4L: String,
    @SerializedName("Cart5L") val cart5L: String,
    @SerializedName("Cart6L") val cart6L: String,
    val utime: String
)

data class RankedCarWeight(
    val originalData: CarWeightData,
    val rankedCarts: Map<Int, Int>, // Key is cart index (1-6), value is rank (1-6)
    val selectedCar: Int        // Selected car (1-6)
)
