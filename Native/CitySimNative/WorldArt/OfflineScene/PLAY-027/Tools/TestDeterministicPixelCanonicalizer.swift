import Foundation

enum CanonicalizerTestError: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case let .failed(message):
            return message
        }
    }
}

func testContract() -> SamplingPostQuantizationCanonicalizerDescriptor {
    SamplingPostQuantizationCanonicalizerDescriptor(
        algorithm: "opaque-isolated-one-quantum-majority-3x3",
        version: 2,
        quantizationQuantum: 32,
        neighborhoodSize: 3,
        majorityThreshold: 7,
        requiresFullyOpaqueNeighborhood: true,
        immutableSourceBuffer: true,
        requiresChromaFreeNeighborhood: true,
        channels: "rgb-only",
        preservesAlpha: true,
        preservesChroma: true,
        boundaryAssist: nil
    )
}

func testV3Contract() -> SamplingPostQuantizationCanonicalizerDescriptor {
    SamplingPostQuantizationCanonicalizerDescriptor(
        algorithm: "opaque-isolated-one-quantum-majority-3x3",
        version: 3,
        quantizationQuantum: 32,
        neighborhoodSize: 3,
        majorityThreshold: 7,
        requiresFullyOpaqueNeighborhood: true,
        immutableSourceBuffer: true,
        requiresChromaFreeNeighborhood: true,
        channels: "rgb-only",
        preservesAlpha: true,
        preservesChroma: true,
        boundaryAssist: SamplingBoundaryAssistDescriptor(
            algorithm:
                "immutable-prequantized-one-value-boundary-6-plus-1",
            version: 1,
            baseQuantizedMajorityCount: 6,
            requiredBoundaryVoteCount: 1,
            effectiveSupportCount: 7,
            maximumCompetingSupportAfterBoundaryReclassification: 2,
            quantizerStep: 32,
            quantizerMidpointOffset: 8,
            boundaryBandWidthValues: 1,
            requiresSameChannelEvidence: true,
            immutablePrequantizedBuffer: true,
            recordsBoundaryVoteReason: true
        )
    )
}

func quantizeTestImage(_ prequantized: [UInt8]) -> [UInt8] {
    var result = prequantized
    for pixel in stride(from: 0, to: result.count, by: 4) {
        if Array(result[pixel..<(pixel + 4)]) == [255, 0, 255, 255] {
            continue
        }
        for channel in 0..<3 {
            let value = Int(result[pixel + channel])
            result[pixel + channel] = UInt8(
                min(255, ((value + 8) / 32) * 32 + 16)
            )
        }
    }
    return result
}

func makeBoundaryFixture(
    boundaryGreen: UInt8,
    secondBoundaryGreen: UInt8? = nil
) -> [UInt8] {
    var image = makeTestImage(rgba: [4, 32, 2, 255])
    let center = testPixelIndex(x: 2, y: 2)
    let stableMinority = testPixelIndex(x: 1, y: 2)
    let boundary = testPixelIndex(x: 3, y: 2)
    image[center + 1] = 22
    image[stableMinority + 1] = 22
    image[boundary + 1] = boundaryGreen
    if let secondBoundaryGreen {
        image[stableMinority + 1] = secondBoundaryGreen
    }
    return image
}

func makeTestImage(
    width: Int = 5,
    height: Int = 5,
    rgba: [UInt8] = [16, 48, 16, 255]
) -> [UInt8] {
    Array(repeating: rgba, count: width * height).flatMap { $0 }
}

func testPixelIndex(
    x: Int,
    y: Int,
    width: Int = 5
) -> Int {
    (y * width + x) * 4
}

func requireTest(
    _ condition: @autoclosure () -> Bool,
    _ message: String
) throws {
    if !condition() {
        throw CanonicalizerTestError.failed(message)
    }
}

