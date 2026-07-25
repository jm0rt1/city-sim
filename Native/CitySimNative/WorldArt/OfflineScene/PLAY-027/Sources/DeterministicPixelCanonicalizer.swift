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
    let boundaryAssist: PixelBoundaryAssistRecord?
}

struct PixelBoundaryVoteRecord: Codable, Equatable {
    let x: Int
    let y: Int
    let channel: Int
    let prequantizedValue: Int
    let quantizedValue: Int
    let boundaryPair: [Int]
}

struct PixelBoundaryAssistRecord: Codable, Equatable {
    let vote: PixelBoundaryVoteRecord
    let effectiveSupportCount: Int
    let competingSupportAfterBoundaryReclassification: Int
    let reason: String
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
    let standardMajorityEligible: Bool
    let boundaryAssistEligible: Bool
    let boundaryVotes: [PixelBoundaryVoteRecord]
    let competingSupportAfterBoundaryReclassification: Int?
    let eligibilityReason: String
}

struct PixelCanonicalizationResult: Equatable {
    let rgba: [UInt8]
    let mutations: [PixelCanonicalizationMutation]
    let evaluations: [PixelCanonicalizationEvaluation]
}

func canonicalizeIsolatedQuantizedRGBOutliers(
    sourceRGBA: [UInt8],
    prequantizedRGBA: [UInt8]? = nil,
    width: Int,
    height: Int,
    contract: SamplingPostQuantizationCanonicalizerDescriptor,
    traceCoordinates: [[Int]] = []
) throws -> PixelCanonicalizationResult {
    let isV2 =
        contract.algorithm
            == "opaque-isolated-one-quantum-majority-3x3"
        && contract.version == 2
        && contract.boundaryAssist == nil
    let isV3 =
        contract.algorithm
            == "opaque-isolated-one-quantum-majority-3x3"
        && contract.version == 3
        && contract.boundaryAssist != nil
    guard
        width >= contract.neighborhoodSize,
        height >= contract.neighborhoodSize,
        sourceRGBA.count == width * height * 4,
        isV2 || isV3,
        contract.quantizationQuantum == 32,
        contract.neighborhoodSize == 3,
        contract.majorityThreshold == 7,
        contract.requiresFullyOpaqueNeighborhood,
        contract.immutableSourceBuffer,
        contract.requiresChromaFreeNeighborhood,
        contract.channels == "rgb-only",
        contract.preservesAlpha,
        contract.preservesChroma,
        !isV3 || prequantizedRGBA?.count == sourceRGBA.count
    else {
        throw DeterministicPixelCanonicalizerError.invalid(
            "post-quantization canonicalizer contract mismatch"
        )
    }
    if isV3 {
        guard
            let assist = contract.boundaryAssist,
            assist.algorithm
                == "immutable-prequantized-one-value-boundary-6-plus-1",
            assist.version == 1,
            assist.baseQuantizedMajorityCount == 6,
            assist.requiredBoundaryVoteCount == 1,
            assist.effectiveSupportCount == 7,
            assist.maximumCompetingSupportAfterBoundaryReclassification
                == 2,
            assist.quantizerStep == 32,
            assist.quantizerMidpointOffset == 8,
            assist.boundaryBandWidthValues == 1,
            assist.requiresSameChannelEvidence,
            assist.immutablePrequantizedBuffer,
            assist.recordsBoundaryVoteReason
        else {
            throw DeterministicPixelCanonicalizerError.invalid(
                "boundary-assist contract mismatch"
            )
        }
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
                                mutated: false,
                                standardMajorityEligible: false,
                                boundaryAssistEligible: false,
                                boundaryVotes: [],
                                competingSupportAfterBoundaryReclassification:
                                    nil,
                                eligibilityReason:
                                    allOpaque
                                    ? "exact-chroma-neighborhood"
                                    : "non-opaque-neighborhood"
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
                let standardEligible =
                    majorityCount >= contract.majorityThreshold
                    && exactQuantumDifference
                let boundaryEvaluation =
                    try evaluateBoundaryAssist(
                        quantizedSource: immutableSource,
                        prequantizedSource: prequantizedRGBA,
                        neighborhoodIndices: neighborhoodIndices,
                        width: width,
                        channel: channel,
                        centerValue: Int(centerValue),
                        majorityValue: majorityValue,
                        majorityCount: majorityCount,
                        exactQuantumDifference:
                            exactQuantumDifference,
                        contract: contract
                    )
                let eligible =
                    standardEligible
                    || boundaryEvaluation.eligible
                let eligibilityReason: String = {
                    if boundaryEvaluation.eligible {
                        return "boundary-assisted-6-plus-1"
                    }
                    if standardEligible {
                        return "standard-majority-\(majorityCount)"
                    }
                    return boundaryEvaluation.rejectionReason
                }()
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
                            mutated: eligible,
                            standardMajorityEligible:
                                standardEligible,
                            boundaryAssistEligible:
                                boundaryEvaluation.eligible,
                            boundaryVotes:
                                boundaryEvaluation.votes,
                            competingSupportAfterBoundaryReclassification:
                                boundaryEvaluation.competingSupport,
                            eligibilityReason: eligibilityReason
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
                        majorityValue: Int(majority.key),
                        boundaryAssist:
                            boundaryEvaluation.eligible
                            ? PixelBoundaryAssistRecord(
                                vote:
                                    boundaryEvaluation.votes[0],
                                effectiveSupportCount:
                                    boundaryEvaluation.effectiveSupport,
                                competingSupportAfterBoundaryReclassification:
                                    boundaryEvaluation.competingSupport
                                    ?? -1,
                                reason:
                                    "one immutable same-channel prequantized boundary vote raises stable support from 6 to 7"
                            )
                            : nil
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

private struct BoundaryAssistEvaluation {
    let eligible: Bool
    let votes: [PixelBoundaryVoteRecord]
    let effectiveSupport: Int
    let competingSupport: Int?
    let rejectionReason: String
}

private func quantizedBoundaryPair(
    centerValue: Int,
    majorityValue: Int,
    step: Int,
    midpointOffset: Int
) -> [Int]? {
    guard
        abs(centerValue - majorityValue) == step,
        step > 0
    else {
        return nil
    }
    let upperBin = max(centerValue, majorityValue)
    let upperBucket = (upperBin - step / 2) / step
    let boundary = upperBucket * step - midpointOffset
    guard boundary > 0, boundary <= 255 else {
        return nil
    }
    return [boundary - 1, boundary]
}

private func evaluateBoundaryAssist(
    quantizedSource: [UInt8],
    prequantizedSource: [UInt8]?,
    neighborhoodIndices: [Int],
    width: Int,
    channel: Int,
    centerValue: Int,
    majorityValue: Int?,
    majorityCount: Int,
    exactQuantumDifference: Bool,
    contract: SamplingPostQuantizationCanonicalizerDescriptor
) throws -> BoundaryAssistEvaluation {
    guard contract.version == 3 else {
        return BoundaryAssistEvaluation(
            eligible: false,
            votes: [],
            effectiveSupport: majorityCount,
            competingSupport: nil,
            rejectionReason: "standard-majority-not-reached"
        )
    }
    guard
        let assist = contract.boundaryAssist,
        let prequantizedSource,
        let majorityValue,
        exactQuantumDifference,
        let boundaryPair = quantizedBoundaryPair(
            centerValue: centerValue,
            majorityValue: majorityValue,
            step: assist.quantizerStep,
            midpointOffset: assist.quantizerMidpointOffset
        )
    else {
        return BoundaryAssistEvaluation(
            eligible: false,
            votes: [],
            effectiveSupport: majorityCount,
            competingSupport: nil,
            rejectionReason: "no-adjacent-bin-boundary"
        )
    }
    let chroma = [UInt8(255), 0, 255, 255]
    var prequantizedOpaque = true
    var prequantizedChromaFree = true
    var votes: [PixelBoundaryVoteRecord] = []
    for index in neighborhoodIndices {
        if prequantizedSource[index + 3] != 255 {
            prequantizedOpaque = false
        }
        if Array(prequantizedSource[index..<(index + 4)]) == chroma {
            prequantizedChromaFree = false
        }
        let prequantizedValue =
            Int(prequantizedSource[index + channel])
        let quantizedValue =
            Int(quantizedSource[index + channel])
        let frozenQuantizedValue = min(
            255,
            (
                (prequantizedValue + assist.quantizerMidpointOffset)
                    / assist.quantizerStep
            ) * assist.quantizerStep + assist.quantizerStep / 2
        )
        if
            boundaryPair.contains(prequantizedValue),
            frozenQuantizedValue == quantizedValue,
            quantizedValue == centerValue
                || quantizedValue == majorityValue
        {
            let pixel = index / 4
            votes.append(
                PixelBoundaryVoteRecord(
                    x: pixel % width,
                    y: pixel / width,
                    channel: channel,
                    prequantizedValue: prequantizedValue,
                    quantizedValue: quantizedValue,
                    boundaryPair: boundaryPair
                )
            )
        }
    }
    guard prequantizedOpaque, prequantizedChromaFree else {
        return BoundaryAssistEvaluation(
            eligible: false,
            votes: votes,
            effectiveSupport: majorityCount,
            competingSupport: nil,
            rejectionReason:
                prequantizedOpaque
                ? "prequantized-exact-chroma-neighborhood"
                : "prequantized-non-opaque-neighborhood"
        )
    }

    let nonMajorityVotes = votes.filter {
        $0.quantizedValue != majorityValue
    }
    var reclassifiedCounts: [UInt8: Int] = [:]
    for index in neighborhoodIndices {
        reclassifiedCounts[
            quantizedSource[index + channel],
            default: 0
        ] += 1
    }
    if let vote = nonMajorityVotes.first {
        let value = UInt8(vote.quantizedValue)
        reclassifiedCounts[value, default: 0] -= 1
    }
    let competingSupport =
        reclassifiedCounts
        .filter { Int($0.key) != majorityValue }
        .map(\.value)
        .max() ?? 0
    let effectiveSupport = majorityCount + nonMajorityVotes.count
    let eligible = boundaryAssistEligible(
        majorityCount: majorityCount,
        boundaryVoteCount: votes.count,
        nonMajorityBoundaryVoteCount: nonMajorityVotes.count,
        effectiveSupport: effectiveSupport,
        competingSupport: competingSupport,
        contract: assist
    )
    let rejectionReason: String = {
        if majorityCount != assist.baseQuantizedMajorityCount {
            return "boundary-assist-requires-six-stable-votes"
        }
        if votes.count != assist.requiredBoundaryVoteCount {
            return votes.count > assist.requiredBoundaryVoteCount
                ? "multiple-boundary-votes"
                : "missing-boundary-vote"
        }
        if nonMajorityVotes.count
            != assist.requiredBoundaryVoteCount
        {
            return "boundary-vote-is-not-additional-support"
        }
        if effectiveSupport != assist.effectiveSupportCount {
            return "effective-support-is-not-seven"
        }
        if
            competingSupport
                > assist
                    .maximumCompetingSupportAfterBoundaryReclassification
        {
            return "competing-support-exceeds-two"
        }
        return "boundary-assisted-6-plus-1"
    }()
    return BoundaryAssistEvaluation(
        eligible: eligible,
        votes: votes,
        effectiveSupport: effectiveSupport,
        competingSupport: competingSupport,
        rejectionReason: rejectionReason
    )
}

func boundaryAssistEligible(
    majorityCount: Int,
    boundaryVoteCount: Int,
    nonMajorityBoundaryVoteCount: Int,
    effectiveSupport: Int,
    competingSupport: Int,
    contract: SamplingBoundaryAssistDescriptor
) -> Bool {
    majorityCount == contract.baseQuantizedMajorityCount
        && boundaryVoteCount == contract.requiredBoundaryVoteCount
        && nonMajorityBoundaryVoteCount
            == contract.requiredBoundaryVoteCount
        && effectiveSupport == contract.effectiveSupportCount
        && competingSupport
            <= contract
                .maximumCompetingSupportAfterBoundaryReclassification
}
