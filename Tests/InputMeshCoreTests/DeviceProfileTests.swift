import XCTest
@testable import InputMeshCore

final class DeviceProfileTests: XCTestCase {
    func testPlatformIndependentCapabilityMatching() throws {
        let required: Set<InputCapability> = [.injectKeyboard, .injectPointer]
        for system in HostPlatform.allCases {
            let profile = DeviceProfile(id: "peer-1", platform: system,
                                        capabilities: required.union([.enumerateDisplays]))
            XCTAssertNoThrow(try PeerCompatibility.require(required, from: profile))
            let restored = try JSONDecoder().decode(DeviceProfile.self,
                                                     from: JSONEncoder().encode(profile))
            XCTAssertEqual(restored, profile)
        }
    }

    func testMissingCapabilitiesAndProtocolMismatchFailClosed() {
        let profile = DeviceProfile(id: "win-1", platform: .windows,
                                    capabilities: [.injectPointer])
        XCTAssertThrowsError(try PeerCompatibility.require([.injectPointer, .injectKeyboard], from: profile)) {
            XCTAssertEqual($0 as? PeerCompatibilityError,
                           .missingCapabilities([.injectKeyboard]))
        }
        let outdated = DeviceProfile(id: "linux-1", platform: .linux, protocolVersion: 999,
                                     capabilities: [.injectPointer])
        XCTAssertThrowsError(try PeerCompatibility.require([.injectPointer], from: outdated)) {
            XCTAssertEqual($0 as? PeerCompatibilityError, .incompatibleVersion)
        }
        let anonymous = DeviceProfile(id: "", platform: .macOS, capabilities: [.injectPointer])
        XCTAssertThrowsError(try PeerCompatibility.require([], from: anonymous)) {
            XCTAssertEqual($0 as? PeerCompatibilityError, .invalidDeviceIdentity)
        }
    }
}
