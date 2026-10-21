#if os(macOS)
import Foundation
import Network
import XCTest
import InputMeshWorkspace
@testable import InputMeshMacOS

private final class TCPTestTrustStore: WorkspacePeerTrustPersistence {
    private var values: [Data] = []
    private let lock = NSLock()
    func load() throws -> [Data] {
        lock.lock(); defer { lock.unlock() }
        return values
    }
    func save(_ keys: [Data]) throws {
        lock.lock(); defer { lock.unlock() }
        values = keys
    }
}

private final class TCPTestReference {
    var transport: WorkspaceTCPTransport?
}

/// Loopback test runs actual Network.framework TCP connections; automatically
/// entering the SAS is a TEST FIXTURE ONLY, never application behavior.
final class WorkspaceTCPLoopbackTests: XCTestCase {
    func testTwoIndependentPeersExchangeOnlyEncryptedManifestOverRealTCP() throws {
        let received = expectation(description: "Validated encrypted Git manifest delivered via TCP")
        let noError = expectation(description: "No transport error")
        noError.isInverted = true

        let source = try WorkspaceManifest(createdAt: Date(timeIntervalSince1970: 0),
            sourceDeviceName: "Simulated Mac A",
            repository: RepositorySnapshot(origin: "https://github.com/example/project.git",
                branch: "main", headSHA: String(repeating: "a", count: 40),
                hasUncommittedChanges: false, hasUntrackedFiles: false))

        let identityA = MacDeviceIdentity()
        let identityB = MacDeviceIdentity()
        let storeA = WorkspacePeerTrustStore(persistence: TCPTestTrustStore())
        let storeB = WorkspacePeerTrustStore(persistence: TCPTestTrustStore())
        let a = try WorkspaceConsentCoordinator(identity: identityA, role: .initiator, trustStore: storeA)
        let b = try WorkspaceConsentCoordinator(identity: identityB, role: .responder, trustStore: storeB)

        let clientRef = TCPTestReference()
        let serverRef = TCPTestReference()
        let listenerQueue = DispatchQueue(label: "dev.inputmesh.test.listener")
        let listener = try NWListener(using: .tcp, on: .any)

        listener.newConnectionHandler = { connection in
            let transport = WorkspaceTCPTransport(connection: connection, coordinator: b,
                onEvent: { [weak serverRef] event in
                    switch event {
                    case .pairingCode(let code):
                        serverRef?.transport?.approveMatchingCode(code)
                    case .manifest(let manifest):
                        XCTAssertEqual(manifest, source)
                        received.fulfill()
                    case .ready, .closed:
                        break
                    }
                }, onError: { error in
                    XCTFail("Responder transport error: \(error)")
                    noError.fulfill()
                })
            serverRef.transport = transport
            transport.start()
        }

        listener.stateUpdateHandler = { state in
            guard case .ready = state, let port = listener.port else { return }
            let connection = NWConnection(host: "127.0.0.1", port: port, using: .tcp)
            let transport = WorkspaceTCPTransport(connection: connection, coordinator: a,
                onEvent: { [weak clientRef] event in
                    switch event {
                    case .pairingCode(let code):
                        clientRef?.transport?.approveMatchingCode(code)
                    case .ready:
                        clientRef?.transport?.sendManifest(source)
                    case .manifest, .closed:
                        break
                    }
                }, onError: { error in
                    XCTFail("Initiator transport error: \(error)")
                    noError.fulfill()
                })
            clientRef.transport = transport
            transport.start()
        }

        listener.start(queue: listenerQueue)
        wait(for: [received], timeout: 25)
        XCTAssertTrue(try storeA.isTrusted(identityB.publicKey))
        XCTAssertTrue(try storeB.isTrusted(identityA.publicKey))
        clientRef.transport?.stop()
        serverRef.transport?.stop()
        listener.cancel()
    }
}
#endif
