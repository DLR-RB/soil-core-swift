import Testing
import Soil

@Suite("Framing")
struct SyncByteLengthFramingTests {

    // Common sync pattern used in tests
    private let sync: [UInt8] = [0xAA, 0x55]

    @Test("Add header")
    func encodeAddsSyncAndLength() async throws {
        let framing = SyncByteLengthFraming(syncBytes: sync)

        let payload: [UInt8] = [1, 2, 3]

        let encoded = try await framing.encodeForStream(payload)

        #expect(encoded == [
            0xAA, 0x55, // sync
            0x00, 0x03, // length
            1, 2, 3     // payload
        ])
    }

    @Test("Empty payload")
    func encodeEmptyPayload() async throws {
        let framing = SyncByteLengthFraming(syncBytes: sync)

        let encoded = try await framing.encodeForStream([])

        #expect(encoded == [
            0xAA, 0x55,
            0x00, 0x00
        ])
    }

    @Test("Complete frame")
    func decodeSingleFrame() async {
        let framing = SyncByteLengthFraming(syncBytes: sync)

        let frame: [UInt8] = [
            0xAA, 0x55,
            0x00, 0x03,
            10, 11, 12
        ]

        let messages = await framing.processStreamBytes(frame)

        #expect(messages.count == 1)
        #expect(messages[0] == [10, 11, 12])
    }

    @Test("Multiple frames in one chunk")
    func decodeMultipleFramesInSingleChunk() async {
        let framing = SyncByteLengthFraming(syncBytes: sync)

        let stream: [UInt8] = [
            0xAA, 0x55, 0x00, 0x01, 1,
            0xAA, 0x55, 0x00, 0x02, 2, 3
        ]

        let messages = await framing.processStreamBytes(stream)

        #expect(messages.count == 2)
        #expect(messages[0] == [1])
        #expect(messages[1] == [2, 3])
    }

    @Test("Decode fragmented")
    func decodeFragmentedFrame() async {
        let framing = SyncByteLengthFraming(syncBytes: sync)

        let part1: [UInt8] = [0xAA]
        let part2: [UInt8] = [0x55, 0x00]
        let part3: [UInt8] = [0x02, 7, 8]

        #expect(await framing.processStreamBytes(part1).isEmpty)
        #expect(await framing.processStreamBytes(part2).isEmpty)

        let messages = await framing.processStreamBytes(part3)

        #expect(messages.count == 1)
        #expect(messages[0] == [7, 8])
    }

    @Test("Skip non-sync bytes")
    func skipsNoiseBeforeSync() async {
        let framing = SyncByteLengthFraming(syncBytes: sync)

        let stream: [UInt8] = [
            9, 9, 9, // noise
            0xAA, 0x55,
            0x00, 0x01,
            42
        ]

        let messages = await framing.processStreamBytes(stream)

        #expect(messages.count == 1)
        #expect(messages[0] == [42])
    }

    @Test("Resync after truncation")
    func resynchronizesAfterCorruption() async {
        let framing = SyncByteLengthFraming(syncBytes: sync)

        let stream: [UInt8] = [
            0xAA, 0x55, 0x00, 0x05, // claims 5 bytes
            1, 2,                   // truncated / corrupted
            0xAA, 0x55,             // new sync, will be treated as payload
            0x00, 0x01,
            99,
            0xAA, 0x55,             // Final message, will be detected again
            0x00, 0x02,
            42, 43
        ]

        let messages = await framing.processStreamBytes(stream)

        #expect(messages.count == 2)
        #expect(messages[0] == [1, 2, 0xAA, 0x55, 0x00])
        #expect(messages[1] == [42, 43])
        #expect(await framing.bufferedBytes == 0)
    }

    @Test("Partial frame")
    func holdsPartialFrameUntilComplete() async {
        let framing = SyncByteLengthFraming(syncBytes: sync)

        let part1: [UInt8] = [
            0xAA, 0x55, 0x00, 0x03, 1
        ]

        let part2: [UInt8] = [2, 3]

        #expect(await framing.processStreamBytes(part1).isEmpty)

        let messages = await framing.processStreamBytes(part2)

        #expect(messages.count == 1)
        #expect(messages[0] == [1, 2, 3])
    }

    @Test("Discard invalid length")
    func invalidLengthTriggersResync() async {
        let framing = SyncByteLengthFraming(
            syncBytes: sync,
            maxPayloadLength: 4
        )

        let stream: [UInt8] = [
            0xAA, 0x55,
            0x00, 0x10, // invalid length (16 > max 4)
            0xAA, 0x55,
            0x00, 0x01,
            7
        ]

        let messages = await framing.processStreamBytes(stream)

        #expect(messages.count == 1)
        #expect(messages[0] == [7])
    }

    @Test("Fragmented frame")
    func streamingAcrossMultipleCalls() async {
        let framing = SyncByteLengthFraming(syncBytes: sync)

        let chunks: [[UInt8]] = [
            [0xAA],
            [0x55, 0x00],
            [0x02],
            [5],
            [6]
        ]

        var messages: [[UInt8]] = []

        for chunk in chunks {
            messages += await framing.processStreamBytes(chunk)
        }

        #expect(messages.count == 1)
        #expect(messages[0] == [5, 6])
    }

    @Test("Fragmented frames")
    func backToBackFramesFragmented() async {
        let framing = SyncByteLengthFraming(syncBytes: sync)

        let stream1: [UInt8] = [
            0xAA, 0x55, 0x00, 0x01, 1,
            0xAA
        ]

        let stream2: [UInt8] = [
            0x55, 0x00, 0x01, 2
        ]

        var messages: [[UInt8]] = []

        messages += await framing.processStreamBytes(stream1)
        messages += await framing.processStreamBytes(stream2)

        #expect(messages.count == 2)
        #expect(messages[0] == [1])
        #expect(messages[1] == [2])
    }

    @Test("Wrap")
    func handlesRingBufferWrap() async {
        // Buffer size will be 7
        let framing = SyncByteLengthFraming(
            syncBytes: sync,
            maxPayloadLength: 1
        )

        // Fill buffer with noise first
        let noise = [UInt8](repeating: 42, count: 5)
        _ = await framing.processStreamBytes(noise)

        // Then a valid frame that forces wrap
        let frame: [UInt8] = [
            0xAA, 0x55,
            0x00, 0x01,
            33
        ]

        let messages = await framing.processStreamBytes(frame)

        #expect(messages.count == 1)
        #expect(messages[0] == [33])
    }

    @Test("Encode and decode")
    func roundTripEncodeDecode() async throws {
        let framing = SyncByteLengthFraming(syncBytes: sync)

        let payloads: [[UInt8]] = [
            [],
            [1],
            [1, 2, 3, 4, 5]
        ]

        var stream: [UInt8] = []

        for p in payloads {
            stream += try await framing.encodeForStream(p)
        }

        let messages = await framing.processStreamBytes(stream)

        #expect(messages == payloads)
    }
}
