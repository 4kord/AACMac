import Foundation

public enum UserMessage {
    public static func text(for error: Error) -> String {
        if let f = error as? SetupFailure {
            return "Setup stopped at “\(f.step.title)”. \(text(for: f.underlying))"
        }
        switch error {
        case DownloadError.hashMismatch(let file):
            return "\(file) did not match its expected checksum, so it was deleted. Try again; if it keeps failing, the download has changed and the app needs an update."
        case DownloadError.notAnExecutable(let file):
            return "The download of \(file) did not return a Windows program. The download site may be down; try again later."
        case DownloadError.failed(let url, let attempts):
            return "Could not download \(url.absoluteString) after \(attempts) attempts. Check your internet connection."
        case InstallError.runtimeHashMismatch:
            return "The Wine runtime inside the app is damaged. Download the app again."
        case InstallError.commandFailed(let message):
            return message
        case PreferencesError.launcherRunning:
            return "Close the ArcheAge Classic launcher and the game first."
        case PreferencesError.noGameSettingsFolder:
            return "The game settings folder doesn't exist yet. Finish setup first."
        default:
            return error.localizedDescription
        }
    }
}
