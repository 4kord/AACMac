import XCTest
@testable import AACCore

final class UserMessageTests: XCTestCase {
    func testSetupFailureNamesTheStepAndTheCause() {
        let e = SetupFailure(step: .webView2, underlying: DownloadError.hashMismatch(file: "webview2.exe"))
        let text = UserMessage.text(for: e)
        XCTAssertTrue(text.hasPrefix("Setup stopped at “Downloading Microsoft WebView2”."), text)
        XCTAssertTrue(text.contains("webview2.exe did not match its expected checksum"), text)
    }

    func testLauncherRunning() {
        XCTAssertEqual(UserMessage.text(for: PreferencesError.launcherRunning),
                       "Close the ArcheAge Classic launcher and the game first.")
    }

    func testCommandFailurePassesThrough() {
        XCTAssertEqual(UserMessage.text(for: InstallError.commandFailed("The official installer did not create the launcher.")),
                       "The official installer did not create the launcher.")
    }
}
