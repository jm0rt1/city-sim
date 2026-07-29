import CryptoKit
import Foundation

enum PLAY027MatteCanonicalizationV2Error: Error, CustomStringConvertible {
    case rejected(String)

    var description: String {
        switch self {
        case let .rejected(message):
            return "matte-canonicalization-v2 rejected: \(message)"
        }
    }
}

struct PLAY027MatteCanonicalizationV2Request {
    var pipelineName: String
    var descriptorData: Data
    var materialLibraryData: Data
    var descriptorSHA256: String
    var materialLibrarySHA256: String
    var width: Int
    var height: Int
}

struct PLAY027MatteCanonicalizationV2Binding {
    let decodedRGBASHA256: String
    let descriptorSHA256: String
    let materialLibrarySHA256: String
    let authoredPaletteAllowsMagenta: Bool
}

struct PLAY027MatteCanonicalizationV2Result {
    let rgba: [UInt8]
    let binding: PLAY027MatteCanonicalizationV2Binding
    let borderConnectedMatteMask: [Bool]
    let retainedDespillMask: [Bool]
    let changedMask: [Bool]
}

enum PLAY027MatteCanonicalizationV2 {
    static let pipelineName = "matte-canonicalization-v2"
    static let logicalBuildingID = "industrial_l04"
    static let variantID = "variant-0"
    static let sourceRevision = "source-v17-prepixel"
    static let direction = "n"
    static let sceneGeometryID =
        "industrial-l04-crucible-gantry-v17-north-monumental-portal"
    static let descriptorSHA256 =
        "6cb190ea388746c620945ff401a03817df0ff1f92797a18fff8e86b00b0cd94a"
    static let materialLibrarySHA256 =
        "147c11d64be9fac934a6d4276a2e1a9d27f207bb1a1babd47222aaf5c2b3d202"
    static let decodedRGBASHA256 =
        "0d9ca24f63de0f17c72cd36c38b742bd6fe6aca8aaee60c987a541af952e620f"
    static let width = 1_536
    static let height = 1_024

    static func canonicalize(
        rgba: [UInt8],
        request: PLAY027MatteCanonicalizationV2Request
    ) throws -> PLAY027MatteCanonicalizationV2Result {
        let binding = try bind(rgba: rgba, request: request)

        let pixelCount = request.width * request.height
        var queued = [Bool](repeating: false, count: pixelCount)
        var matte = [Bool](repeating: false, count: pixelCount)
        var queue: [Int] = []
        queue.reserveCapacity(pixelCount / 2)

        func enqueue(_ x: Int, _ y: Int) {
            let index = y * request.width + x
            guard !queued[index] else { return }
            queued[index] = true
            queue.append(index)
        }

        for x in 0..<request.width {
            enqueue(x, 0)
            enqueue(x, request.height - 1)
        }
        for y in 0..<request.height {
            enqueue(0, y)
            enqueue(request.width - 1, y)
        }

        var cursor = 0
        while cursor < queue.count {
            let index = queue[cursor]
            cursor += 1
            let offset = index * 4
            guard isPredicateBoundMatte(rgba, offset: offset) else { continue }
            matte[index] = true
            let x = index % request.width
            let y = index / request.width
            if x > 0 { enqueue(x - 1, y) }
            if x + 1 < request.width { enqueue(x + 1, y) }
            if y > 0 { enqueue(x, y - 1) }
            if y + 1 < request.height { enqueue(x, y + 1) }
        }

        var output = rgba
        var changed = [Bool](repeating: false, count: pixelCount)
        var retainedDespill = [Bool](repeating: false, count: pixelCount)
        for index in 0..<pixelCount where matte[index] {
            let offset = index * 4
            output[offset] = 0
            output[offset + 1] = 0
            output[offset + 2] = 0
            output[offset + 3] = 0
            changed[index] = true
        }

        for index in 0..<pixelCount {
            let offset = index * 4
            if output[offset + 3] == 0 {
                if
                    output[offset] != 0
                        || output[offset + 1] != 0
                        || output[offset + 2] != 0
                {
                    changed[index] = true
                }
                output[offset] = 0
                output[offset + 1] = 0
                output[offset + 2] = 0
                continue
            }
            let red = Int(output[offset])
            let green = Int(output[offset + 1])
            let blue = Int(output[offset + 2])
            if
                Double(red) > Double(green) * 1.35,
                Double(blue) > Double(green) * 1.25
            {
                let spill = min(red, blue) - green
                let newRed = UInt8(max(green, red - spill))
                let newBlue = UInt8(max(green, blue - spill))
                if newRed != output[offset] || newBlue != output[offset + 2] {
                    output[offset] = newRed
                    output[offset + 2] = newBlue
                    changed[index] = true
                    retainedDespill[index] = true
                }
            }
        }

        return PLAY027MatteCanonicalizationV2Result(
            rgba: output,
            binding: binding,
            borderConnectedMatteMask: matte,
            retainedDespillMask: retainedDespill,
            changedMask: changed
        )
    }

