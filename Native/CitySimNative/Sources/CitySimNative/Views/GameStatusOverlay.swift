import SwiftUI

struct GameStatusOverlay: View {
    @ObservedObject var store: CityGameStore

    var body: some View {
        ZStack {
            Color.black.opacity(0.58).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: store.state.status == .won ? "trophy.fill" : "exclamationmark.octagon.fill")
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(store.state.status == .won ? GameTheme.warning : GameTheme.danger)
                Text(store.state.status == .won ? "A City Worth Calling Home" : "The City Is in Crisis")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                Text(store.state.status == .won
                     ? "You built a solvent, thriving metropolis of \(store.state.population.formatted()) residents."
                     : "New Arcadia can no longer meet its obligations. Reconsider the balance between growth, services, and taxation.")
                    .multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 480)
                HStack {
                    Button("Start a New Region") { store.perform(.newRegion) }.buttonStyle(.borderedProminent).tint(GameTheme.accent)
                    Button("Load Quicksave") { store.perform(.loadCity) }.buttonStyle(.bordered)
                        .disabled(!store.canPerform(.loadCity))
                }
            }
            .padding(38)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.15)))
        }
    }
}
