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
        preservesChroma: true
    )
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
                    majorityValue: 48
                )
            ],
            "isolated mutation record mismatch"
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

        print("PASS 8 deterministic pixel canonicalizer tests")
    }
}
