import AppKit
import Foundation

enum CitySoundCue: Equatable, Sendable {
    case constructionApproved
    case actionRejected
    case persistenceSucceeded
    case actionReversed
    case demolitionApproved

    fileprivate var systemSoundName: NSSound.Name {
        switch self {
        case .constructionApproved: NSSound.Name("Tink")
        case .actionRejected: NSSound.Name("Basso")
        case .persistenceSucceeded: NSSound.Name("Glass")
        case .actionReversed: NSSound.Name("Pop")
        case .demolitionApproved: NSSound.Name("Funk")
        }
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
