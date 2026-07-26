import CoreGraphics
import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum MaterialValueLadderError: Error, CustomStringConvertible {
    case arguments
    case invalid(String)

    var description: String {
        switch self {
        case .arguments:
            return "usage: build-material-value-ladder --repository-root <path> --materials <json> --output <png> --record <json>"
        case let .invalid(message):
            return message
        }
    }
}

private func ladderArgument(_ name: String, in arguments: [String]) throws -> String {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else {
        throw MaterialValueLadderError.arguments
    }
    return arguments[index + 1]
}

private func ladderSHA256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func ladderRelative(_ url: URL, root: URL) -> String {
    let prefix = root.path + "/"
    return url.path.hasPrefix(prefix) ? String(url.path.dropFirst(prefix.count)) : url.path
}

private func ladderJSON(_ object: Any) throws -> Data {
    var data = try JSONSerialization.data(
        withJSONObject: object,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    return data
}

@main
enum BuildMaterialValueLadderMain {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        let root = URL(fileURLWithPath: try ladderArgument("--repository-root", in: arguments))
            .standardizedFileURL
        let materialsURL = URL(fileURLWithPath: try ladderArgument("--materials", in: arguments))
            .standardizedFileURL
        let outputURL = URL(fileURLWithPath: try ladderArgument("--output", in: arguments))
            .standardizedFileURL
        let recordURL = URL(fileURLWithPath: try ladderArgument("--record", in: arguments))
            .standardizedFileURL

        let materialData = try Data(contentsOf: materialsURL)
        guard
            let rootObject = try JSONSerialization.jsonObject(with: materialData) as? [String: Any],
            let hierarchy = rootObject["authoredValueHierarchy"] as? [String: Any],
            let expectedCount = hierarchy["materialRoleCount"] as? Int,
            let order = hierarchy["ladderOrder"] as? [String],
            let materials = rootObject["materials"] as? [[String: Any]],
            rootObject["productionSelected"] as? Bool == false,
            hierarchy["lightingMode"] as? String == "authored-constant-v1"
        else {
            throw MaterialValueLadderError.invalid("material value hierarchy is incomplete")
        }
        guard
            expectedCount == 21,
            order.count == expectedCount,
            Set(order).count == expectedCount,
            materials.count == expectedCount
        else {
            throw MaterialValueLadderError.invalid("material ladder count/identity mismatch")
        }

        var materialByID: [String: [String: Any]] = [:]
        for material in materials {
            guard
                let id = material["id"] as? String,
                let rgba = material["baseColorRGBA"] as? [Double],
                rgba.count == 4,
                rgba.allSatisfy({ $0 >= 0 && $0 <= 1 }),
                rgba[3] == 1,
                material["emissionRGBA"] is NSNull
            else {
                throw MaterialValueLadderError.invalid("invalid authored constant material")
            }
            guard materialByID.updateValue(material, forKey: id) == nil else {
                throw MaterialValueLadderError.invalid("duplicate material id \(id)")
            }
        }
        guard Set(order) == Set(materialByID.keys) else {
            throw MaterialValueLadderError.invalid("ladder does not cover every material exactly once")
        }

        let width = 560
        let rowHeight = 28
        let margin = 16
        let height = margin * 2 + rowHeight * expectedCount
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        guard
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: &pixels,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            throw MaterialValueLadderError.invalid("could not create deterministic RGBA canvas")
        }
        context.setFillColor(CGColor(red: 0.055, green: 0.055, blue: 0.06, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        var records: [[String: Any]] = []
        var previousLuminance = -Double.infinity
        for (index, id) in order.enumerated() {
            guard
                let material = materialByID[id],
                let rgba = material["baseColorRGBA"] as? [Double]
            else {
                throw MaterialValueLadderError.invalid("missing ladder material \(id)")
            }
            let luminance = rgba[0] * 0.2126 + rgba[1] * 0.7152 + rgba[2] * 0.0722
            guard luminance > previousLuminance else {
                throw MaterialValueLadderError.invalid(
                    "ladder is not strictly increasing at \(id)"
                )
            }
            let delta = previousLuminance.isFinite ? luminance - previousLuminance : 0
            previousLuminance = luminance
            let grayByte = Int((luminance * 255).rounded())
            let y = height - margin - (index + 1) * rowHeight + 3
            context.setFillColor(
                CGColor(red: rgba[0], green: rgba[1], blue: rgba[2], alpha: 1)
            )
            context.fill(CGRect(x: 16, y: y, width: 246, height: rowHeight - 6))
            context.setFillColor(
                CGColor(red: luminance, green: luminance, blue: luminance, alpha: 1)
            )
            context.fill(CGRect(x: 298, y: y, width: 246, height: rowHeight - 6))
            let roleData = try JSONSerialization.data(
                withJSONObject: material,
                options: [.sortedKeys, .withoutEscapingSlashes]
            )
            records.append([
                "index": index,
                "materialID": id,
                "baseColorRGBA": rgba,
                "relativeLuminance": luminance,
                "grayscaleByte": grayByte,
                "deltaFromPrevious": delta,
                "materialRoleSHA256": ladderSHA256(roleData),
            ])
        }
        guard let image = context.makeImage() else {
            throw MaterialValueLadderError.invalid("could not create ladder image")
        }
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard
            let destination = CGImageDestinationCreateWithURL(
                outputURL as CFURL,
                UTType.png.identifier as CFString,
                1,
                nil
            )
        else {
            throw MaterialValueLadderError.invalid("could not create PNG destination")
        }
        CGImageDestinationAddImage(
            destination,
            image,
            [
                kCGImagePropertyPNGInterlaceType: 0,
                kCGImagePropertyDPIWidth: 72,
                kCGImagePropertyDPIHeight: 72,
            ] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            throw MaterialValueLadderError.invalid("could not finalize PNG")
        }
        let outputData = try Data(contentsOf: outputURL)
        let report: [String: Any] = [
            "schema": 1,
            "task": "PLAY-027",
            "logicalBuildingID": "industrial_l02",
            "sourceRevision": "source-v05",
            "purpose": "pre-pixel authored material color and grayscale value hierarchy",
            "materialLibraryFile": ladderRelative(materialsURL, root: root),
            "materialLibrarySHA256": ladderSHA256(materialData),
            "contactSheetFile": ladderRelative(outputURL, root: root),
            "contactSheetSHA256": ladderSHA256(outputData),
            "contactSheetWidth": width,
            "contactSheetHeight": height,
            "layout": "each row presents authored color at left and exact relative-luminance grayscale at right; darkest role first",
            "materialRoleCount": expectedCount,
            "strictlyIncreasingLuminance": true,
            "minimumLuminance": records.first?["relativeLuminance"] ?? 0,
            "maximumLuminance": records.last?["relativeLuminance"] ?? 0,
            "roles": records,
            "buildingPixelsCreated": false,
            "productionSelected": false,
            "passed": true,
        ]
        try ladderJSON(report).write(to: recordURL, options: .atomic)
    }
}
