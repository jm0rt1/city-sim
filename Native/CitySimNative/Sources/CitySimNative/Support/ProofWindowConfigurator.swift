import AppKit
import SwiftUI

/// Explicit window sizing for deterministic real-app layout proof.
struct ProofWindowConfigurator: NSViewRepresentable {
    static let establishedCandidateDefaultKey = "hasEstablishedCitySimCandidateWindowDefault"
    static let defaultContentSize = NSSize(width: 1_440, height: 900)
    static let compactContentSize = NSSize(width: 900, height: 600)
    static let regularProofContentSize = NSSize(width: 1_278, height: 768)

    /// `WindowGroup.defaultSize` is applied before the representable has a window.
    /// Put explicit proof sizes in the scene itself so it cannot restore 1,440 × 900
    /// after the proof configurator requests a compact content area.
    static var initialSceneContentSize: NSSize {
        initialSceneContentSize(environment: ProcessInfo.processInfo.environment)
    }

    static func initialSceneContentSize(environment: [String: String]) -> NSSize {
        if environment["CITYSIM_COMPACT_WINDOW"] == "1" { return compactContentSize }
        if environment["CITYSIM_REGULAR_WINDOW"] == "1" { return regularProofContentSize }
        return defaultContentSize
    }

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

    /// SwiftUI may apply an established frame after the representable attaches.
    /// Reassert only an explicit proof request on activation; normal launches
    /// and data-root defaults must remain user-resizable after their first size.
    static func reassertsSizeAfterWindowActivation(environment: [String: String]) -> Bool {
        environment["CITYSIM_COMPACT_WINDOW"] == "1"
            || environment["CITYSIM_REGULAR_WINDOW"] == "1"
    }

    func makeNSView(context: Context) -> NSView {
        let view = ProofWindowView(frame: .zero)
        let environment = ProcessInfo.processInfo.environment
        let defaults = UserDefaults.standard
        let hadEstablishedDefault = defaults.bool(forKey: Self.establishedCandidateDefaultKey)
        let proofSize = Self.requestedContentSize(
            environment: environment,
            hasEstablishedCandidateDefault: hadEstablishedDefault
        )
        guard let proofSize else { return view }
        view.configure = { window in
            window.setContentSize(proofSize)
            window.center()
            if environment[SaveGameService.dataRootEnvironmentKey] != nil,
               environment["CITYSIM_COMPACT_WINDOW"] != "1",
               environment["CITYSIM_REGULAR_WINDOW"] != "1" {
                defaults.set(true, forKey: Self.establishedCandidateDefaultKey)
            }
        }
        view.reassertsSizeAfterWindowActivation = Self.reassertsSizeAfterWindowActivation(
            environment: environment
        )
        view.scheduleConfiguration()
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ProofWindowView)?.scheduleConfiguration()
    }
}

private final class ProofWindowView: NSView {
    var configure: ((NSWindow) -> Void)?
    var reassertsSizeAfterWindowActivation = false
    private var configurationScheduled = false
    private var configured = false
    private var activationConfigurationScheduled = false
    private var activationConfigured = false
    private var observedWindow: NSWindow?

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        if observedWindow !== newWindow {
            NotificationCenter.default.removeObserver(
                self,
                name: NSWindow.didBecomeKeyNotification,
                object: observedWindow
            )
            observedWindow = nil
        }
        super.viewWillMove(toWindow: newWindow)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observeWindowActivationIfNeeded()
        scheduleConfiguration()
    }

    func scheduleConfiguration(afterWindowActivation: Bool = false) {
        guard configure != nil else { return }
        if afterWindowActivation {
            guard !activationConfigured, !activationConfigurationScheduled else { return }
            activationConfigurationScheduled = true
        } else {
            guard !configured, !configurationScheduled else { return }
            configurationScheduled = true
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if afterWindowActivation {
                self.activationConfigurationScheduled = false
                guard !self.activationConfigured else { return }
            } else {
                self.configurationScheduled = false
                guard !self.configured else { return }
            }
            guard let window = self.window, let configure = self.configure else { return }
            configure(window)
            if afterWindowActivation {
                self.activationConfigured = true
            } else {
                self.configured = true
            }
        }
    }

    private func observeWindowActivationIfNeeded() {
        guard reassertsSizeAfterWindowActivation,
              let window,
              observedWindow !== window else { return }
        observedWindow = window
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: window
        )
    }

    @objc private func windowDidBecomeKey(_ notification: Notification) {
        scheduleConfiguration(afterWindowActivation: true)
    }
}
