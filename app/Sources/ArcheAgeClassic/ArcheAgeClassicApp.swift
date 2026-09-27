import AppKit
import SwiftUI

@main
struct ArcheAgeClassicApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra("ArcheAge Classic", systemImage: "gamecontroller") {
            MenuContent().environmentObject(delegate.model)
        }
        Settings {
            PreferencesView().environmentObject(delegate.model)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.start()
    }
}
