import AppKit
import SwiftUI

struct MenuContent: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Text(model.statusLine)
        Divider()
        SettingsLink { Text("Preferences…") }
            .keyboardShortcut(",")
        Button("Open Logs") { model.openLogs() }
        Divider()
        Button("Quit ArcheAge Classic") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
