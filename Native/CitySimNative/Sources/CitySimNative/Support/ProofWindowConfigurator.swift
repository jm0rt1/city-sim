import AppKit
import SwiftUI

/// Debug-only window sizing for deterministic real-app layout proof.
struct ProofWindowConfigurator: NSViewRepresentable {
    static let establishedCandidateDefaultKey = "hasEstablishedCitySimCandidateWindowDefault"
    static let defaultContentSize = NSSize(width: 1_440, height: 900)
    static let compactContentSize = NSSize(width: 900, height: 600)
    static let regularProofContentSize = NSSize(width: 1_278, height: 768)

    static func requestedContentSize(
        environment: [String: String],
        hasEstablishedCandidateDefault: Bool
    ) -> NSSize? {
        if environment["CITYSIM_COMPACT_WINDOW"] == "1" { return compactContentSize }
        if environment["CITYSIM_REGULAR_WINDOW"] == "1" { return regularProofContentSize }
        if environment[SaveGameService.dataRootEnvironmentKey] != nil,
           !hasEstablishedCandidateDefault {
            return defaultContentSize
        }
        return nil
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
#if DEBUG
        let environment = ProcessInfo.processInfo.environment
        let defaults = UserDefaults.standard
        let hadEstablishedDefault = defaults.bool(forKey: Self.establishedCandidateDefaultKey)
        let proofSize = Self.requestedContentSize(
            environment: environment,
            hasEstablishedCandidateDefault: hadEstablishedDefault
        )
        guard let proofSize else { return view }
        DispatchQueue.main.async { [weak view] in
            guard let window = view?.window else { return }
            window.setContentSize(proofSize)
            window.center()
            if environment[SaveGameService.dataRootEnvironmentKey] != nil,
               environment["CITYSIM_COMPACT_WINDOW"] != "1",
               environment["CITYSIM_REGULAR_WINDOW"] != "1" {
                defaults.set(true, forKey: Self.establishedCandidateDefaultKey)
            }
        }
#endif
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