@main
enum TestDeterministicPixelCanonicalizerMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let contract = testContract()

        var isolated = makeTestImage()
        let isolatedIndex = testPixelIndex(x: 2, y: 2)
        isolated[isolatedIndex + 1] = 16
        let repaired = try canonicalizeIsolatedQuantizedRGBOutliers(
            sourceRGBA: isolated,
            width: 5,
            height: 5,
            contract: contract
        )
        try requireTest(
            repaired.rgba[isolatedIndex + 1] == 48,
            "isolated one-quantum green outlier was not repaired"
        )
        try requireTest(
            repaired.mutations == [
                PixelCanonicalizationMutation(
                    x: 2,
                    y: 2,
                    channel: 1,
                    originalValue: 16,
                    majorityValue: 48,
                    boundaryAssist: nil
                )
            ],
            "isolated mutation record mismatch"
        )
        let tracedRepair = try canonicalizeIsolatedQuantizedRGBOutliers(
            sourceRGBA: isolated,
            width: 5,
            height: 5,
            contract: contract,
            traceCoordinates: [[2, 2]]
        )
        try requireTest(
            tracedRepair.rgba == repaired.rgba
                && tracedRepair.mutations == repaired.mutations,
            "diagnostic trace must not change repair pixels or mutations"
        )
        try requireTest(
            tracedRepair.evaluations.count == 3
                && tracedRepair.evaluations[1].eligible
                && tracedRepair.evaluations[1].mutated,
            "diagnostic trace did not record target eligibility and mutation"
        )

        var weakMajority = isolated
        for point in [(1, 1), (2, 1)] {
            weakMajority[testPixelIndex(x: point.0, y: point.1) + 1] = 16
        }
        let weakResult = try canonicalizeIsolatedQuantizedRGBOutliers(
            sourceRGBA: weakMajority,
            width: 5,
            height: 5,
            contract: contract
        )
        try requireTest(
            weakResult.rgba[isolatedIndex + 1] == 16,
            "six-of-nine neighborhood must not repair"
        )

        var twoQuantum = makeTestImage()
        twoQuantum[isolatedIndex + 1] = 112
        let twoQuantumResult =
            try canonicalizeIsolatedQuantizedRGBOutliers(
                sourceRGBA: twoQuantum,
                width: 5,
                height: 5,
                contract: contract
            )
        try requireTest(
            twoQuantumResult.rgba[isolatedIndex + 1] == 112,
            "two-quantum outlier must not repair"
        )

        var transparentNeighbor = isolated
        transparentNeighbor[testPixelIndex(x: 1, y: 1) + 3] = 254
        let transparentResult =
            try canonicalizeIsolatedQuantizedRGBOutliers(
                sourceRGBA: transparentNeighbor,
                width: 5,
                height: 5,
                contract: contract
            )
        try requireTest(
            transparentResult.rgba[isolatedIndex + 1] == 16,
            "non-opaque neighborhood must not repair"
        )

        let exactChroma = makeTestImage(rgba: [255, 0, 255, 255])
        let exactChromaResult =
            try canonicalizeIsolatedQuantizedRGBOutliers(
                sourceRGBA: exactChroma,
                width: 5,
                height: 5,
                contract: contract
            )
        try requireTest(
            exactChromaResult.rgba == exactChroma
                && exactChromaResult.mutations.isEmpty,
            "exact chroma pixels must remain byte-identical"
        )

        var chromaEdge = makeTestImage()
        chromaEdge[isolatedIndex + 1] = 16
        let chromaNeighbor = testPixelIndex(x: 1, y: 1)
        chromaEdge.replaceSubrange(
            chromaNeighbor..<(chromaNeighbor + 4),
            with: [255, 0, 255, 255]
        )
        let chromaEdgeResult =
            try canonicalizeIsolatedQuantizedRGBOutliers(
                sourceRGBA: chromaEdge,
                width: 5,
                height: 5,
                contract: contract
            )
        try requireTest(
            chromaEdgeResult.rgba[isolatedIndex + 1] == 16
                && chromaEdgeResult.mutations.isEmpty,
            "any exact-chroma neighbor must suppress the repair"
        )

        var immutableCascade = makeTestImage(width: 5, height: 3)
        let firstOutlier = testPixelIndex(x: 2, y: 1)
        let secondOutlier = testPixelIndex(x: 3, y: 1)
        let outsideFirstNeighborhood = testPixelIndex(x: 4, y: 0)
        immutableCascade[firstOutlier + 1] = 16
        immutableCascade[secondOutlier + 1] = 16
        immutableCascade[outsideFirstNeighborhood + 1] = 16
        let immutableResult =
            try canonicalizeIsolatedQuantizedRGBOutliers(
                sourceRGBA: immutableCascade,
                width: 5,
                height: 3,
                contract: contract
            )
        try requireTest(
            immutableResult.rgba[firstOutlier + 1] == 48
                && immutableResult.rgba[secondOutlier + 1] == 16,
            "repair decisions must not cascade from earlier mutations"
        )

        var channelIsolation = makeTestImage()
        channelIsolation[isolatedIndex] = 48
        channelIsolation[isolatedIndex + 1] = 16
        channelIsolation[isolatedIndex + 2] = 48
        let isolatedResult =
            try canonicalizeIsolatedQuantizedRGBOutliers(
                sourceRGBA: channelIsolation,
                width: 5,
                height: 5,
                contract: contract
            )
        try requireTest(
            Array(isolatedResult.rgba[
                isolatedIndex..<(isolatedIndex + 4)
            ]) == [16, 48, 16, 255],
            "RGB-only repair or alpha preservation failed"
        )

        let v3Contract = testV3Contract()
        let retained23 = makeBoundaryFixture(boundaryGreen: 23)
        let retained24 = makeBoundaryFixture(boundaryGreen: 24)
        let retained23Result =
            try canonicalizeIsolatedQuantizedRGBOutliers(
                sourceRGBA: quantizeTestImage(retained23),
                prequantizedRGBA: retained23,
                width: 5,
                height: 5,
                contract: v3Contract,
                traceCoordinates: [[2, 2]]
            )
        let retained24Result =
            try canonicalizeIsolatedQuantizedRGBOutliers(
                sourceRGBA: quantizeTestImage(retained24),
                prequantizedRGBA: retained24,
                width: 5,
                height: 5,
                contract: v3Contract,
                traceCoordinates: [[2, 2]]
            )
        try requireTest(
            retained23Result.rgba == retained24Result.rgba
                && retained23Result.rgba[isolatedIndex + 1] == 48,
            "retained 23/24 boundary identities did not converge"
        )
        try requireTest(
            retained23Result.mutations.first {
                $0.x == 2 && $0.y == 2 && $0.channel == 1
            }?.boundaryAssist?.vote.prequantizedValue == 23,
            "boundary-assisted repair did not retain the prequantized vote"
        )
        try requireTest(
            retained24Result.evaluations.first {
                $0.x == 2 && $0.y == 2 && $0.channel == 1
            }?.boundaryVotes.first?.prequantizedValue == 24,
            "standard seven-vote sibling did not retain symmetric boundary evidence"
        )

        let ordinarySix = makeBoundaryFixture(boundaryGreen: 22)
        let ordinarySixResult =
            try canonicalizeIsolatedQuantizedRGBOutliers(
                sourceRGBA: quantizeTestImage(ordinarySix),
                prequantizedRGBA: ordinarySix,
                width: 5,
                height: 5,
                contract: v3Contract
            )
        try requireTest(
            ordinarySixResult.rgba[isolatedIndex + 1] == 16,
            "ordinary six-of-nine support must remain rejected"
        )

        let twoBoundaryVotes = makeBoundaryFixture(
            boundaryGreen: 23,
            secondBoundaryGreen: 23
        )
        let twoBoundaryResult =
            try canonicalizeIsolatedQuantizedRGBOutliers(
                sourceRGBA: quantizeTestImage(twoBoundaryVotes),
                prequantizedRGBA: twoBoundaryVotes,
                width: 5,
                height: 5,
                contract: v3Contract
            )
        try requireTest(
            twoBoundaryResult.rgba[isolatedIndex + 1] == 16,
            "two boundary votes must remain rejected"
        )

        let nonAdjacentBoundary = makeBoundaryFixture(
            boundaryGreen: 56
        )
        let nonAdjacentResult =
            try canonicalizeIsolatedQuantizedRGBOutliers(
                sourceRGBA: quantizeTestImage(nonAdjacentBoundary),
                prequantizedRGBA: nonAdjacentBoundary,
                width: 5,
                height: 5,
                contract: v3Contract
            )
        try requireTest(
            nonAdjacentResult.rgba[isolatedIndex + 1] == 16,
            "a boundary for non-adjacent bins must remain rejected"
        )

        try requireTest(
            !boundaryAssistEligible(
                majorityCount: 6,
                boundaryVoteCount: 1,
                nonMajorityBoundaryVoteCount: 1,
                effectiveSupport: 7,
                competingSupport: 3,
                contract: v3Contract.boundaryAssist!
            ),
            "competing support above two must remain rejected"
        )

        var v3Chroma = retained23
        let v3Neighbor = testPixelIndex(x: 1, y: 1)
        v3Chroma.replaceSubrange(
            v3Neighbor..<(v3Neighbor + 4),
            with: [255, 0, 255, 255]
        )
        let v3ChromaResult =
            try canonicalizeIsolatedQuantizedRGBOutliers(
                sourceRGBA: quantizeTestImage(v3Chroma),
                prequantizedRGBA: v3Chroma,
                width: 5,
                height: 5,
                contract: v3Contract
            )
        try requireTest(
            v3ChromaResult.rgba[isolatedIndex + 1] == 16,
            "v3 exact-chroma neighborhood must suppress boundary assist"
        )

        var v3Alpha = retained23
        v3Alpha[v3Neighbor + 3] = 254
        let v3AlphaResult =
            try canonicalizeIsolatedQuantizedRGBOutliers(
                sourceRGBA: quantizeTestImage(v3Alpha),
                prequantizedRGBA: v3Alpha,
                width: 5,
                height: 5,
                contract: v3Contract
            )
        try requireTest(
            v3AlphaResult.rgba[isolatedIndex + 1] == 16,
            "v3 non-opaque neighborhood must suppress boundary assist"
        )

        let v3ImmutableResult =
            try canonicalizeIsolatedQuantizedRGBOutliers(
                sourceRGBA: immutableCascade,
                prequantizedRGBA: immutableCascade,
                width: 5,
                height: 3,
                contract: v3Contract
            )
        try requireTest(
            v3ImmutableResult.rgba[firstOutlier + 1] == 48
                && v3ImmutableResult.rgba[secondOutlier + 1] == 16,
            "v3 decisions must not cascade from earlier mutations"
        )

        let passedTests = [
            "isolated one-quantum RGB repair",
            "diagnostic trace pixel identity and eligibility",
            "six-of-nine majority rejection",
            "two-quantum rejection",
            "non-opaque-neighborhood rejection",
            "exact-chroma preservation",
            "chroma-neighbor exclusion",
            "immutable-buffer non-cascade",
            "RGB channel isolation and alpha preservation",
            "retained 23/24 boundary convergence",
            "prequantized boundary vote provenance",
            "symmetric 24-side boundary evidence",
            "ordinary six-of-nine rejection",
            "two-boundary-vote rejection",
            "non-adjacent-boundary rejection",
            "competing-support rejection",
            "v3 exact-chroma exclusion",
            "v3 alpha exclusion",
            "v3 immutable-buffer non-cascade",
        ]
        if
            let reportIndex = arguments.firstIndex(of: "--report"),
            reportIndex + 1 < arguments.count
        {
            let reportURL = URL(
                fileURLWithPath: arguments[reportIndex + 1]
            ).standardizedFileURL
            guard reportURL.path.contains("/diagnostics/") else {
                throw CanonicalizerTestError.failed(
                    "test report must remain under diagnostics"
                )
            }
            let report: [String: Any] = [
                "schema": 1,
                "task": "PLAY-027",
                "contractsTested": [
                    "play027-deterministic-4x-no-msaa-lanczos-v2",
                    "play027-deterministic-4x-no-msaa-lanczos-v3",
                ],
                "algorithm":
                    "opaque-isolated-one-quantum-majority-3x3",
                "requiresChromaFreeNeighborhood": true,
                "v3BoundaryAssistAlgorithm":
                    "immutable-prequantized-one-value-boundary-6-plus-1",
                "testCount": passedTests.count,
                "passedTests": passedTests,
                "status": "pass",
                "productionSelected": false,
            ]
            var data = try JSONSerialization.data(
                withJSONObject: report,
                options: [
                    .prettyPrinted,
                    .sortedKeys,
                    .withoutEscapingSlashes,
                ]
            )
            data.append(0x0a)
            try FileManager.default.createDirectory(
                at: reportURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: reportURL, options: .atomic)
        }
        print(
            "PASS \(passedTests.count) deterministic pixel canonicalizer tests"
        )
    }
}
