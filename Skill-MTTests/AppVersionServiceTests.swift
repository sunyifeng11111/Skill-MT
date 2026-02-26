import XCTest
@testable import Skill_MT

final class AppVersionServiceTests: XCTestCase {
    func testCompare_same() {
        let service = AppVersionService()
        XCTAssertEqual(service.compare("1.1.0", "1.1.0"), .orderedSame)
    }

    func testCompare_withLeadingV() {
        let service = AppVersionService()
        XCTAssertEqual(service.compare("1.1.0", "v1.2.0"), .orderedAscending)
        XCTAssertEqual(service.compare("v1.3.0", "1.2.9"), .orderedDescending)
    }

    func testCompare_differentSegmentLength() {
        let service = AppVersionService()
        XCTAssertEqual(service.compare("1.2", "1.2.0"), .orderedSame)
        XCTAssertEqual(service.compare("1.2.1", "1.2"), .orderedDescending)
    }
}
