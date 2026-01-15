import Foundation

class CartRanking {
    func rankCarWeights(_ carWeights: [CarWeightData]) -> [RankedCarWeight] {
        var rankedResults: [RankedCarWeight] = []
        
        for weight in carWeights {
            // Convert cart values to integer array
            let cartValues = [
                Int(weight.cart1L) ?? 0,
                Int(weight.cart2L) ?? 0,
                Int(weight.cart3L) ?? 0,
                Int(weight.cart4L) ?? 0,
                Int(weight.cart5L) ?? 0,
                Int(weight.cart6L) ?? 0
            ]
            
            // Sort from lowest to highest and preserve original indices
            let sortedCarts = cartValues.enumerated().sorted { $0.element < $1.element }
            
            // Generate rankings (starting from 1)
            var rankings: [Int: Int] = [:]
            for (rank, (index, _)) in sortedCarts.enumerated() {
                rankings[index + 1] = rank + 1 // Index starts from 0, rank from 1
            }
            
            // Handle ties (same values get same rank)
            var previousValue: Int? = nil
            for (rank, (index, value)) in sortedCarts.enumerated() {
                if let prev = previousValue, prev == value {
                    rankings[index + 1] = rankings[sortedCarts[rank - 1].offset + 1]
                }
                previousValue = value
            }
            
            // Select the best car
            var selectedCar = 0
            
            // Check for rank 1 cars
            let rank1Carts = rankings.filter { $0.value == 1 }.map { ($0.key, cartValues[$0.key - 1]) }
            if let firstNonZero = rank1Carts.first(where: { $0.1 > 0 }) {
                // There are rank 1 cars with non-zero values
                let rank1NonZeroCarts = rank1Carts.filter { $0.1 == firstNonZero.1 && $0.1 > 0 }
                selectedCar = rank1NonZeroCarts.randomElement()?.0 ?? rank1Carts[0].0
            } else {
                // Check rank 2 cars
                let rank2Carts = rankings.filter { $0.value == 2 }.map { ($0.key, cartValues[$0.key - 1]) }
                if let secondNonZero = rank2Carts.first(where: { $0.1 > 0 }) {
                    let rank2NonZeroCarts = rank2Carts.filter { $0.1 == secondNonZero.1 && $0.1 > 0 }
                    selectedCar = rank2NonZeroCarts.randomElement()?.0 ?? rank2Carts[0].0
                } else {
                    // Check rank 3 cars
                    let rank3Carts = rankings.filter { $0.value == 3 }.map { ($0.key, cartValues[$0.key - 1]) }
                    if let thirdNonZero = rank3Carts.first(where: { $0.1 > 0 }) {
                        let rank3NonZeroCarts = rank3Carts.filter { $0.1 == thirdNonZero.1 && $0.1 > 0 }
                        selectedCar = rank3NonZeroCarts.randomElement()?.0 ?? rank3Carts[0].0
                    } else {
                        // If ranks 1-3 all have no valid cars, pick a random one
                        selectedCar = Int.random(in: 1...6)
                    }
                }
            }
            
            let rankedCarWeight = RankedCarWeight(originalData: weight, rankedCarts: rankings, selectedCar: selectedCar)
            rankedResults.append(rankedCarWeight)
        }
        
        return rankedResults
    }
}
