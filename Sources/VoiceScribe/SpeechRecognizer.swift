import AppKit
import Speech
import AVFoundation

final class SpeechRecognizer {
    static let shared = SpeechRecognizer()

    private var recognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var currentLocale: Locale = Locale(identifier: "zh-CN")
    private var didReceiveResult = false

    private init() {
        updateLocale()
    }

    func requestPermission() {
        SFSpeechRecognizer.requestAuthorization { status in
            switch status {
            case .authorized:
                break
            case .denied, .restricted, .notDetermined:
                DispatchQueue.main.async {
                    self.showSpeechPermissionAlert()
                }
            @unknown default:
                break
            }
        }
    }

    func updateLocale() {
        let langCode = UserDefaults.standard.string(forKey: "selectedLanguage") ?? "zh-CN"
        currentLocale = Locale(identifier: langCode)
        recognizer = SFSpeechRecognizer(locale: currentLocale)
        recognizer?.defaultTaskHint = .dictation
    }

    func startRecognition(format: AVAudioFormat) {
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil

        guard let recognizer = recognizer, recognizer.isAvailable else {
            print("Speech recognizer not available for locale: \(currentLocale.identifier)")
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return }

        request.shouldReportPartialResults = true
        request.taskHint = .dictation

        // Enable on-device recognition if available
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = false // Allow cloud for better accuracy
        }

        didReceiveResult = false
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self = self else { return }

            if let result = result {
                self.didReceiveResult = true
                let transcript = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    OverlayWindowController.shared.updateTranscription(transcript)
                }

                if result.isFinal {
                    DispatchQueue.main.async {
                        self.handleFinalTranscription(transcript)
                    }
                }
            }

            if let error = error {
                let nsError = error as NSError
                // Ignore cancellation errors
                if nsError.code != 301 && nsError.domain != "kAFAssistantErrorDomain" {
                    print("Speech recognition error: \(error)")
                }
            }
        }
    }

    func append(buffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(buffer)
    }

    func stopRecognition() {
        recognitionRequest?.endAudio()
        // If no speech detected at all, always close overlay immediately
        if !didReceiveResult {
            OverlayWindowController.shared.hide()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.recognitionTask?.finish()
        }
    }

    private func handleFinalTranscription(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            OverlayWindowController.shared.hide()
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            TextInjector.shared.inject(text: trimmed)
        }
        OverlayWindowController.shared.hide()
    }

    private func showSpeechPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Speech Recognition Permission Required"
        alert.informativeText = "VoiceScribe needs speech recognition access. Please grant access in System Settings > Privacy & Security > Speech Recognition."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")!)
        }
    }
}
