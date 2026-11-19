import Cocoa
import QuartzCore
import WebKit
import Network
import ScreenCaptureKit
import Carbon
import CoreGraphics

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
        if isPrimary || isActiveTint {
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

        NSColor(calibratedWhite: 1.0, alpha: (isPrimary || isActiveTint) ? 0.25 : 0.12).setStroke()
        path.lineWidth = 0.5
        path.stroke()

        let font = NSFont.systemFont(ofSize: 11.0, weight: (isPrimary || isActiveTint) ? .semibold : .medium)
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

        let dotColor = isPlayerPaused
            ? NSColor(calibratedRed: 0.20, green: 0.82, blue: 0.48, alpha: 0.85)
            : NSColor(calibratedRed: 0.19, green: 0.88, blue: 0.40, alpha: 1.0)
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

    // Pure-AppKit Compact Dynamic Island (316 x 178pt — fast, compact, 100% native, never blank!)
    private var islandPanel: GhostPanel!
    private var islandShell: DynamicIslandShellView!
    private var controlsContainer: FlippedControlsView!
    private var lblCurTime: NSTextField!
    private var lblDurTime: NSTextField!
    private var progressSlider: NSSlider!
    private var btnPlayMain: IslandPillButton!
    private var btnRate: IslandPillButton!
    private var btnMute: IslandPillButton!
    private var segMode: NSSegmentedControl!
    private var stealthSlider: NSSlider!
    private var btnThrough: IslandPillButton!
    private var btnVis: IslandPillButton!
    private var lblStreakBadge: NSTextField!
    private var arenaWindow: NSWindow?
    private var arenaWebView: WKWebView?
    private var currentStreakSec: Int = 0
    private var totalSlackingSec: Int = UserDefaults.standard.integer(forKey: "chameleonTotalSec")
    private var pausedSecondsCount: Int = 0

    private var isIslandExpanded: Bool = false
    private let wsHub = LocalWebSocketHub()

    private var clickThrough: Bool = false
    private var bossMode: Bool = false
    private var autoSense: Bool = true
    private var hideFromCapture: Bool = true
    private var isVisible: Bool = true
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
        panel.sharingType = (hideFromCapture && isProMember) ? .none : .readOnly
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

        // Background-safe Hover Detector: shows 4-corner resize brackets & HUD even when Chrome/VSCode is active!
        let hoverTimer = Timer(timeInterval: 0.06, repeats: true) { [weak self] _ in
            guard let self = self, self.isVisible, !self.clickThrough else { return }
            let inside = self.panel.frame.insetBy(dx: -4, dy: -4).contains(NSEvent.mouseLocation)
            if inside != self.isWindowHovered {
                self.isWindowHovered = inside
                self.webView.evaluateJavaScript("window.GeckoNativeBridge?.setHovered(\(inside ? "true" : "false"));", completionHandler: nil)
            }
        }
        RunLoop.main.add(hoverTimer, forMode: .common)

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
                // Generous corner (26pt) & edge (14pt) hit zones
                let inCornerX = loc.x <= 26 || loc.x >= b.width - 26
                let inCornerY = loc.y <= 26 || loc.y >= b.height - 26
                let isCorner = inCornerX && inCornerY

                let nearL = loc.x <= (isCorner ? 26 : 14)
                let nearR = loc.x >= b.width - (isCorner ? 26 : 14)
                let nearB = loc.y <= (isCorner ? 26 : 14)
                let nearT = loc.y >= b.height - (isCorner ? 26 : 12)

                var dir = ""
                if nearT { dir += "n" } else if nearB { dir += "s" }
                if nearL { dir += "w" } else if nearR { dir += "e" }

                if !dir.isEmpty {
                    self.startNativeResize(dir: dir)
                    return nil
                }

                let inTopHud = loc.y > b.height - 46
                let inBottomHud = loc.y < 68
                if !inTopHud && !inBottomHud {
                    self.startNativeDrag(offset: loc)
                }
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
        let expH: CGFloat = 208

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
        let lblBrand = Self.makeLabel("变色龙投影", frame: NSRect(x: 14, y: 11, width: 64, height: 16), alpha: 0.78)
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
            self.sendPlayerCmdToWebView("{\"action\":\"toggleMute\"}")
        }

        controlsContainer.addSubview(btnBack)
        controlsContainer.addSubview(btnPlayMain)
        controlsContainer.addSubview(btnFwd)
        controlsContainer.addSubview(btnRate)
        controlsContainer.addSubview(btnMute)

        // Row 3 (y = 104): 3 Optical Projector Modes
        segMode = NSSegmentedControl(labels: ["光影投影", "浮雕纹理", "彩透投影"], trackingMode: .selectOne, target: self, action: #selector(onModeChanged(_:)))
        segMode.frame = NSRect(x: 14, y: 104, width: 288, height: 24)
        segMode.selectedSegment = 0
        segMode.segmentDistribution = .fillEqually
        controlsContainer.addSubview(segMode)

        // Row 4 (y = 136): Intensity Slider + [穿透] [显隐] [本地] [退出]
        let lblStealth = Self.makeLabel("浓度", frame: NSRect(x: 14, y: 141, width: 28, height: 16), alpha: 0.75)
        stealthSlider = NSSlider(value: 58, minValue: 10, maxValue: 95, target: self, action: #selector(onStealthSlide(_:)))
        stealthSlider.frame = NSRect(x: 42, y: 139, width: 76, height: 20)
        stealthSlider.isContinuous = true
        stealthSlider.controlSize = .small

        btnThrough = IslandPillButton(frame: NSRect(x: 124, y: 136, width: 42, height: 25), title: "穿透")
        btnThrough.onClick = { [weak self] in
            guard let self = self else { return }
            if !self.clickThrough && !self.isProMember {
                self.openArenaWindow(upgradeReason: "「鼠标穿透 (⌃⇧M)」为 Pro 会员专属功能，点击下方可免费体验 3 天 Pro！")
                return
            }
            self.setClickThrough(!self.clickThrough)
        }

        btnVis = IslandPillButton(frame: NSRect(x: 170, y: 136, width: 42, height: 25), title: "显示")
        btnVis.isActiveTint = true
        btnVis.onClick = { [weak self] in
            guard let self = self else { return }
            self.isVisible.toggle()
            if self.isVisible { self.panel.orderFrontRegardless() } else { self.panel.orderOut(nil) }
            self.broadcastPlaybackStateToArena()
            self.syncNativeIslandControls()
        }

        let btnLocal = IslandPillButton(frame: NSRect(x: 216, y: 136, width: 42, height: 25), title: "本地")
        btnLocal.onClick = { [weak self] in self?.openLocalVideoFile() }

        let btnQuit = IslandPillButton(frame: NSRect(x: 262, y: 136, width: 40, height: 25), title: "退出")
        btnQuit.onClick = { NSApp.terminate(nil) }

        controlsContainer.addSubview(lblStealth)
        controlsContainer.addSubview(stealthSlider)
        controlsContainer.addSubview(btnThrough)
        controlsContainer.addSubview(btnVis)
        controlsContainer.addSubview(btnLocal)
        controlsContainer.addSubview(btnQuit)

        // Row 5 (y = 168): Live Uninterrupted Streak + Quick Zoom [- / +] + [排行 / 对战]
        lblStreakBadge = Self.makeLabel("待机 · 播放视频开始计时", frame: NSRect(x: 14, y: 173, width: 128, height: 16), alpha: 0.88)
        let btnZoomOut = IslandPillButton(frame: NSRect(x: 144, y: 168, width: 34, height: 25), title: "小 -")
        btnZoomOut.onClick = { [weak self] in self?.scalePanelByFactor(0.84) }
        let btnZoomIn = IslandPillButton(frame: NSRect(x: 182, y: 168, width: 34, height: 25), title: "大 +")
        btnZoomIn.onClick = { [weak self] in self?.scalePanelByFactor(1.19) }
        let btnArena = IslandPillButton(frame: NSRect(x: 220, y: 168, width: 82, height: 25), title: "排行 / 对战", primary: true)
        btnArena.onClick = { [weak self] in
            self?.openArenaWindow()
        }
        controlsContainer.addSubview(lblStreakBadge)
        controlsContainer.addSubview(btnZoomOut)
        controlsContainer.addSubview(btnZoomIn)
        controlsContainer.addSubview(btnArena)

        // 1Hz Slacking Streak & Rank Progression Ticker (ONLY counts when real video is actively playing!)
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
        sendPlayerCmdToWebView("{\"action\":\"togglePlay\"}")
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
        if idx > 0 && !isProMember {
            sender.selectedSegment = 0
            openArenaWindow(upgradeReason: "「浮雕纹理」与「彩透电影」为 Pro 会员专属光学引擎，点击下方可免费体验 3 天 Pro！")
            return
        }
        currentMode = modes[idx]
        webView.evaluateJavaScript("window.GeckoNativeBridge?.applyPatch({\"mode\":\"\(currentMode)\"});", completionHandler: nil)
    }

    @objc private func onStealthSlide(_ sender: NSSlider) {
        let nextVal = sender.integerValue
        guard nextVal != currentStealth else { return }
        currentStealth = nextVal
        webView.evaluateJavaScript("window.GeckoNativeBridge?.applyPatch({\"stealth\":\(currentStealth)});", completionHandler: nil)
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
        btnThrough.isActiveTint = clickThrough
        btnVis.isActiveTint = isVisible
        btnVis.title = isVisible ? "显示" : "已隐"
        let activeVideoNow = isVisible && !bossMode && hasActiveVideoPlaying
        if activeVideoNow || currentStreakSec > 0 {
            lblStreakBadge?.stringValue = "连续 \(Self.fmtTime(Double(currentStreakSec))) · \(Self.chameleonRankTitle(for: totalSlackingSec))"
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
        if mins >= 7200  { return "Lv.8 光学幽灵" }
        if mins >= 3000  { return "Lv.7 带薪修行师" }
        if mins >= 1200  { return "Lv.6 死角艺术家" }
        if mins >= 480   { return "Lv.5 幻影魔术师" }
        if mins >= 180   { return "Lv.4 光学猎手" }
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
            if isIslandExpanded {
                lblStreakBadge?.stringValue = "连续 \(Self.fmtTime(Double(currentStreakSec))) · \(Self.chameleonRankTitle(for: totalSlackingSec))"
            }
        } else if currentStreakSec > 0 {
            pausedSecondsCount += 1
            if bossMode || !isVisible || pausedSecondsCount > 10 {
                currentStreakSec = 0
                pausedSecondsCount = 0
                if isIslandExpanded {
                    lblStreakBadge?.stringValue = "待机 · 播放视频开始计时"
                }
            }
        } else if isIslandExpanded {
            lblStreakBadge?.stringValue = "待机 · 播放视频开始计时"
        }

        if telemetryTickCount % 2 == 0 {
            broadcastPlaybackStateToArena()
        }
    }

    private func applyMembershipEntitlement(_ isPro: Bool) {
        isProMember = isPro
        UserDefaults.standard.set(isPro, forKey: "chameleonIsPro")
        // Screen-sharing / screen-recording stealth (.none) is a Pro exclusive capability
        panel?.sharingType = (hideFromCapture && isProMember) ? .none : .readOnly
        if !isProMember && currentMode != "projector" {
            currentMode = "projector"
            webView?.evaluateJavaScript("window.GeckoNativeBridge?.applyPatch({\"mode\":\"projector\"});", completionHandler: nil)
        }
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
            controlsContainer.frame = NSRect(x: 0, y: 0, width: 316, height: 208)
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
        let targetH: CGFloat = isIslandExpanded ? 208 : geo.barHeight
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
        webView.evaluateJavaScript("window.GeckoNativeBridge?.execPlayerCmd(\(jsonCmd));", completionHandler: nil)
    }

    private func setBoss(_ active: Bool) {
        bossMode = active
        if active {
            hasActiveVideoPlaying = false
            currentStreakSec = 0
            islandShell?.isPlayerPaused = true
            wsHub.sendTextToArena("{\"type\":\"bossTriggered\"}")
            broadcastPlaybackStateToArena()
        }
        webView.evaluateJavaScript("window.GeckoNativeBridge?.setBossMode(\(bossMode));", completionHandler: nil)
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
            let escaped = url.absoluteString.replacingOccurrences(of: "'", with: "%27")
            webView.evaluateJavaScript("window.GeckoNativeBridge?.loadLocalVideo('\(escaped)');", completionHandler: nil)
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let dict = message.body as? [String: Any],
              let action = dict["action"] as? String else { return }

        switch action {
        case "enableClickThrough":
            if !isProMember {
                openArenaWindow(upgradeReason: "「鼠标穿透 (⌃⇧M)」为 Pro 会员专属功能，点击下方可免费体验 3 天 Pro！")
            } else {
                setClickThrough(true)
            }
        case "membershipChanged":
            if let pro = dict["isPro"] as? Bool {
                applyMembershipEntitlement(pro)
            }
        case "requestUpgrade":
            let reason = (dict["reason"] as? String) ?? "升级 Pro 解锁全部光学模式、会议隐身与无限联机对战！"
            openArenaWindow(upgradeReason: reason)
        case "setBoss":
            if let v = dict["value"] as? Bool { setBoss(v) }
        case "stateChanged":
            if let st = dict["state"] as? [String: Any] {
                if let m = st["mode"] as? String { currentMode = m }
                if let s = st["stealth"] as? Int { currentStealth = s }
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
            if !clickThrough && !isProMember {
                openArenaWindow(upgradeReason: "「鼠标穿透 (⌃⇧M)」为 Pro 会员专属功能，点击下方可免费体验 3 天 Pro！")
            } else {
                setClickThrough(!clickThrough)
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
        Timer.scheduledTimer(withTimeInterval: 1.8, repeats: true) { [weak self] _ in
            guard let self = self, self.isVisible, !self.bossMode else { return }
            self.senseEnvironmentAsync()
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
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
