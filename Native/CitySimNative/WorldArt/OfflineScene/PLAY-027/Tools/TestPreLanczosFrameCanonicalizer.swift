import Foundation

enum PreLanczosFrameCanonicalizerTestError:
    Error,
    CustomStringConvertible
{
    case failed(String)

    var description: String {
        switch self {
        case let .failed(message):
            return message
        }
    }
}

@main
enum TestPreLanczosFrameCanonicalizerMain {
    static let contract =
        SamplingPreLanczosCanonicalizerDescriptor(
            algorithm:
                "rgb-step32-midpoint8-preserve-alpha-chroma-v1",
            version: 1,
            quantizationStep: 32,
            midpointOffset: 8,
            chromaBypassRGBA: [255, 0, 255, 255],
            channels: "rgb-only",
            opaquePixelPolicy: "quantize-each-rgb-channel",
            transparentPixelPolicy: "zero-hidden-rgb",
            partialAlphaPolicy: "reject",
            preservesAlpha: true,
            preservesChroma: true,
            immutableSourceBuffer: true,
            crossRunState: "none"
        )

    static func main() throws {
        let source: [UInt8] = [
            22, 86, 150, 255,
            255, 0, 255, 255,
            201, 111, 73, 0,
            208, 80, 48, 255,
        ]
        let result = try canonicalizePreLanczosFrameRGBA(
            sourceRGBA: source,
            width: 2,
            height: 2,
            contract: contract
        )
        guard
            result.rgba == [
                16, 80, 144, 255,
                255, 0, 255, 255,
                0, 0, 0, 0,
                208, 80, 48, 255,
            ],
            result.rgba[3] == source[3],
            result.rgba[7] == source[7],
            result.rgba[11] == source[11],
            result.rgba[15] == source[15],
            result.chromaBypassPixelCount == 1,
            result.opaquePixelCount == 2,
            result.transparentPixelCount == 1
        else {
            throw PreLanczosFrameCanonicalizerTestError.failed(
                "frozen transform, alpha, or chroma behavior drifted"
            )
        }

        let runA = try canonicalizePreLanczosFrameRGBA(
            sourceRGBA: [22, 86, 150, 255],
            width: 1,
            height: 1,
            contract: contract
        )
        let runB = try canonicalizePreLanczosFrameRGBA(
            sourceRGBA: [23, 87, 151, 255],
            width: 1,
            height: 1,
            contract: contract
        )
        guard runA.rgba == runB.rgba else {
            throw PreLanczosFrameCanonicalizerTestError.failed(
                "same-bucket one-value perturbations did not converge"
            )
        }

        let boundaryA = try canonicalizePreLanczosFrameRGBA(
            sourceRGBA: [23, 87, 151, 255],
            width: 1,
            height: 1,
            contract: contract
        )
        let boundaryB = try canonicalizePreLanczosFrameRGBA(
            sourceRGBA: [24, 88, 152, 255],
            width: 1,
            height: 1,
            contract: contract
        )
        guard boundaryA.rgba != boundaryB.rgba else {
            throw PreLanczosFrameCanonicalizerTestError.failed(
                "quantization boundary was silently broadened"
            )
        }

        do {
            _ = try canonicalizePreLanczosFrameRGBA(
                sourceRGBA: [16, 48, 80, 254],
                width: 1,
                height: 1,
                contract: contract
            )
            throw PreLanczosFrameCanonicalizerTestError.failed(
                "partial alpha was not rejected"
            )
        } catch is PreLanczosFrameCanonicalizerError {
            // Expected.
        }

        do {
            _ = try canonicalizePreLanczosFrameRGBA(
                sourceRGBA: [16, 48, 80, 255],
                width: 2,
                height: 1,
                contract: contract
            )
            throw PreLanczosFrameCanonicalizerTestError.failed(
                "dimension mismatch was not rejected"
            )
        } catch is PreLanczosFrameCanonicalizerError {
            // Expected.
        }

        let invalidContract =
            SamplingPreLanczosCanonicalizerDescriptor(
                algorithm: contract.algorithm,
                version: contract.version,
                quantizationStep: 16,
                midpointOffset: contract.midpointOffset,
                chromaBypassRGBA: contract.chromaBypassRGBA,
                channels: contract.channels,
                opaquePixelPolicy: contract.opaquePixelPolicy,
                transparentPixelPolicy:
                    contract.transparentPixelPolicy,
                partialAlphaPolicy: contract.partialAlphaPolicy,
                preservesAlpha: contract.preservesAlpha,
                preservesChroma: contract.preservesChroma,
                immutableSourceBuffer: contract.immutableSourceBuffer,
                crossRunState: contract.crossRunState
            )
        do {
            _ = try canonicalizePreLanczosFrameRGBA(
                sourceRGBA: [16, 48, 80, 255],
                width: 1,
                height: 1,
                contract: invalidContract
            )
            throw PreLanczosFrameCanonicalizerTestError.failed(
                "contract drift was not rejected"
            )
        } catch is PreLanczosFrameCanonicalizerError {
            // Expected.
        }

        print(
            "PASS immutable pre-Lanczos frame canonicalizer; "
                + "alpha/chroma preserved, hidden RGB zeroed, "
                + "partial alpha and contract drift rejected"
        )
    }
}
