import Foundation

public enum FrameError: Error, Equatable {
    case emptyPayload
    case frameTooLarge
    case inputChunkTooLarge
    case invalidPayload
}

/// Development-only versioned JSON transport contract. This is NOT a connection or security layer.
/// Network transport must be authenticated and encrypted before any input packet is accepted.
public enum FrameCodec {
    public static let maxPayload = 64 * 1024
    public static let maxChunk = 1024 * 1024

    public static func encode(_ message: InputEnvelope) throws -> Data {
        let bytes = try JSONEncoder().encode(message)
        guard !bytes.isEmpty else { throw FrameError.emptyPayload }
        guard bytes.count <= maxPayload else { throw FrameError.frameTooLarge }
        let len = UInt32(bytes.count)
        var framed = Data([
            UInt8((len >> 24) & 0xff), UInt8((len >> 16) & 0xff),
            UInt8((len >> 8) & 0xff), UInt8(len & 0xff)
        ])
        framed.append(bytes)
        return framed
    }
}

public struct FrameDecoder {
    private var buffer = Data()

    public init() {}

    public mutating func append(_ chunk: Data) throws -> [InputEnvelope] {
        guard chunk.count <= FrameCodec.maxChunk else { throw FrameError.inputChunkTooLarge }
        buffer.append(chunk)
        var frames: [InputEnvelope] = []
        while buffer.count >= 4 {
            let n = buffer.prefix(4).reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            guard n > 0 else { buffer.removeAll(); throw FrameError.emptyPayload }
            guard n <= FrameCodec.maxPayload else { buffer.removeAll(); throw FrameError.frameTooLarge }
            let needed = Int(n) + 4
            guard buffer.count >= needed else { break }
            let body = buffer.subdata(in: 4..<needed)
            buffer.removeSubrange(0..<needed)
            guard let envelope = try? JSONDecoder().decode(InputEnvelope.self, from: body),
                  envelope.version == InputEnvelope.currentVersion else {
                buffer.removeAll()
                throw FrameError.invalidPayload
            }
            frames.append(envelope)
        }
        return frames
    }
}
