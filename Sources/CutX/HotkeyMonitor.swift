import AppKit
import CutXCore

/// Owns the CGEventTap. The callback does the minimum possible work: build a
/// KeyEvent, ask decide(), and either suppress or pass. Everything slow happens
/// afterwards on the main queue.
final class HotkeyMonitor {
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let contextProvider: () -> Context

    var onCut: () -> Void = {}
    var onPaste: () -> Void = {}

    init(contextProvider: @escaping () -> Context) {
        self.contextProvider = contextProvider
    }

    /// Returns false when Accessibility permission has not been granted.
    func start() -> Bool {
        guard tap == nil else { return true }

        let mask = (1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { proxy, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(refcon)
                    .takeUnretainedValue()
                return monitor.handle(proxy: proxy, type: type, event: event)
            },
            userInfo: refcon
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.tap = tap
        self.runLoopSource = source
        return true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
    }

    private func handle(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        // The system disables a tap that takes too long. Re-enable and move on.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        guard type == .keyDown else { return Unmanaged.passUnretained(event) }

        // Never classify our own synthetic ⌘C / ⌥⌘V.
        if event.getIntegerValueField(.eventSourceUserData) == FinderBridge.syntheticMarker {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags
        let keyEvent = KeyEvent(
            keyCode: keyCode,
            command: flags.contains(.maskCommand),
            control: flags.contains(.maskControl),
            shift: flags.contains(.maskShift),
            option: flags.contains(.maskAlternate)
        )

        switch decide(event: keyEvent, context: contextProvider()) {
        case .passThrough:
            return Unmanaged.passUnretained(event)
        case .cut:
            DispatchQueue.main.async { [weak self] in self?.onCut() }
            return nil
        case .paste:
            DispatchQueue.main.async { [weak self] in self?.onPaste() }
            return nil
        }
    }
}
