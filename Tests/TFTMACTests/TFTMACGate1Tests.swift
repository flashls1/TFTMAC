import CoreGraphics
import XCTest

final class TFTMACGate1Tests: XCTestCase {
    func testAspectFitCentersSixteenByNineInsideMatchingViewport() {
        let mapper = ViewportMapper(
            sourceSize: CGSize(width: 1920, height: 1080),
            viewportSize: CGSize(width: 1600, height: 900)
        )
        XCTAssertEqual(mapper.displayedRect, CGRect(x: 0, y: 0, width: 1600, height: 900))
    }

    func testLetterboxRegionDoesNotProduceAndroidTouch() {
        let mapper = ViewportMapper(
            sourceSize: CGSize(width: 1920, height: 1080),
            viewportSize: CGSize(width: 1600, height: 1000)
        )
        XCTAssertNil(mapper.sourcePoint(for: CGPoint(x: 800, y: 20)))
    }

    func testViewportCenterMapsToSourceCenter() throws {
        let mapper = ViewportMapper(
            sourceSize: CGSize(width: 1920, height: 1080),
            viewportSize: CGSize(width: 1600, height: 1000)
        )
        let source = try XCTUnwrap(mapper.sourcePoint(for: CGPoint(x: 800, y: 500)))
        XCTAssertEqual(source.x, 960, accuracy: 0.001)
        XCTAssertEqual(source.y, 540, accuracy: 0.001)
    }
}
