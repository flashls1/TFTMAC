import XCTest

final class StartupCurtainStateTests: XCTestCase {
    func testColdBootAndroidFramesDoNotReveal() {
        var reducer = StartupCurtainReducer()
        reducer.configure(workload: .officialTFT)
        reducer.observeGameFrameStatus(.unavailable(.noTFTSurfaceView), currentPresentedSequence: 10)
        reducer.sourceFramePresented(11)
        XCTAssertEqual(reducer.state, .covered)
    }

    func testElapsedTimeDoesNotReveal() {
        var reducer = StartupCurtainReducer()
        reducer.configure(workload: .officialTFT)
        reducer.timeoutElapsed()
        XCTAssertEqual(reducer.state, .covered)
    }

    func testGameActivityEligibilityRejectsStaleSequence() {
        var reducer = StartupCurtainReducer()
        reducer.configure(workload: .officialTFT)
        reducer.observeGameFrameStatus(.available, currentPresentedSequence: 41)
        reducer.sourceFramePresented(41)
        XCTAssertEqual(reducer.state, .eligible(reason: .tftGameActivity, baselineSequence: 41))
    }

    func testGameActivityEligibilityRevealsOnNewerCompletedSequence() {
        var reducer = StartupCurtainReducer()
        reducer.configure(workload: .officialTFT)
        reducer.observeGameFrameStatus(.available, currentPresentedSequence: 41)
        reducer.sourceFramePresented(42)
        XCTAssertEqual(reducer.state, .revealed)
    }

    func testGameActivityLostBeforeFreshFrameReturnsToCovered() {
        var reducer = StartupCurtainReducer()
        reducer.configure(workload: .officialTFT)
        reducer.observeGameFrameStatus(.available, currentPresentedSequence: 41)
        reducer.observeGameFrameStatus(.unavailable(.noTFTSurfaceView), currentPresentedSequence: 41)
        XCTAssertEqual(reducer.state, .covered)
    }

    func testRiotLoginEligibilityRejectsStaleSequence() {
        var reducer = StartupCurtainReducer()
        reducer.configure(workload: .officialTFT)
        reducer.observeGameFrameStatus(.unavailable(.loginPromptActive), currentPresentedSequence: 20)
        reducer.sourceFramePresented(20)
        XCTAssertEqual(reducer.state, .eligible(reason: .riotLogin, baselineSequence: 20))
    }

    func testRiotLoginEligibilityRevealsOnNewerCompletedSequence() {
        var reducer = StartupCurtainReducer()
        reducer.configure(workload: .officialTFT)
        reducer.observeGameFrameStatus(.unavailable(.loginPromptActive), currentPresentedSequence: 20)
        reducer.sourceFramePresented(21)
        XCTAssertEqual(reducer.state, .revealed)
    }

    func testRuntimeErrorBeforeRevealFailsCovered() {
        var reducer = StartupCurtainReducer()
        reducer.configure(workload: .officialTFT)
        reducer.fail("ADB unavailable")
        XCTAssertEqual(reducer.state, .failed(message: "ADB unavailable"))
        XCTAssertTrue(reducer.state.isVisuallyCovered)
    }

    func testRevealIsLatchedAgainstLaterActivityAndErrors() {
        var reducer = StartupCurtainReducer()
        reducer.configure(workload: .officialTFT)
        reducer.observeGameFrameStatus(.available, currentPresentedSequence: 1)
        reducer.sourceFramePresented(2)
        reducer.observeGameFrameStatus(.unavailable(.noTFTSurfaceView), currentPresentedSequence: 2)
        reducer.fail("later error")
        XCTAssertEqual(reducer.state, .revealed)
    }

    func testFailedStartupCannotLaterExposeAndroid() {
        var reducer = StartupCurtainReducer()
        reducer.configure(workload: .officialTFT)
        reducer.fail("controller failed")
        reducer.observeGameFrameStatus(.available, currentPresentedSequence: 9)
        reducer.sourceFramePresented(10)
        XCTAssertEqual(reducer.state, .failed(message: "controller failed"))
    }

    func testOwnedProbeBypassesConsumerCurtain() {
        var reducer = StartupCurtainReducer()
        reducer.configure(workload: .ownedVulkanProbe)
        XCTAssertFalse(reducer.consumerCurtainEnabled)
        XCTAssertEqual(reducer.state, .revealed)
    }

    func testRepeatedEligibilityDoesNotMoveFreshnessBaseline() {
        var reducer = StartupCurtainReducer()
        reducer.configure(workload: .officialTFT)
        reducer.observeGameFrameStatus(.available, currentPresentedSequence: 100)
        reducer.observeGameFrameStatus(.available, currentPresentedSequence: 120)
        XCTAssertEqual(reducer.state, .eligible(reason: .tftGameActivity, baselineSequence: 100))
        reducer.sourceFramePresented(101)
        XCTAssertEqual(reducer.state, .revealed)
    }
}
