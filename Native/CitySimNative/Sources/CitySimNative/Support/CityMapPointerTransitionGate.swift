import AppKit
import Combine

@MainActor
final class CityMapPointerTransitionGate: ObservableObject {
    static let movementThreshold: CGFloat = 4

    private enum Origin {
        case focusCity
        case compactCatalog
    }

    private weak var originatingWindow: NSWindow?
    private weak var compactCatalogWindow: NSWindow?
    private(set) var originatingWindowNumber: Int?
    private(set) var anchor: NSPoint?
    private var origin: Origin?
    private var movementMonitor: Any?
    private var windowCloseObserver: NSObjectProtocol?
    private var generation: UInt = 0

    var isActive: Bool {
        originatingWindowNumber != nil && anchor != nil
    }

    func bindCompactCatalogWindow(_ window: NSWindow?) {
        compactCatalogWindow = window
    }

    func unbindCompactCatalogWindow(_ window: NSWindow?) {
        guard compactCatalogWindow === window else { return }
        compactCatalogWindow = nil
    }

    @discardableResult
    func beginCompactCatalogSelection(event: NSEvent?) -> Bool {
        guard let event,
              event.type == .leftMouseDown || event.type == .leftMouseUp,
              let contentWindow = compactCatalogWindow else {
            return false
        }

        let screenLocation: NSPoint
        if let eventWindow = event.window
            ?? NSApplication.shared.window(withWindowNumber: event.windowNumber) {
            screenLocation = eventWindow.convertPoint(toScreen: event.locationInWindow)
        } else {
            screenLocation = NSEvent.mouseLocation
        }
        begin(
            window: contentWindow,
            anchor: contentWindow.convertPoint(fromScreen: screenLocation),
            origin: .compactCatalog
        )
        return true
    }

    func begin(window: NSWindow, anchor: NSPoint) {
        begin(window: window, anchor: anchor, origin: .focusCity)
    }

    private func begin(window: NSWindow, anchor: NSPoint, origin: Origin) {
        cancel()
        originatingWindow = window
        originatingWindowNumber = window.windowNumber
        self.anchor = anchor
        self.origin = origin
        let activeGeneration = generation
        movementMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        ) { [weak self] event in
            self?.observeMovement(event)
            return event
        }
        windowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.cancel(generation: activeGeneration)
            }
        }
    }

    func cancel() {
        generation &+= 1
        if let movementMonitor {
            NSEvent.removeMonitor(movementMonitor)
        }
        if let windowCloseObserver {
            NotificationCenter.default.removeObserver(windowCloseObserver)
        }
        movementMonitor = nil
        windowCloseObserver = nil
        originatingWindow = nil
        originatingWindowNumber = nil
        anchor = nil
        origin = nil
    }

    private func cancel(generation expectedGeneration: UInt) {
        guard generation == expectedGeneration else { return }
        cancel()
    }

    func blocksPointerInput(in window: NSWindow?) -> Bool {
        guard isActive else { return false }
        guard let originatingWindow else {
            cancel()
            return false
        }
        guard let window else { return true }
        if window === originatingWindow || window.windowNumber == originatingWindowNumber {
            return true
        }
        if origin == .compactCatalog {
            return false
        }
        cancel()
        return false
    }

    @discardableResult
    func observeMovement(_ event: NSEvent) -> Bool {
        guard let anchor, isActive else { return false }
        guard eventMatchesOriginatingWindow(event) else {
            if origin == .compactCatalog {
                return false
            }
            cancel()
            return true
        }
        let deltaX = event.locationInWindow.x - anchor.x
        let deltaY = event.locationInWindow.y - anchor.y
        guard hypot(deltaX, deltaY) > Self.movementThreshold else { return false }
        cancel()
        return true
    }

    private func eventMatchesOriginatingWindow(_ event: NSEvent) -> Bool {
        guard let originatingWindowNumber else { return false }
        if let eventWindow = event.window,
           let originatingWindow {
            return eventWindow === originatingWindow
                || eventWindow.windowNumber == originatingWindowNumber
        }
        return event.windowNumber == originatingWindowNumber
    }
}
