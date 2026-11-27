import Cocoa
import QuartzCore
import WebKit
import Network
import ScreenCaptureKit
import Carbon
import CoreGraphics
import AVFoundation
import Vision
import CoreMedia
import CoreVideo

final class GhostPanel: NSPanel {
    var allowKeyWindow: Bool = true
    override var canBecomeKey: Bool { allowKeyWindow }
    override var canBecomeMain: Bool { false }
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        return frameRect
    }
}

final class FirstMouseWebView: WKWebView {
    var ignoreAllMouseEvents: Bool = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return !ignoreAllMouseEvents
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        return ignoreAllMouseEvents ? nil : super.hitTest(point)
    }
}

final class FlippedControlsView: NSView {
    override var isFlipped: Bool { true }
}

/// Custom sleek pill button for the pure-AppKit Dynamic Island (100% crisp, never blank!)
final class IslandPillButton: NSControl {
    var title: String { didSet { needsDisplay = true } }
    var isActiveTint: Bool = false { didSet { needsDisplay = true } }
    var isAlertTint: Bool = false { didSet { needsDisplay = true } }
    var isPrimary: Bool = false { didSet { needsDisplay = true } }
    var onClick: (() -> Void)?
    private var isHovered = false
    private var isPressed = false

    init(frame: NSRect, title: String, primary: Bool = false) {
        self.title = title
        self.isPrimary = primary
        super.init(frame: frame)
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func mouseEntered(with event: NSEvent) { isHovered = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { isHovered = false; isPressed = false; needsDisplay = true }
    override func mouseDown(with event: NSEvent) { isPressed = true; needsDisplay = true }
    override func mouseUp(with event: NSEvent) {
        let inside = bounds.contains(convert(event.locationInWindow, from: nil))
        isPressed = false
        needsDisplay = true
        if inside { onClick?() }
    }

    override func draw(_ dirtyRect: NSRect) {
        let bg: NSColor
        if isAlertTint {
            bg = isPressed
                ? NSColor(calibratedRed: 0.78, green: 0.16, blue: 0.18, alpha: 1.0)
                : (isHovered
                    ? NSColor(calibratedRed: 0.96, green: 0.28, blue: 0.30, alpha: 1.0)
                    : NSColor(calibratedRed: 0.88, green: 0.22, blue: 0.24, alpha: 0.95))
        } else if isPrimary || isActiveTint {
            bg = isPressed
                ? NSColor(calibratedRed: 0.03, green: 0.42, blue: 0.88, alpha: 1.0)
                : (isHovered
                    ? NSColor(calibratedRed: 0.12, green: 0.58, blue: 1.0, alpha: 1.0)
                    : NSColor(calibratedRed: 0.04, green: 0.52, blue: 1.0, alpha: 0.92))
        } else {
            bg = isPressed
                ? NSColor(calibratedWhite: 1.0, alpha: 0.24)
                : (isHovered
                    ? NSColor(calibratedWhite: 1.0, alpha: 0.18)
                    : NSColor(calibratedWhite: 1.0, alpha: 0.10))
        }
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 6.5, yRadius: 6.5)
        bg.setFill()
        path.fill()

        NSColor(calibratedWhite: 1.0, alpha: (isPrimary || isActiveTint || isAlertTint) ? 0.28 : 0.12).setStroke()
        path.lineWidth = 0.5
        path.stroke()

        let font = NSFont.systemFont(ofSize: 11.0, weight: (isPrimary || isActiveTint || isAlertTint) ? .semibold : .medium)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let sz = (title as NSString).size(withAttributes: attrs)
        let pt = NSPoint(x: (bounds.width - sz.width) * 0.5, y: (bounds.height - sz.height) * 0.5)
        (title as NSString).draw(at: pt, withAttributes: attrs)
    }
}

/// Draws the seamless pure-black Dynamic Island / Notch shell (Click-to-Expand, never accidental!)
final class DynamicIslandShellView: NSView {
    var isExpanded: Bool = false { didSet { needsDisplay = true } }
    var isPlayerPaused: Bool = true { didSet { needsDisplay = true } }
    var isRadarActive: Bool = false { didSet { needsDisplay = true } }
    var isRadarAlert: Bool = false { didSet { needsDisplay = true } }
    var earWidth: CGFloat = 46
    var onTogglePlay: (() -> Void)?
    var onToggleExpand: (() -> Void)?

    private var hoveredSide: Int = 0 // 0=none, 1=left ear, 2=right ear

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func mouseEntered(with event: NSEvent) { updateHover(with: event) }
    override func mouseMoved(with event: NSEvent) { updateHover(with: event) }
    override func mouseExited(with event: NSEvent) {
        hoveredSide = 0
        needsDisplay = true
    }

    private func updateHover(with event: NSEvent) {
        guard !isExpanded else { hoveredSide = 0; return }
        let pt = convert(event.locationInWindow, from: nil)
        let nextSide: Int
        if pt.x <= earWidth + 6 { nextSide = 1 }
        else if pt.x >= bounds.width - earWidth - 6 { nextSide = 2 }
        else { nextSide = 0 }
        if nextSide != hoveredSide {
            hoveredSide = nextSide
            needsDisplay = true
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard !isExpanded else { return }
        let pt = convert(event.locationInWindow, from: nil)
        if pt.x <= earWidth + 6 {
            onTogglePlay?()
        } else {
            // Click Right Ear or Center Notch to intentionally expand Dynamic Island!
            onToggleExpand?()
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let w = bounds.width
        let h = bounds.height
        let r: CGFloat = isExpanded ? 18.0 : 11.5
        let topFlare: CGFloat = 6.0

        let path = NSBezierPath()
        path.move(to: NSPoint(x: 0, y: h))
        path.curve(
            to: NSPoint(x: topFlare, y: h - topFlare),
            controlPoint1: NSPoint(x: topFlare * 0.65, y: h),
            controlPoint2: NSPoint(x: topFlare, y: h - topFlare * 0.35)
        )
        path.line(to: NSPoint(x: topFlare, y: r))
        path.curve(
            to: NSPoint(x: topFlare + r, y: 0),
            controlPoint1: NSPoint(x: topFlare, y: r * 0.44),
            controlPoint2: NSPoint(x: topFlare + r * 0.44, y: 0)
        )
        path.line(to: NSPoint(x: w - topFlare - r, y: 0))
        path.curve(
            to: NSPoint(x: w - topFlare, y: r),
            controlPoint1: NSPoint(x: w - topFlare - r * 0.44, y: 0),
            controlPoint2: NSPoint(x: w - topFlare, y: r * 0.44)
        )
        path.line(to: NSPoint(x: w - topFlare, y: h - topFlare))
        path.curve(
            to: NSPoint(x: w, y: h),
            controlPoint1: NSPoint(x: w - topFlare, y: h - topFlare * 0.35),
            controlPoint2: NSPoint(x: w - topFlare * 0.65, y: h)
        )
        path.close()

        NSColor(calibratedRed: 0.03, green: 0.04, blue: 0.06, alpha: 0.98).setFill()
        if !isExpanded { NSColor.black.setFill() }
        path.fill()

        NSColor(calibratedWhite: 1.0, alpha: isExpanded ? 0.18 : 0.12).setStroke()
        path.lineWidth = 1.0
        path.stroke()

        guard !isExpanded else { return }

        // Collapsed Left Ear: Live Green Dot + Play/Pause
        let cy = h * 0.5
        let leftCenter = topFlare + (earWidth - topFlare) * 0.52

        if hoveredSide == 1 {
            NSColor(calibratedWhite: 1.0, alpha: 0.16).setFill()
            NSBezierPath(roundedRect: NSRect(x: topFlare + 3, y: cy - 10, width: earWidth - topFlare - 4, height: 20), xRadius: 6, yRadius: 6).fill()
        }

        let dotColor: NSColor
        if isRadarAlert {
            dotColor = NSColor(calibratedRed: 0.98, green: 0.26, blue: 0.28, alpha: 1.0)
        } else if isRadarActive {
            dotColor = NSColor(calibratedRed: 0.22, green: 0.78, blue: 0.98, alpha: 1.0)
        } else if isPlayerPaused {
            dotColor = NSColor(calibratedRed: 0.20, green: 0.82, blue: 0.48, alpha: 0.85)
        } else {
            dotColor = NSColor(calibratedRed: 0.19, green: 0.88, blue: 0.40, alpha: 1.0)
        }
        dotColor.setFill()
        NSBezierPath(ovalIn: NSRect(x: leftCenter - 11.5, y: cy - 2.5, width: 5.0, height: 5.0)).fill()

        NSColor.white.setFill()
        let gx = leftCenter + 3.0
        if isPlayerPaused {
            let tri = NSBezierPath()
            tri.move(to: NSPoint(x: gx - 3.8, y: cy + 5.0))
            tri.line(to: NSPoint(x: gx - 3.8, y: cy - 5.0))
            tri.line(to: NSPoint(x: gx + 4.8, y: cy))
            tri.close()
            tri.fill()
        } else {
            NSBezierPath(roundedRect: NSRect(x: gx - 4.4, y: cy - 4.8, width: 2.8, height: 9.6), xRadius: 0.9, yRadius: 0.9).fill()
            NSBezierPath(roundedRect: NSRect(x: gx + 1.2, y: cy - 4.8, width: 2.8, height: 9.6), xRadius: 0.9, yRadius: 0.9).fill()
        }

        // Collapsed Right Ear: Sleek Chameleon Spiral Tail + Optical Lens Icon + Chevron
        let rightCenter = w - topFlare - (earWidth - topFlare) * 0.52
        if hoveredSide == 2 {
            NSColor(calibratedWhite: 1.0, alpha: 0.16).setFill()
            NSBezierPath(roundedRect: NSRect(x: w - earWidth + 1, y: cy - 10, width: earWidth - topFlare - 4, height: 20), xRadius: 6, yRadius: 6).fill()
        }

        NSColor(calibratedWhite: 1.0, alpha: 0.95).setStroke()
        let rx = rightCenter - 3.2
        // Chameleon arched back + head profile
        let cham = NSBezierPath()
        cham.move(to: NSPoint(x: rx - 6.8, y: cy - 1.2))
        cham.curve(
            to: NSPoint(x: rx + 6.4, y: cy - 0.5),
            controlPoint1: NSPoint(x: rx - 6.5, y: cy + 5.8),
            controlPoint2: NSPoint(x: rx + 3.5, y: cy + 5.6)
        )
        cham.line(to: NSPoint(x: rx + 2.2, y: cy - 2.2))
        // Curled chameleon spiral tail
        cham.move(to: NSPoint(x: rx - 6.8, y: cy - 1.2))
        cham.curve(
            to: NSPoint(x: rx - 2.2, y: cy - 4.8),
            controlPoint1: NSPoint(x: rx - 6.8, y: cy - 4.4),
            controlPoint2: NSPoint(x: rx - 4.5, y: cy - 5.2)
        )
        cham.curve(
            to: NSPoint(x: rx - 4.0, y: cy - 2.0),
            controlPoint1: NSPoint(x: rx - 0.8, y: cy - 4.2),
            controlPoint2: NSPoint(x: rx - 1.8, y: cy - 1.5)
        )
        cham.lineWidth = 1.4
        cham.lineCapStyle = .round
        cham.lineJoinStyle = .round
        cham.stroke()

        // Optical turret lens eye dot
        NSColor.white.setFill()
        NSBezierPath(ovalIn: NSRect(x: rx + 1.8, y: cy + 0.2, width: 2.3, height: 2.3)).fill()

        let chev = NSBezierPath()
        let chx = rightCenter + 9.2
        chev.move(to: NSPoint(x: chx - 2.4, y: cy + 1.2))
        chev.line(to: NSPoint(x: chx, y: cy - 1.6))
        chev.line(to: NSPoint(x: chx + 2.4, y: cy + 1.2))
        chev.lineWidth = 1.3
        chev.lineCapStyle = .round
        chev.lineJoinStyle = .round
        chev.stroke()
    }
}

/// Black Tech #1: 100% On-Device Apple Vision Anti-Peek Radar (zero upload, zero storage!)
final class VisionAntiPeekRadar: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.chameleon.vision.radar", qos: .utility)
    private var isConfigured = false
    private var isActive = false
    private var lastAnalyzeTime: CFTimeInterval = 0

    var onFaceCount: ((Int) -> Void)?
    var onStarted: (() -> Void)?
    var onError: ((String) -> Void)?

    func start() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            queue.async { [weak self] in self?.configureAndStartLocked() }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self = self else { return }
                if granted {
                    self.queue.async { self.configureAndStartLocked() }
                } else {
                    DispatchQueue.main.async { self.onError?("camera_denied") }
                }
            }
        default:
            DispatchQueue.main.async { self.onError?("camera_denied") }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.isActive = false
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    private func configureAndStartLocked() {
        if !isConfigured {
            session.beginConfiguration()
            if session.canSetSessionPreset(.cif352x288) {
                session.sessionPreset = .cif352x288
            } else if session.canSetSessionPreset(.low) {
                session.sessionPreset = .low
            }

            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                session.commitConfiguration()
                DispatchQueue.main.async { self.onError?("no_camera") }
                return
            }
            session.addInput(input)

            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: queue)
            guard session.canAddOutput(output) else {
                session.commitConfiguration()
                DispatchQueue.main.async { self.onError?("no_camera") }
                return
            }
            session.addOutput(output)
            session.commitConfiguration()
            isConfigured = true
        }

        isActive = true
        if !session.isRunning {
            session.startRunning()
        }
        DispatchQueue.main.async { [weak self] in self?.onStarted?() }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isActive else { return }
        let now = CACurrentMediaTime()
        guard now - lastAnalyzeTime >= 0.30 else { return }
        lastAnalyzeTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let req = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([req])
            let faces = (req.results ?? []).filter { $0.boundingBox.width >= 0.028 && $0.boundingBox.height >= 0.028 }
            let count = faces.count
            DispatchQueue.main.async { [weak self] in
                self?.onFaceCount?(count)
            }
        } catch {
            // Silently ignore single frame Vision error
        }
    }
}

/// Helper target for quick-fill site preset buttons inside the native Web URL prompt dialog
final class UrlPresetTarget: NSObject {
    weak var textField: NSTextField?
    init(textField: NSTextField) { self.textField = textField }
    @objc func pickBilibili() { textField?.stringValue = "https://www.bilibili.com" }
    @objc func pickYouTube() { textField?.stringValue = "https://www.youtube.com" }
    @objc func pickDouyin() { textField?.stringValue = "https://www.douyin.com" }
}

final class LocalWebSocketHub {
    private var listeners: [NWListener] = []
    private let queue = DispatchQueue(label: "com.geckopip.wshub", qos: .userInteractive)
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private var ghostViewIds: Set<ObjectIdentifier> = []
    private var arenaViewIds: Set<ObjectIdentifier> = []
    private var producerIds: Set<ObjectIdentifier> = []
    private var offscreenIds: Set<ObjectIdentifier> = []
    // Credit-gated 1-frame mailbox: prevents TCP/WebKit IPC queue buildup across hours of streaming
    private var sendingBinary: Set<ObjectIdentifier> = []
    private var pendingBinary: [ObjectIdentifier: Data] = [:]
    private var ghostCredits: [ObjectIdentifier: Int] = [:]
    private var ghostLastSendTime: [ObjectIdentifier: CFAbsoluteTime] = [:]
    private var lastExternalProducerNotifyAt: CFAbsoluteTime = 0
    var onArenaConnected: (() -> Void)?
    var onExternalProducerActive: (() -> Void)?
    var onGhostCommandForBuiltIn: ((String) -> Void)?

