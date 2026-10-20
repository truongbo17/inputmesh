#if os(macOS)
import Foundation
import XCTest
@testable import InputMeshMacOS

final class MacDeviceIdentityTests: XCTestCase {
    func testSignedChallengeAndStrictNonceValidation() throws {
        let a = MacDeviceIdentity()
        let b = MacDeviceIdentity()
        let nonce = Data(repeating: 42, count: 32)
        let signature = try a.sign(challenge: nonce)
        XCTAssertTrue(MacDeviceIdentity.verify(publicKey: a.publicKey, challenge: nonce, signature: signature))
        XCTAssertFalse(MacDeviceIdentity.verify(publicKey: b.publicKey, challenge: nonce, signature: signature))
        XCTAssertFalse(MacDeviceIdentity.verify(publicKey: a.publicKey, challenge: Data(repeating: 43, count: 32), signature: signature))
        XCTAssertThrowsError(try a.sign(challenge: Data(repeating: 1, count: 2)))
    }

    func testSamePairingCodeInBothOrdersAndNoSelfPairing() throws {
        let a = MacDeviceIdentity()
        let b = MacDeviceIdentity()
        let ab = try MacDeviceIdentity.comparisonCode(localPublicKey: a.publicKey, remotePublicKey: b.publicKey)
        let ba = try MacDeviceIdentity.comparisonCode(localPublicKey: b.publicKey, remotePublicKey: a.publicKey)
        XCTAssertEqual(ab, ba)
        XCTAssertEqual(ab.count, 11)
        XCTAssertThrowsError(try MacDeviceIdentity.comparisonCode(localPublicKey: a.publicKey, remotePublicKey: a.publicKey))
    }
}
#endif
