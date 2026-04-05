import Accelerate
import AppKit
import AVFoundation
import Speech

final class AudioRecorder {
    static let shared = AudioRecorder()

    private let audioEngine = AVAudioEngine()
    private var isRecording = false
    private var tapInstalled = false

    // RMS level published for waveform animation
    var rmsLevel: Float = 0.0
    var onRMSUpdate: ((Float) -> Void)?

    private init() {}

    func requestPermission() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if !granted {
                DispatchQueue.main.async {
                    self.showMicPermissionAlert()
                }
            }
        }
    }

    func startRecording() {
        guard !isRecording else { return }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        // Start speech recognizer
        SpeechRecognizer.shared.startRecognition(format: recordingFormat)

        // Install audio tap for both speech and RMS metering
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            // Feed to speech recognizer
            SpeechRecognizer.shared.append(buffer: buffer)
            // Calculate RMS
            self.calculateRMS(buffer: buffer)
        }
        tapInstalled = true

        do {
            try audioEngine.start()
            isRecording = true
            OverlayWindowController.shared.show()
        } catch {
            print("Audio engine start error: \(error)")
            inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
    }

    func stopRecording() {
        guard isRecording else { return }

        isRecording = false
        rmsLevel = 0.0
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }

        audioEngine.stop()
        SpeechRecognizer.shared.stopRecognition()
    }

    private func calculateRMS(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let channelDataValue = channelData.pointee
        let channelDataCount = Int(buffer.frameLength)

        var sumOfSquares: Float = 0
        vDSP_svesq(channelDataValue, 1, &sumOfSquares, vDSP_Length(channelDataCount))
        let rms = sqrt(sumOfSquares / Float(channelDataCount))
        let normalizedRMS = min(1.0, rms * 20.0) // Scale up for visibility

        rmsLevel = normalizedRMS
        onRMSUpdate?(normalizedRMS)
    }

    private func showMicPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Microphone Permission Required"
        alert.informativeText = "VoiceScribe needs microphone access to record your voice. Please grant access in System Settings > Privacy & Security > Microphone."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
        }
    }
}
