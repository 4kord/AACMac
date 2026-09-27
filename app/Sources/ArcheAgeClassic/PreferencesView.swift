import AACCore
import AppKit
import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Form {
            Picker("Renderer", selection: Binding(get: { model.options.renderer }, set: { model.setRenderer($0) })) {
                Text("Metal (MTLd3D), fastest").tag(Renderer.metal)
                Text("Wine OpenGL, slower but complete").tag(Renderer.wined3d)
            }
            Toggle("x87 acceleration (rosettax87)", isOn: Binding(get: { model.options.x87 }, set: { model.setX87($0) }))
            Toggle("Metal HUD (FPS overlay)", isOn: Binding(get: { model.options.metalHUD }, set: { model.setMetalHUD($0) }))
            Picker("Game window", selection: Binding(get: { model.options.windowed }, set: { model.setWindowed($0) })) {
                Text("Windowed").tag(true)
                Text("Fullscreen").tag(false)
            }
            Text("Renderer and window mode apply the next time the game starts; x87 and Metal HUD the next time the launcher starts.")
                .font(.caption).foregroundStyle(.secondary)
            Section {
                HStack {
                    Button("Repair Installation") { model.repair() }
                    Button("Reset Game Settings") { model.resetGameSettings() }
                }
                Button("Open Logs") { model.openLogs() }
            }
            if let error = model.preferencesError {
                Text(error).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .disabled(model.busy)
        .onAppear { NSApp.activate(ignoringOtherApps: true) }
    }
}
