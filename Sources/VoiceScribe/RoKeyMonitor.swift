import AppKit
import Carbon

final class RoKeyMonitor {
    static let shared = RoKeyMonitor()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isRoDown = false

    private init() {}

    func start() {
        let eventMask: CGEventMask =
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.keyUp.rawValue)

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo = userInfo else { return Unmanaged.passRetained(event) }
            let monitor = Unmanaged<RoKeyMonitor>.fromOpaque(userInfo).takeUnretainedValue()
            return monitor.handleEvent(type: type, event: event)
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: selfPtr
        )

        guard let tap = eventTap else {
            print("Failed to create event tap. Make sure Accessibility permissions are granted.")
            showPermissionAlert()
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    // Right Option key keycode
    private let roKeyCode: Int64 = 0x3D

    private func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .flagsChanged {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            guard keyCode == roKeyCode else {
                return Unmanaged.passRetained(event)
            }

            let flags = event.flags
            let isDown = flags.contains(.maskAlternate)

            if isDown && !isRoDown {
                isRoDown = true
                DispatchQueue.main.async { self.onRoDown() }
                return nil
            } else if !isDown && isRoDown {
                isRoDown = false
                DispatchQueue.main.async { self.onRoUp() }
                return nil
            }
        }

        // Suppress all events while right Option is held
        if isRoDown && (type == .keyDown || type == .keyUp) {
            return nil
        }

        return Unmanaged.passRetained(event)
    }

    private func onRoDown() {
        AudioRecorder.shared.startRecording()
    }

    private func onRoUp() {
        AudioRecorder.shared.stopRecording()
        OverlayWindowController.shared.hide()
    }

    private func showPermissionAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permission Required"
            alert.informativeText = "VoiceScribe needs Accessibility permission to monitor the Right Option key globally. Please grant access in System Settings > Privacy & Security > Accessibility."
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Later")

            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }
    }
}
