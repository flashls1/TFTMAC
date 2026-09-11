import XCTest

final class RiotLoginTests: XCTestCase {
    // Structural labels and roles observed on Riot's live MobileFRE WebView.
    private func form(package: String = "com.riotgames.league.teamfighttactics", extra: String = "",
                      bounds: String = "[116,360][940,484]") -> Data {
        Data("""
        <?xml version="1.0"?><hierarchy>
        <node class="android.widget.TextView" text="Sign In"/>
        <node class="android.view.View" text="USERNAME"/><node class="android.view.View" text="PASSWORD"/>
        <node class="android.widget.EditText" package="\(package)" password="false" clickable="true" enabled="true" focusable="true" focused="true" text="" bounds="\(bounds)"/>
        <node class="android.widget.EditText" package="\(package)" password="true" clickable="true" enabled="true" focusable="true" focused="false" text="" bounds="[980,360][1804,484]"/>
        <node class="android.widget.Button" package="\(package)" text="Sign in" clickable="true" enabled="false" bounds="[1580,740][1846,1006]"/>
        \(extra)</hierarchy>
        """.utf8)
    }

    func testRecognizesObservedRolesAndFocusWithoutFixedCoordinates() throws {
        let parsed = try RiotLoginForm.parse(form())
        XCTAssertTrue(parsed.username.focused)
        XCTAssertFalse(parsed.password.focused)
        XCTAssertEqual(parsed.username.x, 528)
        XCTAssertFalse(parsed.submitEnabled)
    }

    func testRejectsForeignPackageAndUnidentifiedScreen() {
        XCTAssertThrowsError(try RiotLoginForm.parse(form(package: "example.foreign")))
        XCTAssertThrowsError(try RiotLoginForm.parse(Data("<hierarchy/>".utf8)))
    }

    func testRejectsAmbiguousFields() {
        XCTAssertThrowsError(try RiotLoginForm.parse(form(extra: "<node class=\"android.widget.EditText\" password=\"false\"/>")))
    }

    func testChallengeAndRejectedCredentialsStopRecognition() {
        for label in ["Incorrect credentials", "Verification code", "CAPTCHA"] {
            XCTAssertThrowsError(try RiotLoginForm.parse(form(extra: "<node class=\"android.widget.TextView\" text=\"\(label)\"/>")))
        }
    }

    func testRejectsMalformedOrOutOfDisplayBounds() {
        for bounds in ["invalid", "[-2,0][100,100]", "[0,0][99999,100]"] {
            XCTAssertThrowsError(try RiotLoginForm.parse(form(bounds: bounds)))
        }
    }

    func testCredentialBytesArePreservedWithoutEscapeNormalization() throws {
        for password in ["test$*", "test$\\*", "  test  "] {
            let credentials = try RiotCredentials(username: "test-account", passwordBytes: Data(password.utf8))
            XCTAssertEqual(Data(credentials.transientPassword().utf8), Data(password.utf8))
            XCTAssertEqual(credentials.description, "RiotCredentials(redacted)")
        }
    }

    func testManualInputInvalidatesAutomationGeneration() {
        let guardState = RiotLoginInteractionGuard()
        let before = guardState.snapshot()
        guardState.observeManualInput()
        XCTAssertNotEqual(guardState.snapshot(), before)
    }
}
