import AppKit
import SwiftUI

@MainActor
final class CitySimAppDelegate: NSObject, NSApplicationDelegate {
    private weak var store: CityGameStore?
    var terminationConfirmationHandler: (CityTerminationConfirmationPresentation) -> CityTerminationAction = {
        CitySimAppDelegate.presentTerminationConfirmation($0)
    }

    func bind(store: CityGameStore) {
        self.store = store
    }

    // CitySim restores player progress only through the explicit quicksave in
    // the selected data root. AppKit's secure window restoration can otherwise
    // show a stale scene snapshot before a fresh isolated session is rendered.
    func applicationShouldRestoreSecureState(_ app: NSApplication) -> Bool {
        false
    }

    func applicationShouldSaveSecureState(_ app: NSApplication) -> Bool {
        false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        if let iconURL = Bundle.main.url(forResource: "CitySim-KeyArt", withExtension: "png"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let store, store.hasUnsavedProgress else { return .terminateNow }
        let previousSpeed = store.speed
        store.speed = .paused
        let presentation = CityTerminationConfirmationPresentation.make(
            state: store.state,
            persistenceStatus: store.persistenceStatus
        )
        switch terminationConfirmationHandler(presentation) {
        case .saveAndQuit:
            guard store.save() else {
                store.speed = previousSpeed
                return .terminateCancel
            }
            return .terminateNow
        case .quitWithoutSaving:
            return .terminateNow
        case .cancel:
            store.speed = previousSpeed
            return .terminateCancel
        }
    }

    private static func presentTerminationConfirmation(
        _ presentation: CityTerminationConfirmationPresentation
    ) -> CityTerminationAction {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = presentation.title
        alert.informativeText = presentation.message
        alert.addButton(withTitle: presentation.saveActionTitle)
        alert.addButton(withTitle: presentation.cancelActionTitle)
        alert.addButton(withTitle: presentation.discardActionTitle)
        alert.buttons[1].keyEquivalent = "\u{1b}"
        switch alert.runModal() {
        case .alertFirstButtonReturn: return .saveAndQuit
        case .alertThirdButtonReturn: return .quitWithoutSaving
        default: return .cancel
        }
    }
}

@main
struct CitySimNativeApp: App {
    @NSApplicationDelegateAdaptor(CitySimAppDelegate.self) private var appDelegate
    @StateObject private var store: CityGameStore

    init() {
        let hasSeenWelcome = UserDefaults.standard.bool(
            forKey: CityPlayerPreferenceKey.hasSeenWelcome
        )
        _store = StateObject(wrappedValue: CityGameStore(
            commandPolicy: hasSeenWelcome ? .enabled : .blocked(.welcome),
            startsPaused: true,
            capturesScenarioCheckpoints: true
        ))
    }

    var body: some Scene {
        WindowGroup("CitySim", id: "main") {
            ContentView(store: store, startupResumeEnabled: true)
                .preferredColorScheme(.dark)
                .onAppear { appDelegate.bind(store: store) }
        }
        .defaultSize(
            width: ProofWindowConfigurator.initialSceneContentSize.width,
            height: ProofWindowConfigurator.initialSceneContentSize.height
        )
        .windowResizability(.contentMinSize)
        .commands { CityGameCommands(store: store) }

        Settings { SettingsView() }
    }
}

struct CityGameCommands: Commands {
    @ObservedObject var store: CityGameStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            ForEach(CityCommandCatalog.descriptors(in: .files).filter { $0.id != .undo }) {
                commandButton($0)
            }
        }
        CommandGroup(replacing: .undoRedo) {
            commandButton(CityCommandCatalog.descriptor(for: .undo))
        }
        CommandMenu("Simulation") {
            ForEach(CityCommandCatalog.descriptors(in: .simulation)) {
                commandButton($0)
            }
        }
        CommandMenu("Tools") {
            ForEach(CityCommandCatalog.descriptors(in: .modes)) {
                commandButton($0)
            }
            Divider()
            ForEach(CityCommandCatalog.descriptors(in: .buildCategories)) {
                commandButton($0)
            }
            Divider()
            ForEach(CityCommandCatalog.descriptors(in: .buildTools)) {
                commandButton($0)
            }
        }
        CommandMenu("City Data") {
            ForEach(CityCommandCatalog.descriptors(in: .overlays)) {
                commandButton($0)
            }
            Divider()
            ForEach(CityCommandCatalog.descriptors(in: .panels).filter {
                [.toggleObjectives, .toggleCommandCenter, .toggleCityFocus, .togglePhotoMode,
                 .capturePhoto, .openNotices].contains($0.id)
            }) {
                commandButton($0)
            }
            Divider()
            ForEach(CityCommandCatalog.descriptors(in: .inspectors)) {
                commandButton($0)
            }
        }
        CommandGroup(after: .help) {
            ForEach(CityCommandCatalog.descriptors(in: .panels).filter {
                [.openHandbook, .openCommandGuide, .dismissFeedback].contains($0.id)
            }) {
                commandButton($0)
            }
        }
    }

    private func commandButton(_ descriptor: CityCommandDescriptor) -> some View {
        let title = descriptor.shortcut?.focusScope == .gameplay && descriptor.shortcut != nil
            ? "\(descriptor.title) · \(descriptor.shortcut?.display ?? "")"
            : descriptor.title
        return Button(title) { store.perform(descriptor.id) }
            .disabled(!store.canPerform(descriptor.id))
            .help(store.disabledReason(for: descriptor.id) ?? descriptor.discoverability)
            .modifier(CityCatalogShortcutModifier(shortcut: descriptor.shortcut))
    }
}
