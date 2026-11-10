import AppKit

private let ink = NSColor(srgbRed: 0.23, green: 0.20, blue: 0.17, alpha: 1)
private let muted = NSColor(srgbRed: 0.44, green: 0.40, blue: 0.35, alpha: 1)
private let cream = NSColor(srgbRed: 0.98, green: 0.96, blue: 0.92, alpha: 1)
private let cinnamon = NSColor(srgbRed: 0.48, green: 0.29, blue: 0.19, alpha: 1)

final class OatmealMark: NSView {
    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.scaleX(by: bounds.width / 100, yBy: bounds.height / 100)
        transform.concat()
        NSColor(srgbRed: 0.93, green: 0.88, blue: 0.79, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 0, y: 0, width: 100, height: 100), xRadius: 26, yRadius: 26).fill()
        let steam = NSBezierPath()
        for x in [38.0, 52.0, 66.0] {
            steam.move(to: NSPoint(x: x, y: 66))
            steam.curve(to: NSPoint(x: x, y: 84), controlPoint1: NSPoint(x: x - 8, y: 72), controlPoint2: NSPoint(x: x + 6, y: 77))
        }
        cinnamon.withAlphaComponent(0.6).setStroke()
        steam.lineWidth = 2.5
        steam.lineCapStyle = .round
        steam.stroke()
        let bowl = NSBezierPath()
        bowl.move(to: NSPoint(x: 18, y: 55))
        bowl.curve(to: NSPoint(x: 50, y: 22), controlPoint1: NSPoint(x: 21, y: 31), controlPoint2: NSPoint(x: 33, y: 22))
        bowl.curve(to: NSPoint(x: 82, y: 55), controlPoint1: NSPoint(x: 67, y: 22), controlPoint2: NSPoint(x: 79, y: 31))
        bowl.close()
        cinnamon.setFill()
        bowl.fill()
        NSColor(srgbRed: 1, green: 0.98, blue: 0.91, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 18, y: 47, width: 64, height: 17)).fill()
        NSColor(srgbRed: 0.78, green: 0.63, blue: 0.42, alpha: 1).setFill()
        for (x, y) in [(32.0, 54.0), (44.0, 51.0), (55.0, 56.0), (66.0, 52.0)] {
            NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 6, height: 3)).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
    }
}

final class PrimaryButton: NSButton {
    override func draw(_ dirtyRect: NSRect) {
        (isEnabled ? cinnamon : cinnamon.withAlphaComponent(0.4)).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 12, yRadius: 12).fill()
        if isHighlighted {
            NSColor.black.withAlphaComponent(0.12).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 12, yRadius: 12).fill()
        }
        let text = NSAttributedString(string: title, attributes: [.font: NSFont.systemFont(ofSize: 14, weight: .semibold), .foregroundColor: NSColor.white])
        let size = text.size()
        text.draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2))
    }
}

