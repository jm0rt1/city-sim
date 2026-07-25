import Foundation

enum DeterministicPixelCanonicalizerError:
    Error, CustomStringConvertible
{
    case invalid(String)

    var description: String {
        switch self {
        case let .invalid(message):
            return message
        }
    }
}

struct PixelCanonicalizationMutation: Codable, Equatable {
    let x: Int
    let y: Int
    let channel: Int
    let originalValue: Int
    let majorityValue: Int
}

struct PixelCanonicalizationEvaluation: Codable, Equatable {
    let x: Int
    let y: Int
    let channel: Int
    let centerValue: Int
    let majorityValue: Int?
    let majorityCount: Int
    let fullyOpaqueNeighborhood: Bool
    let chromaFreeNeighborhood: Bool
    let exactQuantumDifference: Bool
    let eligible: Bool
    let mutated: Bool
}

struct PixelCanonicalizationResult: Equatable {
    let rgba: [UInt8]
    let mutations: [PixelCanonicalizationMutation]
    let evaluations: [PixelCanonicalizationEvaluation]
}

func canonicalizeIsolatedQuantizedRGBOutliers(
    sourceRGBA: [UInt8],
    width: Int,
    height: Int,
    contract: SamplingPostQuantizationCanonicalizerDescriptor,
    traceCoordinates: [[Int]] = []
) throws -> PixelCanonicalizationResult {
    guard
        width >= contract.neighborhoodSize,
        height >= contract.neighborhoodSize,
        sourceRGBA.count == width * height * 4,
        contract.algorithm
            == "opaque-isolated-one-quantum-majority-3x3",
        contract.version == 2,
        contract.quantizationQuantum == 32,
        contract.neighborhoodSize == 3,
        contract.majorityThreshold == 7,
        contract.requiresFullyOpaqueNeighborhood,
        contract.immutableSourceBuffer,
        contract.requiresChromaFreeNeighborhood,
        contract.channels == "rgb-only",
        contract.preservesAlpha,
        contract.preservesChroma
    else {
        throw DeterministicPixelCanonicalizerError.invalid(
            "post-quantization canonicalizer contract mismatch"
        )
    }

    // Every decision reads only this immutable value. Mutations are written
    // to a separate buffer, so scan order cannot create a later majority.
    let immutableSource = sourceRGBA
    var output = sourceRGBA
    var mutations: [PixelCanonicalizationMutation] = []
    var evaluations: [PixelCanonicalizationEvaluation] = []
    let chroma = [UInt8(255), 0, 255, 255]
    let traceKeys = Set(
        traceCoordinates.compactMap { coordinate in
            coordinate.count == 2
                ? "\(coordinate[0]),\(coordinate[1])"
                : nil
        }
    )

    for y in 1..<(height - 1) {
        for x in 1..<(width - 1) {
            let center = (y * width + x) * 4
            let shouldTrace = traceKeys.contains("\(x),\(y)")
            var neighborhoodIndices: [Int] = []
            var allOpaque = true
            var containsChroma = false
            for neighborY in (y - 1)...(y + 1) {
                for neighborX in (x - 1)...(x + 1) {
                    let index = (neighborY * width + neighborX) * 4
                    neighborhoodIndices.append(index)
                    if immutableSource[index + 3] != 255 {
                        allOpaque = false
                    }
                    if Array(
                        immutableSource[index..<(index + 4)]
                    ) == chroma {
                        containsChroma = true
                    }
                }
            }
            guard allOpaque, !containsChroma else {
                if shouldTrace {
                    for channel in 0..<3 {
                        evaluations.append(
                            PixelCanonicalizationEvaluation(
                                x: x,
                                y: y,
                                channel: channel,
                                centerValue:
                                    Int(immutableSource[center + channel]),
                                majorityValue: nil,
                                majorityCount: 0,
                                fullyOpaqueNeighborhood: allOpaque,
                                chromaFreeNeighborhood: !containsChroma,
                                exactQuantumDifference: false,
                                eligible: false,
                                mutated: false
                            )
                        )
                    }
                }
                continue
            }
            for channel in 0..<3 {
                var counts: [UInt8: Int] = [:]
                for index in neighborhoodIndices {
                    counts[immutableSource[index + channel], default: 0] += 1
                }
                let centerValue = immutableSource[center + channel]
                let majority = counts.max(by: {
                    if $0.value == $1.value {
                        return $0.key > $1.key
                    }
                    return $0.value < $1.value
                })
                let majorityValue = majority.map { Int($0.key) }
                let majorityCount = majority?.value ?? 0
                let exactQuantumDifference =
                    majorityValue.map {
                        abs(Int(centerValue) - $0)
                            == contract.quantizationQuantum
                    } ?? false
                let eligible =
                    majorityCount >= contract.majorityThreshold
                    && exactQuantumDifference
                if shouldTrace {
                    evaluations.append(
                        PixelCanonicalizationEvaluation(
                            x: x,
                            y: y,
                            channel: channel,
                            centerValue: Int(centerValue),
                            majorityValue: majorityValue,
                            majorityCount: majorityCount,
                            fullyOpaqueNeighborhood: true,
                            chromaFreeNeighborhood: true,
                            exactQuantumDifference:
                                exactQuantumDifference,
                            eligible: eligible,
                            mutated: eligible
                        )
                    )
                }
                guard eligible, let majority else {
                    continue
                }
                output[center + channel] = majority.key
                mutations.append(
                    PixelCanonicalizationMutation(
                        x: x,
                        y: y,
                        channel: channel,
                        originalValue: Int(centerValue),
                        majorityValue: Int(majority.key)
                    )
                )
            }
        }
    }
    return PixelCanonicalizationResult(
        rgba: output,
        mutations: mutations,
        evaluations: evaluations
    )
}
