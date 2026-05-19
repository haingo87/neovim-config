import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
	let nvimOpenPath: String
	var cooldownTimer: Timer?
	var receivedAppleEvent = false

	override init() {
		let bundleDir = Bundle.main.bundleURL.resolvingSymlinksInPath()
		let repoDir = bundleDir.deletingLastPathComponent()
		nvimOpenPath = repoDir.appendingPathComponent("nvim-open").path
	}

	func resolvePath() -> String {
		let env = ProcessInfo.processInfo.environment
		var parts: [String] = []
		let extras = ["/opt/homebrew/bin", "/usr/local/bin"]
		for dir in extras { if FileManager.default.fileExists(atPath: dir) { parts.append(dir) } }
		if let existing = env["PATH"] { parts.append(existing) }
		return parts.joined(separator: ":")
	}

	func applicationDidFinishLaunching(_ notification: Notification) {
		let args = Array(CommandLine.arguments.dropFirst())
		if !args.isEmpty {
			for path in args { launchNvim(path) }
			return
		}
		// Let Apple Events arrive first, then handle "no file" case
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
			guard let self, !self.receivedAppleEvent else { return }
			self.launchNvim(nil)
		}
	}

	func application(_ sender: NSApplication, openFile filename: String) -> Bool {
		receivedAppleEvent = true
		launchNvim(filename)
		return true
	}

	func application(_ sender: NSApplication, openFiles filenames: [String]) {
		receivedAppleEvent = true
		for path in filenames { launchNvim(path) }
	}

	func launchNvim(_ file: String?) {
		let task = Process()
		task.executableURL = URL(fileURLWithPath: nvimOpenPath)
		task.arguments = file != nil ? [file!] : []

		var env = ProcessInfo.processInfo.environment
		env["PATH"] = resolvePath()
		task.environment = env

		cooldownTimer?.invalidate()
		cooldownTimer = nil

		task.terminationHandler = { proc in
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
				NSApplication.shared.terminate(nil)
			}
		}

		do { try task.run() } catch { NSApplication.shared.terminate(nil) }
	}
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.prohibited)
app.run()