// A small native controller for the existing local web app and its services.
final class OatmealApp: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private let status = NSTextField(labelWithString: "Starting Oatmeal AI…")
    private let badge = NSTextField(labelWithString: "●  STARTING")
    private var openButton: NSButton!
    private var process: Process?
    private var quitting = false
    private var terminationPending = false
    private var root = URL(fileURLWithPath: "/")
    private var logURL: URL { root.appendingPathComponent(".data/launcher.log") }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let resources = Bundle.main.resourceURL!
        guard let location = try? String(contentsOf: resources.appendingPathComponent("repo-path.txt"), encoding: .utf8) else {
            NSApplication.shared.terminate(nil)
            return
        }
        root = URL(fileURLWithPath: location.trimmingCharacters(in: .whitespacesAndNewlines))
        let menu = NSMenu()
        let appItem = NSMenuItem()
        menu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Open Oatmeal AI", action: #selector(openApp), keyEquivalent: "o").target = self
        appMenu.addItem(withTitle: "Show Logs", action: #selector(showLogs), keyEquivalent: "l").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Oatmeal AI", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        NSApplication.shared.mainMenu = menu

        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 450),
                          styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = "Oatmeal AI"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = cream
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        window.center()
        let content = window.contentView!
        func place(_ view: NSView, _ frame: NSRect) {
            view.frame = frame
            content.addSubview(view)
        }
        let mark = OatmealMark(frame: .zero)
        mark.setAccessibilityLabel("A warm bowl of oatmeal")
        place(mark, NSRect(x: 32, y: 314, width: 76, height: 76))
        let eyebrow = NSTextField(labelWithString: "YOUR CLASS STUDY ASSISTANT")
        eyebrow.font = .systemFont(ofSize: 9, weight: .semibold)
        eyebrow.textColor = muted
        place(eyebrow, NSRect(x: 126, y: 365, width: 320, height: 16))
        let title = NSTextField(labelWithString: "Oatmeal AI")
        title.font = .systemFont(ofSize: 30, weight: .semibold)
        title.textColor = ink
        place(title, NSRect(x: 123, y: 322, width: 320, height: 40))

        let card = NSView(frame: NSRect(x: 32, y: 191, width: 416, height: 98))
        card.wantsLayer = true
        card.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.72).cgColor
        card.layer?.cornerRadius = 16
        card.layer?.borderWidth = 1
        card.layer?.borderColor = NSColor(srgbRed: 0.90, green: 0.86, blue: 0.80, alpha: 1).cgColor
        content.addSubview(card)
        badge.font = .systemFont(ofSize: 10, weight: .bold)
        badge.textColor = cinnamon
        badge.frame = NSRect(x: 18, y: 61, width: 380, height: 16)
        card.addSubview(badge)
        status.font = .systemFont(ofSize: 13)
        status.textColor = ink
        status.lineBreakMode = .byWordWrapping
        status.maximumNumberOfLines = 2
        status.frame = NSRect(x: 18, y: 13, width: 380, height: 40)
        status.stringValue = "Getting your study space ready…"
        card.addSubview(status)
        openButton = PrimaryButton(title: "Open Oatmeal AI  ↗", target: self, action: #selector(openApp))
        openButton.isBordered = false
        openButton.isEnabled = false
        openButton.keyEquivalent = "\r"
        place(openButton, NSRect(x: 32, y: 125, width: 416, height: 46))

        let note = NSTextField(wrappingLabelWithString: "Your saved classes stay on this Mac. Finish recording and processing before you quit.")
        note.font = .systemFont(ofSize: 11)
        note.textColor = muted
        note.alignment = .center
        place(note, NSRect(x: 56, y: 78, width: 368, height: 32))
        let divider = NSBox(frame: NSRect(x: 32, y: 62, width: 416, height: 1))
        divider.boxType = .separator
        content.addSubview(divider)
        let logs = NSButton(title: "Show logs", target: self, action: #selector(showLogs))
        logs.isBordered = false
        logs.font = .systemFont(ofSize: 11)
        logs.contentTintColor = muted
        place(logs, NSRect(x: 27, y: 22, width: 76, height: 24))
        let quit = NSButton(title: "Quit & stop Docker", target: NSApplication.shared, action: #selector(NSApplication.terminate(_:)))
        quit.isBordered = false
        quit.font = .systemFont(ofSize: 11)
        quit.contentTintColor = muted
        place(quit, NSRect(x: 302, y: 22, width: 151, height: 24))
        if let index = CommandLine.arguments.firstIndex(of: "--preview"), CommandLine.arguments.count > index + 1 {
            setStatus("READY TO STUDY", "Your study space is ready. Open your classes in the browser.", color: NSColor(srgbRed: 0.27, green: 0.42, blue: 0.29, alpha: 1))
            openButton.isEnabled = true
            content.wantsLayer = true
            content.layer?.backgroundColor = cream.cgColor
            writePNG(content, to: CommandLine.arguments[index + 1])
            exit(0)
        }
        showWindow()
        start()
    }

    private func setStatus(_ label: String, _ message: String, color: NSColor = cinnamon) {
        badge.stringValue = "●  " + label
        badge.textColor = color
        status.stringValue = message
    }

    private func showWindow() {
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        if process == nil && !quitting { openApp() }
        return true
    }

    @objc private func openApp() {
        guard !quitting else { return }
        if process != nil {
            showWindow()
        } else {
            NSWorkspace.shared.open(URL(string: "http://localhost:3000")!)
        }
    }

    @objc private func showLogs() {
        NSWorkspace.shared.open(root.appendingPathComponent(".data"))
    }

    private func start() {
        run("scripts/start-mac.sh", arguments: ["--background"]) { code in
            if self.quitting {
                self.stop()
            } else if code == 0 {
                self.setStatus("READY TO STUDY", "Your study space is ready. Open your classes in the browser.", color: NSColor(srgbRed: 0.27, green: 0.42, blue: 0.29, alpha: 1))
                self.openButton.isEnabled = true
            } else {
                self.setStatus("NEEDS ATTENTION", "Could not start. Check the logs, then quit before trying again.", color: .systemRed)
                self.showError("Oatmeal AI could not start", detail: "See launcher.log and services.log in the logs folder. Choose Quit to stop any services that started.")
            }
        }
    }

    private func run(_ script: String, arguments: [String], completion: @escaping (Int32) -> Void) {
        do {
            let data = root.appendingPathComponent(".data")
            try FileManager.default.createDirectory(at: data, withIntermediateDirectories: true,
                                                    attributes: [.posixPermissions: 0o700])
            if !FileManager.default.fileExists(atPath: logURL.path) {
                FileManager.default.createFile(atPath: logURL.path, contents: nil,
                                               attributes: [.posixPermissions: 0o600])
            }
            let log = try FileHandle(forWritingTo: logURL)
            log.seekToEndOfFile()
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/bash")
            task.arguments = [root.appendingPathComponent(script).path] + arguments
            task.currentDirectoryURL = root
            var environment = ProcessInfo.processInfo.environment
            let savedPath = (try? String(contentsOf: Bundle.main.resourceURL!.appendingPathComponent("launch-path.txt"), encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            environment["PATH"] = savedPath + ":/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
            task.environment = environment
            task.standardInput = FileHandle.nullDevice
            task.standardOutput = log
            task.standardError = log
            task.terminationHandler = { task in
                try? log.close()
                DispatchQueue.main.async {
                    self.process = nil
                    completion(task.terminationStatus)
                }
            }
            process = task
            try task.run()
        } catch {
            process = nil
            status.stringValue = "Could not run the launcher: \(error.localizedDescription)"
            completion(1)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if terminationPending { return .terminateLater }
        terminationPending = true
        quitting = true
        openButton.isEnabled = false
        setStatus("CLOSING UP", process == nil ? "Stopping services and Docker Desktop…" : "Finishing startup, then stopping services and Docker Desktop…")
        showWindow()
        // Serialize shutdown after startup so Docker cannot restart after Quit.
        if process == nil { stop() }
        return .terminateLater
    }

    private func stop() {
        setStatus("CLOSING UP", "Stopping services and Docker Desktop…")
        run("scripts/stop-mac.sh", arguments: ["--quit-docker"]) { code in
            if code == 0 {
                NSApplication.shared.reply(toApplicationShouldTerminate: true)
            } else {
                self.quitting = false
                self.terminationPending = false
                self.setStatus("NEEDS ATTENTION", "Shutdown needs attention. Check the logs, then quit to retry.", color: .systemRed)
                NSApplication.shared.reply(toApplicationShouldTerminate: false)
                self.showError("Oatmeal AI could not finish shutting down", detail: "See launcher.log in the logs folder. Docker may still be running. Choose Quit to retry.")
            }
        }
    }

    private func showError(_ message: String, detail: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = detail
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: window)
    }
}

func writePNG(_ view: NSView, to path: String) {
    view.layoutSubtreeIfNeeded()
    guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { exit(1) }
    view.cacheDisplay(in: view.bounds, to: bitmap)
    guard let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
    do { try png.write(to: URL(fileURLWithPath: path)) } catch { exit(1) }
}

let app = NSApplication.shared
if let index = CommandLine.arguments.firstIndex(of: "--render-icon"), CommandLine.arguments.count > index + 1 {
    writePNG(OatmealMark(frame: NSRect(x: 0, y: 0, width: 1024, height: 1024)), to: CommandLine.arguments[index + 1])
    exit(0)
}
let delegate = OatmealApp()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
