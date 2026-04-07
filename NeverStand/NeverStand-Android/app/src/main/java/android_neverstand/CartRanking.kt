package android_neverstand

import android_neverstand.model.CarWeightData
import android_neverstand.model.RankedCarWeight

class CartRanking {
    fun rankCarWeights(carWeights: List<CarWeightData>): List<RankedCarWeight> {
        val rankedResults = mutableListOf<RankedCarWeight>()
        
        for (weight in carWeights) {
            val cartValues = listOf(
                weight.cart1L.toIntOrNull() ?: 0,
                weight.cart2L.toIntOrNull() ?: 0,
                weight.cart3L.toIntOrNull() ?: 0,
                weight.cart4L.toIntOrNull() ?: 0,
                weight.cart5L.toIntOrNull() ?: 0,
                weight.cart6L.toIntOrNull() ?: 0
            )
            
            // Sort from lowest to highest and preserve original indices
            val sortedCarts = cartValues.mapIndexed { index, value -> index to value }
                .sortedBy { it.second }
                
            // Generate rankings (starting from 1)
            val rankings = mutableMapOf<Int, Int>()
            sortedCarts.forEachIndexed { rank, (index, _) ->
                rankings[index + 1] = rank + 1
            }
            
            // Handle ties
            var previousValue: Int? = null
            sortedCarts.forEachIndexed { rank, (index, value) ->
                if (previousValue != null && previousValue == value) {
                    rankings[index + 1] = rankings[sortedCarts[rank - 1].first + 1] ?: (rank + 1)
                }
                previousValue = value
            }
            
            var selectedCar = 0
            
            // Check for rank 1 cars
            val rank1Carts = rankings.filter { it.value == 1 }.map { it.key to cartValues[it.key - 1] }
            val firstNonZero = rank1Carts.firstOrNull { it.second > 0 }
            if (firstNonZero != null) {
                val rank1NonZeroCarts = rank1Carts.filter { it.second == firstNonZero.second && it.second > 0 }
                selectedCar = rank1NonZeroCarts.map { it.first }.randomOrNull() ?: rank1Carts[0].first
            } else {
                val rank2Carts = rankings.filter { it.value == 2 }.map { it.key to cartValues[it.key - 1] }
                val secondNonZero = rank2Carts.firstOrNull { it.second > 0 }
                if (secondNonZero != null) {
                    val rank2NonZeroCarts = rank2Carts.filter { it.second == secondNonZero.second && it.second > 0 }
                    selectedCar = rank2NonZeroCarts.map { it.first }.randomOrNull() ?: rank2Carts[0].first
                } else {
                    val rank3Carts = rankings.filter { it.value == 3 }.map { it.key to cartValues[it.key - 1] }
                    val thirdNonZero = rank3Carts.firstOrNull { it.second > 0 }
                    if (thirdNonZero != null) {
                        val rank3NonZeroCarts = rank3Carts.filter { it.second == thirdNonZero.second && it.second > 0 }
                        selectedCar = rank3NonZeroCarts.map { it.first }.randomOrNull() ?: rank3Carts[0].first
                    } else {
                        selectedCar = (1..6).random()
                    }
                }
            }
            
            rankedResults.add(RankedCarWeight(weight, rankings, selectedCar))
        }
        return rankedResults
    }
}
