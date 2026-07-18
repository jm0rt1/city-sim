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
    @StateObject private var store = CityGameStore()

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
            Button("New Region") { store.newCity() }.keyboardShortcut("n")
            Divider()
            Button("Save City") { store.save() }.keyboardShortcut("s")
            Button("Load City") { store.load() }.keyboardShortcut("o")
        }
        CommandGroup(replacing: .undoRedo) {
            Button("Undo Construction") { store.undoLastAction() }
                .keyboardShortcut("z")
                .disabled(!store.canUndo)
        }
        CommandMenu("Simulation") {
            Button("Pause") { store.speed = .paused }.keyboardShortcut(.space, modifiers: [])
            Button("Normal Speed") { store.speed = .normal }.keyboardShortcut("1", modifiers: [])
            Button("Fast Speed") { store.speed = .fast }.keyboardShortcut("2", modifiers: [])
            Button("Fastest Speed") { store.speed = .fastest }.keyboardShortcut("3", modifiers: [])
        }
        CommandMenu("Tools") {
            Button(store.bulldozeMode ? "Deactivate Bulldozer" : "Activate Bulldozer") {
                store.toggleBulldozer()
            }
            .keyboardShortcut("b", modifiers: [])
            Divider()
            ForEach(BuildingKind.buildPalette) { kind in
                Button(kind.title) { store.selectTool(kind) }
            }
        }
        CommandMenu("City Data") {
            ForEach(DataOverlay.allCases) { overlay in
                Button(overlay.title) { store.overlay = overlay }
            }
            Divider()
            Button("Toggle Objectives") { store.showObjectives.toggle() }.keyboardShortcut("j", modifiers: [.command])
            Button("Toggle Inspector") { store.showInspector.toggle() }.keyboardShortcut("i", modifiers: [.command, .option])
        }
    }
}