    func start(ports: [UInt16] = [27182, 51937]) {
        for port in ports {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            if let tcpOpts = params.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options {
                tcpOpts.noDelay = true
            }
            let wsOptions = NWProtocolWebSocket.Options()
            wsOptions.autoReplyPing = true
            wsOptions.maximumMessageSize = 4 * 1024 * 1024
            params.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

            guard let nwPort = NWEndpoint.Port(rawValue: port) else { continue }
            params.requiredLocalEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host("127.0.0.1"), port: nwPort)

            do {
                let l = try NWListener(using: params)
                l.stateUpdateHandler = { state in
                    if case .failed(let err) = state {
                        NSLog("[GeckoGhost] WS listener failed on port \(port): \(err)")
                    }
                }
                l.newConnectionHandler = { [weak self] conn in self?.handleNewConnection(conn) }
                l.start(queue: queue)
                self.listeners.append(l)
            } catch {
                NSLog("[GeckoGhost] WS listener error on port \(port): \(error)")
            }
        }
    }

    private func handleNewConnection(_ conn: NWConnection) {
        let id = ObjectIdentifier(conn)
        connections[id] = conn
        conn.stateUpdateHandler = { [weak self] state in
            if case .failed = state { self?.cleanup(id) }
            if case .cancelled = state { self?.cleanup(id) }
        }
        conn.start(queue: queue)
        receiveLoop(conn, id: id)
    }

    private func cleanup(_ id: ObjectIdentifier) {
        if let conn = connections.removeValue(forKey: id) {
            conn.stateUpdateHandler = nil
            conn.cancel()
        }
        ghostViewIds.remove(id)
        arenaViewIds.remove(id)
        producerIds.remove(id)
        offscreenIds.remove(id)
        sendingBinary.remove(id)
        pendingBinary.removeValue(forKey: id)
        ghostCredits.removeValue(forKey: id)
        ghostLastSendTime.removeValue(forKey: id)
    }

    func sendTextToArena(_ json: String) {
        guard let data = json.data(using: .utf8) else { return }
        queue.async { [weak self] in
            guard let self = self else { return }
            let meta = NWProtocolWebSocket.Metadata(opcode: .text)
            let ctx = NWConnection.ContentContext(identifier: "wsArena", metadata: [meta])
            for cid in self.arenaViewIds {
                self.connections[cid]?.send(content: data, contentContext: ctx, isComplete: true, completion: .idempotent)
            }
        }
    }

    func pushLocalBuiltInFrame(_ data: Data) {
        queue.async { [weak self] in
            guard let self = self else { return }
            for cid in self.ghostViewIds {
                if let c = self.connections[cid] {
                    self.enqueueOrSendBinary(data, to: cid, conn: c)
                }
            }
        }
    }

    func pushLocalBuiltInText(_ json: String) {
        guard let data = json.data(using: .utf8) else { return }
        queue.async { [weak self] in
            guard let self = self else { return }
            let meta = NWProtocolWebSocket.Metadata(opcode: .text)
            let ctx = NWConnection.ContentContext(identifier: "wsLocalText", metadata: [meta])
            for cid in self.ghostViewIds {
                self.connections[cid]?.send(content: data, contentContext: ctx, isComplete: true, completion: .idempotent)
            }
            if json.contains("\"type\":\"meta\"") || json.contains("\"type\":\"streamStopped\"") {
                for aid in self.arenaViewIds {
                    self.connections[aid]?.send(content: data, contentContext: ctx, isComplete: true, completion: .idempotent)
                }
            }
        }
    }

    private func receiveLoop(_ conn: NWConnection, id: ObjectIdentifier) {
        conn.receiveMessage { [weak self] data, context, _, error in
            guard let self = self else { return }
            if let data = data, !data.isEmpty {
                let wsMeta = context?.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata
                let opcode = wsMeta?.opcode ?? .binary

                if opcode == .text, let text = String(data: data, encoding: .utf8) {
                    if text == "ack" {
                        self.ghostCredits[id] = min(2, (self.ghostCredits[id] ?? 0) + 1)
                        if !self.sendingBinary.contains(id),
                           (self.ghostCredits[id] ?? 0) > 0,
                           let next = self.pendingBinary.removeValue(forKey: id),
                           let liveConn = self.connections[id] {
                            self.ghostCredits[id] = max(0, (self.ghostCredits[id] ?? 1) - 1)
                            self.dispatchBinaryNow(next, to: id, conn: liveConn)
                        }
                    } else if text.contains("\"role\":\"ghostView\"") {
                        self.ghostViewIds.insert(id)
                        self.ghostCredits[id] = 2
                        self.ghostLastSendTime[id] = CFAbsoluteTimeGetCurrent()
                    } else if text.contains("\"role\":\"arenaView\"") {
                        self.arenaViewIds.insert(id)
                        self.onArenaConnected?()
                    } else if text.contains("\"role\":\"offscreenController\"") {
                        self.offscreenIds.insert(id)
                    } else if text.contains("\"role\":\"streamProducer\"") {
                        self.producerIds.insert(id)
                    } else if self.arenaViewIds.contains(id) {
                        if text.contains("\"type\":\"membershipUpdated\"") {
                            self.broadcast(data: data, opcode: .text, toGhostViews: true, sender: id)
                        }
                    } else if self.ghostViewIds.contains(id) {
                        if text.contains("\"type\":\"videoPlaybackState\"") {
                            let meta = NWProtocolWebSocket.Metadata(opcode: .text)
                            let ctx = NWConnection.ContentContext(identifier: "wsArenaPlay", metadata: [meta])
                            for aid in self.arenaViewIds {
                                self.connections[aid]?.send(content: data, contentContext: ctx, isComplete: true, completion: .idempotent)
                            }
                        } else {
                            if let cb = self.onGhostCommandForBuiltIn {
                                DispatchQueue.main.async { cb(text) }
                            }
                            self.broadcast(data: data, opcode: .text, toGhostViews: false, sender: id)
                        }
                    } else {
                        self.broadcast(data: data, opcode: .text, toGhostViews: true, sender: id)
                        // Also mirror meta telemetry to any open Arena Leaderboard / PK window!
                        let meta = NWProtocolWebSocket.Metadata(opcode: .text)
                        let ctx = NWConnection.ContentContext(identifier: "wsArenaMeta", metadata: [meta])
                        for aid in self.arenaViewIds {
                            self.connections[aid]?.send(content: data, contentContext: ctx, isComplete: true, completion: .idempotent)
                        }
                    }
                } else if opcode == .binary {
                    if self.producerIds.contains(id) || self.offscreenIds.contains(id) {
                        let now = CFAbsoluteTimeGetCurrent()
                        if now - self.lastExternalProducerNotifyAt > 0.8 {
                            self.lastExternalProducerNotifyAt = now
                            DispatchQueue.main.async { [weak self] in
                                self?.onExternalProducerActive?()
                            }
                        }
                    }
                    self.broadcast(data: data, opcode: .binary, toGhostViews: true, sender: id)
                }
            }
            if error == nil { self.receiveLoop(conn, id: id) }
            else { self.cleanup(id) }
        }
    }

    private func enqueueOrSendBinary(_ data: Data, to cid: ObjectIdentifier, conn: NWConnection) {
        let now = CFAbsoluteTimeGetCurrent()
        // Deadlock recovery guard: restore credit if a client missed ACKs for >450ms
        if (ghostCredits[cid] ?? 0) <= 0 && now - (ghostLastSendTime[cid] ?? 0) > 0.45 && !sendingBinary.contains(cid) {
            ghostCredits[cid] = 2
        }
        if (ghostCredits[cid] ?? 0) <= 0 || sendingBinary.contains(cid) {
            // Overwrite stale frame in Swift RAM (zero kernel TCP or WebKit IPC backlog!)
            pendingBinary[cid] = data
            return
        }
        ghostCredits[cid] = max(0, (ghostCredits[cid] ?? 1) - 1)
        dispatchBinaryNow(data, to: cid, conn: conn)
    }

    private func dispatchBinaryNow(_ data: Data, to cid: ObjectIdentifier, conn: NWConnection) {
        sendingBinary.insert(cid)
        ghostLastSendTime[cid] = CFAbsoluteTimeGetCurrent()
        let meta = NWProtocolWebSocket.Metadata(opcode: .binary)
        let ctx = NWConnection.ContentContext(identifier: "wsBin", metadata: [meta])
        conn.send(content: data, contentContext: ctx, isComplete: true, completion: .contentProcessed { [weak self] err in
            guard let self = self else { return }
            self.sendingBinary.remove(cid)
            if err != nil {
                self.cleanup(cid)
                return
            }
            if (self.ghostCredits[cid] ?? 0) > 0,
               let next = self.pendingBinary.removeValue(forKey: cid),
               let liveConn = self.connections[cid] {
                self.ghostCredits[cid] = max(0, (self.ghostCredits[cid] ?? 1) - 1)
                self.dispatchBinaryNow(next, to: cid, conn: liveConn)
            }
        })
    }

    private func broadcast(data: Data, opcode: NWProtocolWebSocket.Opcode, toGhostViews: Bool, sender: ObjectIdentifier) {
        if opcode == .binary {
            for (cid, c) in connections where cid != sender {
                if ghostViewIds.contains(cid) == toGhostViews {
                    enqueueOrSendBinary(data, to: cid, conn: c)
                }
            }
            return
        }
        let meta = NWProtocolWebSocket.Metadata(opcode: opcode)
        let ctx = NWConnection.ContentContext(identifier: "wsFrame", metadata: [meta])
        if toGhostViews {
            for cid in ghostViewIds where cid != sender {
                connections[cid]?.send(content: data, contentContext: ctx, isComplete: true, completion: .idempotent)
            }
            return
        }

        // Control cmds & statePatch from ghostView: strictly route to offscreenController OR direct streamProducer
        if !offscreenIds.isEmpty {
            for cid in offscreenIds where cid != sender {
                connections[cid]?.send(content: data, contentContext: ctx, isComplete: true, completion: .idempotent)
            }
        } else if !producerIds.isEmpty {
            for cid in producerIds where cid != sender {
                connections[cid]?.send(content: data, contentContext: ctx, isComplete: true, completion: .idempotent)
            }
        } else {
            for (cid, c) in connections where cid != sender && !ghostViewIds.contains(cid) && !arenaViewIds.contains(cid) {
                c.send(content: data, contentContext: ctx, isComplete: true, completion: .idempotent)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, WKScriptMessageHandler, WKUIDelegate, WKNavigationDelegate {
    private var panel: GhostPanel!
    private var webView: WKWebView!
    private var builtInWebView: FirstMouseWebView?
    private var isBuiltInWebActive: Bool = false
    private var builtInVideoIsolated: Bool = false
    private var builtInSnapshotTimer: Timer?
    private var builtInSnapshotBusy: Bool = false
    private var currentBuiltInUrl: String = ""
    private var cachedBiliCookie: String = ""

    // Independent Multi-Line Developer Terminal / Output Log Window (zero video obstruction!)
    private var logPanel: GhostPanel?
    private var logWebView: FirstMouseWebView?
    private var lastLogConsoleJson: String = ""

    // Independent Full-Web Stealth Search Browser Window (never covers the small PiP window!)
    private var searchWindow: NSWindow?
    private var searchToolbarView: FlippedControlsView?
    private var searchOmnibox: NSTextField?
    private var segSearchEngine: NSSegmentedControl?
    private var btnBrowserGray: IslandPillButton?
    private var searchWebView: FirstMouseWebView?
    private var browserGrayCamo: Bool = true
    private var wasSearchWindowOpenBeforeBoss: Bool = false

    // Pure-AppKit Compact Dynamic Island (316 x 240pt — fast, compact, 100% native, never blank!)
    private var islandPanel: GhostPanel!
    private var islandShell: DynamicIslandShellView!
    private var controlsContainer: FlippedControlsView!
    private var lblBrand: NSTextField!
    private var lblCurTime: NSTextField!
    private var lblDurTime: NSTextField!
    private var progressSlider: NSSlider!
    private var btnPlayMain: IslandPillButton!
    private var btnRate: IslandPillButton!
    private var btnMute: IslandPillButton!
    private var segMode: NSSegmentedControl!
    private var stealthSlider: NSSlider!
    private var btnHoverReveal: IslandPillButton!
    private var btnThrough: IslandPillButton!
    private var btnVis: IslandPillButton!
    private var btnRadar: IslandPillButton!
    private var btnWebUrl: IslandPillButton!
    private var btnStealthSub: IslandPillButton!
    private var lblStreakBadge: NSTextField!
    private var arenaWindow: NSWindow?
    private var arenaWebView: WKWebView?
    private var currentStreakSec: Int = 0
    private var totalSlackingSec: Int = UserDefaults.standard.integer(forKey: "chameleonTotalSec")
    private var pausedSecondsCount: Int = 0

    // Black Tech #1: 100% Free Unlimited On-Device Apple Vision Anti-Peek Radar
    private let antiPeekRadar = VisionAntiPeekRadar()
    private var radarEnabled: Bool = false
    private var radarAlertActive: Bool = false
    private var bossTriggeredByRadar: Bool = false
    private var radarSafeStreakCount: Int = 0
    private var radarLastFaceCount: Int = 0

    // Black Tech #3: Disguised Code/Terminal Log Subtitle Bar
    private var stealthSubtitleEnabled: Bool = UserDefaults.standard.bool(forKey: "chameleonStealthSubtitle")

    private var isIslandExpanded: Bool = false
    private let wsHub = LocalWebSocketHub()

    private var clickThrough: Bool = false
    private var bossMode: Bool = false
    private var autoSense: Bool = true
    private var hideFromCapture: Bool = true
    private var isVisible: Bool = true
    private var hoverRevealEnabled: Bool = UserDefaults.standard.bool(forKey: "chameleonHoverReveal")
    private var isProMember: Bool = UserDefaults.standard.bool(forKey: "chameleonIsPro")
    private var pendingUpgradeReason: String? = nil

    private var isPlayerPaused: Bool = true
    private var hasActiveVideoPlaying: Bool = false
    private var telemetryTickCount: Int = 0
    private var playerCurTime: Double = 0
    private var playerDuration: Double = 180
    private var playerMuted: Bool = false
    private var playerRate: Double = 1.0

    private var currentMode: String = "projector"
    private var currentStealth: Int = 58
    private var currentOpacity: Int = 100
    private var currentFeather: Int = 28

    private var lastKeyTime: TimeInterval = 0
    private var dragOriginOffset: NSPoint?
    private var dragDownScreenPt: NSPoint?
    private var isDraggingWindow: Bool = false
    private var activeResizeDir: String?
    private var resizeInitialFrame: NSRect = .zero
    private var resizeStartMouse: NSPoint = .zero
    private weak var activeDragWindow: NSWindow?
    private var pointerTrackTimer: Timer?
    private var isWindowHovered: Bool = false
    private var lastExternalApp: (name: String, archetype: String) = ("桌面", "web")
    private var lastSensedAppName: String = ""
    private var lastSensedFrame: NSRect = .zero
    private var senseDebounceWork: DispatchWorkItem?
    private var hotKeyRefs: [EventHotKeyRef?] = []
    private var appNapActivity: NSObjectProtocol?

    // Native macOS Menu Bar Status Item (allows standalone launch/control anytime without Chrome!)
    private var statusItem: NSStatusItem?
    private var menuShowHideItem: NSMenuItem?
    private var menuSearchItem: NSMenuItem?
    private var menuLogSubItem: NSMenuItem?
    private var menuRadarItem: NSMenuItem?
    private var menuBossItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStandardMainMenu()
        appNapActivity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep, .latencyCritical],
            reason: "ChameleonPiP 60fps Real-Time Video Camouflage"
        )
        configureAntiPeekRadarCallbacks()
        wsHub.onArenaConnected = { [weak self] in
            DispatchQueue.main.async {
                self?.broadcastPlaybackStateToArena()
            }
        }
        wsHub.onExternalProducerActive = { [weak self] in
            guard let self = self else { return }
            if self.isBuiltInWebActive {
                self.exitBuiltInWebMode()
            }
            if !self.isVisible {
                self.isVisible = true
            }
            if self.bossMode {
                self.setBoss(false)
            }
            self.panel?.orderFrontRegardless()
            self.syncNativeIslandControls()
        }
        wsHub.onGhostCommandForBuiltIn = { [weak self] rawText in
            self?.handleGhostCommandForBuiltIn(rawText)
        }
        wsHub.start(ports: [27182, 51937])
        setupGhostPanel()
        setupDynamicNotchIsland()
        setupMenuBarStatusItem()
        if stealthSubtitleEnabled {
            setStealthLogPanelVisible(true)
        }
        registerGlobalHotKeys()
        setupGlobalTypingSensor()
        startAutoSceneLoop()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.layoutDynamicIsland(animated: false)
        }
    }

    private func makeMenuBarTemplateIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let img = NSImage(size: size)
        img.lockFocus()
        NSColor.black.setStroke()
        NSColor.black.setFill()

        // Outer borderless PiP frame with chameleon inner eye lens
        let outer = NSBezierPath(roundedRect: NSRect(x: 2.0, y: 3.2, width: 14.0, height: 11.6), xRadius: 3.0, yRadius: 3.0)
        outer.lineWidth = 1.45
        outer.stroke()

        let eyeRing = NSBezierPath(ovalIn: NSRect(x: 6.2, y: 6.2, width: 5.6, height: 5.6))
        eyeRing.lineWidth = 1.25
        eyeRing.stroke()

        let pupil = NSBezierPath(ovalIn: NSRect(x: 8.1, y: 8.1, width: 1.8, height: 1.8))
        pupil.fill()

        img.unlockFocus()
        img.isTemplate = true
        return img
    }

    private func setupMenuBarStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = item.button {
            btn.image = makeMenuBarTemplateIcon()
            btn.imagePosition = .imageOnly
            btn.toolTip = "变色龙画中画 ChameleonPiP"
        }

        let menu = NSMenu()
        let miShow = NSMenuItem(title: "隐藏变色龙小窗 (⌃⇧G)", action: #selector(toggleGhostPanelFromMenu), keyEquivalent: "")
        miShow.target = self
        menu.addItem(miShow)

        let miSearch = NSMenuItem(title: "打开独立搜片浏览器 (⌃⇧S)", action: #selector(openSearchFromMenu), keyEquivalent: "")
        miSearch.target = self
        menu.addItem(miSearch)

        let miUrl = NSMenuItem(title: "粘贴网址直连播放...", action: #selector(openUrlPromptFromMenu), keyEquivalent: "")
        miUrl.target = self
        menu.addItem(miUrl)

        let miLocal = NSMenuItem(title: "打开本地 MP4 视频...", action: #selector(openLocalFileFromMenu), keyEquivalent: "")
        miLocal.target = self
        menu.addItem(miLocal)

        menu.addItem(NSMenuItem.separator())

        let miLog = NSMenuItem(title: "代码日志伪装字幕", action: #selector(toggleStealthSubFromMenu), keyEquivalent: "")
        miLog.target = self
        menu.addItem(miLog)

        let miRadar = NSMenuItem(title: "AI 背后防偷窥雷达", action: #selector(toggleRadarFromMenu), keyEquivalent: "")
        miRadar.target = self
        menu.addItem(miRadar)

        let miBoss = NSMenuItem(title: "老板键一键秒隐 (⌃⇧B)", action: #selector(toggleBossFromMenu), keyEquivalent: "")
        miBoss.target = self
        menu.addItem(miBoss)

        menu.addItem(NSMenuItem.separator())

        let miArena = NSMenuItem(title: "全球排行榜 & 支持者中心", action: #selector(openArenaFromMenu), keyEquivalent: "")
        miArena.target = self
        menu.addItem(miArena)

        menu.addItem(NSMenuItem.separator())

        let miQuit = NSMenuItem(title: "退出变色龙画中画", action: #selector(quitAppFromMenu), keyEquivalent: "q")
        miQuit.target = self
        menu.addItem(miQuit)

        item.menu = menu
        self.statusItem = item
        self.menuShowHideItem = miShow
        self.menuSearchItem = miSearch
        self.menuLogSubItem = miLog
        self.menuRadarItem = miRadar
        self.menuBossItem = miBoss
        syncMenuBarItems()
    }

    private func syncMenuBarItems() {
        menuShowHideItem?.title = isVisible ? "隐藏变色龙小窗 (⌃⇧G)" : "显示变色龙小窗 (⌃⇧G)"
        menuSearchItem?.title = (searchWindow?.isVisible ?? false) ? "收起独立搜片浏览器 (⌃⇧S)" : "打开独立搜片浏览器 (⌃⇧S)"
        menuLogSubItem?.state = stealthSubtitleEnabled ? .on : .off
        menuRadarItem?.state = radarEnabled ? .on : .off
        menuRadarItem?.title = radarEnabled ? "AI 背后防偷窥雷达（检测 \(radarLastFaceCount) 人）" : "AI 背后防偷窥雷达"
        menuBossItem?.state = bossMode ? .on : .off
    }

    @objc private func toggleGhostPanelFromMenu() {
        isVisible.toggle()
        if isVisible {
            if bossMode { setBoss(false) }
            panel?.orderFrontRegardless()
        } else {
            panel?.orderOut(nil)
        }
        broadcastPlaybackStateToArena()
        syncNativeIslandControls()
    }

    @objc private func openSearchFromMenu() {
        if searchWindow?.isVisible == true {
            searchWindow?.orderOut(nil)
            syncNativeIslandControls()
        } else {
            openSearchBrowserWindow()
        }
    }

    @objc private func openUrlPromptFromMenu() {
        openWebVideoUrlPrompt()
    }

    @objc private func openLocalFileFromMenu() {
        openLocalVideoFile()
    }

    @objc private func toggleStealthSubFromMenu() {
        setStealthSubtitle(!stealthSubtitleEnabled)
    }

    @objc private func toggleRadarFromMenu() {
        toggleAntiPeekRadar()
    }

    @objc private func toggleBossFromMenu() {
        setBoss(!bossMode)
    }

    @objc private func openArenaFromMenu() {
        openArenaWindow()
    }

    @objc private func quitAppFromMenu() {
        NSApp.terminate(nil)
    }

    private func hasActiveShieldEntitlement() -> Bool {
        return true
    }

    private func setupStandardMainMenu() {
        let mainMenu = NSMenu()
        let editItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        mainMenu.addItem(editItem)
        mainMenu.setSubmenu(editMenu, for: editItem)
        NSApp.mainMenu = mainMenu
    }

    private func updatePanelSharingType() {
        panel?.sharingType = hideFromCapture ? .none : .readOnly
        searchWindow?.sharingType = hideFromCapture ? .none : .readOnly
        logPanel?.sharingType = hideFromCapture ? .none : .readOnly
    }

    private func configureAntiPeekRadarCallbacks() {
        antiPeekRadar.onStarted = { [weak self] in
            guard let self = self else { return }
            self.radarEnabled = true
            self.radarAlertActive = false
            self.radarSafeStreakCount = 0
            self.islandShell?.isRadarActive = true
            self.islandShell?.isRadarAlert = false
            self.syncNativeIslandControls()
        }
        antiPeekRadar.onError = { [weak self] code in
            guard let self = self else { return }
            self.radarEnabled = false
            self.radarAlertActive = false
            self.islandShell?.isRadarActive = false
            self.islandShell?.isRadarAlert = false
            self.syncNativeIslandControls()
            self.showCameraPermissionHelp(code: code)
        }
        antiPeekRadar.onFaceCount = { [weak self] count in
            guard let self = self, self.radarEnabled else { return }
            let prevCount = self.radarLastFaceCount
            self.radarLastFaceCount = count
            if count >= 2 {
                self.radarSafeStreakCount = 0
                if !self.bossMode {
                    self.bossTriggeredByRadar = true
                    self.radarAlertActive = true
                    self.islandShell?.isRadarAlert = true
                    self.setBoss(true)
                } else if self.bossTriggeredByRadar && !self.radarAlertActive {
                    self.radarAlertActive = true
                    self.islandShell?.isRadarAlert = true
                    self.syncNativeIslandControls()
                } else if prevCount != count {
                    self.syncNativeIslandControls()
                }
            } else {
                if self.bossTriggeredByRadar && self.bossMode {
                    self.radarSafeStreakCount += 1
                    // ~2.4 seconds continuously clear (8 checks * 0.3s) -> auto-recover!
                    if self.radarSafeStreakCount >= 8 {
                        self.bossTriggeredByRadar = false
                        self.radarAlertActive = false
                        self.radarSafeStreakCount = 0
                        self.islandShell?.isRadarAlert = false
                        self.setBoss(false)
                    } else if prevCount != count {
                        self.syncNativeIslandControls()
                    }
                } else if self.radarAlertActive {
                    self.radarAlertActive = false
                    self.islandShell?.isRadarAlert = false
                    self.syncNativeIslandControls()
                } else if prevCount != count {
                    self.syncNativeIslandControls()
                }
            }
        }
    }

    private func showCameraPermissionHelp(code: String) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.alertStyle = .informational
        if code == "no_camera" {
            alert.messageText = "未检测到可用摄像头"
            alert.informativeText = "AI 背后防偷窥雷达需要使用本机前置摄像头进行 100% 本地人脸数量检测。"
            alert.addButton(withTitle: "知道了")
            alert.runModal()
        } else {
            alert.messageText = "需要允许本机摄像头权限"
            alert.informativeText = "ChameleonPiP 的「AI 背后防偷窥雷达」100% 运行在本地内存中（调用 Apple Vision 仅统计画面人数，画面实时丢弃，绝不录制或上传）。请在系统设置 → 隐私与安全性 → 摄像头中开启允许。"
            alert.addButton(withTitle: "打开系统设置")
            alert.addButton(withTitle: "暂不开启")
            if alert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    private func toggleAntiPeekRadar() {
        if radarEnabled {
            radarEnabled = false
            radarAlertActive = false
            bossTriggeredByRadar = false
            radarSafeStreakCount = 0
            antiPeekRadar.stop()
            islandShell?.isRadarActive = false
            islandShell?.isRadarAlert = false
            syncNativeIslandControls()
            return
        }
        antiPeekRadar.start()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        isVisible = true
        if bossMode { setBoss(false) }
        panel?.orderFrontRegardless()
        if !hasActiveVideoPlaying && !(searchWindow?.isVisible ?? false) {
            openSearchBrowserWindow()
        }
        syncNativeIslandControls()
        return true
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        isVisible = true
        if bossMode { setBoss(false) }
        panel?.orderFrontRegardless()
        if urls.contains(where: { $0.host == "search" || $0.path.contains("search") }) {
            openSearchBrowserWindow()
        }
        syncNativeIslandControls()
    }

    private func setupGhostPanel() {
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let w: CGFloat = 392
        let h: CGFloat = 220
        let initialRect = NSRect(x: screenFrame.maxX - w - 26, y: screenFrame.minY + 26, width: w, height: h)

        panel = GhostPanel(
            contentRect: initialRect,
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.sharingType = (hideFromCapture && hasActiveShieldEntitlement()) ? .none : .readOnly
        panel.ignoresMouseEvents = clickThrough
        panel.minSize = NSSize(width: 190, height: 110)

        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "ghostAction")
        config.mediaTypesRequiringUserActionForPlayback = []

        webView = FirstMouseWebView(frame: panel.contentView!.bounds, configuration: config)
        webView.autoresizingMask = [.width, .height]
        webView.setValue(false, forKey: "drawsBackground")
        panel.contentView?.addSubview(webView)

        if let htmlURL = Bundle.main.url(forResource: "ghost-view", withExtension: "html") {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: URL(fileURLWithPath: "/"))
        }

        // Background-safe Hover Detector: respects the `hoverRevealEnabled` switch!
        // When OFF, hovering the small window stays 100% stealthy (hold Option ⌥ to peek anytime).
        let hoverTimer = Timer(timeInterval: 0.06, repeats: true) { [weak self] _ in
            guard let self = self, self.isVisible, !self.clickThrough else { return }
            let inside = self.panel.frame.insetBy(dx: -4, dy: -4).contains(NSEvent.mouseLocation)
            let optionHeld = NSEvent.modifierFlags.contains(.option)
            let shouldReveal = inside && (self.hoverRevealEnabled || optionHeld)
            if shouldReveal != self.isWindowHovered {
                self.isWindowHovered = shouldReveal
                let js = "window.GeckoNativeBridge?.setHovered(\(shouldReveal ? "true" : "false"), \(optionHeld ? "true" : "false"));"
                self.webView.evaluateJavaScript(js, completionHandler: nil)
                if self.isBuiltInWebActive {
                    self.builtInWebView?.evaluateJavaScript(
                        "window.ChameleonBuiltInBridge?.setHovered(\(shouldReveal ? "true" : "false"));",
                        completionHandler: nil
                    )
                }
            }
        }
        RunLoop.main.add(hoverTimer, forMode: .common)

        // Push saved hoverReveal & stealthSubtitle preferences into WebView right after boot
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self = self else { return }
            self.webView.evaluateJavaScript(
                "window.GeckoNativeBridge?.applyPatch({\"hoverReveal\":\(self.hoverRevealEnabled ? "true" : "false"),\"stealthSubtitle\":\(self.stealthSubtitleEnabled ? "true" : "false")});",
                completionHandler: nil
            )
        }

        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .scrollWheel, .magnify]) { [weak self] event in
            guard let self = self else { return event }

            // Independent Multi-Line Stealth Log Console Window drag & 8-way resize
            if let lw = self.logPanel, event.window === lw, event.type == .leftMouseDown {
                let loc = event.locationInWindow
                let b = lw.frame.size
                let cornerPad: CGFloat = 16
                let edgePad: CGFloat = 9
                let inCornerX = loc.x <= cornerPad || loc.x >= b.width - cornerPad
                let inCornerY = loc.y <= cornerPad || loc.y >= b.height - cornerPad
                let isCorner = inCornerX && inCornerY
                let nearL = loc.x <= (isCorner ? cornerPad : edgePad)
                let nearR = loc.x >= b.width - (isCorner ? cornerPad : edgePad)
                let nearB = loc.y <= (isCorner ? cornerPad : edgePad)
                let nearT = loc.y >= b.height - (isCorner ? cornerPad : 7)

                var dir = ""
                if nearT { dir += "n" } else if nearB { dir += "s" }
                if nearL { dir += "w" } else if nearR { dir += "e" }
                if !dir.isEmpty {
                    self.startNativeResize(dir: dir, window: lw)
                    return nil
                }
                // Header bar (top 28pt) excluding right-side toolbar pills
                if loc.y >= b.height - 28 && loc.x < b.width - 270 {
                    self.startNativeDrag(offset: loc, window: lw)
                    return nil
                }
                return event
            }

            guard !self.clickThrough, event.window === self.panel, !self.bossMode else { return event }

            // Support two-finger trackpad pinch-to-zoom directly on the small window!
            if event.type == .magnify {
                self.scalePanelByFactor(1.0 + event.magnification)
                return nil
            }
            // Support Option/Command + Scroll-wheel zoom directly on the small window!
            if event.type == .scrollWheel, event.modifierFlags.intersection([.command, .option, .control]).isEmpty == false {
                let delta = event.scrollingDeltaY * (event.hasPreciseScrollingDeltas ? 0.004 : 0.025)
                self.scalePanelByFactor(1.0 + delta)
                return nil
            }

            if event.type == .leftMouseDown {
                let loc = event.locationInWindow
                let b = self.panel.frame.size
                let hudVisible = self.hoverRevealEnabled || event.modifierFlags.contains(.option)

                // Let HUD buttons (top bar: 穿透/搜片/日志/老板键/模式/尺寸, bottom bar: 播放/静音/进度条) receive clicks first!
                let inTopHudButtons = hudVisible && loc.y >= b.height - 46 && loc.y <= b.height - 8 && loc.x >= 10 && loc.x <= b.width - 10
                let inBottomHudButtons = hudVisible && loc.y >= 8 && loc.y <= 66 && loc.x >= 10 && loc.x <= b.width - 10
                if inTopHudButtons || inBottomHudButtons {
                    return event
                }

                // Generous corner & edge hit zones for borderless window resizing
                let cornerPad: CGFloat = hudVisible ? 18 : 24
                let edgePad: CGFloat = hudVisible ? 9 : 14
                let inCornerX = loc.x <= cornerPad || loc.x >= b.width - cornerPad
                let inCornerY = loc.y <= cornerPad || loc.y >= b.height - cornerPad
                let isCorner = inCornerX && inCornerY

                let nearL = loc.x <= (isCorner ? cornerPad : edgePad)
                let nearR = loc.x >= b.width - (isCorner ? cornerPad : edgePad)
                let nearB = loc.y <= (isCorner ? cornerPad : edgePad)
                let nearT = loc.y >= b.height - (isCorner ? cornerPad : 8)

                var dir = ""
                if nearT { dir += "n" } else if nearB { dir += "s" }
                if nearL { dir += "w" } else if nearR { dir += "e" }

                if !dir.isEmpty {
                    self.startNativeResize(dir: dir, window: self.panel)
                    return nil
                }

                self.startNativeDrag(offset: loc, window: self.panel)
            }
            return event
        }

        panel.orderFrontRegardless()
    }

    private func scalePanelByFactor(_ factor: CGFloat) {
        let f0 = panel.frame
        let nw = min(max(190, f0.width * factor), 980)
        let nh = round(nw * 9.0 / 16.0)
        let nx = f0.midX - nw * 0.5
        let ny = f0.midY - nh * 0.5
        panel.setFrame(NSRect(x: nx, y: ny, width: nw, height: nh), display: true)
    }

    private func startNativeResize(dir: String, window: NSWindow? = nil) {
        let targetWin = window ?? panel!
        activeDragWindow = targetWin
        activeResizeDir = dir
        resizeInitialFrame = targetWin.frame
        resizeStartMouse = NSEvent.mouseLocation
        dragOriginOffset = nil
        isDraggingWindow = false
        ensurePointerTrackTimer()
    }

    private func startNativeDrag(offset: NSPoint, window: NSWindow? = nil) {
        activeDragWindow = window ?? panel!
        activeResizeDir = nil
        dragOriginOffset = offset
        dragDownScreenPt = NSEvent.mouseLocation
        isDraggingWindow = false
        ensurePointerTrackTimer()
    }

    // 120Hz WindowServer Pointer Tracker — works 100% reliably even when dragging outward outside panel bounds!
    private func ensurePointerTrackTimer() {
        pointerTrackTimer?.invalidate()
        let timer = Timer(timeInterval: 0.008, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            let targetWin = self.activeDragWindow ?? self.panel!
            if (NSEvent.pressedMouseButtons & 1) == 0 {
                t.invalidate()
                self.pointerTrackTimer = nil
                if targetWin === self.panel && (self.activeResizeDir != nil || self.isDraggingWindow) {
                    self.senseEnvironmentAsync()
                }
                self.activeDragWindow = nil
                self.activeResizeDir = nil
                self.dragOriginOffset = nil
                self.dragDownScreenPt = nil
                self.isDraggingWindow = false
                return
            }

            let m = NSEvent.mouseLocation
            if let dir = self.activeResizeDir {
                let minW: CGFloat = (targetWin === self.logPanel) ? 360 : 190
                let minH: CGFloat = (targetWin === self.logPanel) ? 115 : 110
                let dx = m.x - self.resizeStartMouse.x
                let dy = m.y - self.resizeStartMouse.y
                let f0 = self.resizeInitialFrame
                var nf = f0

                if dir.contains("e") { nf.size.width = max(minW, f0.width + dx) }
                if dir.contains("w") {
                    let nw = max(minW, f0.width - dx)
                    nf.origin.x = f0.maxX - nw
                    nf.size.width = nw
                }
                if dir.contains("n") { nf.size.height = max(minH, f0.height + dy) }
                if dir.contains("s") {
                    let nh = max(minH, f0.height - dy)
                    nf.origin.y = f0.maxY - nh
                    nf.size.height = nh
                }
                targetWin.setFrame(nf, display: true)
                return
            }

            if let offset = self.dragOriginOffset, let downPt = self.dragDownScreenPt {
                if !self.isDraggingWindow && hypot(m.x - downPt.x, m.y - downPt.y) > 3 {
                    self.isDraggingWindow = true
                }
                if self.isDraggingWindow {
                    targetWin.setFrameOrigin(NSPoint(x: m.x - offset.x, y: m.y - offset.y))
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pointerTrackTimer = timer
    }

    // MARK: - Compact Pure-AppKit MacBook Dynamic Island (316 x 178pt)
    private func computeNotchGeometry() -> (screen: NSScreen, midX: CGFloat, notchWidth: CGFloat, barHeight: CGFloat) {
        let s = NSScreen.main ?? NSScreen.screens.first!
        if #available(macOS 12.0, *),
           s.safeAreaInsets.top > 0,
           let auxL = s.auxiliaryTopLeftArea,
           let auxR = s.auxiliaryTopRightArea,
           auxR.minX > auxL.maxX {
            let nLeft = auxL.maxX
            let nRight = auxR.minX
            return (s, (nLeft + nRight) * 0.5, nRight - nLeft, s.safeAreaInsets.top)
        }
        let barH = max(24, min(40, s.frame.maxY - s.visibleFrame.maxY))
        return (s, s.frame.midX, 32, barH)
    }

    private static func makeLabel(_ text: String, frame: NSRect, align: NSTextAlignment = .left, alpha: CGFloat = 0.78) -> NSTextField {
        let lbl = NSTextField(labelWithString: text)
        lbl.frame = frame
        lbl.alignment = align
        lbl.font = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .medium)
        lbl.textColor = NSColor(calibratedWhite: 1.0, alpha: alpha)
        return lbl
    }

    private func setupDynamicNotchIsland() {
        let expW: CGFloat = 316
        let expH: CGFloat = 240

        islandPanel = GhostPanel(
            contentRect: NSRect(x: 600, y: 1000, width: 296, height: 38),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        islandPanel.allowKeyWindow = true
        islandPanel.isOpaque = false
        islandPanel.backgroundColor = .clear
        islandPanel.hasShadow = true
        islandPanel.appearance = NSAppearance(named: .darkAqua)
        islandPanel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        islandPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        islandShell = DynamicIslandShellView(frame: NSRect(x: 0, y: 0, width: 296, height: 38))
        islandShell.autoresizingMask = [.width, .height]
        islandShell.onTogglePlay = { [weak self] in
            self?.togglePlayAction()
        }
        islandShell.onToggleExpand = { [weak self] in
            guard let self = self else { return }
            self.setIslandExpanded(!self.isIslandExpanded)
        }

        // Fixed-coordinate Flipped Container (y = 0 at top, ZERO autoresizing distortion!)
        controlsContainer = FlippedControlsView(frame: NSRect(x: 0, y: 0, width: expW, height: expH))
        controlsContainer.appearance = NSAppearance(named: .darkAqua)
        controlsContainer.isHidden = true

        // Top Ear Header (flanking the 38pt center Camera Notch!)
        lblBrand = Self.makeLabel("变色龙投影", frame: NSRect(x: 14, y: 11, width: 92, height: 16), alpha: 0.82)
        let btnCollapse = IslandPillButton(frame: NSRect(x: 252, y: 8, width: 50, height: 22), title: "收起 ▲")
        btnCollapse.onClick = { [weak self] in self?.setIslandExpanded(false) }
        controlsContainer.addSubview(lblBrand)
        controlsContainer.addSubview(btnCollapse)

        // Row 1 (y = 44): Real-time Video Progress Scrubber
        lblCurTime = Self.makeLabel("00:00", frame: NSRect(x: 14, y: 46, width: 38, height: 16), align: .left, alpha: 0.85)
        progressSlider = NSSlider(value: 0, minValue: 0, maxValue: 180, target: self, action: #selector(onProgressScrub(_:)))
        progressSlider.frame = NSRect(x: 54, y: 44, width: 208, height: 20)
        progressSlider.isContinuous = true
        progressSlider.controlSize = .small
        lblDurTime = Self.makeLabel("03:00", frame: NSRect(x: 264, y: 46, width: 38, height: 16), align: .right, alpha: 0.60)
        controlsContainer.addSubview(lblCurTime)
        controlsContainer.addSubview(progressSlider)
        controlsContainer.addSubview(lblDurTime)

        // Row 2 (y = 70): Transport [-10s] [▶ 播放] [+10s] [1.0x] [静音]
        let btnBack = IslandPillButton(frame: NSRect(x: 14, y: 70, width: 46, height: 26), title: "-10s")
        btnBack.onClick = { [weak self] in self?.sendPlayerCmdToWebView("{\"action\":\"seek\",\"delta\":-10}") }

        btnPlayMain = IslandPillButton(frame: NSRect(x: 65, y: 70, width: 82, height: 26), title: "▶ 播放", primary: true)
        btnPlayMain.onClick = { [weak self] in self?.togglePlayAction() }

        let btnFwd = IslandPillButton(frame: NSRect(x: 152, y: 70, width: 46, height: 26), title: "+10s")
        btnFwd.onClick = { [weak self] in self?.sendPlayerCmdToWebView("{\"action\":\"seek\",\"delta\":10}") }

        btnRate = IslandPillButton(frame: NSRect(x: 203, y: 70, width: 46, height: 26), title: "1.0x")
        btnRate.onClick = { [weak self] in
            guard let self = self else { return }
            let rates: [Double] = [1.0, 1.25, 1.5, 2.0]
            let idx = rates.firstIndex(where: { abs($0 - self.playerRate) < 0.05 }) ?? 0
            let next = rates[(idx + 1) % rates.count]
            self.playerRate = next
            self.syncNativeIslandControls()
            self.sendPlayerCmdToWebView("{\"action\":\"setRate\",\"value\":\(next)}")
        }

        btnMute = IslandPillButton(frame: NSRect(x: 254, y: 70, width: 48, height: 26), title: "静音")
        btnMute.onClick = { [weak self] in
            guard let self = self else { return }
            self.playerMuted.toggle()
            self.syncNativeIslandControls()
            self.sendPlayerCmdToWebView("{\"action\":\"setMuted\",\"value\":\(self.playerMuted ? "true" : "false")}")
        }

        controlsContainer.addSubview(btnBack)
        controlsContainer.addSubview(btnPlayMain)
        controlsContainer.addSubview(btnFwd)
        controlsContainer.addSubview(btnRate)
        controlsContainer.addSubview(btnMute)

        // Row 3 (y = 104): All 3 Chameleon Camouflage Modes (100% FREE!)
        segMode = NSSegmentedControl(labels: ["变色融合", "浮雕隐身", "彩透变色"], trackingMode: .selectOne, target: self, action: #selector(onModeChanged(_:)))
        segMode.frame = NSRect(x: 14, y: 104, width: 288, height: 24)
        segMode.selectedSegment = 0
        segMode.segmentDistribution = .fillEqually
        controlsContainer.addSubview(segMode)

        // Row 4 (y = 136): Intensity Slider + [悬停] [穿透] [显示] [本地] [退出]
        let lblStealth = Self.makeLabel("浓度", frame: NSRect(x: 14, y: 141, width: 26, height: 16), alpha: 0.75)
        stealthSlider = NSSlider(value: 58, minValue: 10, maxValue: 95, target: self, action: #selector(onStealthSlide(_:)))
        stealthSlider.frame = NSRect(x: 40, y: 139, width: 66, height: 20)
        stealthSlider.isContinuous = true
        stealthSlider.controlSize = .small

        btnHoverReveal = IslandPillButton(frame: NSRect(x: 110, y: 136, width: 36, height: 25), title: "悬停")
        btnHoverReveal.isActiveTint = hoverRevealEnabled
        btnHoverReveal.onClick = { [weak self] in
            guard let self = self else { return }
            self.setHoverReveal(!self.hoverRevealEnabled)
        }

        btnThrough = IslandPillButton(frame: NSRect(x: 150, y: 136, width: 36, height: 25), title: "穿透")
        btnThrough.onClick = { [weak self] in
            guard let self = self else { return }
            self.setClickThrough(!self.clickThrough)
        }

        btnVis = IslandPillButton(frame: NSRect(x: 190, y: 136, width: 36, height: 25), title: "显示")
        btnVis.isActiveTint = true
        btnVis.onClick = { [weak self] in
            guard let self = self else { return }
            self.isVisible.toggle()
            if self.isVisible { self.panel.orderFrontRegardless() } else { self.panel.orderOut(nil) }
            self.broadcastPlaybackStateToArena()
            self.syncNativeIslandControls()
        }

        let btnLocal = IslandPillButton(frame: NSRect(x: 230, y: 136, width: 36, height: 25), title: "本地")
        btnLocal.onClick = { [weak self] in self?.openLocalVideoFile() }

        let btnQuit = IslandPillButton(frame: NSRect(x: 270, y: 136, width: 32, height: 25), title: "退出")
        btnQuit.onClick = { NSApp.terminate(nil) }

        controlsContainer.addSubview(lblStealth)
        controlsContainer.addSubview(stealthSlider)
        controlsContainer.addSubview(btnHoverReveal)
        controlsContainer.addSubview(btnThrough)
        controlsContainer.addSubview(btnVis)
        controlsContainer.addSubview(btnLocal)
        controlsContainer.addSubview(btnQuit)

        // Row 5 (y = 168): 3 Hardcore Black Techs + Quick Zoom [AI防窥] [网页直连] [日志字幕] [小 -] [大 +]
        btnRadar = IslandPillButton(frame: NSRect(x: 14, y: 168, width: 72, height: 25), title: "AI防窥")
        btnRadar.onClick = { [weak self] in self?.toggleAntiPeekRadar() }

        btnWebUrl = IslandPillButton(frame: NSRect(x: 90, y: 168, width: 66, height: 25), title: "搜片浏览")
        btnWebUrl.onClick = { [weak self] in
            self?.openSearchBrowserWindow()
        }

        btnStealthSub = IslandPillButton(frame: NSRect(x: 160, y: 168, width: 64, height: 25), title: "日志字幕")
        btnStealthSub.isActiveTint = stealthSubtitleEnabled
        btnStealthSub.onClick = { [weak self] in
            guard let self = self else { return }
            self.setStealthSubtitle(!self.stealthSubtitleEnabled)
        }

        let btnZoomOut = IslandPillButton(frame: NSRect(x: 228, y: 168, width: 35, height: 25), title: "小 -")
        btnZoomOut.onClick = { [weak self] in self?.scalePanelByFactor(0.84) }

        let btnZoomIn = IslandPillButton(frame: NSRect(x: 267, y: 168, width: 35, height: 25), title: "大 +")
        btnZoomIn.onClick = { [weak self] in self?.scalePanelByFactor(1.19) }

        controlsContainer.addSubview(btnRadar)
        controlsContainer.addSubview(btnWebUrl)
        controlsContainer.addSubview(btnStealthSub)
        controlsContainer.addSubview(btnZoomOut)
        controlsContainer.addSubview(btnZoomIn)

        // Row 6 (y = 200): Live Uninterrupted Streak / Radar Status + [排行 / 支持]
        lblStreakBadge = Self.makeLabel("待机 · 播放视频开始计时", frame: NSRect(x: 14, y: 205, width: 196, height: 16), alpha: 0.88)
        let btnArena = IslandPillButton(frame: NSRect(x: 214, y: 200, width: 88, height: 25), title: "排行 / 支持", primary: true)
        btnArena.onClick = { [weak self] in
            self?.openArenaWindow()
        }
        controlsContainer.addSubview(lblStreakBadge)
        controlsContainer.addSubview(btnArena)

        // 1Hz Slacking Streak & Daily Shield Quota Ticker (ONLY counts when real video is actively playing!)
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tickSlackingTelemetry()
        }

        islandShell.addSubview(controlsContainer)
        islandPanel.contentView = islandShell

        syncNativeIslandControls()
        layoutDynamicIsland(animated: false)
        islandPanel.orderFrontRegardless()

        // Collapse cleanly when user clicks anywhere outside the expanded island
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, self.isIslandExpanded else { return }
            if !self.islandPanel.frame.contains(NSEvent.mouseLocation) {
                self.setIslandExpanded(false)
            }
        }
    }

    private func togglePlayAction() {
        isPlayerPaused.toggle()
        islandShell.isPlayerPaused = isPlayerPaused
        syncNativeIslandControls()
        sendPlayerCmdToWebView("{\"action\":\"setPaused\",\"value\":\(isPlayerPaused ? "true" : "false")}")
    }

    private func setHoverReveal(_ enabled: Bool) {
        hoverRevealEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "chameleonHoverReveal")
        if !enabled {
            isWindowHovered = false
            webView.evaluateJavaScript("window.GeckoNativeBridge?.setHovered(false, false);", completionHandler: nil)
            builtInWebView?.evaluateJavaScript("window.ChameleonBuiltInBridge?.setHovered(false);", completionHandler: nil)
        }
        let patchJs = "{\"hoverReveal\":\(enabled ? "true" : "false")}"
        webView.evaluateJavaScript("window.GeckoNativeBridge?.applyPatch(\(patchJs));", completionHandler: nil)
        builtInWebView?.evaluateJavaScript("window.ChameleonBuiltInBridge?.applyPatch(\(patchJs));", completionHandler: nil)
        syncNativeIslandControls()
    }

    private func setStealthSubtitle(_ enabled: Bool) {
        stealthSubtitleEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "chameleonStealthSubtitle")
        let patchJs = "{\"stealthSubtitle\":\(enabled ? "true" : "false"),\"mirrorSubtitles\":\(enabled ? "true" : "false")}"
        webView.evaluateJavaScript("window.GeckoNativeBridge?.applyPatch(\(patchJs));", completionHandler: nil)
        setStealthLogPanelVisible(enabled)
        syncNativeIslandControls()
    }

    @objc private func onProgressScrub(_ sender: NSSlider) {
        let val = sender.doubleValue
        playerCurTime = val
        lblCurTime.stringValue = Self.fmtTime(val)
        sendPlayerCmdToWebView("{\"action\":\"seekTo\",\"value\":\(val)}")
    }

    @objc private func onModeChanged(_ sender: NSSegmentedControl) {
        let modes = ["projector", "emboss", "cinema"]
        let idx = max(0, min(2, sender.selectedSegment))
        currentMode = modes[idx]
        let patchJs = "{\"mode\":\"\(currentMode)\"}"
        webView.evaluateJavaScript("window.GeckoNativeBridge?.applyPatch(\(patchJs));", completionHandler: nil)
        builtInWebView?.evaluateJavaScript("window.ChameleonBuiltInBridge?.applyPatch(\(patchJs));", completionHandler: nil)
    }

    @objc private func onStealthSlide(_ sender: NSSlider) {
        let nextVal = sender.integerValue
        guard nextVal != currentStealth else { return }
        currentStealth = nextVal
        let patchJs = "{\"stealth\":\(currentStealth)}"
        webView.evaluateJavaScript("window.GeckoNativeBridge?.applyPatch(\(patchJs));", completionHandler: nil)
        builtInWebView?.evaluateJavaScript("window.ChameleonBuiltInBridge?.applyPatch(\(patchJs));", completionHandler: nil)
    }

    private static func fmtTime(_ sec: Double) -> String {
        guard sec.isFinite && sec >= 0 else { return "00:00" }
        let total = Int(sec)
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private func syncNativeIslandControls() {
        syncMenuBarItems()
        guard controlsContainer != nil else { return }
        let dur = playerDuration > 0 ? playerDuration : 180
        let cur = max(0, min(dur, playerCurTime))

        progressSlider.maxValue = dur
        if NSEvent.pressedMouseButtons == 0 {
            progressSlider.doubleValue = cur
        }
        lblCurTime.stringValue = Self.fmtTime(cur)
        lblDurTime.stringValue = Self.fmtTime(dur)

        btnPlayMain.title = isPlayerPaused ? "▶ 播放" : "⏸ 暂停"
        let rStr = (playerRate.truncatingRemainder(dividingBy: 1.0) == 0)
            ? String(format: "%.1fx", playerRate)
            : String(format: "%.2fx", playerRate).replacingOccurrences(of: ".50x", with: ".5x")
        btnRate.title = rStr
        btnMute.title = playerMuted ? "已静音" : "静音"
        btnMute.isActiveTint = playerMuted

        let mIdx = currentMode == "emboss" ? 1 : (currentMode == "cinema" ? 2 : 0)
        segMode.selectedSegment = mIdx
        if NSEvent.pressedMouseButtons == 0 {
            stealthSlider.integerValue = currentStealth
        }
        btnHoverReveal?.isActiveTint = hoverRevealEnabled
        btnThrough.isActiveTint = clickThrough
        btnVis.isActiveTint = isVisible
        btnVis.title = isVisible ? "显示" : "已隐"

        // Black Tech #1, #2, #3 button states (with live verifiable AI face-count telemetry!)
        if radarAlertActive {
            btnRadar?.title = "⚠\(radarLastFaceCount)人!"
            btnRadar?.isAlertTint = true
            btnRadar?.isActiveTint = false
            lblBrand?.stringValue = "⚠ 背后\(radarLastFaceCount)人!"
            lblBrand?.textColor = NSColor(calibratedRed: 0.99, green: 0.45, blue: 0.42, alpha: 1.0)
        } else if radarEnabled {
            btnRadar?.title = "防窥·\(radarLastFaceCount)人"
            btnRadar?.isAlertTint = false
            btnRadar?.isActiveTint = true
            lblBrand?.stringValue = "AI防窥(\(radarLastFaceCount)人)"
            lblBrand?.textColor = NSColor(calibratedRed: 0.43, green: 0.90, blue: 0.72, alpha: 0.95)
        } else {
            btnRadar?.title = "AI防窥"
            btnRadar?.isAlertTint = false
            btnRadar?.isActiveTint = false
            lblBrand?.stringValue = isBuiltInWebActive ? "网页直连中" : "变色龙投影"
            lblBrand?.textColor = NSColor(calibratedWhite: 1.0, alpha: 0.82)
        }

        btnWebUrl?.isActiveTint = (searchWindow?.isVisible ?? false) || isBuiltInWebActive
        btnWebUrl?.title = (searchWindow?.isVisible ?? false) ? "搜片中" : "搜片浏览"
        btnStealthSub?.isActiveTint = stealthSubtitleEnabled
        btnStealthSub?.title = stealthSubtitleEnabled ? "日志 ON" : "日志字幕"

        let activeVideoNow = isVisible && !bossMode && hasActiveVideoPlaying
        if radarAlertActive {
            lblStreakBadge?.stringValue = "检测到背后 \(radarLastFaceCount) 人 · 已秒隐静音"
        } else if activeVideoNow || currentStreakSec > 0 {
            lblStreakBadge?.stringValue = "连续 \(Self.fmtTime(Double(currentStreakSec))) · \(Self.chameleonRankTitle(for: totalSlackingSec))"
        } else if radarEnabled {
            lblStreakBadge?.stringValue = "AI防窥已就绪 · 实时检测 \(radarLastFaceCount) 人 (≥2人秒隐)"
        } else if isBuiltInWebActive && !builtInVideoIsolated {
            lblStreakBadge?.stringValue = "网页直连 · 点播视频自动变色融合"
        } else {
            lblStreakBadge?.stringValue = "待机 · 播放视频开始计时"
        }
    }

    private func broadcastPlaybackStateToArena() {
        let activeVideoNow = isVisible && !bossMode && hasActiveVideoPlaying
        wsHub.sendTextToArena("{\"type\":\"videoPlaybackState\",\"playing\":\(activeVideoNow ? "true" : "false")}")
    }

    private static func chameleonRankTitle(for totalSec: Int) -> String {
        let mins = totalSec / 60
        if mins >= 36000 { return "Lv.10 摸鱼之神" }
        if mins >= 18000 { return "Lv.9 殿堂变色龙" }
        if mins >= 7200  { return "Lv.8 暗影变色龙" }
        if mins >= 3000  { return "Lv.7 带薪修行师" }
        if mins >= 1200  { return "Lv.6 死角艺术家" }
        if mins >= 480   { return "Lv.5 幻影魔术师" }
        if mins >= 180   { return "Lv.4 拟态猎手" }
        if mins >= 60    { return "Lv.3 拟态学徒" }
        if mins >= 15    { return "Lv.2 工位幼龙" }
        return "Lv.1 透明实习生"
    }

    private func tickSlackingTelemetry() {
        telemetryTickCount += 1
        let activeVideoNow = isVisible && !bossMode && hasActiveVideoPlaying
        if activeVideoNow {
            pausedSecondsCount = 0
            currentStreakSec += 1
            totalSlackingSec += 1
            if totalSlackingSec % 10 == 0 {
                UserDefaults.standard.set(totalSlackingSec, forKey: "chameleonTotalSec")
            }
            if isIslandExpanded && !radarAlertActive {
                lblStreakBadge?.stringValue = "连续 \(Self.fmtTime(Double(currentStreakSec))) · \(Self.chameleonRankTitle(for: totalSlackingSec))"
            }
        } else if currentStreakSec > 0 {
            pausedSecondsCount += 1
            if bossMode || !isVisible || pausedSecondsCount > 10 {
                currentStreakSec = 0
                pausedSecondsCount = 0
                if isIslandExpanded && !radarAlertActive {
                    lblStreakBadge?.stringValue = "待机 · 播放视频开始计时"
                }
            }
        } else if isIslandExpanded && !radarAlertActive {
            if radarEnabled {
                lblStreakBadge?.stringValue = "AI防窥已就绪 · 实时检测 \(radarLastFaceCount) 人 (≥2人秒隐)"
            } else {
                lblStreakBadge?.stringValue = isBuiltInWebActive && !builtInVideoIsolated ? "网页直连 · 点播视频自动变色融合" : "待机 · 播放视频开始计时"
            }
        }

        if telemetryTickCount % 2 == 0 {
            broadcastPlaybackStateToArena()
        }
    }

    private func applyMembershipEntitlement(_ isPro: Bool) {
        isProMember = isPro
        UserDefaults.standard.set(isPro, forKey: "chameleonIsPro")
        updatePanelSharingType()
        syncNativeIslandControls()
    }

    private func openArenaWindow(upgradeReason: String? = nil) {
        setIslandExpanded(false)
        let isNewWindow = (arenaWindow == nil)
        if arenaWindow == nil {
            let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            let w: CGFloat = min(1180, screenFrame.width - 60)
            let h: CGFloat = min(790, screenFrame.height - 50)
            let rect = NSRect(x: screenFrame.midX - w * 0.5, y: screenFrame.midY - h * 0.5, width: w, height: h)
            let win = NSWindow(
                contentRect: rect,
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            win.title = "ChameleonPiP 变色龙 · 全球摸鱼排位、线上耐力 PK 与请喝咖啡赞赏"
            win.appearance = NSAppearance(named: .darkAqua)
            win.backgroundColor = NSColor(calibratedRed: 0.03, green: 0.04, blue: 0.07, alpha: 1.0)
            win.isReleasedWhenClosed = false

            let aWeb = WKWebView(frame: NSRect(x: 0, y: 0, width: w, height: h))
            aWeb.autoresizingMask = [.width, .height]
            aWeb.setValue(false, forKey: "drawsBackground")
            if let arenaURL = Bundle.main.url(forResource: "arena", withExtension: "html") {
                aWeb.loadFileURL(arenaURL, allowingReadAccessTo: arenaURL.deletingLastPathComponent().deletingLastPathComponent())
            }
            win.contentView = aWeb
            self.arenaWindow = win
            self.arenaWebView = aWeb
        }
        arenaWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        if let reason = upgradeReason {
            let escaped = reason.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
            let delay: TimeInterval = isNewWindow ? 0.55 : 0.05
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.arenaWebView?.evaluateJavaScript("window.openProModal?.('\(escaped)');", completionHandler: nil)
                self?.wsHub.sendTextToArena("{\"type\":\"openUpgradeModal\",\"reason\":\"\(escaped)\"}")
            }
        }
    }

    private func setIslandExpanded(_ expanded: Bool) {
        guard expanded != isIslandExpanded else { return }
        isIslandExpanded = expanded
        islandShell.isExpanded = expanded

        if expanded {
            syncNativeIslandControls()
            controlsContainer.frame = NSRect(x: 0, y: 0, width: 316, height: 240)
            controlsContainer.isHidden = false
            layoutDynamicIsland(animated: true)
        } else {
            controlsContainer.isHidden = true
            layoutDynamicIsland(animated: true)
        }
    }

    private func layoutDynamicIsland(animated: Bool) {
        guard islandPanel != nil else { return }
        let geo = computeNotchGeometry()
        let earW: CGFloat = 46
        islandShell.earWidth = earW

        let targetW: CGFloat = isIslandExpanded ? 316 : (geo.notchWidth + earW * 2)
        let targetH: CGFloat = isIslandExpanded ? 240 : geo.barHeight
        let targetX = round(geo.midX - targetW * 0.5)
        let targetY = geo.screen.frame.maxY - targetH
        let rect = NSRect(x: targetX, y: targetY, width: targetW, height: targetH)

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.18
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                islandPanel.animator().setFrame(rect, display: true)
            }
        } else {
            islandPanel.setFrame(rect, display: true)
        }
    }

    private func sendPlayerCmdToWebView(_ jsonCmd: String) {
        if !isVisible {
            isVisible = true
            panel.orderFrontRegardless()
        }
        if bossMode { setBoss(false) }
        if isBuiltInWebActive {
            builtInWebView?.evaluateJavaScript("window.ChameleonBuiltInBridge?.execPlayerCmd(\(jsonCmd));", completionHandler: nil)
        } else {
            webView.evaluateJavaScript("window.GeckoNativeBridge?.execPlayerCmd(\(jsonCmd));", completionHandler: nil)
        }
    }

    private func handleGhostCommandForBuiltIn(_ rawText: String) {
        guard isBuiltInWebActive,
              let data = rawText.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = obj["type"] as? String else { return }
        if type == "cmd" {
            let safeData = try? JSONSerialization.data(withJSONObject: obj, options: [])
            if let safeData = safeData, let jsonStr = String(data: safeData, encoding: .utf8) {
                builtInWebView?.evaluateJavaScript("window.ChameleonBuiltInBridge?.execPlayerCmd(\(jsonStr));", completionHandler: nil)
            }
        }
    }

    private func setBoss(_ active: Bool) {
        bossMode = active
        if active {
            hasActiveVideoPlaying = false
            currentStreakSec = 0
            islandShell?.isPlayerPaused = true
            wasSearchWindowOpenBeforeBoss = (searchWindow?.isVisible ?? false)
            searchWindow?.orderOut(nil)
            wsHub.sendTextToArena("{\"type\":\"bossTriggered\"}")
            broadcastPlaybackStateToArena()
        } else {
            bossTriggeredByRadar = false
            radarAlertActive = false
            islandShell?.isRadarAlert = false
            if wasSearchWindowOpenBeforeBoss {
                wasSearchWindowOpenBeforeBoss = false
                searchWindow?.orderFrontRegardless()
            }
        }
        if isBuiltInWebActive {
            builtInWebView?.evaluateJavaScript("window.ChameleonBuiltInBridge?.setBossMode(\(bossMode));", completionHandler: nil)
        }
        webView.evaluateJavaScript("window.GeckoNativeBridge?.setBossMode(\(bossMode));", completionHandler: nil)
        logWebView?.evaluateJavaScript("window.StealthConsoleBridge?.setBossSafeMode(\(bossMode ? "true" : "false"));", completionHandler: nil)
        syncNativeIslandControls()
    }

    private func setClickThrough(_ val: Bool) {
        clickThrough = val
        panel.allowKeyWindow = !clickThrough
        panel.ignoresMouseEvents = clickThrough
        syncNativeIslandControls()
    }

    private func openLocalVideoFile() {
        setIslandExpanded(false)
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        if openPanel.runModal() == .OK, let url = openPanel.url {
            exitBuiltInWebMode()
            let escaped = url.absoluteString.replacingOccurrences(of: "'", with: "%27")
            webView.evaluateJavaScript("window.GeckoNativeBridge?.loadLocalVideo('\(escaped)');", completionHandler: nil)
        }
    }

    // MARK: - Black Tech #2: Standalone Built-in Web Video Player (Zero Chrome Extension Required!)
    private func openWebVideoUrlPrompt() {
        setIslandExpanded(false)
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "免插件网页直连播放"
        alert.informativeText = "直接粘贴 B站 / YouTube / 抖音 / 直播网页链接，或直链 .mp4 / .m3u8 地址，在桌面小窗内原生变色播放（无需浏览器插件）："

        let box = NSView(frame: NSRect(x: 0, y: 0, width: 390, height: 64))
        let input = NSTextField(frame: NSRect(x: 0, y: 34, width: 390, height: 26))
        input.placeholderString = "https://www.bilibili.com/video/BV..."
        if let clip = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
           clip.hasPrefix("http://") || clip.hasPrefix("https://") {
            input.stringValue = clip
        } else if !currentBuiltInUrl.isEmpty {
            input.stringValue = currentBuiltInUrl
        }
        box.addSubview(input)

        let presetTarget = UrlPresetTarget(textField: input)
        let btnBili = NSButton(title: "B站", target: presetTarget, action: #selector(UrlPresetTarget.pickBilibili))
        btnBili.bezelStyle = .rounded
        btnBili.frame = NSRect(x: 0, y: 2, width: 68, height: 24)
        let btnYt = NSButton(title: "YouTube", target: presetTarget, action: #selector(UrlPresetTarget.pickYouTube))
        btnYt.bezelStyle = .rounded
        btnYt.frame = NSRect(x: 74, y: 2, width: 84, height: 24)
        let btnDy = NSButton(title: "抖音", target: presetTarget, action: #selector(UrlPresetTarget.pickDouyin))
        btnDy.bezelStyle = .rounded
        btnDy.frame = NSRect(x: 164, y: 2, width: 68, height: 24)

        let hintLbl = NSTextField(labelWithString: "点击可快速填入网站首页")
        hintLbl.frame = NSRect(x: 240, y: 6, width: 150, height: 16)
        hintLbl.font = NSFont.systemFont(ofSize: 10.5)
        hintLbl.textColor = .secondaryLabelColor

        box.addSubview(btnBili)
        box.addSubview(btnYt)
        box.addSubview(btnDy)
        box.addSubview(hintLbl)

        alert.accessoryView = box
        alert.addButton(withTitle: "开始变色播放")
        if isBuiltInWebActive {
            alert.addButton(withTitle: "退出网页源")
        }
        alert.addButton(withTitle: "取消")
        alert.window.initialFirstResponder = input

        let resp = alert.runModal()
        withExtendedLifetime(presetTarget) {
            if resp == .alertFirstButtonReturn {
                let raw = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !raw.isEmpty {
                    loadBuiltInWebUrl(raw)
                }
            } else if isBuiltInWebActive && resp == .alertSecondButtonReturn {
                exitBuiltInWebMode()
            }
        }
    }

    private func stopBuiltInSnapshotPump() {
        builtInSnapshotTimer?.invalidate()
        builtInSnapshotTimer = nil
        builtInSnapshotBusy = false
    }

    private func startBuiltInSnapshotPump() {
        guard builtInSnapshotTimer == nil else { return }
        let t = Timer(timeInterval: 0.04, repeats: true) { [weak self] timer in
            guard let self = self, self.isBuiltInWebActive, let bw = self.builtInWebView else {
                timer.invalidate()
                self?.builtInSnapshotTimer = nil
                return
            }
            if !self.isVisible || self.bossMode || self.builtInSnapshotBusy { return }
            let sz = bw.bounds.size
            if sz.width < 10 || sz.height < 10 { return }
            self.builtInSnapshotBusy = true
            let cfg = WKSnapshotConfiguration()
            cfg.rect = CGRect(origin: .zero, size: sz)
            cfg.snapshotWidth = NSNumber(value: 448)
            bw.takeSnapshot(with: cfg) { [weak self] image, _ in
                guard let self = self else { return }
                self.builtInSnapshotBusy = false
                guard self.isBuiltInWebActive, !self.bossMode,
                      let img = image,
                      let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
                let rep = NSBitmapImageRep(cgImage: cg)
                if let jpg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.72]) {
                    self.wsHub.pushLocalBuiltInFrame(jpg)
                }
            }
        }
        RunLoop.main.add(t, forMode: .common)
        builtInSnapshotTimer = t
    }

    private func configureBuiltInProducerWebView(_ bw: FirstMouseWebView) {
        bw.ignoreAllMouseEvents = true
        bw.setValue(false, forKey: "drawsBackground")
        bw.alphaValue = 0.004
        bw.autoresizingMask = [.width, .height]
        bw.frame = panel.contentView!.bounds
        bw.removeFromSuperview()
        panel.contentView?.addSubview(bw, positioned: .below, relativeTo: webView)
    }

    private func loadBuiltInWebUrl(_ raw: String) {
        var norm = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if !norm.lowercased().hasPrefix("http://") && !norm.lowercased().hasPrefix("https://") {
            norm = "https://" + norm
        }
        guard let url = URL(string: norm) else { return }

        let lowerPath = url.path.lowercased()
        let isDirectMedia = lowerPath.hasSuffix(".mp4") || lowerPath.hasSuffix(".webm") || lowerPath.hasSuffix(".mov") || lowerPath.hasSuffix(".m4v") || lowerPath.hasSuffix(".m3u8")
        if isDirectMedia {
            exitBuiltInWebMode()
            isVisible = true
            if bossMode { setBoss(false) }
            panel.orderFrontRegardless()
            let escaped = norm.replacingOccurrences(of: "'", with: "%27")
            webView.evaluateJavaScript("window.GeckoNativeBridge?.loadLocalVideo('\(escaped)');", completionHandler: nil)
            return
        }

        stopBuiltInSnapshotPump()
        currentBuiltInUrl = norm
        if builtInWebView == nil {
            let cfg = WKWebViewConfiguration()
            cfg.userContentController.add(self, name: "ghostAction")
            cfg.mediaTypesRequiringUserActionForPlayback = []
            cfg.allowsAirPlayForMediaPlayback = false
            cfg.userContentController.addUserScript(
                WKUserScript(source: Self.searchBrowserPreHookScript(), injectionTime: .atDocumentStart, forMainFrameOnly: false)
            )
            cfg.userContentController.addUserScript(
                WKUserScript(source: Self.builtInBridgeScript(), injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            )

            let bw = FirstMouseWebView(frame: panel.contentView!.bounds, configuration: cfg)
            bw.uiDelegate = self
            bw.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15"
            builtInWebView = bw
        }

        if let bw = builtInWebView {
            configureBuiltInProducerWebView(bw)
        }
        isBuiltInWebActive = true
        builtInVideoIsolated = true
        webView.isHidden = false
        isVisible = true
        if bossMode { setBoss(false) }
        panel.orderFrontRegardless()
        builtInWebView?.load(URLRequest(url: url))
        syncNativeIslandControls()
    }

    private func exitBuiltInWebMode() {
        stopBuiltInSnapshotPump()
        guard isBuiltInWebActive else { return }
        isBuiltInWebActive = false
        builtInVideoIsolated = false
        builtInWebView?.evaluateJavaScript("window.ChameleonBuiltInBridge?.stop?.(); document.querySelectorAll('video').forEach(v => v.pause());", completionHandler: nil)
        builtInWebView?.loadHTMLString("<html><body style='background:transparent'></body></html>", baseURL: nil)
        builtInWebView?.removeFromSuperview()
        builtInWebView = nil
        webView.isHidden = false
        wsHub.pushLocalBuiltInText("{\"type\":\"streamStopped\"}")
        hasActiveVideoPlaying = false
        broadcastPlaybackStateToArena()
        syncNativeIslandControls()
    }

    // MARK: - Independent Full-Web Stealth Search Browser Window (Zero PiP Overlap!)
    private func openSearchBrowserWindow() {
        setIslandExpanded(false)
        if bossMode { setBoss(false) }

        if searchWindow == nil {
            let screenVis = (panel.screen ?? NSScreen.main)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            let w: CGFloat = min(640, screenVis.width - 40)
            let h: CGFloat = min(476, screenVis.height - 80)
            let x = round(screenVis.midX - w * 0.5)
            let y = max(screenVis.minY + 16, screenVis.maxY - h - 14)

            let win = NSWindow(
                contentRect: NSRect(x: x, y: y, width: w, height: h),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            win.title = "ChameleonPiP 隐蔽搜片微浏览器 — 全网搜片 · 点右上「投送到小窗」"
            win.appearance = NSAppearance(named: .darkAqua)
            win.backgroundColor = NSColor(calibratedRed: 0.06, green: 0.08, blue: 0.12, alpha: 1.0)
            win.minSize = NSSize(width: 480, height: 340)
            win.level = .floating
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            win.sharingType = hideFromCapture ? .none : .readOnly
            win.isReleasedWhenClosed = false
            win.delegate = self

            let contentRoot = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))
            contentRoot.autoresizingMask = [.width, .height]
            win.contentView = contentRoot

            let tbH: CGFloat = 76
            let tb = FlippedControlsView(frame: NSRect(x: 0, y: h - tbH, width: w, height: tbH))
            tb.autoresizingMask = [.width, .minYMargin]
            tb.wantsLayer = true
            tb.layer?.backgroundColor = NSColor(calibratedRed: 0.07, green: 0.09, blue: 0.14, alpha: 0.98).cgColor

            // Row 1 (y = 8): Navigation + Full-Width Omnibox + Go + Project
            let btnBack = IslandPillButton(frame: NSRect(x: 10, y: 9, width: 28, height: 26), title: "←")
            btnBack.autoresizingMask = [.maxXMargin]
            btnBack.onClick = { [weak self] in self?.searchWebView?.goBack() }

            let btnFwd = IslandPillButton(frame: NSRect(x: 42, y: 9, width: 28, height: 26), title: "→")
            btnFwd.autoresizingMask = [.maxXMargin]
            btnFwd.onClick = { [weak self] in self?.searchWebView?.goForward() }

            let btnRel = IslandPillButton(frame: NSRect(x: 74, y: 9, width: 28, height: 26), title: "↻")
            btnRel.autoresizingMask = [.maxXMargin]
            btnRel.onClick = { [weak self] in self?.searchWebView?.reload() }

            let btnHome = IslandPillButton(frame: NSRect(x: 106, y: 9, width: 44, height: 26), title: "热榜")
            btnHome.autoresizingMask = [.maxXMargin]
            btnHome.onClick = { [weak self] in self?.loadStealthStartPageInSearchWebView() }

            let omni = NSTextField(frame: NSRect(x: 156, y: 9, width: w - 318, height: 26))
            omni.autoresizingMask = [.width]
            omni.bezelStyle = .roundedBezel
            omni.drawsBackground = true
            omni.backgroundColor = NSColor(calibratedWhite: 0.14, alpha: 1.0)
            omni.textColor = .white
            omni.font = NSFont.systemFont(ofSize: 12.0)
            omni.focusRingType = .none
            omni.placeholderString = "输入关键词全网搜片，或粘贴 B站/YouTube/抖音/网页链接回车..."
            omni.target = self
            omni.action = #selector(onOmniboxSubmit(_:))

            let btnGo = IslandPillButton(frame: NSRect(x: w - 156, y: 9, width: 46, height: 26), title: "搜索")
            btnGo.autoresizingMask = [.minXMargin]
            btnGo.onClick = { [weak self] in
                guard let self = self, let o = self.searchOmnibox else { return }
                self.onOmniboxSubmit(o)
            }

            let btnProj = IslandPillButton(frame: NSRect(x: w - 106, y: 9, width: 96, height: 26), title: "投送到小窗 ▶", primary: true)
            btnProj.autoresizingMask = [.minXMargin]
            btnProj.onClick = { [weak self] in self?.projectSearchBrowserToSmallWindow() }

            tb.addSubview(btnBack)
            tb.addSubview(btnFwd)
            tb.addSubview(btnRel)
            tb.addSubview(btnHome)
            tb.addSubview(omni)
            tb.addSubview(btnGo)
            tb.addSubview(btnProj)

            // Row 2 (y = 43): Engine Switcher + Grayscale Camouflage + Shortcut Hint
            let seg = NSSegmentedControl(
                labels: ["B站", "必应全网", "百度", "YouTube", "抖音"],
                trackingMode: .selectOne,
                target: self,
                action: #selector(onSearchEngineChanged(_:))
            )
            seg.frame = NSRect(x: 10, y: 43, width: 296, height: 24)
            seg.selectedSegment = 0
            seg.font = NSFont.systemFont(ofSize: 10.5, weight: .medium)

            let btnGray = IslandPillButton(frame: NSRect(x: 314, y: 43, width: 88, height: 24), title: "灰度伪装 ON")
            btnGray.isActiveTint = browserGrayCamo
            btnGray.onClick = { [weak self] in self?.toggleBrowserGrayCamo() }

            let lblHint = Self.makeLabel("打开视频点「投送到小窗」 · ⌃⇧S 显隐", frame: NSRect(x: 410, y: 47, width: w - 420, height: 16), alpha: 0.65)
            lblHint.autoresizingMask = [.width]

            tb.addSubview(seg)
            tb.addSubview(btnGray)
            tb.addSubview(lblHint)

            contentRoot.addSubview(tb)
            self.searchToolbarView = tb
            self.searchOmnibox = omni
            self.segSearchEngine = seg
            self.btnBrowserGray = btnGray
            self.searchWindow = win
        }

        if searchWebView == nil {
            createAndAttachSearchWebView()
            loadStealthStartPageInSearchWebView()
        }

        searchWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        syncNativeIslandControls()
    }

    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSWindow) === searchWindow {
            DispatchQueue.main.async { [weak self] in
                self?.syncNativeIslandControls()
            }
        }
    }

    private func createAndAttachSearchWebView() {
        guard let contentRoot = searchWindow?.contentView else { return }
        let tbH: CGFloat = 76
        let h = max(120, contentRoot.bounds.height - tbH)
        let cfg = WKWebViewConfiguration()
        cfg.userContentController.add(self, name: "ghostAction")
        cfg.mediaTypesRequiringUserActionForPlayback = []
        cfg.allowsAirPlayForMediaPlayback = false
        cfg.userContentController.addUserScript(
            WKUserScript(source: Self.searchBrowserPreHookScript(), injectionTime: .atDocumentStart, forMainFrameOnly: false)
        )
        cfg.userContentController.addUserScript(
            WKUserScript(source: Self.searchBrowserHelperScript(), injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        )

        let swv = FirstMouseWebView(frame: NSRect(x: 0, y: 0, width: contentRoot.bounds.width, height: h), configuration: cfg)
        swv.autoresizingMask = [.width, .height]
        swv.uiDelegate = self
        swv.navigationDelegate = self
        swv.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15"
        contentRoot.addSubview(swv)
        self.searchWebView = swv
    }

    private func loadStealthStartPageInSearchWebView() {
        if searchWebView == nil { createAndAttachSearchWebView() }
        searchOmnibox?.stringValue = ""
        searchWebView?.loadHTMLString(Self.stealthStartPageHtml(), baseURL: nil)
    }

    private func syncGrayCamoInSearchWebView() {
        let on = browserGrayCamo ? "true" : "false"
        searchWebView?.evaluateJavaScript(
            "document.documentElement?.classList.toggle('chm-gray-browse', \(on));",
            completionHandler: nil
        )
    }

    private func toggleBrowserGrayCamo() {
        browserGrayCamo.toggle()
        btnBrowserGray?.isActiveTint = browserGrayCamo
        btnBrowserGray?.title = browserGrayCamo ? "灰度伪装 ON" : "灰度伪装 OFF"
        syncGrayCamoInSearchWebView()
    }

    @objc private func onSearchEngineChanged(_ sender: NSSegmentedControl) {
        let txt = (searchOmnibox?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !txt.isEmpty && !txt.lowercased().hasPrefix("http://") && !txt.lowercased().hasPrefix("https://") {
            navigateOmniboxText(txt)
        }
    }

    @objc private func onOmniboxSubmit(_ sender: NSTextField) {
        let raw = sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            loadStealthStartPageInSearchWebView()
            return
        }
        navigateOmniboxText(raw)
    }

    private func navigateOmniboxText(_ raw: String) {
        if searchWebView == nil { createAndAttachSearchWebView() }
        let lower = raw.lowercased()
        let isUrl = lower.hasPrefix("http://") || lower.hasPrefix("https://") ||
            lower.hasPrefix("www.") || (raw.contains(".") && !raw.contains(" "))
        let upper = raw.uppercased()
        let isBv = upper.hasPrefix("BV") && raw.count >= 12 && !raw.contains(" ")

        let targetStr: String
        if isBv {
            targetStr = "https://www.bilibili.com/video/\(raw)"
        } else if isUrl {
            targetStr = (lower.hasPrefix("http://") || lower.hasPrefix("https://")) ? raw : "https://\(raw)"
        } else {
            let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? raw
            let idx = segSearchEngine?.selectedSegment ?? 0
            switch idx {
            case 1: targetStr = "https://cn.bing.com/search?q=\(encoded)"
            case 2: targetStr = "https://www.baidu.com/s?wd=\(encoded)"
            case 3: targetStr = "https://www.youtube.com/results?search_query=\(encoded)"
            case 4: targetStr = "https://www.douyin.com/search/\(encoded)"
            default: targetStr = "https://search.bilibili.com/all?keyword=\(encoded)"
            }
        }
        if let url = URL(string: targetStr) {
            searchWebView?.load(URLRequest(url: url))
        }
    }

    private func projectSearchBrowserToSmallWindow() {
        guard let swv = searchWebView, let curUrl = swv.url,
              let scheme = curUrl.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            searchWebView?.evaluateJavaScript(
                "window.setStartPageHint?.('请先点击下方任意视频条目或搜索并打开具体视频网页，再点右上「投送到小窗 ▶」');",
                completionHandler: nil
            )
            return
        }

        let lowerHost = (curUrl.host ?? "").lowercased()
        let lowerPath = curUrl.path.lowercased()
        let isSearchResultsList = lowerHost == "search.bilibili.com" ||
            lowerPath.hasPrefix("/results") ||
            lowerPath == "/search" ||
            lowerPath == "/s"

        if isSearchResultsList {
            swv.evaluateJavaScript("Array.from(document.querySelectorAll('video')).some(v => v.readyState >= 2 && (v.duration || 0) > 8 && !v.paused)") { [weak self] res, _ in
                if (res as? Bool) == true {
                    self?.performPromoteSearchWebViewToChameleon(swv, url: curUrl)
                } else {
                    swv.evaluateJavaScript(
                        "window.__CHAMELEON_SHOW_SRCH_TOAST__?.('当前是搜索列表页，请先点开任意视频，或点击视频卡片右上「变色龙小窗播 ▶」');",
                        completionHandler: nil
                    )
                }
            }
            return
        }

        performPromoteSearchWebViewToChameleon(swv, url: curUrl)
    }

    private func performPromoteSearchWebViewToChameleon(_ swv: FirstMouseWebView, url curUrl: URL) {
        stopBuiltInSnapshotPump()
        if let oldBw = builtInWebView {
            oldBw.evaluateJavaScript("window.ChameleonBuiltInBridge?.stop?.(); document.querySelectorAll('video').forEach(v => v.pause());", completionHandler: nil)
            oldBw.loadHTMLString("<html><body style='background:transparent'></body></html>", baseURL: nil)
            oldBw.removeFromSuperview()
            builtInWebView = nil
        }

        // Turn off search-mode overlay & grayscale browsing before promoting WebView behind Metal ghost-view!
        swv.evaluateJavaScript(
            "document.documentElement?.classList.remove('chm-gray-browse'); window.__CHAMELEON_SET_SRCH_MODE__?.(false);",
            completionHandler: nil
        )

        let bridgeSrc = Self.builtInBridgeScript()
        swv.configuration.userContentController.addUserScript(
            WKUserScript(source: bridgeSrc, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        )
        swv.evaluateJavaScript(bridgeSrc, completionHandler: nil)

        configureBuiltInProducerWebView(swv)
        builtInWebView = swv
        searchWebView = nil
        currentBuiltInUrl = curUrl.absoluteString
        isBuiltInWebActive = true
        builtInVideoIsolated = true
        webView.isHidden = false
        isVisible = true
        if bossMode { setBoss(false) }

        searchWindow?.orderOut(nil)
        panel.orderFrontRegardless()
        syncNativeIslandControls()
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        guard webView === searchWebView, let u = webView.url else { return }
        if u.scheme == "http" || u.scheme == "https" {
            searchOmnibox?.stringValue = u.absoluteString
        } else {
            searchOmnibox?.stringValue = ""
        }
        syncGrayCamoInSearchWebView()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if webView === searchWebView {
            syncGrayCamoInSearchWebView()
            if let u = webView.url, u.scheme == "http" || u.scheme == "https" {
                searchOmnibox?.stringValue = u.absoluteString
            }
        }
    }

    private func pushStealthFeedToWebView(reqId: String, items: [[String: String]], error: String?) {
        var payload: [String: Any] = ["reqId": reqId, "items": items]
        if let err = error { payload["error"] = err }
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: []),
              let json = String(data: data, encoding: .utf8) else { return }
        DispatchQueue.main.async { [weak self] in
            self?.searchWebView?.evaluateJavaScript("window.onStealthHomeFeedResult?.(\(json));", completionHandler: nil)
        }
    }

    private static func searchBrowserPreHookScript() -> String {
        return #"""
        (function() {
          if (window.__CHAMELEON_PRE_HOOK__) return;
          window.__CHAMELEON_PRE_HOOK__ = true;
          const post = (p) => window.webkit?.messageHandlers?.ghostAction?.postMessage(p);

          try {
            if (typeof HTMLVideoElement !== 'undefined') {
              HTMLVideoElement.prototype.requestPictureInPicture = function() {
                post({ action: 'projectFromSearchBrowser' });
                return Promise.reject(new DOMException('ChameleonPiP intercepted', 'AbortError'));
              };
              const origSetPres = HTMLVideoElement.prototype.webkitSetPresentationMode;
              if (typeof origSetPres === 'function') {
                HTMLVideoElement.prototype.webkitSetPresentationMode = function(mode) {
                  if (mode === 'picture-in-picture') {
                    post({ action: 'projectFromSearchBrowser' });
                    return;
                  }
                  return origSetPres.apply(this, arguments);
                };
              }
            }
            if (window.documentPictureInPicture?.requestWindow) {
              window.documentPictureInPicture.requestWindow = function() {
                post({ action: 'projectFromSearchBrowser' });
                return Promise.reject(new DOMException('ChameleonPiP intercepted', 'AbortError'));
              };
            }
          } catch (_) {}

          document.addEventListener('click', (e) => {
            if (window.__CHAMELEON_BUILTIN_LOADED__) return;
            const tgt = e.target && e.target.closest ? e.target.closest(
              '.bpx-player-ctrl-pip, .bilibili-player-video-btn-pip, .ytp-pip-button, .xgplayer-pip, [data-e2e="pip-icon"], [aria-label*="画中画"], [aria-label*="小窗"], [title*="画中画"], [title*="小窗"]'
            ) : null;
            if (tgt) {
              e.preventDefault();
              e.stopImmediatePropagation();
              post({ action: 'projectFromSearchBrowser' });
            }
          }, true);
        })();
        """#
    }

    private static func searchBrowserHelperScript() -> String {
        return #"""
        (function() {
          if (window.__CHAMELEON_SRCH_HELPER__) return;
          window.__CHAMELEON_SRCH_HELPER__ = true;
          const post = (p) => window.webkit?.messageHandlers?.ghostAction?.postMessage(p);
          let srchOverlayEnabled = true;

          const st = document.createElement('style');
          st.textContent = `
            html.chm-gray-browse img,
            html.chm-gray-browse video,
            html.chm-gray-browse [style*="background-image"] {
              filter: grayscale(0.88) contrast(0.95) opacity(0.76) !important;
              transition: filter 0.16s ease, opacity 0.16s ease;
            }
            html.chm-gray-browse img:hover,
            html.chm-gray-browse video:hover {
              filter: none !important;
              opacity: 1 !important;
            }
            .bili-mini-mask, .login-panel-popover, .lt-row, .bili-Layout-header, ytd-consent-bump-v2-lightbox { display: none !important; }
            #chm-srch-proj-btn {
              position: fixed; top: 12px; right: 14px; z-index: 2147483647;
              appearance: none; border: 1px solid rgba(52,211,153,0.65);
              background: linear-gradient(135deg, rgba(5,150,105,0.94), rgba(13,148,136,0.94));
              color: #fff; font: 700 11.5px -apple-system, 'PingFang SC', sans-serif;
              padding: 6px 12px; border-radius: 999px; cursor: pointer;
              box-shadow: 0 8px 24px rgba(0,0,0,0.45); display: none;
            }
            #chm-srch-proj-btn:hover { filter: brightness(1.1); transform: translateY(-1px); }
            #chm-srch-toast {
              position: fixed; top: 14px; left: 50%; transform: translateX(-50%); z-index: 2147483647;
              padding: 7px 14px; border-radius: 999px;
              background: rgba(13,17,23,0.94); border: 1px solid rgba(52,211,153,0.55);
              color: #a7f3d0; font: 600 11.5px -apple-system, 'PingFang SC', sans-serif;
              box-shadow: 0 10px 28px rgba(0,0,0,0.5); display: none; white-space: nowrap;
            }
            .chm-card-proj {
              position: absolute; top: 6px; right: 6px; z-index: 40;
              appearance: none; border: 1px solid rgba(52,211,153,0.7);
              background: rgba(5,150,105,0.92); color: #fff;
              font: 700 10px -apple-system, 'PingFang SC', sans-serif;
              padding: 3px 7px; border-radius: 999px; cursor: pointer;
              box-shadow: 0 3px 10px rgba(0,0,0,0.45); opacity: 0; transition: opacity 0.14s ease;
            }
            .bili-video-card:hover .chm-card-proj,
            ytd-video-renderer:hover .chm-card-proj,
            ytd-rich-item-renderer:hover .chm-card-proj { opacity: 1; }
            .chm-card-proj:hover { background: #10b981; }
          `;
          document.head?.appendChild(st);

          const btn = document.createElement('button');
          btn.id = 'chm-srch-proj-btn';
          btn.textContent = '变色龙小窗播放 ▶';
          btn.addEventListener('click', (e) => {
            e.preventDefault();
            e.stopPropagation();
            post({ action: 'projectFromSearchBrowser' });
          });
          document.body?.appendChild(btn);

          const toast = document.createElement('div');
          toast.id = 'chm-srch-toast';
          document.body?.appendChild(toast);
          let toastTimer = null;
          window.__CHAMELEON_SHOW_SRCH_TOAST__ = (msg) => {
            toast.textContent = msg;
            toast.style.display = 'block';
            clearTimeout(toastTimer);
            toastTimer = setTimeout(() => { toast.style.display = 'none'; }, 3500);
          };

          window.__CHAMELEON_SET_SRCH_MODE__ = (active) => {
            srchOverlayEnabled = Boolean(active);
            if (!srchOverlayEnabled) {
              btn.remove();
              toast.remove();
              document.querySelectorAll('.chm-card-proj').forEach(x => x.remove());
            }
          };

          function attachCardQuickButtons() {
            if (!srchOverlayEnabled || window.__CHAMELEON_BUILTIN_LOADED__) return;
            const cards = document.querySelectorAll('.bili-video-card, ytd-video-renderer, ytd-rich-item-renderer');
            for (const card of cards) {
              if (card.dataset.chmCardBound) continue;
              const link = card.querySelector('a[href*="/video/BV"], a#thumbnail[href*="/watch?v="]');
              if (!link) continue;
              const rawHref = link.getAttribute('href') || '';
              if (!rawHref) continue;
              const fullHref = rawHref.startsWith('//') ? 'https:' + rawHref
                : rawHref.startsWith('/') ? location.origin + rawHref : rawHref;
              const imgWrap = card.querySelector('.bili-video-card__image, #thumbnail') || card;
              if (getComputedStyle(imgWrap).position === 'static') {
                imgWrap.style.position = 'relative';
              }
              const pb = document.createElement('button');
              pb.className = 'chm-card-proj';
              pb.textContent = '变色龙小窗播 ▶';
              pb.addEventListener('click', (e) => {
                e.preventDefault();
                e.stopPropagation();
                post({ action: 'openDirectUrl', url: fullHref });
              });
              imgWrap.appendChild(pb);
              card.dataset.chmCardBound = '1';
            }
          }

          setInterval(() => {
            if (!srchOverlayEnabled || window.__CHAMELEON_BUILTIN_LOADED__) {
              btn.style.display = 'none';
              return;
            }
            if (!location.href.startsWith('http')) {
              btn.style.display = 'none';
              return;
            }
            attachCardQuickButtons();
            const isListPage = location.hostname === 'search.bilibili.com' || location.pathname.startsWith('/results');
            const hasVid = !isListPage && Array.from(document.querySelectorAll('video')).some(v => {
              const r = v.getBoundingClientRect();
              return (r.width >= 160 && r.height >= 90) || v.readyState >= 1;
            });
            btn.style.display = hasVid ? 'inline-flex' : 'none';
          }, 500);
        })();
        """#
    }

    private static func stealthStartPageHtml() -> String {
        return """
        <!doctype html>
        <html lang="zh-CN">
        <head>
          <meta charset="utf-8" />
          <style>
            * { box-sizing: border-box; margin: 0; padding: 0; }
            html, body {
              width: 100%; height: 100%; background: #0d1117; color: #c9d1d9;
              font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, "SF Mono", "PingFang SC", monospace;
              overflow: hidden;
            }
            .wrap { display: flex; flex-direction: column; height: 100%; }
            .bar {
              display: flex; align-items: center; justify-content: space-between;
              padding: 8px 12px; border-bottom: 1px solid rgba(255,255,255,0.08);
              background: rgba(255,255,255,0.02); flex-shrink: 0; gap: 8px;
            }
            .tabs, .sites { display: flex; align-items: center; gap: 4px; flex-wrap: wrap; }
            .tab, .site {
              appearance: none; border: 1px solid rgba(255,255,255,0.08); background: rgba(255,255,255,0.03);
              color: #8b949e; font: inherit; font-size: 11px; padding: 3px 8px; border-radius: 5px; cursor: pointer;
            }
            .tab:hover, .site:hover { color: #fff; border-color: rgba(52,211,153,0.45); }
            .tab.active { color: #6ee7b7; background: rgba(16,185,129,0.16); border-color: rgba(52,211,153,0.5); font-weight: 600; }
            .site { color: #79c0ff; }
            .hint-banner {
              padding: 6px 12px; font-size: 10.5px; color: #6ee7b7;
              background: rgba(16,185,129,0.08); border-bottom: 1px solid rgba(52,211,153,0.18);
              display: none; flex-shrink: 0;
            }
            .list { flex: 1; overflow-y: auto; padding: 6px 8px; display: flex; flex-direction: column; gap: 2px; }
            .row {
              display: flex; align-items: center; gap: 8px; padding: 6px 8px; border-radius: 6px;
              font-size: 11.5px; cursor: pointer; border-left: 2px solid transparent;
            }
            .row:hover { background: rgba(52,211,153,0.10); border-left-color: #34d399; }
            .idx { color: #64748b; flex-shrink: 0; }
            .tag { color: #79c0ff; flex-shrink: 0; }
            .dur { color: #34d399; flex-shrink: 0; min-width: 40px; }
            .ttl { flex: 1; min-width: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
            .up { color: #64748b; flex-shrink: 0; max-width: 110px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
            .go-btn {
              appearance: none; border: 1px solid rgba(52,211,153,0.4); background: rgba(16,185,129,0.15);
              color: #6ee7b7; font: inherit; font-size: 10px; padding: 2px 7px; border-radius: 4px; cursor: pointer; flex-shrink: 0;
            }
            .go-btn:hover { background: #059669; color: #fff; }
            .empty { padding: 28px; text-align: center; color: #64748b; font-size: 11.5px; }
          </style>
        </head>
        <body>
          <div class="wrap">
            <div class="bar">
              <div class="tabs" id="tabs">
                <button class="tab active" data-feed="hot">--hot 全站热榜</button>
                <button class="tab" data-feed="tech">--tech 科技数码</button>
                <button class="tab" data-feed="standup">--standup 下饭吐槽</button>
                <button class="tab" data-feed="film">--film 影视解说</button>
                <button class="tab" data-feed="lofi">--lofi 白噪音</button>
              </div>
              <div class="sites">
                <button class="site" data-url="https://www.bilibili.com/">B站</button>
                <button class="site" data-url="https://cn.bing.com/">必应</button>
                <button class="site" data-url="https://www.youtube.com/">YouTube</button>
                <button class="site" data-url="https://www.douyin.com/">抖音</button>
              </div>
            </div>
            <div class="hint-banner" id="hintBanner"></div>
            <div class="list" id="feedList"><div class="empty">[init] loading package index (--hot)...</div></div>
          </div>
          <script>
            const post = (p) => window.webkit?.messageHandlers?.ghostAction?.postMessage(p);
            const feedList = document.getElementById('feedList');
            const hintBanner = document.getElementById('hintBanner');
            let seq = 0, activeReq = '';

            window.setStartPageHint = (msg) => {
              hintBanner.textContent = msg;
              hintBanner.style.display = msg ? 'block' : 'none';
            };

            function loadFeed(src) {
              activeReq = 'srch_' + (++seq);
              feedList.innerHTML = '<div class="empty">[sync] resolving index (' + src + ')...</div>';
              post({ action: 'fetchStealthFeed', source: src, query: '', reqId: activeReq });
            }

            window.onStealthHomeFeedResult = (res) => {
              if (!res || (res.reqId && activeReq && res.reqId !== activeReq)) return;
              const items = res.items || [];
              if (!items.length) {
                feedList.innerHTML = '<div class="empty">[err] 暂未获取到列表，可在顶部地址栏直接输入关键词全网搜片</div>';
                return;
              }
              feedList.innerHTML = '';
              items.forEach((it, idx) => {
                const row = document.createElement('div');
                row.className = 'row';
                row.title = '点击在浏览器中打开；点右侧「直投小窗」直接无边框播放';
                const esc = (s) => String(s || '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
                row.innerHTML = '<span class="idx">[' + String(idx + 1).padStart(2, '0') + ']</span>' +
                  '<span class="tag">mod::' + esc((it.bvid || 'bv').slice(0, 8)) + '</span>' +
                  '<span class="dur">' + esc(it.duration || '--:--') + '</span>' +
                  '<span class="ttl">' + esc(it.title) + '</span>' +
                  '<span class="up">// ' + esc(it.author || '') + '</span>' +
                  '<button class="go-btn">直投小窗</button>';
                row.addEventListener('click', () => {
                  window.location.href = it.url;
                });
                row.querySelector('.go-btn').addEventListener('click', (e) => {
                  e.stopPropagation();
                  post({ action: 'openDirectUrl', url: it.url });
                });
                feedList.appendChild(row);
              });
            };

            document.querySelectorAll('.tab').forEach(b => {
              b.addEventListener('click', () => {
                document.querySelectorAll('.tab').forEach(x => x.classList.toggle('active', x === b));
                loadFeed(b.dataset.feed);
              });
            });
            document.querySelectorAll('.site').forEach(b => {
              b.addEventListener('click', () => {
                window.location.href = b.dataset.url;
              });
            });
            loadFeed('hot');
          </script>
        </body>
        </html>
        """
    }

    private static func stripHtmlEntities(_ raw: String) -> String {
        var s = raw.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities: [(String, String)] = [
            ("&quot;", "\""), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&#39;", "'"), ("&apos;", "'"), ("&nbsp;", " ")
        ]
        for (k, v) in entities { s = s.replacingOccurrences(of: k, with: v) }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func formatDurationValue(_ raw: Any?) -> String {
        if let sec = raw as? Int {
            let m = max(0, sec) / 60
            let s = max(0, sec) % 60
            return String(format: "%02d:%02d", m, s)
        }
        if let dStr = raw as? String, !dStr.isEmpty {
            return dStr
        }
        return "--:--"
    }

    private static func formatViewCount(_ count: Int) -> String {
        if count >= 10000 {
            return String(format: "%.1f万", Double(count) / 10000.0)
        }
        return "\(max(0, count))"
    }

    private func ensureBiliCookie(forceRefresh: Bool = false, completion: @escaping (String) -> Void) {
        if !forceRefresh, !cachedBiliCookie.isEmpty {
            completion(cachedBiliCookie)
            return
        }
        guard let url = URL(string: "https://www.bilibili.com/") else { completion(""); return }
        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { [weak self] _, resp, _ in
            var cookiePairs: [String] = []
            if let http = resp as? HTTPURLResponse,
               let headers = http.allHeaderFields as? [String: String],
               let respUrl = http.url {
                let cookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: respUrl)
                cookiePairs = cookies.map { "\($0.name)=\($0.value)" }
            }
            let joined = cookiePairs.joined(separator: "; ")
            if !joined.isEmpty {
                self?.cachedBiliCookie = joined
            }
            completion(joined)
        }.resume()
    }

    private func fetchStealthFeed(source: String, query: String, reqId: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let keyword: String
        if !trimmed.isEmpty {
            keyword = trimmed
        } else {
            switch source {
            case "tech": keyword = "科技 AI 硬核评测"
            case "standup": keyword = "脱口秀 单口喜剧 下饭"
            case "film": keyword = "高分电影 深度解说"
            case "lofi": keyword = "Lofi 雨声 白噪音 编程"
            default: keyword = ""
            }
        }

        let ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"

        if keyword.isEmpty {
            guard let url = URL(string: "https://api.bilibili.com/x/web-interface/popular?ps=24&pn=1") else {
                pushStealthFeedToWebView(reqId: reqId, items: [], error: "invalid_url")
                return
            }
            var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
            req.setValue(ua, forHTTPHeaderField: "User-Agent")
            req.setValue("https://www.bilibili.com/", forHTTPHeaderField: "Referer")
            URLSession.shared.dataTask(with: req) { [weak self] data, _, err in
                guard let self = self else { return }
                guard err == nil, let data = data,
                      let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let dObj = root["data"] as? [String: Any],
                      let list = dObj["list"] as? [[String: Any]] else {
                    self.pushStealthFeedToWebView(reqId: reqId, items: [], error: err?.localizedDescription ?? "network_error")
                    return
                }
                let items: [[String: String]] = list.compactMap { row in
                    guard let bvid = row["bvid"] as? String, !bvid.isEmpty else { return nil }
                    let rawTitle = (row["title"] as? String) ?? "Untitled"
                    let owner = (row["owner"] as? [String: Any])?["name"] as? String ?? "B站UP"
                    let views = (row["stat"] as? [String: Any])?["view"] as? Int ?? 0
                    return [
                        "bvid": bvid,
                        "title": Self.stripHtmlEntities(rawTitle),
                        "author": Self.stripHtmlEntities(owner),
                        "duration": Self.formatDurationValue(row["duration"]),
                        "views": Self.formatViewCount(views),
                        "url": "https://www.bilibili.com/video/\(bvid)"
                    ]
                }
                self.pushStealthFeedToWebView(reqId: reqId, items: items, error: nil)
            }.resume()
            return
        }

        let encoded = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
        let searchUrlStr = "https://api.bilibili.com/x/web-interface/search/type?search_type=video&keyword=\(encoded)&page=1&page_size=22"
        func runSearch(retryAfterRefresh: Bool) {
            ensureBiliCookie(forceRefresh: retryAfterRefresh) { [weak self] cookie in
                guard let self = self, let url = URL(string: searchUrlStr) else { return }
                var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
                req.setValue(ua, forHTTPHeaderField: "User-Agent")
                req.setValue("https://www.bilibili.com/", forHTTPHeaderField: "Referer")
                if !cookie.isEmpty { req.setValue(cookie, forHTTPHeaderField: "Cookie") }
                URLSession.shared.dataTask(with: req) { [weak self] data, _, err in
                    guard let self = self else { return }
                    guard err == nil, let data = data,
                          let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        self.pushStealthFeedToWebView(reqId: reqId, items: [], error: err?.localizedDescription ?? "network_error")
                        return
                    }
                    let code = (root["code"] as? Int) ?? -1
                    if code != 0 && !retryAfterRefresh {
                        self.cachedBiliCookie = ""
                        runSearch(retryAfterRefresh: true)
                        return
                    }
                    let list = (root["data"] as? [String: Any])?["result"] as? [[String: Any]] ?? []
                    let items: [[String: String]] = list.compactMap { row in
                        guard let bvid = row["bvid"] as? String, !bvid.isEmpty else { return nil }
                        let rawTitle = (row["title"] as? String) ?? "Untitled"
                        let author = (row["author"] as? String) ?? "B站UP"
                        let views = (row["play"] as? Int) ?? 0
                        return [
                            "bvid": bvid,
                            "title": Self.stripHtmlEntities(rawTitle),
                            "author": Self.stripHtmlEntities(author),
                            "duration": Self.formatDurationValue(row["duration"]),
                            "views": Self.formatViewCount(views),
                            "url": "https://www.bilibili.com/video/\(bvid)"
                        ]
                    }
                    self.pushStealthFeedToWebView(reqId: reqId, items: items, error: nil)
                }.resume()
            }
        }
        runSearch(retryAfterRefresh: false)
    }

    private static func builtInBridgeScript() -> String {
        return #"""
        (function() {
          if (window.__CHAMELEON_BUILTIN_LOADED__) return;
          window.__CHAMELEON_BUILTIN_LOADED__ = true;
          const post = (p) => window.webkit?.messageHandlers?.ghostAction?.postMessage(p);

          let targetVideo = null;
          let wasPlayingBeforeBoss = false;
          let bossMode = false;
          let stopped = false;
          let tainted = false;
          let taintNotified = false;
          let canvas = null;
          let ctx = null;
          let stealthSubOn = true;

          const seenDm = [];
          const seenDmSet = new Set();
          let lastDmText = '';
          let lastDmAt = 0;

          const st = document.createElement('style');
          st.id = 'chm-builtin-style';
          st.textContent = `
            html, body { background: #000 !important; overflow: hidden !important; margin: 0 !important; padding: 0 !important; }
            .bili-mini-mask, .login-panel-popover, .lt-row, .bili-Layout-header, ytd-consent-bump-v2-lightbox, #chm-srch-proj-btn, .chm-card-proj { display: none !important; }
            video.chm-prod-vid {
              position: fixed !important; inset: 0 !important; width: 100vw !important; height: 100vh !important;
              max-width: none !important; max-height: none !important; min-width: 100vw !important; min-height: 100vh !important;
              margin: 0 !important; padding: 0 !important; object-fit: cover !important;
              z-index: 2147483647 !important; background: #000 !important;
              opacity: 1 !important; visibility: visible !important; display: block !important; transform: none !important;
            }
          `;
          document.head?.appendChild(st);

          function findBestVideo() {
            const vids = Array.from(document.querySelectorAll('video'));
            let best = null, bestScore = -1;
            for (const v of vids) {
              if (!v.isConnected) continue;
              const r = v.getBoundingClientRect();
              const area = Math.max(0, r.width) * Math.max(0, r.height);
              if (area < 4000 && v.readyState < 2) continue;
              let s = area / 1000;
              if (!v.paused && !v.ended) s += 8000;
              if (v.readyState >= 2) s += 2000;
              if (v.currentTime > 0) s += 500;
              if (s > bestScore) { bestScore = s; best = v; }
            }
            return best;
          }

          function readSub(v) {
            const sels = [
              '.bpx-player-subtitle-panel-text',
              '.bili-subtitle-x-subtitle-panel-text',
              '.bilibili-player-video-subtitle .subtitle-item-text',
              '.ytp-caption-segment',
              '.txp_subtitle_text',
              '.iqp-subtitle-text',
              '.xg-text-track-span'
            ];
            for (const sel of sels) {
              const ns = document.querySelectorAll(sel);
              if (ns.length) {
                const txt = Array.from(ns).map(n => (n.textContent || '').trim()).filter(Boolean).join(' ');
                if (txt) return txt;
              }
            }
            if (v?.textTracks) {
              let hasAct = false;
              for (const tr of v.textTracks) {
                if (tr.mode === 'showing' || tr.mode === 'hidden') { hasAct = true; break; }
              }
              if (!hasAct) {
                for (const tr of v.textTracks) {
                  if (tr.kind === 'subtitles' || tr.kind === 'captions') {
                    try { tr.mode = 'hidden'; } catch (_) {}
                    break;
                  }
                }
              }
              for (const tr of v.textTracks) {
                if ((tr.mode === 'showing' || tr.mode === 'hidden') && tr.activeCues?.length) {
                  return Array.from(tr.activeCues).map(c => c.text || '').join(' ').replace(/<[^>]+>/g, '').trim();
                }
              }
            }
            if (stealthSubOn) {
              const now = performance.now();
              const dms = document.querySelectorAll('.bpx-player-row-dm-wrap .bili-danmaku-x-dm, .bilibili-player-video-danmaku .b-danmaku, .xgplayer-danmu div');
              if (dms.length > 0 && now - lastDmAt < 1100 && lastDmText) return lastDmText;
              const picked = [];
              for (const dn of dms) {
                const t = (dn.textContent || '').split(/\s+/).filter(Boolean).join(' ').trim();
                if (t.length >= 2 && t.length <= 60 && !seenDmSet.has(t)) {
                  seenDmSet.add(t);
                  seenDm.push(t);
                  if (seenDm.length > 80) seenDmSet.delete(seenDm.shift());
                  picked.push(t);
                  if (picked.length >= 2) break;
                }
              }
              if (picked.length > 0) {
                lastDmText = picked.join('  //  ');
                lastDmAt = now;
                return lastDmText;
              }
              if (now - lastDmAt < 3200 && lastDmText) return lastDmText;
            }
            return '';
          }

          function pushMetaNow() {
            if (stopped) return;
            const v = targetVideo || findBestVideo();
            if (!v) return;
            const aspect = (v.videoWidth || 16) / Math.max(1, v.videoHeight || 9);
            const payload = {
              type: 'meta',
              aspect: aspect,
              subtitle: readSub(v),
              player: {
                paused: Boolean(v.paused),
                ended: Boolean(v.ended),
                readyState: v.readyState || 0,
                currentTime: Number(v.currentTime || 0),
                duration: Number.isFinite(v.duration) ? v.duration : 0,
                muted: Boolean(v.muted || v.volume === 0),
                volume: Number(v.volume ?? 1),
                playbackRate: Number(v.playbackRate || 1)
              }
            };
            post({ action: 'builtInVideoMeta', json: JSON.stringify(payload) });
          }

          function ensureCanvas(w, h) {
            if (!canvas) {
              canvas = document.createElement('canvas');
              canvas.width = w;
              canvas.height = h;
              ctx = canvas.getContext('2d', { alpha: false });
            } else if (canvas.width !== w || canvas.height !== h) {
              canvas.width = w;
              canvas.height = h;
            }
            return ctx;
          }

          function captureAndSendFrame() {
            if (stopped || bossMode || tainted) return;
            const v = targetVideo || findBestVideo();
            if (!v || v.readyState < 2 || !v.videoWidth || !v.videoHeight) return;
            targetVideo = v;
            if (!v.classList.contains('chm-prod-vid')) {
              document.querySelectorAll('video.chm-prod-vid').forEach(el => el.classList.remove('chm-prod-vid'));
              v.classList.add('chm-prod-vid');
            }
            const aspect = v.videoWidth / Math.max(1, v.videoHeight);
            const tw = aspect < 0.85 ? 272 : 448;
            const th = Math.max(136, Math.round(tw / aspect));
            const c = ensureCanvas(tw, th);
            if (!c) return;
            try {
              c.drawImage(v, 0, 0, tw, th);
              const dataUrl = canvas.toDataURL('image/jpeg', 0.72);
              const comma = dataUrl.indexOf(',');
              if (comma > 0) {
                post({ action: 'builtInVideoFrame', b64: dataUrl.slice(comma + 1) });
              }
            } catch (_) {
              tainted = true;
              if (!taintNotified) {
                taintNotified = true;
                post({ action: 'builtInCanvasTainted' });
              }
            }
          }

          let autoPlayAttempted = false;
          const isDirectWatchUrl = location.href.includes('/video/') || location.href.includes('youtube.com/watch');

          const frameTimer = setInterval(() => {
            if (stopped) { clearInterval(frameTimer); return; }
            const v = findBestVideo();
            if (v && v !== targetVideo) {
              targetVideo = v;
              tainted = false;
              taintNotified = false;
              v.classList.add('chm-prod-vid');
            }
            if (v && isDirectWatchUrl && !autoPlayAttempted && v.paused && v.readyState >= 1 && !bossMode) {
              autoPlayAttempted = true;
              v.play().catch(() => {});
            }
            captureAndSendFrame();
          }, 26);

          const metaTimer = setInterval(() => {
            if (stopped) { clearInterval(metaTimer); return; }
            pushMetaNow();
          }, 340);

          setTimeout(pushMetaNow, 120);

          window.ChameleonBuiltInBridge = {
            stop() {
              stopped = true;
              clearInterval(frameTimer);
              clearInterval(metaTimer);
              const v = targetVideo || findBestVideo();
              try { v?.pause(); } catch (_) {}
            },
            applyPatch(p) {
              if (p && typeof p.stealthSubtitle === 'boolean') stealthSubOn = p.stealthSubtitle;
            },
            setBossMode(val) {
              bossMode = Boolean(val);
              const v = targetVideo || findBestVideo();
              if (!v) return;
              if (bossMode) {
                wasPlayingBeforeBoss = !v.paused;
                v.pause();
              } else if (wasPlayingBeforeBoss) {
                v.play().catch(() => {});
              }
              pushMetaNow();
            },
            execPlayerCmd(cmd) {
              const v = targetVideo || findBestVideo();
              if (!v || !cmd) return;
              if (cmd.action === 'setPaused') { cmd.value ? v.pause() : v.play().catch(() => {}); }
              else if (cmd.action === 'togglePlay') { v.paused ? v.play().catch(() => {}) : v.pause(); }
              else if (cmd.action === 'seek') { v.currentTime = Math.max(0, (v.currentTime || 0) + Number(cmd.delta || 0)); }
              else if (cmd.action === 'seekTo' && Number.isFinite(cmd.value)) { v.currentTime = Math.max(0, cmd.value); }
              else if (cmd.action === 'setMuted') { v.muted = Boolean(cmd.value); if (!v.muted && v.volume < 0.05) v.volume = 0.85; }
              else if (cmd.action === 'toggleMute') { v.muted = !(v.muted || v.volume === 0); if (!v.muted && v.volume < 0.05) v.volume = 0.85; }
              else if (cmd.action === 'setVolume' && Number.isFinite(cmd.value)) { v.volume = Math.max(0, Math.min(1, Number(cmd.value))); v.muted = v.volume === 0; }
              else if (cmd.action === 'setRate' && Number.isFinite(cmd.value)) { v.playbackRate = Number(cmd.value); }
              setTimeout(pushMetaNow, 30);
            }
          };
        })();
        """#
    }

    // MARK: - Independent Multi-Line Developer Terminal / Output Console Window
    private func ensureStealthLogPanel() {
        if logPanel != nil { return }
        let screenVis = (panel?.screen ?? NSScreen.main)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let w: CGFloat = min(580, max(380, screenVis.width * 0.42))
        let h: CGFloat = 192
        let rect = NSRect(x: screenVis.minX + 26, y: screenVis.minY + 26, width: w, height: h)

        let lp = GhostPanel(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel, .resizable],
            backing: .buffered,
            defer: false
        )
        lp.isOpaque = false
        lp.backgroundColor = .clear
        lp.hasShadow = true
        lp.level = .floating
        lp.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        lp.sharingType = hideFromCapture ? .none : .readOnly
        lp.minSize = NSSize(width: 360, height: 115)

        let cfg = WKWebViewConfiguration()
        cfg.userContentController.add(self, name: "ghostAction")
        let lwv = FirstMouseWebView(frame: lp.contentView!.bounds, configuration: cfg)
        lwv.autoresizingMask = [.width, .height]
        lwv.setValue(false, forKey: "drawsBackground")
        lp.contentView?.addSubview(lwv)
        lwv.loadHTMLString(Self.stealthLogConsoleHtml(), baseURL: nil)

        self.logPanel = lp
        self.logWebView = lwv
    }

    private func setStealthLogPanelVisible(_ visible: Bool) {
        if visible {
            ensureStealthLogPanel()
            logPanel?.orderFrontRegardless()
            if !lastLogConsoleJson.isEmpty {
                let js = "window.StealthConsoleBridge?.pushSubtitle(\(lastLogConsoleJson));"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
                    self?.logWebView?.evaluateJavaScript(js, completionHandler: nil)
                }
            }
            if bossMode {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
                    self?.logWebView?.evaluateJavaScript("window.StealthConsoleBridge?.setBossSafeMode(true);", completionHandler: nil)
                }
            }
        } else {
            logPanel?.orderOut(nil)
        }
    }

    private func pushStealthLogToConsole(_ dict: [String: Any]) {
        guard stealthSubtitleEnabled else { return }
        if logPanel?.isVisible != true {
            setStealthLogPanelVisible(true)
        }
        let payload: [String: Any] = [
            "text": (dict["text"] as? String) ?? "",
            "paused": (dict["paused"] as? Bool) ?? isPlayerPaused,
            "currentTime": (dict["currentTime"] as? Double) ?? playerCurTime,
            "duration": (dict["duration"] as? Double) ?? playerDuration
        ]
        if let rawData = try? JSONSerialization.data(withJSONObject: payload, options: []),
           let json = String(data: rawData, encoding: .utf8) {
            lastLogConsoleJson = json
            logWebView?.evaluateJavaScript("window.StealthConsoleBridge?.pushSubtitle(\(json));", completionHandler: nil)
        }
    }

    private static func stealthLogConsoleHtml() -> String {
        return #"""
        <!doctype html>
        <html lang="zh-CN">
        <head>
          <meta charset="utf-8" />
          <style>
            * { box-sizing: border-box; margin: 0; padding: 0; }
            html, body {
              width: 100%; height: 100%; overflow: hidden; background: transparent;
              font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, "SF Mono", "PingFang SC", monospace;
              -webkit-font-smoothing: antialiased;
            }
            .shell {
              display: flex; flex-direction: column; width: 100%; height: 100%;
              border-radius: 9px; overflow: hidden;
              background: #0d1117; border: 1px solid rgba(255,255,255,0.12); color: #c9d1d9;
            }
            body[data-theme="light"] .shell {
              background: #f8fafc; border-color: rgba(15,23,42,0.16); color: #1e293b;
            }
            body[data-theme="glass"] .shell {
              background: rgba(13,17,23,0.72); border-color: rgba(255,255,255,0.14);
              backdrop-filter: blur(14px); -webkit-backdrop-filter: blur(14px);
            }
            .hdr {
              height: 28px; display: flex; align-items: center; justify-content: space-between;
              padding: 0 10px; border-bottom: 1px solid rgba(255,255,255,0.08);
              background: rgba(255,255,255,0.03); flex-shrink: 0; cursor: grab; user-select: none;
              font-size: 10.5px;
            }
            body[data-theme="light"] .hdr {
              border-bottom-color: rgba(15,23,42,0.10); background: rgba(15,23,42,0.04);
            }
            .tabs { display: flex; align-items: center; gap: 11px; }
            .tab-lbl { color: #6e7681; font-weight: 600; letter-spacing: 0.3px; }
            .tab-lbl.on { color: #e6edf3; border-bottom: 1.5px solid #34d399; padding: 5px 0; }
            body[data-theme="light"] .tab-lbl.on { color: #0f172a; }
            .hdr-tools { display: flex; align-items: center; gap: 4px; }
            .tbtn {
              appearance: none; border: 1px solid rgba(255,255,255,0.11); background: rgba(255,255,255,0.04);
              color: #8b949e; font: inherit; font-size: 10px; padding: 2px 6px; border-radius: 4px; cursor: pointer;
            }
            .tbtn:hover { color: #fff; border-color: rgba(52,211,153,0.45); }
            .tbtn.on { color: #6ee7b7; border-color: rgba(52,211,153,0.55); background: rgba(16,185,129,0.16); font-weight: 600; }
            body[data-theme="light"] .tbtn { border-color: rgba(15,23,42,0.15); color: #475569; background: rgba(15,23,42,0.03); }
            body[data-theme="light"] .tbtn.on { color: #047857; background: rgba(16,185,129,0.14); border-color: rgba(16,185,129,0.45); }
            .body {
              flex: 1; overflow-y: auto; padding: 8px 12px; font-size: 11.5px; line-height: 1.56;
              user-select: text;
            }
            .body::-webkit-scrollbar { width: 5px; }
            .body::-webkit-scrollbar-thumb { background: rgba(148,163,184,0.22); border-radius: 99px; }
            .log-row {
              white-space: pre-wrap; word-break: break-word;
              padding: 1.5px 0 1.5px 14px; text-indent: -14px;
            }
            .ts { color: #6e7681; }
            .lv-info { color: #34d399; font-weight: 700; }
            .lv-dbg { color: #79c0ff; font-weight: 600; }
            .mod { color: #79c0ff; }
            .msg { color: #e6edf3; }
            .meta { color: #8b949e; }
            body[data-theme="light"] .ts, body[data-theme="light"] .meta { color: #64748b; }
            body[data-theme="light"] .lv-info { color: #059669; }
            body[data-theme="light"] .lv-dbg, body[data-theme="light"] .mod { color: #0284c7; }
            body[data-theme="light"] .msg { color: #0f172a; }
            body.boss-safe .sub-line { display: none !important; }
            .ftr {
              height: 20px; display: flex; align-items: center; justify-content: space-between;
              padding: 0 10px; font-size: 10px; color: #6e7681; flex-shrink: 0;
              border-top: 1px solid rgba(255,255,255,0.06); background: rgba(255,255,255,0.02);
              user-select: none;
            }
            body[data-theme="light"] .ftr { border-top-color: rgba(15,23,42,0.08); background: rgba(15,23,42,0.02); }
            .cur {
              display: inline-block; width: 6px; height: 11px; background: #34d399;
              vertical-align: middle; margin-left: 4px; animation: blink 1.1s steps(2, start) infinite;
            }
            @keyframes blink { 0%, 100% { opacity: 1; } 50% { opacity: 0; } }
          </style>
        </head>
        <body>
          <div class="shell">
            <div class="hdr">
              <div class="tabs">
                <span class="tab-lbl">PROBLEMS</span>
                <span class="tab-lbl on">OUTPUT</span>
                <span class="tab-lbl">TERMINAL</span>
              </div>
              <div class="hdr-tools">
                <button class="tbtn on" data-tpl="api">后端API</button>
                <button class="tbtn" data-tpl="ml">模型训练</button>
                <button class="tbtn" data-tpl="test">编译测试</button>
                <button class="tbtn" id="btnTheme">暗色</button>
                <button class="tbtn" id="btnSm">A-</button>
                <button class="tbtn" id="btnLg">A+</button>
                <button class="tbtn" id="btnClr">清空</button>
                <button class="tbtn" id="btnCls" title="关闭终端日志窗口">×</button>
              </div>
            </div>
            <div class="body" id="logBody"></div>
            <div class="ftr">
              <span id="ftrLeft">main*  0 errors  0 warnings  |  worker-runtime (watch)</span>
              <span>UTF-8  LF  <span id="ftrState">IDLE</span><span class="cur"></span></span>
            </div>
          </div>

          <script>
            const post = (p) => window.webkit?.messageHandlers?.ghostAction?.postMessage(p);
            const logBody = document.getElementById('logBody');
            const ftrState = document.getElementById('ftrState');
            const themes = ['dark', 'light', 'glass'];
            const themeLabels = { dark: '暗色', light: '浅色', glass: '透底' };
            let curTheme = localStorage.getItem('chmLogTheme') || 'dark';
            let curTpl = localStorage.getItem('chmLogTpl') || 'api';
            let fontPx = Number(localStorage.getItem('chmLogFont') || 11.5);
            let reqSeq = 1040;
            let trainStep = 14820;
            let lastSub = '';
            let hovered = false;

            function applyUiPrefs() {
              document.body.setAttribute('data-theme', curTheme);
              document.getElementById('btnTheme').textContent = themeLabels[curTheme] || '暗色';
              logBody.style.fontSize = fontPx.toFixed(1) + 'px';
              document.querySelectorAll('[data-tpl]').forEach(b => b.classList.toggle('on', b.dataset.tpl === curTpl));
            }

            function nowStamp() {
              const d = new Date();
              const ms = String(d.getMilliseconds()).padStart(3, '0');
              return String(d.getHours()).padStart(2, '0') + ':' +
                     String(d.getMinutes()).padStart(2, '0') + ':' +
                     String(d.getSeconds()).padStart(2, '0') + '.' + ms;
            }

            function esc(s) {
              return String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
            }

            function appendRow(html, isSub) {
              const row = document.createElement('div');
              row.className = isSub ? 'log-row sub-line' : 'log-row';
              row.innerHTML = html;
              logBody.appendChild(row);
              while (logBody.children.length > 90) {
                logBody.removeChild(logBody.firstChild);
              }
              if (!hovered) {
                logBody.scrollTop = logBody.scrollHeight;
              }
            }

            function pushAmbient(forceMsg) {
              const ts = nowStamp();
              reqSeq += 1;
              trainStep += 4;
              const ms = (3.2 + (reqSeq % 14) * 0.6).toFixed(1);
              if (forceMsg) {
                appendRow(`<span class="ts">[${ts}]</span> <span class="lv-info">INFO </span> <span class="mod">[core.boot]</span> <span class="meta">${esc(forceMsg)}</span>`, false);
                return;
              }
              const pool = [
                `<span class="ts">[${ts}]</span> <span class="lv-dbg">DEBUG</span> <span class="mod">[pg.pool]</span> <span class="meta">conn_acquired=2 idle=6 tx=0x${reqSeq.toString(16)} (${ms}ms)</span>`,
                `<span class="ts">[${ts}]</span> <span class="lv-dbg">DEBUG</span> <span class="mod">[redis.lru]</span> <span class="meta">MGET batch_keys=18 hit_ratio=99.4% rss=41.2MB</span>`,
                `<span class="ts">[${ts}]</span> <span class="lv-info">INFO </span> <span class="mod">[grpc.gw]</span> <span class="meta">heartbeat ok shard=us-west-2 seq=${reqSeq} rtt=${ms}ms</span>`,
                `<span class="ts">[${ts}]</span> <span class="lv-dbg">DEBUG</span> <span class="mod">[vite.hmr]</span> <span class="meta">chunk graph verified (64 modules, 0 stale edges)</span>`
              ];
              appendRow(pool[reqSeq % pool.length], false);
            }

            function formatSubRow(clean) {
              const ts = nowStamp();
              reqSeq += 1;
              trainStep += 1;
              const lat = (4.1 + (reqSeq % 9) * 0.7).toFixed(1);
              if (curTpl === 'ml') {
                const loss = (0.0412 - (trainStep % 15) * 0.0004).toFixed(4);
                return `<span class="ts">[${ts}]</span> <span class="lv-info">TRAIN</span> <span class="mod">[eval.batch]</span> <span class="meta">step=${trainStep} loss=${loss} | sample="</span><span class="msg">${esc(clean)}</span><span class="meta">"</span>`;
              }
              if (curTpl === 'test') {
                return `<span class="ts">[${ts}]</span> <span class="lv-info">PASS </span> <span class="mod">[spec.suite]</span> <span class="meta">pipeline.spec.ts &gt; #${reqSeq}: </span><span class="msg">${esc(clean)}</span> <span class="meta">(${lat}ms)</span>`;
              }
              return `<span class="ts">[${ts}]</span> <span class="lv-info">INFO </span> <span class="mod">[trace.worker]</span> <span class="meta">req=0x${reqSeq.toString(16)} status=200 msg="</span><span class="msg">${esc(clean)}</span><span class="meta">" (${lat}ms)</span>`;
            }

            function seedInitialLogs() {
              pushAmbient('Initializing worker-runtime v5.4 (node=20.11, workers=8)');
              pushAmbient('Mounted telemetry bus & ring-buffer pipeline');
              pushAmbient('Connected datastore pool (primary=127.0.0.1, pool_max=32)');
              pushAmbient('Loaded scheduler policy [stealth-console=attached]');
              pushAmbient('Health check passed (0 warnings, 0 errors)');
            }

            logBody.addEventListener('mouseenter', () => { hovered = true; });
            logBody.addEventListener('mouseleave', () => { hovered = false; logBody.scrollTop = logBody.scrollHeight; });

            document.querySelectorAll('[data-tpl]').forEach(b => {
              b.addEventListener('click', () => {
                curTpl = b.dataset.tpl;
                localStorage.setItem('chmLogTpl', curTpl);
                applyUiPrefs();
              });
            });
            document.getElementById('btnTheme').addEventListener('click', () => {
              curTheme = themes[(themes.indexOf(curTheme) + 1) % themes.length];
              localStorage.setItem('chmLogTheme', curTheme);
              applyUiPrefs();
            });
            document.getElementById('btnSm').addEventListener('click', () => {
              fontPx = Math.max(9.5, fontPx - 0.5);
              localStorage.setItem('chmLogFont', String(fontPx));
              applyUiPrefs();
            });
            document.getElementById('btnLg').addEventListener('click', () => {
              fontPx = Math.min(16, fontPx + 0.5);
              localStorage.setItem('chmLogFont', String(fontPx));
              applyUiPrefs();
            });
            document.getElementById('btnClr').addEventListener('click', () => {
              logBody.innerHTML = '';
              lastSub = '';
              pushAmbient('Console buffer cleared');
            });
            document.getElementById('btnCls').addEventListener('click', () => {
              post({ action: 'closeStealthLogPanel' });
            });

            setInterval(() => { pushAmbient(null); }, 4200);

            window.StealthConsoleBridge = {
              pushSubtitle(payload) {
                if (!payload) return;
                const clean = String(payload.text || '').trim();
                const sec = Math.max(0, Math.floor(Number(payload.currentTime || 0)));
                const mm = String(Math.floor(sec / 60)).padStart(2, '0');
                const ss = String(sec % 60).padStart(2, '0');
                ftrState.textContent = (payload.paused ? 'PAUSE ' : 'LIVE ') + mm + ':' + ss;
                if (clean && clean !== lastSub) {
                  lastSub = clean;
                  appendRow(formatSubRow(clean), true);
                }
              },
              setBossSafeMode(active) {
                document.body.classList.toggle('boss-safe', Boolean(active));
                if (active) {
                  pushAmbient('Build verification snapshot complete (0 failures)');
                  pushAmbient('Idle GC pass reclaimed 12.4MB');
                }
              }
            };

            applyUiPrefs();
            seedInitialLogs();
          </script>
        </body>
        </html>
        """#
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let dict = message.body as? [String: Any],
              let action = dict["action"] as? String else { return }

        switch action {
        case "enableClickThrough":
            setClickThrough(true)
        case "membershipChanged":
            if let pro = dict["isPro"] as? Bool {
                applyMembershipEntitlement(pro)
            }
        case "requestUpgrade":
            let reason = (dict["reason"] as? String) ?? "请开发者喝杯美式（¥9.9 永久）即可永久解除每日 30 分钟限制并解锁全部支持者权益！"
            openArenaWindow(upgradeReason: reason)
        case "setBoss":
            if let v = dict["value"] as? Bool { setBoss(v) }
        case "openSearchBrowser":
            openSearchBrowserWindow()
        case "openWebVideoUrl":
            openSearchBrowserWindow()
        case "openStealthTerminal":
            openSearchBrowserWindow()
        case "projectFromSearchBrowser":
            projectSearchBrowserToSmallWindow()
        case "fetchStealthFeed":
            let source = (dict["source"] as? String) ?? "hot"
            let query = (dict["query"] as? String) ?? ""
            let reqId = (dict["reqId"] as? String) ?? ""
            fetchStealthFeed(source: source, query: query, reqId: reqId)
        case "openDirectUrl":
            if let rawUrl = dict["url"] as? String, !rawUrl.isEmpty {
                searchWindow?.orderOut(nil)
                loadBuiltInWebUrl(rawUrl)
            }
        case "exitBuiltInWeb":
            exitBuiltInWebMode()
        case "builtInVideoFrame":
            if isBuiltInWebActive && !bossMode,
               let b64 = dict["b64"] as? String,
               let data = Data(base64Encoded: b64) {
                wsHub.pushLocalBuiltInFrame(data)
            }
        case "builtInVideoMeta":
            if isBuiltInWebActive, let json = dict["json"] as? String {
                wsHub.pushLocalBuiltInText(json)
            }
        case "builtInCanvasTainted":
            if isBuiltInWebActive {
                startBuiltInSnapshotPump()
            }
        case "stealthLogUpdate":
            pushStealthLogToConsole(dict)
        case "closeStealthLogPanel":
            setStealthSubtitle(false)
        case "builtInVideoStatus":
            if let iso = dict["isolated"] as? Bool {
                builtInVideoIsolated = iso
                syncNativeIslandControls()
            }
        case "chromeStreamStarted":
            if !isVisible {
                isVisible = true
            }
            if bossMode {
                setBoss(false)
            }
            panel?.orderFrontRegardless()
            syncNativeIslandControls()
        case "stateChanged":
            if let st = dict["state"] as? [String: Any] {
                if let m = st["mode"] as? String { currentMode = m }
                if let s = st["stealth"] as? Int { currentStealth = s }
                if let asVal = st["autoSense"] as? Bool { autoSense = asVal }
                if let ss = st["stealthSubtitle"] as? Bool, ss != stealthSubtitleEnabled {
                    stealthSubtitleEnabled = ss
                    UserDefaults.standard.set(ss, forKey: "chameleonStealthSubtitle")
                    webView.evaluateJavaScript(
                        "window.GeckoNativeBridge?.applyPatch({\"stealthSubtitle\":\(ss ? "true" : "false"),\"mirrorSubtitles\":\(ss ? "true" : "false")});",
                        completionHandler: nil
                    )
                    setStealthLogPanelVisible(ss)
                }
                if let hr = st["hoverReveal"] as? Bool, hr != hoverRevealEnabled {
                    hoverRevealEnabled = hr
                    UserDefaults.standard.set(hr, forKey: "chameleonHoverReveal")
                    if !hr {
                        isWindowHovered = false
                        webView.evaluateJavaScript("window.GeckoNativeBridge?.setHovered(false, false);", completionHandler: nil)
                    }
                }
                syncNativeIslandControls()
            }
        case "playerChanged":
            if let pl = dict["player"] as? [String: Any] {
                let paused = (pl["paused"] as? Bool) ?? true
                let activeVideo = (pl["hasActiveVideo"] as? Bool) ?? false
                let prevActive = hasActiveVideoPlaying
                hasActiveVideoPlaying = activeVideo
                let effectivePaused = !(isVisible && !bossMode && activeVideo)
                if paused != isPlayerPaused || effectivePaused != islandShell?.isPlayerPaused {
                    isPlayerPaused = paused
                    islandShell?.isPlayerPaused = effectivePaused
                }
                if prevActive != hasActiveVideoPlaying {
                    broadcastPlaybackStateToArena()
                }
                if let ct = pl["currentTime"] as? Double { playerCurTime = ct }
                if let dur = pl["duration"] as? Double, dur > 0 { playerDuration = dur }
                if let m = pl["muted"] as? Bool { playerMuted = m }
                if let r = pl["playbackRate"] as? Double { playerRate = r }
                if isIslandExpanded {
                    syncNativeIslandControls()
                }
            }
        case "beginResize":
            if let dir = dict["dir"] as? String {
                startNativeResize(dir: dir)
            }
        case "scaleBy":
            if let factor = dict["factor"] as? CGFloat {
                scalePanelByFactor(factor)
            }
        case "resizeWindow":
            if let w = dict["width"] as? CGFloat, let h = dict["height"] as? CGFloat {
                var f = panel.frame
                f.origin.y += (f.height - h)
                f.size = NSSize(width: w, height: h)
                panel.setFrame(f, display: true, animate: true)
            }
        case "openLocalMp4":
            openLocalVideoFile()
        default:
            break
        }
    }

    private func registerGlobalHotKeys() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let event = event, let userData = userData else { return noErr }
                var hkID = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hkID)
                let app = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { app.handleHotKey(id: hkID.id) }
                return noErr
            },
            1, &eventType, selfPtr, nil
        )

        let mods = UInt32(controlKey | shiftKey)
        for (id, keyCode) in [(UInt32(1), kVK_ANSI_G), (UInt32(2), kVK_ANSI_B), (UInt32(3), kVK_ANSI_M), (UInt32(4), kVK_ANSI_S)] {
            var ref: EventHotKeyRef?
            let hkID = EventHotKeyID(signature: OSType(0x4745434B), id: id)
            RegisterEventHotKey(UInt32(keyCode), mods, hkID, GetApplicationEventTarget(), 0, &ref)
            hotKeyRefs.append(ref)
        }
    }

    private func handleHotKey(id: UInt32) {
        switch id {
        case 1:
            isVisible.toggle()
            if isVisible { panel.orderFrontRegardless() } else { panel.orderOut(nil) }
            broadcastPlaybackStateToArena()
            syncNativeIslandControls()
        case 2:
            setBoss(!bossMode)
        case 3:
            setClickThrough(!clickThrough)
        case 4:
            if searchWindow?.isVisible == true {
                searchWindow?.orderOut(nil)
                syncNativeIslandControls()
            } else {
                openSearchBrowserWindow()
            }
        default: break
        }
    }

    private func setupGlobalTypingSensor() {
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
            self?.lastKeyTime = ProcessInfo.processInfo.systemUptime
        }
    }

    private func startAutoSceneLoop() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, self.isVisible, !self.bossMode else { return }
            self.senseDebounceWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self = self, self.isVisible, !self.bossMode else { return }
                self.senseEnvironmentAsync(periodic: false)
            }
            self.senseDebounceWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
        }

        // Defer first ScreenCaptureKit probe by 1.5s, then use a lightweight 10s periodic fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
                guard let self = self, self.isVisible, !self.bossMode else { return }
                self.senseEnvironmentAsync(periodic: true)
            }
        }
    }

    private func classifyFrontmostApp() -> (name: String, archetype: String) {
        guard let app = NSWorkspace.shared.frontmostApplication else { return lastExternalApp }
        let bid = (app.bundleIdentifier ?? "").lowercased()
        if bid == "com.geckopip.ghost" { return lastExternalApp }
        let name = app.localizedName ?? "桌面"
        let lowName = name.lowercased()
        let result: (String, String)
        if bid.contains("vscode") || bid.contains("cursor") || bid.contains("xcode") ||
           bid.contains("jetbrains") || bid.contains("zed") || bid.contains("antigravity") || lowName.contains("code") {
            result = (name, "ide")
        } else if bid.contains("terminal") || bid.contains("iterm") || bid.contains("warp") || bid.contains("ghostty") {
            result = (name, "terminal")
        } else if bid.contains("excel") || bid.contains("numbers") || bid.contains("wps") {
            result = (name, "sheet")
        } else if bid.contains("lark") || bid.contains("feishu") || bid.contains("wechat") || bid.contains("notion") || bid.contains("word") {
            result = (name, "doc")
        } else {
            result = (name, "web")
        }
        lastExternalApp = result
        return result
    }

    private func fallbackColorForArchetype(_ archetype: String) -> String {
        let isSystemDark = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark"
        switch archetype {
        case "ide": return isSystemDark ? "#1e1e1e" : "#f8fafc"
        case "terminal": return "#0d1117"
        case "sheet": return "#f4f6f5"
        case "doc": return isSystemDark ? "#1f2329" : "#ffffff"
        default: return isSystemDark ? "#1e2228" : "#f8fafc"
        }
    }

    private func senseEnvironmentAsync(periodic: Bool = false) {
        guard autoSense else { return }
        let (appName, archetype) = classifyFrontmostApp()
        let isTyping = (ProcessInfo.processInfo.systemUptime - lastKeyTime) < 1.5
        let panelFrame = panel.frame
        if periodic && hasActiveVideoPlaying && appName == lastSensedAppName && panelFrame == lastSensedFrame {
            return
        }
        lastSensedAppName = appName
        lastSensedFrame = panelFrame
        let ghostWinID = CGWindowID(panel.windowNumber)

        guard CGPreflightScreenCaptureAccess() else {
            let hex = fallbackColorForArchetype(archetype)
            pushSensorToWebView(bgColor: hex, archetype: archetype, appName: appName, isTyping: isTyping)
            return
        }

        let primaryH = NSScreen.screens.first?.frame.height ?? 1080
        let quartzRect = CGRect(x: panelFrame.origin.x, y: primaryH - (panelFrame.origin.y + panelFrame.height), width: panelFrame.width, height: panelFrame.height)

        SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { [weak self] content, err in
            guard let self = self, let content = content, err == nil else { return }
            guard let scDisplay = content.displays.first(where: { CGDisplayBounds($0.displayID).intersects(quartzRect) }) ?? content.displays.first else { return }
            let dispBounds = CGDisplayBounds(scDisplay.displayID)
            var localRect = CGRect(
                x: quartzRect.origin.x - dispBounds.origin.x,
                y: quartzRect.origin.y - dispBounds.origin.y,
                width: quartzRect.width,
                height: quartzRect.height
            ).intersection(CGRect(x: 0, y: 0, width: dispBounds.width, height: dispBounds.height))
            if localRect.width < 16 || localRect.height < 16 { localRect = CGRect(x: 0, y: 0, width: 64, height: 36) }

            let excluded = content.windows.filter { $0.windowID == ghostWinID }
            let filter = SCContentFilter(display: scDisplay, excludingWindows: excluded)
            let cfg = SCStreamConfiguration()
            cfg.sourceRect = localRect
            cfg.width = 48
            cfg.height = 27
            cfg.showsCursor = false

            SCScreenshotManager.captureImage(contentFilter: filter, configuration: cfg) { cgImage, capErr in
                let hex: String
                if let img = cgImage, capErr == nil, let sampled = Self.averageHex(img) {
                    hex = sampled
                } else {
                    hex = self.fallbackColorForArchetype(archetype)
                }
                DispatchQueue.main.async {
                    self.pushSensorToWebView(bgColor: hex, archetype: archetype, appName: appName, isTyping: isTyping)
                }
            }
        }
    }

    private static func averageHex(_ img: CGImage) -> String? {
        let w = img.width, h = img.height
        guard w > 2, h > 2 else { return nil }
        var buf = [UInt8](repeating: 0, count: w * h * 4)
        guard let ctx = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        var rSum = 0.0, gSum = 0.0, bSum = 0.0
        let count = Double(w * h)
        for i in stride(from: 0, to: w * h * 4, by: 4) {
            rSum += Double(buf[i]); gSum += Double(buf[i + 1]); bSum += Double(buf[i + 2])
        }
        return String(format: "#%02x%02x%02x", Int((rSum / count).rounded()), Int((gSum / count).rounded()), Int((bSum / count).rounded()))
    }

    private func pushSensorToWebView(bgColor: String, archetype: String, appName: String, isTyping: Bool) {
        let safeApp = appName.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\\", with: "")
        let js = "window.GeckoNativeBridge?.onMacSensor({bgColor:'\(bgColor)',archetype:'\(archetype)',appName:'\(safeApp)',isTyping:\(isTyping ? "true" : "false")});"
        webView.evaluateJavaScript(js, completionHandler: nil)
        if isBuiltInWebActive {
            builtInWebView?.evaluateJavaScript(
                "window.ChameleonBuiltInBridge?.onMacSensor({bgColor:'\(bgColor)',archetype:'\(archetype)'});",
                completionHandler: nil
            )
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
