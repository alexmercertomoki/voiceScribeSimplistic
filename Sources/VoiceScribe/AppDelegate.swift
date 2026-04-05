import AppKit
import Carbon

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!

    // MARK: - Supported Languages
    struct SupportedLanguage {
        let displayName: String
        let code: String
    }

    static let languages: [SupportedLanguage] = [
        SupportedLanguage(displayName: "简体中文", code: "zh-CN"),
        SupportedLanguage(displayName: "English", code: "en-US"),
        SupportedLanguage(displayName: "繁體中文", code: "zh-TW"),
        SupportedLanguage(displayName: "日本語", code: "ja-JP"),
        SupportedLanguage(displayName: "한국어", code: "ko-KR"),
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set default language if not set
        if UserDefaults.standard.string(forKey: "selectedLanguage") == nil {
            UserDefaults.standard.set("zh-CN", forKey: "selectedLanguage")
        }

        setupStatusItem()

        // Request permissions
        SpeechRecognizer.shared.requestPermission()
        AudioRecorder.shared.requestPermission()

        // Setup Right Option key monitor
        RoKeyMonitor.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        RoKeyMonitor.shared.stop()
    }

    // MARK: - Status Item
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "VoiceScribe")
            button.image?.isTemplate = true
        }

        updateMenu()
    }

    func updateMenu() {
        let menu = NSMenu()

        // Language submenu
        let langMenu = NSMenu()
        let currentLang = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "zh-CN"

        for lang in AppDelegate.languages {
            let item = NSMenuItem(title: lang.displayName, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.representedObject = lang.code
            item.target = self
            if lang.code == currentLang {
                item.state = .on
            }
            langMenu.addItem(item)
        }

        let langItem = NSMenuItem(title: "Language / 语言", action: nil, keyEquivalent: "")
        menu.addItem(langItem)
        menu.setSubmenu(langMenu, for: langItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit VoiceScribe", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    // MARK: - Actions
    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let code = sender.representedObject as? String else { return }
        UserDefaults.standard.set(code, forKey: "selectedLanguage")
        updateMenu()
        SpeechRecognizer.shared.updateLocale()
    }

}
