import AppKit
import SwiftUI

@MainActor
final class CitySimAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        if let iconURL = Bundle.main.url(forResource: "CitySim-KeyArt", withExtension: "png"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct CitySimNativeApp: App {
    @NSApplicationDelegateAdaptor(CitySimAppDelegate.self) private var appDelegate
    @StateObject private var store: CityGameStore

    init() {
        let hasSeenWelcome = UserDefaults.standard.bool(forKey: "hasSeenCitySimWelcome")
        _store = StateObject(wrappedValue: CityGameStore(
            commandPolicy: hasSeenWelcome ? .enabled : .blocked(.welcome)
        ))
    }

    var body: some Scene {
        WindowGroup("CitySim", id: "main") {
            ContentView(store: store)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1_440, height: 900)
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
                [.toggleObjectives, .toggleCommandCenter, .toggleCityFocus, .openNotices].contains($0.id)
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
                [.openCommandGuide, .dismissFeedback].contains($0.id)
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
