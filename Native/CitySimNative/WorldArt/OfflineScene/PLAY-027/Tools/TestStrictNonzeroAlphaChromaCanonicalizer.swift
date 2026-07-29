import Foundation

enum StrictChromaTestError: Error {
    case failed(String)
}

@main
enum TestStrictNonzeroAlphaChromaCanonicalizer {
    static func main() throws {
        let alphas: [UInt8] = [0, 1, 2, 3, 8, 64, 128, 254, 255]
        var input: [UInt8] = []
        for alpha in alphas {
            if alpha == 0 {
                input.append(contentsOf: [0, 0, 0, 0])
            } else {
                input.append(contentsOf: [alpha, 0, alpha, alpha])
            }
        }
        input.append(contentsOf: [200, 40, 180, 255])
        input.append(contentsOf: [80, 120, 160, 255])
        let result =
            try StrictNonzeroAlphaChromaCanonicalizer.canonicalize(input)
        guard
            result.metrics.inputExactChromaAtNonzeroAlpha == 8,
            result.metrics.inputNearChromaAtNonzeroAlpha == 9,
            result.metrics.outputExactChromaAtNonzeroAlpha == 0,
            result.metrics.outputNearChromaAtNonzeroAlpha == 0,
            result.metrics.changedPixelCount == 9,
            result.metrics.alphaMutationCount == 0,
            result.metrics.zeroAlphaHiddenRGBPixelCount == 0,
            result.pixels.suffix(4) == [80, 120, 160, 255]
        else {
            throw StrictChromaTestError.failed(
                "synthetic alpha/chroma contract mismatch"
            )
        }

        let repeated =
            try StrictNonzeroAlphaChromaCanonicalizer.canonicalize(input)
        guard repeated.pixels == result.pixels else {
            throw StrictChromaTestError.failed(
                "repeat application from immutable input differs"
            )
        }
        let idempotent =
            try StrictNonzeroAlphaChromaCanonicalizer.canonicalize(
                result.pixels
            )
        guard idempotent.pixels == result.pixels else {
            throw StrictChromaTestError.failed(
                "canonicalizer is not idempotent"
            )
        }
        do {
            _ = try StrictNonzeroAlphaChromaCanonicalizer.canonicalize(
                [255, 0, 255]
            )
            throw StrictChromaTestError.failed(
                "invalid RGBA length did not fail closed"
            )
        } catch is StrictNonzeroAlphaChromaError {
            // Expected.
        }
        print(
            "PASS \(StrictNonzeroAlphaChromaCanonicalizer.contractID); "
                + "alpha 0/1/2/3/8/64/128/254/255, exact/near chroma, "
                + "pass-through, repeat identity, idempotence, and "
                + "invalid-length rejection"
        )
    }
}
