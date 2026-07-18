import SwiftUI

struct SettingsView: View {
    @AppStorage("soundEffects") private var soundEffects = true
    @AppStorage("reduceGameMotion") private var reduceMotion = false

    var body: some View {
        Form {
            Toggle("Sound effects", isOn: $soundEffects)
            Toggle("Reduce ambient animation", isOn: $reduceMotion)
            LabeledContent("Renderer", value: "SpriteKit · 60 FPS")
            LabeledContent("Save location", value: "Application Support/CitySimNative")
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 460, height: 230)
    }
}
