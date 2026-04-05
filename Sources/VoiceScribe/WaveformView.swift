import AppKit
import QuartzCore

final class WaveformView: NSView {
    // Bar weights: center highest, sides lower
    private let weights: [Float] = [0.5, 0.8, 1.0, 0.75, 0.55]
    private let barCount = 5
    private let barWidth: CGFloat = 4
    private let barSpacing: CGFloat = 3.5
    private let minBarHeight: CGFloat = 4
    private let maxBarHeight: CGFloat = 28

    // Smoothed envelope per bar
    private var smoothedLevels: [Float]
    private var targetRMS: Float = 0.0
    private var currentRMS: Float = 0.0

    // Random jitter seeds (stable per bar)
    private var jitterPhases: [Double]

    private var displayLink: CVDisplayLink?
    private var barLayers: [CALayer] = []
    private var isAnimating = false

    private let attackCoeff: Float = 0.40
    private let releaseCoeff: Float = 0.15

    override init(frame: NSRect) {
        smoothedLevels = Array(repeating: 0.0, count: 5)
        jitterPhases = (0..<5).map { Double($0) * 1.23456 + 0.7 }
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        setupBarLayers()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupBarLayers() {
        layer?.sublayers?.forEach { $0.removeFromSuperlayer() }
        barLayers = []

        let totalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing
        let startX = (bounds.width - totalWidth) / 2

        for i in 0..<barCount {
            let x = startX + CGFloat(i) * (barWidth + barSpacing)
            let barLayer = CALayer()
            barLayer.cornerRadius = barWidth / 2
            barLayer.backgroundColor = NSColor.white.withAlphaComponent(0.9).cgColor
            barLayer.frame = CGRect(x: x, y: (bounds.height - minBarHeight) / 2,
                                    width: barWidth, height: minBarHeight)
            layer?.addSublayer(barLayer)
            barLayers.append(barLayer)
        }
    }

    func updateRMS(_ rms: Float) {
        targetRMS = rms
    }

    func startAnimating() {
        guard !isAnimating else { return }
        isAnimating = true
        setupBarLayers()
        startDisplayLink()
    }

    func stopAnimating() {
        isAnimating = false
        stopDisplayLink()
        targetRMS = 0
        currentRMS = 0
        smoothedLevels = Array(repeating: 0.0, count: barCount)
        // Animate bars back to minimum
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.3)
        for (_, barLayer) in barLayers.enumerated() {
            let x = barLayer.frame.minX
            barLayer.frame = CGRect(x: x, y: (bounds.height - minBarHeight) / 2,
                                    width: barWidth, height: minBarHeight)
        }
        CATransaction.commit()
    }

    private func startDisplayLink() {
        var displayLinkRef: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLinkRef)
        guard let dl = displayLinkRef else { return }

        let callback: CVDisplayLinkOutputCallback = { _, _, _, _, _, userInfo in
            guard let userInfo = userInfo else { return kCVReturnSuccess }
            let waveform = Unmanaged<WaveformView>.fromOpaque(userInfo).takeUnretainedValue()
            waveform.tick()
            return kCVReturnSuccess
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(dl, callback, selfPtr)
        CVDisplayLinkStart(dl)
        self.displayLink = dl
    }

    private func stopDisplayLink() {
        if let dl = displayLink {
            CVDisplayLinkStop(dl)
        }
        displayLink = nil
    }

    private func tick() {
        // Smooth RMS with attack/release envelope
        if targetRMS > currentRMS {
            currentRMS = currentRMS + attackCoeff * (targetRMS - currentRMS)
        } else {
            currentRMS = currentRMS + releaseCoeff * (targetRMS - currentRMS)
        }

        let time = CACurrentMediaTime()

        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isAnimating else { return }

            CATransaction.begin()
            CATransaction.setDisableActions(true)

            let totalWidth = CGFloat(self.barCount) * self.barWidth + CGFloat(self.barCount - 1) * self.barSpacing
            let startX = (self.bounds.width - totalWidth) / 2

            for i in 0..<self.barCount {
                // Apply per-bar weight
                let weight = self.weights[i]

                // Smooth per-bar level with attack/release
                let barTarget = self.currentRMS * weight
                if barTarget > self.smoothedLevels[i] {
                    self.smoothedLevels[i] = self.smoothedLevels[i] + self.attackCoeff * (barTarget - self.smoothedLevels[i])
                } else {
                    self.smoothedLevels[i] = self.smoothedLevels[i] + self.releaseCoeff * (barTarget - self.smoothedLevels[i])
                }

                // Add organic jitter: ±4% of max height, slow oscillation
                let jitter = Float(sin(time * 3.7 + self.jitterPhases[i]) * 0.04)
                let level = max(0, min(1.0, self.smoothedLevels[i] + jitter))

                let barHeight = self.minBarHeight + CGFloat(level) * (self.maxBarHeight - self.minBarHeight)
                let x = startX + CGFloat(i) * (self.barWidth + self.barSpacing)
                let y = (self.bounds.height - barHeight) / 2

                self.barLayers[i].frame = CGRect(x: x, y: y, width: self.barWidth, height: barHeight)
            }

            CATransaction.commit()
        }
    }

    override func layout() {
        super.layout()
        setupBarLayers()
    }
}