    static func bind(
        rgba: [UInt8],
        request: PLAY027MatteCanonicalizationV2Request,
    ) throws -> PLAY027MatteCanonicalizationV2Binding {
        guard request.pipelineName == pipelineName else {
            throw PLAY027MatteCanonicalizationV2Error.rejected("pipeline")
        }
        let actualDescriptorSHA = digest(request.descriptorData)
        let actualMaterialSHA = digest(request.materialLibraryData)
        let actualDecodedRGBASHA = digest(Data(rgba))
        guard
            request.descriptorSHA256 == descriptorSHA256,
            actualDescriptorSHA == request.descriptorSHA256
        else {
            throw PLAY027MatteCanonicalizationV2Error.rejected("descriptor hash")
        }
        guard
            request.materialLibrarySHA256 == materialLibrarySHA256,
            actualMaterialSHA == request.materialLibrarySHA256
        else {
            throw PLAY027MatteCanonicalizationV2Error.rejected("material hash")
        }
        guard actualDecodedRGBASHA == decodedRGBASHA256 else {
            throw PLAY027MatteCanonicalizationV2Error.rejected("decoded RGBA hash")
        }
        guard request.width == width, request.height == height else {
            throw PLAY027MatteCanonicalizationV2Error.rejected("dimensions")
        }
        guard rgba.count == width * height * 4 else {
            throw PLAY027MatteCanonicalizationV2Error.rejected("RGBA byte count")
        }

        guard
            let descriptor = try? JSONSerialization.jsonObject(
                with: request.descriptorData
            ) as? [String: Any],
            descriptor["logicalBuildingID"] as? String == logicalBuildingID,
            descriptor["variantID"] as? String == variantID,
            descriptor["sourceRevision"] as? String == sourceRevision,
            descriptor["viewDirection"] as? String == direction,
            descriptor["sceneGeometryID"] as? String == sceneGeometryID,
            let descriptorMaterial =
                descriptor["materialLibrary"] as? [String: Any],
            descriptorMaterial["sha256"] as? String == actualMaterialSHA
        else {
            throw PLAY027MatteCanonicalizationV2Error.rejected(
                "descriptor byte binding"
            )
        }
        guard
            let materialObject = try? JSONSerialization.jsonObject(
                with: request.materialLibraryData
            ) as? [String: Any],
            let materials = materialObject["materials"] as? [[String: Any]],
            !materials.isEmpty
        else {
            throw PLAY027MatteCanonicalizationV2Error.rejected(
                "material byte binding"
            )
        }
        var authoredPaletteAllowsMagenta = false
        for material in materials {
            guard
                let rgba = material["baseColorRGBA"] as? [NSNumber],
                rgba.count == 4
            else {
                throw PLAY027MatteCanonicalizationV2Error.rejected(
                    "material base color"
                )
            }
            if
                rgba[0].doubleValue >= 0.70,
                rgba[1].doubleValue <= 0.43,
                rgba[2].doubleValue >= 0.59
            {
                authoredPaletteAllowsMagenta = true
            }
        }
        guard !authoredPaletteAllowsMagenta else {
            throw PLAY027MatteCanonicalizationV2Error.rejected(
                "authored magenta-family palette"
            )
        }
        return PLAY027MatteCanonicalizationV2Binding(
            decodedRGBASHA256: actualDecodedRGBASHA,
            descriptorSHA256: actualDescriptorSHA,
            materialLibrarySHA256: actualMaterialSHA,
            authoredPaletteAllowsMagenta: authoredPaletteAllowsMagenta
        )
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func isPredicateBoundMatte(
        _ rgba: [UInt8],
        offset: Int
    ) -> Bool {
        let red = Int(rgba[offset])
        let green = Int(rgba[offset + 1])
        let blue = Int(rgba[offset + 2])
        let alpha = Int(rgba[offset + 3])
        return alpha > 0
            && red >= 180
            && blue >= 150
            && green <= 110
            && red + blue >= green * 4
    }
}
