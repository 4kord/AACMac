import AppKit
import SwiftUI

struct SetupView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch model.phase {
            case .checking:
                ProgressView("Checking installation…")
            case .needsRosetta:
                Text("Rosetta 2 is required").font(.headline)
                Text("ArcheAge Classic is an Intel game, so macOS needs Rosetta 2 to run it. Installing it asks for your password.")
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Spacer()
                    Button("Quit") { NSApp.terminate(nil) }
                    Button("Install Rosetta") { model.installRosetta() }.keyboardShortcut(.defaultAction)
                }
            case let .working(title, detail, step, total):
                Text(title).font(.headline)
                ProgressView(value: Double(max(step - 1, 0)), total: Double(max(total, 1))) { Text(detail) }
                Text("The first setup downloads about 250 MB and takes a few minutes. If you quit, it continues where it stopped next time.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Spacer()
                    Button("Cancel") { NSApp.terminate(nil) }
                }
            case .launching:
                ProgressView("Starting the launcher…")
            case .running:
                Text("The launcher is running.")
            case let .failed(message):
                Text(message).fixedSize(horizontal: false, vertical: true)
                HStack {
                    Spacer()
                    Button("Quit") { NSApp.terminate(nil) }
                    Button("Open Logs") { model.openLogs() }
                    Button("Retry") { model.retry() }.keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(20)
        .frame(width: 460)
    }
}
