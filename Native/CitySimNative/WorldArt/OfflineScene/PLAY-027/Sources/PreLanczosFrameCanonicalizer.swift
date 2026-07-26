import Foundation

enum PreLanczosFrameCanonicalizerError:
    Error,
    CustomStringConvertible
{
    case invalid(String)

    var description: String {
        switch self {
        case let .invalid(message):
            return message
        }
    }
}

struct PreLanczosFrameCanonicalizationResult: Equatable {
    let rgba: [UInt8]
    let changedChannelCount: Int
    let changedPixelCount: Int
    let opaquePixelCount: Int
    let transparentPixelCount: Int
    let chromaBypassPixelCount: Int
}

private func validatePreLanczosFrameContract(
    _ contract: SamplingPreLanczosCanonicalizerDescriptor
) throws {
    guard
        contract.algorithm
            == "rgb-step32-midpoint8-preserve-alpha-chroma-v1",
        contract.version == 1,
        contract.quantizationStep == 32,
        contract.midpointOffset == 8,
        contract.chromaBypassRGBA == [255, 0, 255, 255],
        contract.channels == "rgb-only",
        contract.opaquePixelPolicy == "quantize-each-rgb-channel",
        contract.transparentPixelPolicy == "zero-hidden-rgb",
        contract.partialAlphaPolicy == "reject",
        contract.preservesAlpha,
        contract.preservesChroma,
        contract.immutableSourceBuffer,
        contract.crossRunState == "none"
    else {
        throw PreLanczosFrameCanonicalizerError.invalid(
            "pre-Lanczos canonicalizer contract mismatch"
        )
    }
}

func canonicalizePreLanczosFrameRGBA(
    sourceRGBA: [UInt8],
    width: Int,
    height: Int,
    contract: SamplingPreLanczosCanonicalizerDescriptor
) throws -> PreLanczosFrameCanonicalizationResult {
    try validatePreLanczosFrameContract(contract)
    guard
        width > 0,
        height > 0,
        sourceRGBA.count == width * height * 4
    else {
        throw PreLanczosFrameCanonicalizerError.invalid(
            "pre-Lanczos canonicalizer requires exact RGBA8 dimensions"
        )
    }

    let immutableSource = sourceRGBA
    var output = immutableSource
    let chroma = contract.chromaBypassRGBA.map(UInt8.init)
    var changedChannels = 0
    var changedPixels = 0
    var opaquePixels = 0
    var transparentPixels = 0
    var chromaPixels = 0

    for pixel in stride(from: 0, to: immutableSource.count, by: 4) {
        let sourcePixel = Array(immutableSource[pixel..<(pixel + 4)])
        if sourcePixel == chroma {
            chromaPixels += 1
            continue
        }

        let alpha = immutableSource[pixel + 3]
        switch alpha {
        case 0:
            transparentPixels += 1
            var pixelChanged = false
            for channel in 0..<3 where output[pixel + channel] != 0 {
                output[pixel + channel] = 0
                changedChannels += 1
                pixelChanged = true
            }
            if pixelChanged {
                changedPixels += 1
            }
        case 255:
            opaquePixels += 1
            var pixelChanged = false
            for channel in 0..<3 {
                let value = Int(immutableSource[pixel + channel])
                let quantized = min(
                    255,
                    ((value + contract.midpointOffset)
                        / contract.quantizationStep)
                        * contract.quantizationStep
                        + contract.quantizationStep / 2
                )
                let replacement = UInt8(quantized)
                if replacement != immutableSource[pixel + channel] {
                    output[pixel + channel] = replacement
                    changedChannels += 1
                    pixelChanged = true
                }
            }
            if pixelChanged {
                changedPixels += 1
            }
        default:
            throw PreLanczosFrameCanonicalizerError.invalid(
                "pre-Lanczos canonicalizer rejects partial alpha"
            )
        }
    }

    guard
        stride(from: 3, to: immutableSource.count, by: 4).allSatisfy({
            immutableSource[$0] == output[$0]
        })
    else {
        throw PreLanczosFrameCanonicalizerError.invalid(
            "pre-Lanczos canonicalizer changed alpha"
        )
    }
    return PreLanczosFrameCanonicalizationResult(
        rgba: output,
        changedChannelCount: changedChannels,
        changedPixelCount: changedPixels,
        opaquePixelCount: opaquePixels,
        transparentPixelCount: transparentPixels,
        chromaBypassPixelCount: chromaPixels
    )
}
