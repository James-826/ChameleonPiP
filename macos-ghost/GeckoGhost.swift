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
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
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
        guard now - lastAnalyzeTime >= 0.40 else { return }
        lastAnalyzeTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let req = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try handler.perform([req])
            let faces = (req.results ?? []).filter { $0.boundingBox.width >= 0.045 && $0.boundingBox.height >= 0.045 }
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
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.geckopip.wshub", qos: .userInteractive)
    private var connections: [ObjectIdentifier: NWConnection] = [:]
    private var ghostViewIds: Set<ObjectIdentifier> = []
    private var arenaViewIds: Set<ObjectIdentifier> = []
    // Zero-lag 1-frame mailbox: drops stale intermediate frames so video NEVER lags behind audio!
    private var sendingBinary: Set<ObjectIdentifier> = []
    private var pendingBinary: [ObjectIdentifier: Data] = [:]
    var onArenaConnected: (() -> Void)?

    func start(port: UInt16 = 51937) {
        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true
        if let tcpOpts = params.defaultProtocolStack.transportProtocol as? NWProtocolTCP.Options {
            tcpOpts.noDelay = true
        }
        let wsOptions = NWProtocolWebSocket.Options()
        wsOptions.autoReplyPing = true
        wsOptions.maximumMessageSize = 4 * 1024 * 1024
        params.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }
        params.requiredLocalEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host("127.0.0.1"), port: nwPort)

        do {
            let l = try NWListener(using: params)
            l.newConnectionHandler = { [weak self] conn in self?.handleNewConnection(conn) }
            l.start(queue: queue)
            self.listener = l
        } catch {
            NSLog("[GeckoGhost] WS listener error: \(error)")
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
        connections.removeValue(forKey: id)
        ghostViewIds.remove(id)
        arenaViewIds.remove(id)
        sendingBinary.remove(id)
        pendingBinary.removeValue(forKey: id)
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

    private func receiveLoop(_ conn: NWConnection, id: ObjectIdentifier) {
        conn.receiveMessage { [weak self] data, context, _, error in
            guard let self = self else { return }
            if let data = data, !data.isEmpty {
                let wsMeta = context?.protocolMetadata(definition: NWProtocolWebSocket.definition) as? NWProtocolWebSocket.Metadata
                let opcode = wsMeta?.opcode ?? .binary

                if opcode == .text, let text = String(data: data, encoding: .utf8) {
                    if text.contains("\"role\":\"ghostView\"") {
                        self.ghostViewIds.insert(id)
                    } else if text.contains("\"role\":\"arenaView\"") {
                        self.arenaViewIds.insert(id)
                        self.onArenaConnected?()
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
                    self.broadcast(data: data, opcode: .binary, toGhostViews: true, sender: id)
                }
            }
            if error == nil { self.receiveLoop(conn, id: id) }
            else { self.cleanup(id) }
        }
    }

    private func sendLatestBinary(_ data: Data, to cid: ObjectIdentifier, conn: NWConnection) {
        if sendingBinary.contains(cid) {
            // Overwrite any queued frame with the newest frame (zero latency buildup!)
            pendingBinary[cid] = data
            return
        }
        sendingBinary.insert(cid)
        let meta = NWProtocolWebSocket.Metadata(opcode: .binary)
        let ctx = NWConnection.ContentContext(identifier: "wsBin", metadata: [meta])
        conn.send(content: data, contentContext: ctx, isComplete: true, completion: .contentProcessed { [weak self] err in
            guard let self = self else { return }
            self.sendingBinary.remove(cid)
            if err != nil {
                self.cleanup(cid)
                return
            }
            if let next = self.pendingBinary.removeValue(forKey: cid), let liveConn = self.connections[cid] {
                self.sendLatestBinary(next, to: cid, conn: liveConn)
            }
        })
    }

    private func broadcast(data: Data, opcode: NWProtocolWebSocket.Opcode, toGhostViews: Bool, sender: ObjectIdentifier) {
        if opcode == .binary {
            for (cid, c) in connections where cid != sender {
                if ghostViewIds.contains(cid) == toGhostViews {
                    sendLatestBinary(data, to: cid, conn: c)
                }
            }
            return
        }
        let meta = NWProtocolWebSocket.Metadata(opcode: opcode)
        let ctx = NWConnection.ContentContext(identifier: "wsFrame", metadata: [meta])
        for (cid, c) in connections where cid != sender {
            if ghostViewIds.contains(cid) == toGhostViews {
                c.send(content: data, contentContext: ctx, isComplete: true, completion: .idempotent)
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, WKScriptMessageHandler {
    private var panel: GhostPanel!
    private var webView: WKWebView!
    private var builtInWebView: FirstMouseWebView?
    private var isBuiltInWebActive: Bool = false
    private var builtInVideoIsolated: Bool = false
    private var currentBuiltInUrl: String = ""

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

    // Black Tech #1: Local Apple Vision Anti-Peek Radar + Z-Library Daily Free 30-Min Shield Quota
    private let antiPeekRadar = VisionAntiPeekRadar()
    private var radarEnabled: Bool = false
    private var radarAlertActive: Bool = false
    private var bossTriggeredByRadar: Bool = false
    private var radarSafeStreakCount: Int = 0
    private var radarLastFaceCount: Int = 0
    private let freeDailyShieldLimitSec: Int = 1800 // 30 minutes FREE every single day!
    private var dailyShieldDate: String = ""
    private var dailyShieldUsedSec: Int = 0

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
    private var pointerTrackTimer: Timer?
    private var isWindowHovered: Bool = false
    private var lastExternalApp: (name: String, archetype: String) = ("桌面", "web")
    private var hotKeyRefs: [EventHotKeyRef?] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        loadDailyShieldQuota()
        configureAntiPeekRadarCallbacks()
        wsHub.onArenaConnected = { [weak self] in
            DispatchQueue.main.async {
                self?.broadcastPlaybackStateToArena()
            }
        }
        wsHub.start(port: 51937)
        setupGhostPanel()
        setupDynamicNotchIsland()
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

    private static func todayDateString() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: Date())
    }

    private func loadDailyShieldQuota() {
        let today = Self.todayDateString()
        let savedDate = UserDefaults.standard.string(forKey: "chameleonShieldDate") ?? ""
        if savedDate == today {
            dailyShieldDate = today
            dailyShieldUsedSec = UserDefaults.standard.integer(forKey: "chameleonShieldUsedSec")
        } else {
            dailyShieldDate = today
            dailyShieldUsedSec = 0
            UserDefaults.standard.set(today, forKey: "chameleonShieldDate")
            UserDefaults.standard.set(0, forKey: "chameleonShieldUsedSec")
        }
    }

    private func hasActiveShieldEntitlement() -> Bool {
        if isProMember { return true }
        let today = Self.todayDateString()
        if dailyShieldDate != today {
            dailyShieldDate = today
            dailyShieldUsedSec = 0
            UserDefaults.standard.set(today, forKey: "chameleonShieldDate")
            UserDefaults.standard.set(0, forKey: "chameleonShieldUsedSec")
        }
        return dailyShieldUsedSec < freeDailyShieldLimitSec
    }

    private func updatePanelSharingType() {
        panel?.sharingType = (hideFromCapture && hasActiveShieldEntitlement()) ? .none : .readOnly
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
                }
            } else {
                if self.bossTriggeredByRadar && self.bossMode {
                    self.radarSafeStreakCount += 1
                    // ~2.8 seconds continuously clear (7 checks * 0.4s) -> auto-recover!
                    if self.radarSafeStreakCount >= 7 {
                        self.bossTriggeredByRadar = false
                        self.radarAlertActive = false
                        self.radarSafeStreakCount = 0
                        self.islandShell?.isRadarAlert = false
                        self.setBoss(false)
                    }
                } else if self.radarAlertActive {
                    self.radarAlertActive = false
                    self.islandShell?.isRadarAlert = false
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
        guard hasActiveShieldEntitlement() else {
            openArenaWindow(upgradeReason: "今日 30 分钟免费「AI 背后防偷窥雷达 & 会议共享隐身」体验额度已用完（明天凌晨自动刷新）。请开发者喝杯美式（¥9.9 永久）即可不限时畅用，或去能量补给站免费打卡领时长！")
            return
        }
        antiPeekRadar.start()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        isVisible = true
        if bossMode { setBoss(false) }
        panel?.orderFrontRegardless()
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
            guard let self = self, !self.clickThrough, event.window === self.panel, !self.bossMode else { return event }

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

                // In Built-in Web Browse Mode (before video is isolated), allow normal webpage clicking inside the interior!
                if self.isBuiltInWebActive && !self.builtInVideoIsolated {
                    let browsePad: CGFloat = 10
                    let nearL = loc.x <= browsePad
                    let nearR = loc.x >= b.width - browsePad
                    let nearB = loc.y <= browsePad
                    let nearT = loc.y >= b.height - browsePad
                    var dir = ""
                    if nearT { dir += "n" } else if nearB { dir += "s" }
                    if nearL { dir += "w" } else if nearR { dir += "e" }
                    if !dir.isEmpty {
                        self.startNativeResize(dir: dir)
                        return nil
                    }
                    // Allow drag from the thin top strip (excluding right-side toolbar buttons)
                    if loc.y >= b.height - 34 && loc.x < b.width - 150 {
                        self.startNativeDrag(offset: loc)
                        return nil
                    }
                    return event
                }

                // Let HUD buttons (top bar: 穿透/日志/老板键/模式/尺寸, bottom bar: 播放/静音/进度条) receive clicks first!
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
                    self.startNativeResize(dir: dir)
                    return nil
                }

                self.startNativeDrag(offset: loc)
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

    private func startNativeResize(dir: String) {
        activeResizeDir = dir
        resizeInitialFrame = panel.frame
        resizeStartMouse = NSEvent.mouseLocation
        dragOriginOffset = nil
        isDraggingWindow = false
        ensurePointerTrackTimer()
    }

    private func startNativeDrag(offset: NSPoint) {
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
            if (NSEvent.pressedMouseButtons & 1) == 0 {
                t.invalidate()
                self.pointerTrackTimer = nil
                if self.activeResizeDir != nil || self.isDraggingWindow {
                    self.senseEnvironmentAsync()
                }
                self.activeResizeDir = nil
                self.dragOriginOffset = nil
                self.dragDownScreenPt = nil
                self.isDraggingWindow = false
                return
            }

            let m = NSEvent.mouseLocation
            if let dir = self.activeResizeDir {
                let dx = m.x - self.resizeStartMouse.x
                let dy = m.y - self.resizeStartMouse.y
                let f0 = self.resizeInitialFrame
                var nf = f0

                if dir.contains("e") { nf.size.width = max(190, f0.width + dx) }
                if dir.contains("w") {
                    let nw = max(190, f0.width - dx)
                    nf.origin.x = f0.maxX - nw
                    nf.size.width = nw
                }
                if dir.contains("n") { nf.size.height = max(110, f0.height + dy) }
                if dir.contains("s") {
                    let nh = max(110, f0.height - dy)
                    nf.origin.y = f0.maxY - nh
                    nf.size.height = nh
                }
                self.panel.setFrame(nf, display: true)
                return
            }

            if let offset = self.dragOriginOffset, let downPt = self.dragDownScreenPt {
                if !self.isDraggingWindow && hypot(m.x - downPt.x, m.y - downPt.y) > 3 {
                    self.isDraggingWindow = true
                }
                if self.isDraggingWindow {
                    self.panel.setFrameOrigin(NSPoint(x: m.x - offset.x, y: m.y - offset.y))
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

        btnWebUrl = IslandPillButton(frame: NSRect(x: 90, y: 168, width: 66, height: 25), title: "网页直连")
        btnWebUrl.onClick = { [weak self] in
            guard let self = self else { return }
            self.openWebVideoUrlPrompt()
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
        let patchJs = "{\"stealthSubtitle\":\(enabled ? "true" : "false"),\"mirrorSubtitles\":true}"
        webView.evaluateJavaScript("window.GeckoNativeBridge?.applyPatch(\(patchJs));", completionHandler: nil)
        builtInWebView?.evaluateJavaScript("window.ChameleonBuiltInBridge?.applyPatch(\(patchJs));", completionHandler: nil)
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

        // Black Tech #1, #2, #3 button states
        if radarAlertActive {
            btnRadar?.title = "⚠有人!"
            btnRadar?.isAlertTint = true
            btnRadar?.isActiveTint = false
            lblBrand?.stringValue = "⚠ 背后有人!"
            lblBrand?.textColor = NSColor(calibratedRed: 0.99, green: 0.45, blue: 0.42, alpha: 1.0)
        } else if radarEnabled {
            let remMin = max(1, (freeDailyShieldLimitSec - dailyShieldUsedSec + 59) / 60)
            btnRadar?.title = isProMember ? "防窥 ON" : "防窥 \(remMin)m"
            btnRadar?.isAlertTint = false
            btnRadar?.isActiveTint = true
            lblBrand?.stringValue = "AI防窥守护中"
            lblBrand?.textColor = NSColor(calibratedRed: 0.43, green: 0.90, blue: 0.72, alpha: 0.95)
        } else {
            btnRadar?.title = "AI防窥"
            btnRadar?.isAlertTint = false
            btnRadar?.isActiveTint = false
            lblBrand?.stringValue = isBuiltInWebActive ? "网页直连中" : "变色龙投影"
            lblBrand?.textColor = NSColor(calibratedWhite: 1.0, alpha: 0.82)
        }

        btnWebUrl?.isActiveTint = isBuiltInWebActive
        btnWebUrl?.title = isBuiltInWebActive ? "切换网页" : "网页直连"
        btnStealthSub?.isActiveTint = stealthSubtitleEnabled
        btnStealthSub?.title = stealthSubtitleEnabled ? "日志 ON" : "日志字幕"

        let activeVideoNow = isVisible && !bossMode && hasActiveVideoPlaying
        if radarAlertActive {
            lblStreakBadge?.stringValue = "检测到背后 \(radarLastFaceCount) 人 · 已秒隐静音"
        } else if activeVideoNow || currentStreakSec > 0 {
            lblStreakBadge?.stringValue = "连续 \(Self.fmtTime(Double(currentStreakSec))) · \(Self.chameleonRankTitle(for: totalSlackingSec))"
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
            lblStreakBadge?.stringValue = isBuiltInWebActive && !builtInVideoIsolated ? "网页直连 · 点播视频自动变色融合" : "待机 · 播放视频开始计时"
        }

        // Z-Library Daily Free 30-Minute Shield Allowance (AI Radar + Screen-Share Stealth)
        if !isProMember {
            let today = Self.todayDateString()
            if dailyShieldDate != today {
                dailyShieldDate = today
                dailyShieldUsedSec = 0
                UserDefaults.standard.set(today, forKey: "chameleonShieldDate")
                UserDefaults.standard.set(0, forKey: "chameleonShieldUsedSec")
                updatePanelSharingType()
            }
            if radarEnabled || (activeVideoNow && hideFromCapture) {
                if dailyShieldUsedSec < freeDailyShieldLimitSec {
                    dailyShieldUsedSec += 1
                    if dailyShieldUsedSec % 10 == 0 || dailyShieldUsedSec >= freeDailyShieldLimitSec {
                        UserDefaults.standard.set(dailyShieldUsedSec, forKey: "chameleonShieldUsedSec")
                    }
                    if radarEnabled && dailyShieldUsedSec % 30 == 0 && isIslandExpanded {
                        syncNativeIslandControls()
                    }
                    if dailyShieldUsedSec >= freeDailyShieldLimitSec {
                        updatePanelSharingType()
                        if radarEnabled {
                            radarEnabled = false
                            radarAlertActive = false
                            bossTriggeredByRadar = false
                            antiPeekRadar.stop()
                            islandShell?.isRadarActive = false
                            islandShell?.isRadarAlert = false
                            syncNativeIslandControls()
                            openArenaWindow(upgradeReason: "今日 30 分钟免费「AI 防偷窥雷达 & 会议共享隐身」额度已用完（明天凌晨自动恢复）。请开发者喝杯美式（¥9.9 永久）即可不限时使用！")
                        }
                    }
                }
            }
        }

        if telemetryTickCount % 2 == 0 {
            broadcastPlaybackStateToArena()
        }
    }

    private func applyMembershipEntitlement(_ isPro: Bool) {
        isProMember = isPro
        UserDefaults.standard.set(isPro, forKey: "chameleonIsPro")
        // Z-Library Model: All 3 Chameleon visual modes stay 100% FREE; supporters unlock unlimited daily Radar & Screen-Share Stealth!
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
            win.title = "ChameleonPiP 变色龙 · 全球摸鱼排位、会员中心与线上耐力 PK"
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

    private func setBoss(_ active: Bool) {
        bossMode = active
        if active {
            hasActiveVideoPlaying = false
            currentStreakSec = 0
            islandShell?.isPlayerPaused = true
            wsHub.sendTextToArena("{\"type\":\"bossTriggered\"}")
            broadcastPlaybackStateToArena()
        } else {
            bossTriggeredByRadar = false
            radarAlertActive = false
            islandShell?.isRadarAlert = false
        }
        webView.evaluateJavaScript("window.GeckoNativeBridge?.setBossMode(\(bossMode));", completionHandler: nil)
        builtInWebView?.evaluateJavaScript("window.ChameleonBuiltInBridge?.setBossMode(\(bossMode));", completionHandler: nil)
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

        currentBuiltInUrl = norm
        if builtInWebView == nil {
            let cfg = WKWebViewConfiguration()
            cfg.userContentController.add(self, name: "ghostAction")
            cfg.mediaTypesRequiringUserActionForPlayback = []
            cfg.allowsAirPlayForMediaPlayback = false

            if let coreURL = Bundle.main.url(forResource: "gecko-core", withExtension: "js"),
               let coreSrc = try? String(contentsOf: coreURL, encoding: .utf8) {
                cfg.userContentController.addUserScript(
                    WKUserScript(source: coreSrc, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
                )
            }
            cfg.userContentController.addUserScript(
                WKUserScript(source: Self.builtInIsolatorScript(), injectionTime: .atDocumentEnd, forMainFrameOnly: true)
            )

            let bw = FirstMouseWebView(frame: panel.contentView!.bounds, configuration: cfg)
            bw.autoresizingMask = [.width, .height]
            bw.setValue(false, forKey: "drawsBackground")
            bw.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Safari/605.1.15"
            panel.contentView?.addSubview(bw)
            builtInWebView = bw
        }

        isBuiltInWebActive = true
        builtInVideoIsolated = false
        webView.isHidden = true
        builtInWebView?.isHidden = false
        isVisible = true
        if bossMode { setBoss(false) }
        // Give user comfortable browsing size if panel is tiny
        if panel.frame.width < 420 {
            var f = panel.frame
            let nw: CGFloat = 480
            let nh: CGFloat = 300
            f.origin.x -= (nw - f.width) * 0.5
            f.origin.y -= (nh - f.height) * 0.5
            f.size = NSSize(width: nw, height: nh)
            panel.setFrame(f, display: true, animate: true)
        }
        panel.orderFrontRegardless()
        builtInWebView?.load(URLRequest(url: url))
        syncNativeIslandControls()

        // Push current state right after page begins loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self = self, self.isBuiltInWebActive else { return }
            let patch = "{\"mode\":\"\(self.currentMode)\",\"stealth\":\(self.currentStealth),\"stealthSubtitle\":\(self.stealthSubtitleEnabled ? "true" : "false"),\"hoverReveal\":\(self.hoverRevealEnabled ? "true" : "false")}"
            self.builtInWebView?.evaluateJavaScript("window.ChameleonBuiltInBridge?.applyPatch(\(patch));", completionHandler: nil)
        }
    }

    private func exitBuiltInWebMode() {
        guard isBuiltInWebActive else { return }
        isBuiltInWebActive = false
        builtInVideoIsolated = false
        builtInWebView?.evaluateJavaScript("document.querySelectorAll('video').forEach(v => v.pause());", completionHandler: nil)
        builtInWebView?.loadHTMLString("<html><body style='background:transparent'></body></html>", baseURL: nil)
        builtInWebView?.isHidden = true
        webView.isHidden = false
        hasActiveVideoPlaying = false
        broadcastPlaybackStateToArena()
        syncNativeIslandControls()
    }

    private static func builtInIsolatorScript() -> String {
        return """
        (function() {
          if (window.__CHAMELEON_BUILTIN_LOADED__) return;
          window.__CHAMELEON_BUILTIN_LOADED__ = true;
          const post = (p) => window.webkit?.messageHandlers?.ghostAction?.postMessage(p);
          const state = { mode: 'projector', stealth: 58, feather: 28, autoSense: true, bgColor: '#505050', mirrorSubtitles: true, stealthSubtitle: false, bossMode: false, hoverReveal: false };
          let isolated = false;
          let autoIsolateWanted = true;
          let targetVideo = null;
          let wasPlayingBeforeBoss = false;
          let isHovered = false;

          const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
          svg.style.cssText = 'position:fixed;width:0;height:0;pointer-events:none;z-index:-1;';
          const defs = document.createElementNS('http://www.w3.org/2000/svg', 'defs');
          svg.appendChild(defs);
          document.documentElement.appendChild(svg);

          const styleEl = document.createElement('style');
          styleEl.id = 'chm-builtin-style';
          styleEl.textContent = `
            html.chm-iso, html.chm-iso body { background: transparent !important; overflow: hidden !important; }
            html.chm-iso body > *:not(#chm-builtin-hud):not(#chm-builtin-sub):not(svg):not(.chm-iso-ancestor) { opacity: 0 !important; pointer-events: none !important; }
            video.chm-iso-vid {
              position: fixed !important; inset: 0 !important; width: 100vw !important; height: 100vh !important;
              max-width: none !important; max-height: none !important; margin: 0 !important; padding: 0 !important;
              object-fit: cover !important; z-index: 2147483640 !important; background: transparent !important;
              opacity: 1 !important; visibility: visible !important; pointer-events: none !important;
            }
            html.chm-boss video.chm-iso-vid, html.chm-boss #chm-builtin-sub { opacity: 0 !important; }
            #chm-builtin-hud {
              position: fixed; top: 6px; right: 8px; z-index: 2147483647;
              display: flex; align-items: center; gap: 4px;
              font: 600 10.5px -apple-system, BlinkMacSystemFont, 'PingFang SC', sans-serif;
              transition: opacity 0.16s ease;
            }
            html.chm-iso:not(.chm-hov) #chm-builtin-hud { opacity: 0; pointer-events: none; }
            #chm-builtin-hud button {
              appearance: none; border: 1px solid rgba(255,255,255,0.18);
              background: rgba(12,18,26,0.82); color: #e2e8f0; border-radius: 6px;
              padding: 4px 8px; cursor: pointer; font: inherit; backdrop-filter: blur(10px);
            }
            #chm-builtin-hud button:hover { background: rgba(16,185,129,0.35); color: #fff; }
            #chm-builtin-sub {
              position: fixed; bottom: 10px; left: 8%; right: 8%; z-index: 2147483645;
              text-align: center; font: 600 12px/1.35 -apple-system, 'PingFang SC', sans-serif;
              pointer-events: none; text-shadow: 0 1px 3px rgba(0,0,0,0.35); display: none;
            }
            #chm-builtin-sub.stealth-log {
              bottom: 8px; left: 8px; right: 8px; text-align: left;
              font: 500 10.5px/1.4 ui-monospace, SFMono-Regular, Menlo, monospace;
              padding: 5px 9px; border-radius: 6px; background: rgba(13,17,23,0.86);
              border: 1px solid rgba(52,211,153,0.24); color: #c9d1d9; text-shadow: none;
              white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
            }
            #chm-builtin-sub.stealth-log.light-bg {
              background: rgba(248,250,252,0.9); border-color: rgba(15,23,42,0.16); color: #1e293b;
            }
          `;
          document.head.appendChild(styleEl);

          const featherStyle = document.createElement('style');
          document.head.appendChild(featherStyle);

          const hud = document.createElement('div');
          hud.id = 'chm-builtin-hud';
          hud.innerHTML = `<button id="chmBtnIso">变色融合</button><button id="chmBtnExit">关闭网页</button>`;
          document.body.appendChild(hud);

          const subEl = document.createElement('div');
          subEl.id = 'chm-builtin-sub';
          document.body.appendChild(subEl);

          const btnIso = hud.querySelector('#chmBtnIso');
          const btnExit = hud.querySelector('#chmBtnExit');

          function markAncestors(v, add) {
            document.querySelectorAll('.chm-iso-ancestor').forEach(el => el.classList.remove('chm-iso-ancestor'));
            if (!add || !v) return;
            let p = v.parentElement;
            while (p && p !== document.body && p !== document.documentElement) {
              p.classList.add('chm-iso-ancestor');
              p = p.parentElement;
            }
          }

          function findBestVideo() {
            const vids = Array.from(document.querySelectorAll('video'));
            let best = null, bestScore = -1;
            for (const v of vids) {
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

          function applyFilter() {
            const Core = window.GeckoCore;
            if (!Core || !targetVideo) return;
            if (isolated) {
              Core.applySvgFilterToMedia(defs, targetVideo, state, { isPeeking: false });
              featherStyle.textContent = Core.buildFeatherRuleCss('video.chm-iso-vid', state.feather);
            } else {
              targetVideo.style.removeProperty('filter');
              featherStyle.textContent = '';
            }
          }

          function setIsolated(val) {
            const v = targetVideo || findBestVideo();
            if (val && !v) return;
            isolated = Boolean(val);
            if (isolated && v) {
              targetVideo = v;
              document.querySelectorAll('video.chm-iso-vid').forEach(el => { if (el !== v) el.classList.remove('chm-iso-vid'); });
              v.classList.add('chm-iso-vid');
              markAncestors(v, true);
              document.documentElement.classList.add('chm-iso');
              btnIso.textContent = '浏览网页';
              applyFilter();
            } else {
              document.documentElement.classList.remove('chm-iso');
              document.querySelectorAll('video.chm-iso-vid').forEach(el => { el.classList.remove('chm-iso-vid'); el.style.removeProperty('filter'); });
              markAncestors(null, false);
              featherStyle.textContent = '';
              btnIso.textContent = '变色融合';
            }
            post({ action: 'builtInVideoStatus', isolated });
          }

          btnIso.addEventListener('click', (e) => {
            e.stopPropagation();
            autoIsolateWanted = !isolated;
            setIsolated(!isolated);
          });
          btnExit.addEventListener('click', (e) => {
            e.stopPropagation();
            post({ action: 'exitBuiltInWeb' });
          });

          function readSub() {
            const sels = ['.bpx-player-subtitle-panel-text', '.bilibili-player-video-subtitle .subtitle-item-text', '.ytp-caption-segment'];
            for (const sel of sels) {
              const ns = document.querySelectorAll(sel);
              if (ns.length) {
                const txt = Array.from(ns).map(n => n.textContent.trim()).filter(Boolean).join(' ');
                if (txt) return txt;
              }
            }
            if (targetVideo?.textTracks) {
              for (const tr of targetVideo.textTracks) {
                if (tr.mode === 'showing' && tr.activeCues?.length) {
                  return Array.from(tr.activeCues).map(c => c.text || '').join(' ').replace(/<[^>]+>/g, '').trim();
                }
              }
            }
            return '';
          }

          function escapeHtml(s) {
            return String(s || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
          }

          function updateSub() {
            const Core = window.GeckoCore;
            const txt = isolated && state.mirrorSubtitles ? readSub() : '';
            if (!txt) { subEl.style.display = 'none'; return; }
            subEl.style.display = 'block';
            if (state.stealthSubtitle && Core?.formatStealthLogParts) {
              const p = Core.formatStealthLogParts(txt);
              const isLight = Core.getLuminance(state.bgColor || '#505050') > 0.62;
              subEl.classList.add('stealth-log');
              subEl.classList.toggle('light-bg', isLight);
              subEl.innerHTML = `<span style="color:#64748b">[${p.ts}]</span> <span style="color:${isLight ? '#059669' : '#34d399'};font-weight:700">[${p.level}]</span> <span style="color:${isLight ? '#0284c7' : '#79c0ff'}">${p.mod}</span> — ${escapeHtml(p.text)}`;
            } else {
              subEl.classList.remove('stealth-log', 'light-bg');
              subEl.style.color = Core ? Core.deriveAutoInkColor(state.bgColor) : 'rgba(255,255,255,0.85)';
              subEl.textContent = txt;
            }
          }

          setInterval(() => {
            const v = findBestVideo();
            if (v && v !== targetVideo) targetVideo = v;
            if (v && autoIsolateWanted && !isolated && !v.paused && v.readyState >= 2) {
              setIsolated(true);
            }
            if (isolated && targetVideo) applyFilter();
            updateSub();
            const playing = Boolean(targetVideo && !targetVideo.paused && !targetVideo.ended && targetVideo.readyState >= 2 && !state.bossMode);
            post({
              action: 'playerChanged',
              source: 'builtin',
              player: {
                paused: targetVideo ? targetVideo.paused : true,
                hasActiveVideo: playing,
                currentTime: targetVideo ? (targetVideo.currentTime || 0) : 0,
                duration: targetVideo && Number.isFinite(targetVideo.duration) ? targetVideo.duration : 180,
                muted: targetVideo ? (targetVideo.muted || targetVideo.volume === 0) : false,
                playbackRate: targetVideo ? (targetVideo.playbackRate || 1) : 1
              }
            });
          }, 350);

          window.ChameleonBuiltInBridge = {
            setHovered(val) {
              isHovered = Boolean(val);
              document.documentElement.classList.toggle('chm-hov', isHovered);
            },
            applyPatch(p) {
              Object.assign(state, p || {});
              applyFilter();
              updateSub();
            },
            onMacSensor(sensor) {
              if (sensor?.bgColor) { state.bgColor = sensor.bgColor; applyFilter(); updateSub(); }
            },
            setBossMode(val) {
              state.bossMode = Boolean(val);
              document.documentElement.classList.toggle('chm-boss', state.bossMode);
              const v = targetVideo || findBestVideo();
              if (!v) return;
              if (state.bossMode) { wasPlayingBeforeBoss = !v.paused; v.pause(); }
              else if (wasPlayingBeforeBoss) { v.play().catch(() => {}); }
            },
            execPlayerCmd(cmd) {
              const v = targetVideo || findBestVideo();
              if (!v || !cmd) return;
              if (cmd.action === 'setPaused') { cmd.value ? v.pause() : v.play().catch(() => {}); }
              else if (cmd.action === 'togglePlay') { v.paused ? v.play().catch(() => {}) : v.pause(); }
              else if (cmd.action === 'seek') { v.currentTime = Math.max(0, (v.currentTime || 0) + Number(cmd.delta || 0)); }
              else if (cmd.action === 'seekTo' && Number.isFinite(cmd.value)) { v.currentTime = Math.max(0, cmd.value); }
              else if (cmd.action === 'setMuted') { v.muted = Boolean(cmd.value); if (!v.muted && v.volume < 0.05) v.volume = 0.85; }
              else if (cmd.action === 'setRate' && Number.isFinite(cmd.value)) { v.playbackRate = cmd.value; }
            }
          };
        })();
        """
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
        case "openWebVideoUrl":
            openWebVideoUrlPrompt()
        case "exitBuiltInWeb":
            exitBuiltInWebMode()
        case "builtInVideoStatus":
            if let iso = dict["isolated"] as? Bool {
                builtInVideoIsolated = iso
                syncNativeIslandControls()
            }
        case "chromeStreamStarted":
            if isBuiltInWebActive {
                exitBuiltInWebMode()
            }
        case "stateChanged":
            if let st = dict["state"] as? [String: Any] {
                if let m = st["mode"] as? String { currentMode = m }
                if let s = st["stealth"] as? Int { currentStealth = s }
                if let ss = st["stealthSubtitle"] as? Bool, ss != stealthSubtitleEnabled {
                    stealthSubtitleEnabled = ss
                    UserDefaults.standard.set(ss, forKey: "chameleonStealthSubtitle")
                    builtInWebView?.evaluateJavaScript(
                        "window.ChameleonBuiltInBridge?.applyPatch({\"stealthSubtitle\":\(ss ? "true" : "false")});",
                        completionHandler: nil
                    )
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
            let src = (dict["source"] as? String) ?? "ghost"
            if (src == "builtin" && !isBuiltInWebActive) || (src != "builtin" && isBuiltInWebActive) {
                return
            }
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
        for (id, keyCode) in [(UInt32(1), kVK_ANSI_G), (UInt32(2), kVK_ANSI_B), (UInt32(3), kVK_ANSI_M)] {
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
        default: break
        }
    }

    private func setupGlobalTypingSensor() {
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
            self?.lastKeyTime = ProcessInfo.processInfo.systemUptime
        }
    }

    private func startAutoSceneLoop() {
        // Defer first ScreenCaptureKit probe by 1.5s so macOS media startup never competes with video Frame 1!
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
                guard let self = self, self.isVisible, !self.bossMode else { return }
                self.senseEnvironmentAsync()
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

    private func senseEnvironmentAsync() {
        let (appName, archetype) = classifyFrontmostApp()
        let isTyping = (ProcessInfo.processInfo.systemUptime - lastKeyTime) < 1.5
        let panelFrame = panel.frame
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
