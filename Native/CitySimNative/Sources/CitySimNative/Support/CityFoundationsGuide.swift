import Foundation

enum CityFoundationsLessonID: String, Codable, CaseIterable, Hashable, Sendable {
    case observe
    case roads
    case zoning
    case utilities
    case budget
    case services
    case runCity
}

struct CityFoundationsLesson: Identifiable, Equatable, Sendable {
    let id: CityFoundationsLessonID
    let symbol: String
    let title: String
    let detail: String
    let completionRule: String
    let actionTitle: String
    let command: CityCommandID

    static let curriculum: [CityFoundationsLesson] = [
        CityFoundationsLesson(
            id: .observe,
            symbol: "scope",
            title: "Read the city",
            detail: "Start with evidence. Inspect any block or open the Command Center overview.",
            completionRule: "Any inspected block or city overview counts.",
            actionTitle: "Open Overview",
            command: .inspectorOverview
        ),
        CityFoundationsLesson(
            id: .roads,
            symbol: "road.lanes",
            title: "Extend access",
            detail: "Add one road block so the next neighborhood can connect to the existing street grid.",
            completionRule: "Any successfully built road counts.",
            actionTitle: "Choose Road",
            command: .buildRoad
        ),
        CityFoundationsLesson(
            id: .zoning,
            symbol: "square.3.layers.3d",
            title: "Choose a growth path",
            detail: "Place a residential, commercial, or industrial block. Each is a valid first strategy.",
            completionRule: "Any residential, commercial, or industrial construction counts.",
            actionTitle: "Choose Residential",
            command: .buildResidential
        ),
        CityFoundationsLesson(
            id: .utilities,
            symbol: "bolt.horizontal.circle",
            title: "Check capacity",
            detail: "Review power and water headroom before growth turns into a service shortage.",
            completionRule: "Utilities diagnostics, the utilities overlay, or new utility capacity counts.",
            actionTitle: "Open Utilities",
            command: .inspectorUtilities
        ),
        CityFoundationsLesson(
            id: .budget,
            symbol: "banknote",
            title: "Protect the budget",
            detail: "Compare revenue, upkeep, and projected balance before approving another project.",
            completionRule: "Opening the Finances section counts.",
            actionTitle: "Open Finances",
            command: .inspectorFinances
        ),
        CityFoundationsLesson(
            id: .services,
            symbol: "cross.case.fill",
            title: "Support the neighborhood",
            detail: "Add a park or civic service, or use the notices journal to diagnose an existing need.",
            completionRule: "Any park, fire, police, or school project—or opening Notices—counts.",
            actionTitle: "Open Notices",
            command: .openNotices
        ),
        CityFoundationsLesson(
            id: .runCity,
            symbol: "play.circle.fill",
            title: "Run and review",
            detail: "Resume the simulation and let one city day pass. Watch the HUD and notices for consequences.",
            completionRule: "Advancing into the next city day completes Foundations.",
            actionTitle: "Run at Normal Speed",
            command: .speedNormal
        ),
    ]
}

struct CityFoundationsGuideProgress: Codable, Equatable, Sendable {
    var completedLessonIDs: Set<CityFoundationsLessonID> = []
    var isDismissed = false

    static let fresh = CityFoundationsGuideProgress()

    var isComplete: Bool {
        completedLessonIDs.isSuperset(of: Set(CityFoundationsLessonID.allCases))
    }

    @discardableResult
    mutating func complete(_ lessonID: CityFoundationsLessonID) -> Bool {
        completedLessonIDs.insert(lessonID).inserted
    }
}

struct CityFoundationsGuidePresentation: Equatable, Sendable {
    let completedCount: Int
    let totalCount: Int
    let currentLesson: CityFoundationsLesson?

    static func make(progress: CityFoundationsGuideProgress) -> Self {
        let curriculum = CityFoundationsLesson.curriculum
        return Self(
            completedCount: curriculum.filter { progress.completedLessonIDs.contains($0.id) }.count,
            totalCount: curriculum.count,
            currentLesson: curriculum.first { !progress.completedLessonIDs.contains($0.id) }
        )
    }

    var isComplete: Bool { currentLesson == nil }

    var progress: Double {
        guard totalCount > 0 else { return 1 }
        return Double(completedCount) / Double(totalCount)
    }

    var accessibilitySummary: String {
        if let currentLesson {
            return "Foundations Guide. " + String(completedCount) + " of " + String(totalCount)
                + " lessons complete. " + currentLesson.title + ". " + currentLesson.detail
                + " " + currentLesson.completionRule
        }
        return "Foundations Guide complete. All " + String(totalCount) + " lessons finished."
    }
}

enum CityFoundationsGuidePersistence {
    static func read(from defaults: UserDefaults) -> CityFoundationsGuideProgress {
        guard let data = defaults.data(forKey: CityPlayerPreferenceKey.foundationsGuideProgress),
              let progress = try? JSONDecoder().decode(CityFoundationsGuideProgress.self, from: data) else {
            return .fresh
        }
        return progress
    }

    static func write(_ progress: CityFoundationsGuideProgress, to defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        defaults.set(data, forKey: CityPlayerPreferenceKey.foundationsGuideProgress)
    }

    static func reset(in defaults: UserDefaults) {
        write(.fresh, to: defaults)
    }
}
