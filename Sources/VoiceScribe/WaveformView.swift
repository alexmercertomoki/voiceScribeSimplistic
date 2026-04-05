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

    private var animationLink: CADisplayLink?
    private var barLayers: [CALayer] = []
    private var isAnimating = false
    private var cachedStartX: CGFloat = 0
    private var cachedTotalWidth: CGFloat = 0

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

        cachedTotalWidth = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * barSpacing
        cachedStartX = (bounds.width - cachedTotalWidth) / 2

        for i in 0..<barCount {
            let x = cachedStartX + CGFloat(i) * (barWidth + barSpacing)
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
        animationLink = window?.displayLink(target: self, selector: #selector(tick))
            ?? NSScreen.main?.displayLink(target: self, selector: #selector(tick))
        animationLink?.add(to: .main, forMode: .default)
    }

    private func stopDisplayLink() {
        animationLink?.invalidate()
        animationLink = nil
    }

    @objc private func tick() {
        guard isAnimating else { return }

        // Smooth RMS with attack/release envelope
        if targetRMS > currentRMS {
            currentRMS = currentRMS + attackCoeff * (targetRMS - currentRMS)
        } else {
            currentRMS = currentRMS + releaseCoeff * (targetRMS - currentRMS)
        }

        let time = CACurrentMediaTime()

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        for i in 0..<barCount {
            let weight = weights[i]

            let barTarget = currentRMS * weight
            if barTarget > smoothedLevels[i] {
                smoothedLevels[i] = smoothedLevels[i] + attackCoeff * (barTarget - smoothedLevels[i])
            } else {
                smoothedLevels[i] = smoothedLevels[i] + releaseCoeff * (barTarget - smoothedLevels[i])
            }

            let jitter = Float(sin(time * 3.7 + jitterPhases[i]) * 0.04)
            let level = max(0, min(1.0, smoothedLevels[i] + jitter))

            let barHeight = minBarHeight + CGFloat(level) * (maxBarHeight - minBarHeight)
            let y = (bounds.height - barHeight) / 2

            barLayers[i].frame = CGRect(x: cachedStartX + CGFloat(i) * (barWidth + barSpacing), y: y, width: barWidth, height: barHeight)
        }

        CATransaction.commit()
    }

    override func layout() {
        super.layout()
        setupBarLayers()
    }
}
