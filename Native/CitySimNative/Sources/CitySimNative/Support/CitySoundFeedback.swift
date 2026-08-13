import AppKit
import Foundation

enum CitySoundCue: Equatable, Sendable {
    case constructionApproved
    case actionRejected
    case persistenceSucceeded
    case actionReversed
    case demolitionApproved
    case objectiveCompleted
    case warningRaised
    case criticalAlertRaised

    fileprivate var systemSoundName: NSSound.Name {
        switch self {
        case .constructionApproved: NSSound.Name("Tink")
        case .actionRejected: NSSound.Name("Basso")
        case .persistenceSucceeded: NSSound.Name("Glass")
        case .actionReversed: NSSound.Name("Pop")
        case .demolitionApproved: NSSound.Name("Funk")
        case .objectiveCompleted: NSSound.Name("Hero")
        case .warningRaised: NSSound.Name("Frog")
        case .criticalAlertRaised: NSSound.Name("Sosumi")
        }
    }
}

enum CitySimulationSoundTransition {
    static func resolve(
        messagesBefore: [CityMessage],
        messagesAfter: [CityMessage],
        objectivesBefore: [CityObjective],
        objectivesAfter: [CityObjective]
    ) -> CitySoundCue? {
        let priorMessageIDs = Set(messagesBefore.map(\.id))
        let newSeverities = messagesAfter.lazy
            .filter { !priorMessageIDs.contains($0.id) }
            .map(\.severity)
        if newSeverities.contains(.critical) { return .criticalAlertRaised }
        if newSeverities.contains(.warning) { return .warningRaised }

        let completedBefore = Set(objectivesBefore.filter(\.completed).map(\.id))
        if objectivesAfter.contains(where: { $0.completed && !completedBefore.contains($0.id) }) {
            return .objectiveCompleted
        }
        return nil
    }
}

@MainActor
protocol CitySoundPlaying: AnyObject {
    func play(_ cue: CitySoundCue, volume: Float)
}

@MainActor
final class CitySystemSoundPlayer: CitySoundPlaying {
    func play(_ cue: CitySoundCue, volume: Float) {
        guard let sound = NSSound(named: cue.systemSoundName) else { return }
        sound.volume = min(1, max(0, volume))
        sound.play()
    }
}

@MainActor
struct CitySoundFeedbackController {
    let defaults: UserDefaults
    let player: any CitySoundPlaying

    func play(_ cue: CitySoundCue) {
        let preferences = CityPlayerPreferenceSnapshot.read(from: defaults)
        guard preferences.soundEffects, preferences.effectsVolume > 0 else { return }
        player.play(cue, volume: Float(preferences.effectsVolume))
    }
}
