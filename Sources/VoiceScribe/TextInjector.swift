import AppKit
import Carbon.HIToolbox

final class TextInjector {
    static let shared = TextInjector()

    private init() {}

    func inject(text: String) {
        guard !text.isEmpty else { return }

        // Save current clipboard
        let pasteboard = NSPasteboard.general
        let savedContents = savePasteboard(pasteboard)

        // Detect current input source
        let originalInputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue()
        let isCJK = currentInputSourceIsCJK()

        // If CJK input source, switch to ASCII first
        if isCJK {
            switchToASCIIInputSource()
            // Small delay to let input source switch take effect
            Thread.sleep(forTimeInterval: 0.05)
        }

        // Set clipboard to transcribed text
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Simulate Cmd+V
        Thread.sleep(forTimeInterval: 0.02)
        simulatePaste()

        // Wait for paste to complete
        Thread.sleep(forTimeInterval: 0.1)

        // Restore original input source
        if isCJK, let original = originalInputSource {
            TISSelectInputSource(original)
        }

        // Restore original clipboard after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.restorePasteboard(pasteboard, contents: savedContents)
        }
    }

    // MARK: - Input Source Handling

    private func currentInputSourceIsCJK() -> Bool {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return false
        }

        let cfID = TISGetInputSourceProperty(source, kTISPropertyInputSourceID)
        guard let id = cfID.map({ Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String }) else {
            return false
        }

        // Check for CJK input source IDs
        let cjkPrefixes = [
            "com.apple.inputmethod.SCIM",       // Simplified Chinese
            "com.apple.inputmethod.TCIM",       // Traditional Chinese
            "com.apple.inputmethod.Japanese",   // Japanese
            "com.apple.inputmethod.Korean",     // Korean
            "com.apple.inputmethod.ChinesePinyin",
            "com.apple.inputmethod.Wubi",
            "com.apple.inputmethod.Shuangpin",
        ]

        return cjkPrefixes.contains(where: { id.hasPrefix($0) })
    }

    private func switchToASCIIInputSource() {
        // Try to find ABC/US keyboard
        let props = [kTISPropertyInputSourceType: kTISTypeKeyboardLayout as Any,
                     kTISPropertyInputSourceIsASCIICapable: true] as CFDictionary
        let sources = TISCreateInputSourceList(props, false)?.takeRetainedValue() as? [TISInputSource]

        // Prefer "ABC" or "US" keyboard layout
        if let ascii = sources?.first(where: { source in
            let cfID = TISGetInputSourceProperty(source, kTISPropertyInputSourceID)
            let id = cfID.map({ Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String }) ?? ""
            return id == "com.apple.keylayout.ABC" || id == "com.apple.keylayout.US"
        }) {
            TISSelectInputSource(ascii)
        } else if let first = sources?.first {
            TISSelectInputSource(first)
        }
    }

    // MARK: - Keyboard Simulation

    private func simulatePaste() {
        let src = CGEventSource(stateID: .hidSystemState)

        // Cmd+V key down
        let keyDown = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true) // 'v'
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        // Cmd+V key up
        let keyUp = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)
    }

    // MARK: - Pasteboard Save/Restore

    private struct PasteboardContents {
        let items: [[NSPasteboard.PasteboardType: Data]]
    }

    private func savePasteboard(_ pasteboard: NSPasteboard) -> PasteboardContents {
        var savedItems: [[NSPasteboard.PasteboardType: Data]] = []

        for item in pasteboard.pasteboardItems ?? [] {
            var itemData: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    itemData[type] = data
                }
            }
            savedItems.append(itemData)
        }

        return PasteboardContents(items: savedItems)
    }

    private func restorePasteboard(_ pasteboard: NSPasteboard, contents: PasteboardContents) {
        pasteboard.clearContents()

        if contents.items.isEmpty { return }

        let newItems = contents.items.map { itemData -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in itemData {
                item.setData(data, forType: type)
            }
            return item
        }

        pasteboard.writeObjects(newItems)
    }
}
