import AppKit

@main
enum TFTMACApplication {
    @MainActor private static var coordinator: AppCoordinator?

    @MainActor
    static func main() {
        let application = NSApplication.shared
        let coordinator = AppCoordinator()
        Self.coordinator = coordinator
        application.delegate = coordinator
        application.setActivationPolicy(.regular)
        application.run()
    }
}
