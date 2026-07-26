import Foundation

struct StrictNonzeroAlphaChromaMetrics {
    let inputExactChromaAtNonzeroAlpha: Int
    let inputNearChromaAtNonzeroAlpha: Int
    let outputExactChromaAtNonzeroAlpha: Int
    let outputNearChromaAtNonzeroAlpha: Int
    let changedPixelCount: Int
    let changedChannelCount: Int
    let alphaMutationCount: Int
    let zeroAlphaHiddenRGBPixelCount: Int

    var json: [String: Any] {
        [
            "inputExactChromaAtNonzeroAlpha":
                inputExactChromaAtNonzeroAlpha,
            "inputNearChromaAtNonzeroAlpha":
                inputNearChromaAtNonzeroAlpha,
            "outputExactChromaAtNonzeroAlpha":
                outputExactChromaAtNonzeroAlpha,
            "outputNearChromaAtNonzeroAlpha":
                outputNearChromaAtNonzeroAlpha,
            "changedPixelCount": changedPixelCount,
            "changedChannelCount": changedChannelCount,
            "alphaMutationCount": alphaMutationCount,
            "zeroAlphaHiddenRGBPixelCount": zeroAlphaHiddenRGBPixelCount,
        ]
    }
}

enum StrictNonzeroAlphaChromaError: Error, CustomStringConvertible {
    case invalid(String)

    var description: String {
        switch self {
        case let .invalid(message):
            return message
        }
    }
}

enum StrictNonzeroAlphaChromaCanonicalizer {
    static let contractID =
        "play027-zero-nonzero-alpha-chroma-premultiplied-v1"

    private static func straight(_ channel: UInt8, alpha: UInt8) -> Int {
        guard alpha > 0 else { return 0 }
        return min(
            255,
            (Int(channel) * 255 + Int(alpha) / 2) / Int(alpha)
        )
    }

    private static func classification(
        red: UInt8,
        green: UInt8,
        blue: UInt8,
        alpha: UInt8
    ) -> (exact: Bool, near: Bool) {
        guard alpha > 0 else { return (false, false) }
        let straightRed = straight(red, alpha: alpha)
        let straightGreen = straight(green, alpha: alpha)
        let straightBlue = straight(blue, alpha: alpha)
        let exact =
            straightRed == 255
            && straightGreen == 0
            && straightBlue == 255
        let near =
            straightRed >= 180
            && straightBlue >= 150
            && straightGreen <= 110
            && straightRed + straightBlue >= straightGreen * 4
        return (exact, near)
    }

    static func canonicalize(
        _ input: [UInt8]
    ) throws -> (pixels: [UInt8], metrics: StrictNonzeroAlphaChromaMetrics) {
        guard input.count.isMultiple(of: 4) else {
            throw StrictNonzeroAlphaChromaError.invalid(
                "RGBA byte count must be divisible by four"
            )
        }
        var output = input
        var inputExact = 0
        var inputNear = 0
        var outputExact = 0
        var outputNear = 0
        var changedPixels = 0
        var changedChannels = 0
        var alphaMutations = 0
        var hiddenRGB = 0

        for offset in stride(from: 0, to: input.count, by: 4) {
            let alpha = input[offset + 3]
            if alpha == 0 {
                if
                    input[offset] != 0
                        || input[offset + 1] != 0
                        || input[offset + 2] != 0
                {
                    hiddenRGB += 1
                }
                continue
            }
            let before = classification(
                red: input[offset],
                green: input[offset + 1],
                blue: input[offset + 2],
                alpha: alpha
            )
            if before.exact { inputExact += 1 }
            if before.near { inputNear += 1 }
            guard before.near else { continue }

            let red = Int(input[offset])
            let green = Int(input[offset + 1])
            let blue = Int(input[offset + 2])
            let spill = max(0, min(red, blue) - green)
            var repairedRed = max(green, red - spill)
            var repairedBlue = max(green, blue - spill)
            var after = classification(
                red: UInt8(repairedRed),
                green: input[offset + 1],
                blue: UInt8(repairedBlue),
                alpha: alpha
            )
            if after.near {
                repairedRed = min(repairedRed, green)
                repairedBlue = min(repairedBlue, green)
                after = classification(
                    red: UInt8(repairedRed),
                    green: input[offset + 1],
                    blue: UInt8(repairedBlue),
                    alpha: alpha
                )
            }
            guard !after.near else {
                throw StrictNonzeroAlphaChromaError.invalid(
                    "near-chroma repair failed closed at pixel \(offset / 4)"
                )
            }
            if repairedRed != red {
                output[offset] = UInt8(repairedRed)
                changedChannels += 1
            }
            if repairedBlue != blue {
                output[offset + 2] = UInt8(repairedBlue)
                changedChannels += 1
            }
            if repairedRed != red || repairedBlue != blue {
                changedPixels += 1
            }
        }

        for offset in stride(from: 0, to: output.count, by: 4) {
            if output[offset + 3] != input[offset + 3] {
                alphaMutations += 1
            }
            let after = classification(
                red: output[offset],
                green: output[offset + 1],
                blue: output[offset + 2],
                alpha: output[offset + 3]
            )
            if after.exact { outputExact += 1 }
            if after.near { outputNear += 1 }
        }
        guard
            outputExact == 0,
            outputNear == 0,
            alphaMutations == 0,
            hiddenRGB == 0
        else {
            throw StrictNonzeroAlphaChromaError.invalid(
                "strict chroma postcondition failed"
            )
        }
        return (
            output,
            StrictNonzeroAlphaChromaMetrics(
                inputExactChromaAtNonzeroAlpha: inputExact,
                inputNearChromaAtNonzeroAlpha: inputNear,
                outputExactChromaAtNonzeroAlpha: outputExact,
                outputNearChromaAtNonzeroAlpha: outputNear,
                changedPixelCount: changedPixels,
                changedChannelCount: changedChannels,
                alphaMutationCount: alphaMutations,
                zeroAlphaHiddenRGBPixelCount: hiddenRGB
            )
        )
    }
}
