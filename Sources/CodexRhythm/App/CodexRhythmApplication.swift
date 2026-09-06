import AppKit

@main
enum CodexRhythmApplication {
    static func main() {
        let application = NSApplication.shared
        let applicationDelegate = ApplicationDelegate()
        application.delegate = applicationDelegate
        application.setActivationPolicy(.accessory)
        AppLogger.log("app.run starting")
        application.run()
    }
}
