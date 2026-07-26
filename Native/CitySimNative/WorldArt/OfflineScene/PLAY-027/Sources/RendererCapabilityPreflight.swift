import Foundation
import Metal
import SceneKit

struct RendererDeviceIdentity {
    let name: String
    let registryID: UInt64
    let isLowPower: Bool
    let isRemovable: Bool
    let hasUnifiedMemory: Bool

    init(_ device: MTLDevice) {
        name = device.name
        registryID = device.registryID
        isLowPower = device.isLowPower
        isRemovable = device.isRemovable
        hasUnifiedMemory = device.hasUnifiedMemory
    }

    var record: [String: Any] {
        [
            "name": name,
            "registryIDDecimal": String(registryID),
            "registryIDHex":
                String(format: "0x%016llx", registryID),
            "isLowPower": isLowPower,
            "isRemovable": isRemovable,
            "hasUnifiedMemory": hasUnifiedMemory,
        ]
    }
}

struct RendererCapabilitySnapshot {
    let visibleDevices: [RendererDeviceIdentity]
    let systemDefaultDevice: RendererDeviceIdentity?
    let rendererDevice: RendererDeviceIdentity?
    let renderingAPIRawValue: UInt

    var available: Bool {
        systemDefaultDevice != nil && rendererDevice != nil
    }

    var result: String {
        available
            ? "renderer-backend-available"
            : "renderer-backend-unavailable"
    }

    var record: [String: Any] {
        [
            "result": result,
            "available": available,
            "visibleMetalDeviceCount": visibleDevices.count,
            "visibleMetalDevices": visibleDevices.map(\.record),
            "systemDefaultMetalDevice":
                systemDefaultDevice?.record ?? NSNull(),
            "sceneKitRendererDevice":
                rendererDevice?.record ?? NSNull(),
            "sceneKitRendererDevicePresent": rendererDevice != nil,
            "renderingAPIRawValue": renderingAPIRawValue,
        ]
    }
}

struct RendererCapabilityContext {
    let renderer: SCNRenderer
    let snapshot: RendererCapabilitySnapshot
}

enum RendererCapabilityPreflight {
    static func capture() -> RendererCapabilityContext {
        let visibleDevices = MTLCopyAllDevices()
            .map(RendererDeviceIdentity.init)
            .sorted {
                if $0.registryID == $1.registryID {
                    return $0.name < $1.name
                }
                return $0.registryID < $1.registryID
            }
        let systemDefault = MTLCreateSystemDefaultDevice()
        let renderer = SCNRenderer(
            device: systemDefault,
            options: nil
        )
        let snapshot = RendererCapabilitySnapshot(
            visibleDevices: visibleDevices,
            systemDefaultDevice:
                systemDefault.map(RendererDeviceIdentity.init),
            rendererDevice:
                renderer.device.map(RendererDeviceIdentity.init),
            renderingAPIRawValue: renderer.renderingAPI.rawValue
        )
        return RendererCapabilityContext(
            renderer: renderer,
            snapshot: snapshot
        )
    }
}

func rendererWriteCapabilityRecord(
    _ record: [String: Any],
    to url: URL
) throws {
    var data = try JSONSerialization.data(
        withJSONObject: record,
        options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    )
    data.append(0x0a)
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try data.write(to: url, options: .atomic)
}
