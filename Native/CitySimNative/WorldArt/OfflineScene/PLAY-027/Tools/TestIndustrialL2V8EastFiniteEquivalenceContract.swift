import CoreGraphics
import CryptoKit
import Foundation

enum IndustrialL2V8FiniteEquivalenceTestError:
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
enum TestIndustrialL2V8EastFiniteEquivalenceContractMain {
    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map {
            String(format: "%02x", $0)
        }.joined()
    }

    static func image(
        rgba: [UInt8],
        width: Int,
        height: Int
    ) throws -> CGImage {
        guard
            rgba.count == width * height * 4,
            let provider = CGDataProvider(data: Data(rgba) as CFData),
            let image = CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB)!,
                bitmapInfo: CGBitmapInfo(
                    rawValue:
                        CGImageAlphaInfo.premultipliedLast.rawValue
                        | CGBitmapInfo.byteOrder32Big.rawValue
                ),
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        else {
            throw IndustrialL2V8FiniteEquivalenceTestError.failed(
                "could not create test image"
            )
        }
        return image
    }

    static func requireRejected(
        _ label: String,
        operation: () throws -> Void
    ) throws {
        do {
            try operation()
            throw IndustrialL2V8FiniteEquivalenceTestError.failed(
                "\(label) was not rejected"
            )
        } catch is IndustrialL2V8EastFiniteEquivalenceError {
            return
        }
    }

    static func mutatedTableData(
        _ original: Data,
        mutate: (inout [String: Any]) -> Void
    ) throws -> Data {
        guard
            var object = try JSONSerialization.jsonObject(
                with: original
            ) as? [String: Any]
        else {
            throw IndustrialL2V8FiniteEquivalenceTestError.failed(
                "could not decode table JSON object"
            )
        }
        mutate(&object)
        return try JSONSerialization.data(
            withJSONObject: object,
            options: [.sortedKeys]
        )
    }

    static func main() throws {
        let root = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        ).standardizedFileURL
        let tableURL = root.appendingPathComponent(
            IndustrialL2V8EastFiniteEquivalenceContract.tablePath
        )
        let tableData = try Data(contentsOf: tableURL)
        let table =
            try IndustrialL2V8EastFiniteEquivalenceContract
            .loadValidatedTable(data: tableData)
        guard
            table.coordinates.count
                == IndustrialL2V8EastFiniteEquivalenceContract
                .expectedCoordinateCount,
            table.classes.count
                == IndustrialL2V8EastFiniteEquivalenceContract
                .expectedClassCount
        else {
            throw IndustrialL2V8FiniteEquivalenceTestError.failed(
                "valid table counts drifted"
            )
        }

        try requireRejected("table hash drift") {
            _ = try IndustrialL2V8EastFiniteEquivalenceContract
                .loadValidatedTable(
                    data: tableData,
                    expectedSHA256: String(repeating: "0", count: 64)
                )
        }

        let duplicateClassData = try mutatedTableData(
            tableData
        ) { object in
            var classes = object["classes"] as! [[String: Any]]
            classes.append(classes[0])
            object["classes"] = classes
            object["classCount"] = classes.count
        }
        try requireRejected("duplicate class") {
            _ = try IndustrialL2V8EastFiniteEquivalenceContract
                .loadValidatedTable(
                    data: duplicateClassData,
                    expectedSHA256: sha256(duplicateClassData)
                )
        }

        let ambiguousTupleData = try mutatedTableData(
            tableData
        ) { object in
            var classes = object["classes"] as! [[String: Any]]
            let firstMembers =
                classes[0]["members"] as! [[String: Any]]
            var secondMembers =
                classes[1]["members"] as! [[String: Any]]
            secondMembers.append(firstMembers[0])
            classes[1]["members"] = secondMembers
            object["classes"] = classes
            object["tupleCount"] =
                (object["tupleCount"] as! Int) + 1
        }
        try requireRejected("ambiguous tuple ownership") {
            _ = try IndustrialL2V8EastFiniteEquivalenceContract
                .loadValidatedTable(
                    data: ambiguousTupleData,
                    expectedSHA256: sha256(ambiguousTupleData)
                )
        }

        let tiedRepresentativeData = try mutatedTableData(
            tableData
        ) { object in
            var classes = object["classes"] as! [[String: Any]]
            var members = classes[0]["members"] as! [[String: Any]]
            members[0]["unstableObservationCount"] = 17
            classes[0]["members"] = members
            object["classes"] = classes
        }
        try requireRejected("ambiguous representative") {
            _ = try IndustrialL2V8EastFiniteEquivalenceContract
                .loadValidatedTable(
                    data: tiedRepresentativeData,
                    expectedSHA256: sha256(tiedRepresentativeData)
                )
        }

        let width =
            IndustrialL2V8EastFiniteEquivalenceContract
            .expectedFramePixels[0]
        let height =
            IndustrialL2V8EastFiniteEquivalenceContract
            .expectedFramePixels[1]
        var source = [UInt8](
            repeating: 255,
            count: width * height * 4
        )
        var governedOffsets = Set<Int>()
        for coordinate in table.coordinates {
            let x = coordinate.coordinate4x[0]
            let y = coordinate.coordinate4x[1]
            let offset = (y * width + x) * 4
            governedOffsets.insert(offset)
            let allowed = coordinate.allowedRGB[0]
            source[offset] = UInt8(allowed[0])
            source[offset + 1] = UInt8(allowed[1])
            source[offset + 2] = UInt8(allowed[2])
            source[offset + 3] = 255
        }
        let sourceHash = sha256(Data(source))
        let sourceImage = try image(
            rgba: source,
            width: width,
            height: height
        )
        let first =
            try IndustrialL2V8EastFiniteEquivalenceContract.apply(
                image: sourceImage,
                table: table,
                expectedInputDecodedRGBASHA256: sourceHash
            )
        let firstMapped =
            try IndustrialL2V8EastFiniteEquivalenceContract
            .canonicalRGBA(image: first.image)
        let second =
            try IndustrialL2V8EastFiniteEquivalenceContract.apply(
                image: sourceImage,
                table: table,
                expectedInputDecodedRGBASHA256: sourceHash
            )
        let secondMapped =
            try IndustrialL2V8EastFiniteEquivalenceContract
            .canonicalRGBA(image: second.image)
        guard
            first.mappedDecodedRGBASHA256
                == second.mappedDecodedRGBASHA256,
            firstMapped == secondMapped,
            first.mutations == second.mutations
        else {
            throw IndustrialL2V8FiniteEquivalenceTestError.failed(
                "output application repeat identity failed"
            )
        }
        for offset in stride(from: 0, to: source.count, by: 4) {
            guard firstMapped[offset + 3] == source[offset + 3] else {
                throw IndustrialL2V8FiniteEquivalenceTestError.failed(
                    "alpha changed"
                )
            }
            if !governedOffsets.contains(offset) {
                guard
                    firstMapped[offset] == source[offset],
                    firstMapped[offset + 1] == source[offset + 1],
                    firstMapped[offset + 2] == source[offset + 2]
                else {
                    throw IndustrialL2V8FiniteEquivalenceTestError.failed(
                        "out-of-scope coordinate changed"
                    )
                }
            }
        }

        try requireRejected("input decoded hash drift") {
            _ = try IndustrialL2V8EastFiniteEquivalenceContract
                .apply(
                    image: sourceImage,
                    table: table,
                    expectedInputDecodedRGBASHA256:
                        String(repeating: "0", count: 64)
                )
        }
        let smallImage = try image(
            rgba: [255, 255, 255, 255],
            width: 1,
            height: 1
        )
        try requireRejected("input dimensions drift") {
            _ = try IndustrialL2V8EastFiniteEquivalenceContract
                .apply(
                    image: smallImage,
                    table: table,
                    expectedInputDecodedRGBASHA256:
                        sha256(Data([255, 255, 255, 255]))
                )
        }

        let firstCoordinate = table.coordinates[0]
        let firstOffset =
            (
                firstCoordinate.coordinate4x[1] * width
                    + firstCoordinate.coordinate4x[0]
            ) * 4
        var unknown = source
        unknown[firstOffset] = 1
        unknown[firstOffset + 1] = 2
        unknown[firstOffset + 2] = 3
        let unknownImage = try image(
            rgba: unknown,
            width: width,
            height: height
        )
        try requireRejected("unknown governed tuple") {
            _ = try IndustrialL2V8EastFiniteEquivalenceContract
                .apply(
                    image: unknownImage,
                    table: table,
                    expectedInputDecodedRGBASHA256:
                        sha256(Data(unknown))
                )
        }

        var nonOpaque = source
        nonOpaque[firstOffset + 3] = 254
        let nonOpaqueImage = try image(
            rgba: nonOpaque,
            width: width,
            height: height
        )
        try requireRejected("non-opaque governed tuple") {
            _ = try IndustrialL2V8EastFiniteEquivalenceContract
                .apply(
                    image: nonOpaqueImage,
                    table: table,
                    expectedInputDecodedRGBASHA256:
                        sha256(Data(nonOpaque))
                )
        }

        var chroma = source
        chroma[firstOffset] = 255
        chroma[firstOffset + 1] = 0
        chroma[firstOffset + 2] = 255
        let chromaImage = try image(
            rgba: chroma,
            width: width,
            height: height
        )
        try requireRejected("chroma governed tuple") {
            _ = try IndustrialL2V8EastFiniteEquivalenceContract
                .apply(
                    image: chromaImage,
                    table: table,
                    expectedInputDecodedRGBASHA256:
                        sha256(Data(chroma))
                )
        }

        let sceneURL = URL(
            fileURLWithPath:
                IndustrialL2V8EastFiniteEquivalenceContract
                .diagnosticScenePath
        )
        let descriptor = try JSONDecoder().decode(
            SceneDescriptor.self,
            from: Data(contentsOf: sceneURL)
        )
        let sampling = try DescriptorSamplingResolver.resolve(
            descriptor: descriptor
        )
        let materialsURL = root.appendingPathComponent(
            IndustrialL2V8EastFiniteEquivalenceContract.materialPath
        )
        let capture = root.appendingPathComponent(
            IndustrialL2V8EastFiniteEquivalenceContract.evidenceRoot
                + "/run-a"
        )
        let valid =
            try IndustrialL2V8EastFiniteEquivalenceContract.validate(
                requestedContractID:
                    IndustrialL2V8EastFiniteEquivalenceContract
                    .contractID,
                repositoryRoot: root,
                sceneURL: sceneURL,
                sceneFileSHA256:
                    IndustrialL2V8EastFiniteEquivalenceContract
                    .sceneSHA256,
                materialsURL: materialsURL,
                materialFileSHA256:
                    IndustrialL2V8EastFiniteEquivalenceContract
                    .materialSHA256,
                outputURL:
                    capture.appendingPathComponent("final-sips.png"),
                recordURL:
                    capture.appendingPathComponent("provenance.json"),
                stageCaptureDirectory: capture,
                stageCoordinate: [707, 687],
                diagnosticPrequantizedOutput:
                    capture.appendingPathComponent(
                        "POST-LANCZOS-PREQUANTIZED.png"
                    ),
                explicitAntialiasing: "none",
                explicitSceneShadows: "current",
                explicitMaterialLighting: "current",
                descriptor: descriptor,
                sampling: sampling
            )
        guard
            valid?.value["finiteTableSHA256"] as? String
                == IndustrialL2V8EastFiniteEquivalenceContract
                .tableSHA256,
            valid?.value["governedCoordinateCount"] as? Int == 57,
            valid?.value["productionSelected"] as? Bool == false
        else {
            throw IndustrialL2V8FiniteEquivalenceTestError.failed(
                "valid renderer contract drifted"
            )
        }
        try requireRejected("descriptor hash drift") {
            _ = try IndustrialL2V8EastFiniteEquivalenceContract
                .validate(
                    requestedContractID:
                        IndustrialL2V8EastFiniteEquivalenceContract
                        .contractID,
                    repositoryRoot: root,
                    sceneURL: sceneURL,
                    sceneFileSHA256:
                        String(repeating: "0", count: 64),
                    materialsURL: materialsURL,
                    materialFileSHA256:
                        IndustrialL2V8EastFiniteEquivalenceContract
                        .materialSHA256,
                    outputURL:
                        capture.appendingPathComponent(
                            "final-sips.png"
                        ),
                    recordURL:
                        capture.appendingPathComponent(
                            "provenance.json"
                        ),
                    stageCaptureDirectory: capture,
                    stageCoordinate: [707, 687],
                    diagnosticPrequantizedOutput:
                        capture.appendingPathComponent(
                            "POST-LANCZOS-PREQUANTIZED.png"
                        ),
                    explicitAntialiasing: "none",
                    explicitSceneShadows: "current",
                    explicitMaterialLighting: "current",
                    descriptor: descriptor,
                    sampling: sampling
                )
        }

        print(
            "PASS Industrial L2 East source-v08-equivalent finite table contract; descriptor/table/input dimension/hash drift, unknown tuples, ambiguity, duplicate classes, alpha/chroma writes, and out-of-scope writes fail closed; repeat application identity holds"
        )
    }
}
