import Foundation

/// One resource source for the composed app. SwiftPM's generated Bundle.module
/// probes the app root, not Contents/Resources, before using its build directory.
/// A packaged app must therefore resolve its sealed resources first.
enum CityResourceBundle {
    static let name = "CitySimNative_CitySimNative.bundle"

    static let shared = resolve(mainResourceURL: Bundle.main.resourceURL) { .module }

    static func resolve(mainResourceURL: URL?, fallback: () -> Bundle) -> Bundle {
        packagedResourceBundle(mainResourceURL: mainResourceURL) ?? fallback()
    }

    static func packagedResourceBundle(mainResourceURL: URL?) -> Bundle? {
        guard let mainResourceURL else { return nil }
        return Bundle(url: mainResourceURL.appendingPathComponent(name, isDirectory: true))
    }
}
