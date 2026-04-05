import AppKit

final class OverlayWindowController {
    static let shared = OverlayWindowController()

    private var panel: NSPanel?
    private var waveformView: WaveformView?
    private var transcriptLabel: NSTextField?
    private var contentView: NSView?
    private var isShowing = false

    private let capsuleHeight: CGFloat = 56
    private let cornerRadius: CGFloat = 28
    private let waveformWidth: CGFloat = 44 + 16 // waveform + padding
    private let minLabelWidth: CGFloat = 160
    private let maxLabelWidth: CGFloat = 560
    private let labelPadding: CGFloat = 20

    private init() {}

    func show() {
        DispatchQueue.main.async { [weak self] in
            self?.showInternal()
        }
    }

    private func showInternal() {
        if panel == nil {
            createPanel()
        }

        guard let panel = panel else { return }

        updateLayout(labelWidth: minLabelWidth)

        // Position at bottom center of main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let panelFrame = panel.frame
            let x = screenFrame.midX - panelFrame.width / 2
            let y = screenFrame.minY + 40
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.alphaValue = 0
        panel.setIsVisible(true)
        panel.orderFrontRegardless()

        isShowing = true

        // Spring entrance animation
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1.0)
            panel.animator().alphaValue = 1.0
        }

        // Scale spring via layer animation
        if let contentView = panel.contentView {
            let anim = CASpringAnimation(keyPath: "transform.scale")
            anim.fromValue = 0.6
            anim.toValue = 1.0
            anim.mass = 1.0
            anim.stiffness = 300
            anim.damping = 20
            anim.duration = 0.35
            contentView.layer?.add(anim, forKey: "entranceScale")
        }

        // Start waveform animation loop
        waveformView?.startAnimating()
        AudioRecorder.shared.onRMSUpdate = { [weak self] rms in
            self?.waveformView?.updateRMS(rms)
        }
    }

    func updateTranscription(_ text: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.isShowing else { return }
            self.transcriptLabel?.stringValue = text

            // Calculate needed width
            let labelNeededWidth = self.measureTextWidth(text)
            let clampedWidth = max(self.minLabelWidth, min(self.maxLabelWidth, labelNeededWidth + 32))

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.25
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.updateLayout(labelWidth: clampedWidth)
                self.repositionPanel()
            }
        }
    }

    func hide() {
        DispatchQueue.main.async { [weak self] in
            self?.hideInternal()
        }
    }

    private func hideInternal() {
        guard isShowing, let panel = panel else { return }

        isShowing = false
        waveformView?.stopAnimating()
        AudioRecorder.shared.onRMSUpdate = nil

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0

            if let contentView = panel.contentView {
                let anim = CABasicAnimation(keyPath: "transform.scale")
                anim.fromValue = 1.0
                anim.toValue = 0.7
                anim.duration = 0.22
                anim.fillMode = .forwards
                anim.isRemovedOnCompletion = false
                contentView.layer?.add(anim, forKey: "exitScale")
            }
        }) { [weak self] in
            self?.panel?.setIsVisible(false)
            self?.transcriptLabel?.stringValue = ""
            self?.transcriptLabel?.textColor = NSColor.labelColor
            if let cv = self?.panel?.contentView {
                cv.layer?.removeAllAnimations()
            }
        }
    }

    private func createPanel() {
        let panelWidth = waveformWidth + labelPadding * 2 + minLabelWidth
        let panelFrame = NSRect(x: 0, y: 0, width: panelWidth, height: capsuleHeight)

        let newPanel = NSPanel(
            contentRect: panelFrame,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        newPanel.level = .floating
        newPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        newPanel.isOpaque = false
        newPanel.backgroundColor = .clear
        newPanel.hasShadow = true
        newPanel.hidesOnDeactivate = false
        newPanel.isMovable = false

        // Visual effect background
        let visualEffect = NSVisualEffectView(frame: panelFrame)
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = cornerRadius
        visualEffect.layer?.masksToBounds = true

        // Content container
        let container = NSView(frame: panelFrame)
        container.wantsLayer = true
        container.layer?.cornerRadius = cornerRadius
        container.layer?.masksToBounds = true

        // Waveform view
        let waveRect = NSRect(x: labelPadding, y: (capsuleHeight - 32) / 2, width: 44, height: 32)
        let wv = WaveformView(frame: waveRect)
        container.addSubview(wv)
        self.waveformView = wv

        // Transcript label
        let labelX = labelPadding + 44 + 12
        let labelRect = NSRect(x: labelX, y: (capsuleHeight - 22) / 2, width: minLabelWidth, height: 22)
        let label = NSTextField(labelWithString: "")
        label.frame = labelRect
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.cell?.truncatesLastVisibleLine = true
        container.addSubview(label)
        self.transcriptLabel = label

        let contentRoot = NSView(frame: panelFrame)
        contentRoot.wantsLayer = true
        contentRoot.addSubview(visualEffect)
        contentRoot.addSubview(container)

        newPanel.contentView = contentRoot
        self.panel = newPanel
        self.contentView = contentRoot
    }

    private func updateLayout(labelWidth: CGFloat) {
        let totalWidth = labelPadding + 44 + 12 + labelWidth + labelPadding
        let newFrame = NSRect(x: 0, y: 0, width: totalWidth, height: capsuleHeight)

        panel?.setContentSize(newFrame.size)

        contentView?.frame = newFrame
        contentView?.subviews.forEach { $0.frame = newFrame }

        let labelX = labelPadding + 44 + 12
        transcriptLabel?.frame = NSRect(x: labelX, y: (capsuleHeight - 22) / 2, width: labelWidth, height: 22)
    }

    private func repositionPanel() {
        guard let panel = panel, let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - panel.frame.width / 2
        let y = screenFrame.minY + 40
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func measureTextWidth(_ text: String) -> CGFloat {
        let font = NSFont.systemFont(ofSize: 15, weight: .medium)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let size = (text as NSString).size(withAttributes: attrs)
        return ceil(size.width)
    }
}
