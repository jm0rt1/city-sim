import AppKit
import SwiftUI

/// Debug-only window sizing for deterministic real-app layout proof.
struct ProofWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
#if DEBUG
        let environment = ProcessInfo.processInfo.environment
        let proofSize: NSSize?
        if environment["CITYSIM_COMPACT_WINDOW"] == "1" {
            proofSize = NSSize(width: 900, height: 600)
        } else if environment["CITYSIM_REGULAR_WINDOW"] == "1" {
            proofSize = NSSize(width: 1_278, height: 768)
        } else {
            proofSize = nil
        }
        guard let proofSize else { return view }
        DispatchQueue.main.async { [weak view] in
            guard let window = view?.window else { return }
            window.setContentSize(proofSize)
            window.center()
        }
#endif
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
