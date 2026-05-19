import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
	let nvimOpenPath: String
	var cooldownTimer: Timer?
	var fallbackTimer: Timer?

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
		fallbackTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
			NSApplication.shared.terminate(nil)
		}
	}

	func application(_ sender: NSApplication, openFile filename: String) -> Bool {
		launchNvim(filename)
		return true
	}

	func application(_ sender: NSApplication, openFiles filenames: [String]) {
		for path in filenames { launchNvim(path) }
	}

	func launchNvim(_ file: String) {
		let task = Process()
		task.executableURL = URL(fileURLWithPath: nvimOpenPath)
		task.arguments = [file]

		var env = ProcessInfo.processInfo.environment
		env["PATH"] = resolvePath()
		task.environment = env

		do { try task.run() } catch {}

		fallbackTimer?.invalidate()
		fallbackTimer = nil
		cooldownTimer?.invalidate()
		cooldownTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
			NSApplication.shared.terminate(nil)
		}
	}
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.prohibited)
app.run()
