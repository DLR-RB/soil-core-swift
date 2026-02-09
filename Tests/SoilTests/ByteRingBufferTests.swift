import Testing
import Soil

@Suite("Ring buffer")
struct ByteRingBufferTests {

    // MARK: - Basic Write / Read

    @Test
    func writeAndReadSingleBytes() throws {
        let ring = ByteRingBuffer(capacity: 8)

        ring.write(0x01)
        ring.write(0x02)
        ring.write(0x03)

        #expect(ring.count == 3)

        let data = ring.read(3)

        #expect(data == [0x01, 0x02, 0x03])
        #expect(ring.count == 0)
    }

    // MARK: - Bulk Write

    @Test
    func writeContentsOfArray() throws {
        let ring = ByteRingBuffer(capacity: 8)

        ring.write(contentsOf: [1, 2, 3, 4])

        #expect(ring.count == 4)

        let out = ring.read(4)

        #expect(out == [1, 2, 3, 4])
    }

    // MARK: - Wrap Around

    @Test
    func wrapAroundReadWrite() throws {
        let ring = ByteRingBuffer(capacity: 5)

        ring.write(contentsOf: [1, 2, 3])
        _ = ring.read(2)              // Move head forward
        ring.write(contentsOf: [4, 5, 6]) // Causes wrap

        #expect(ring.count == 4)

        let out = ring.read(4)

        #expect(out == [3, 4, 5, 6])
    }

    // MARK: - Overwrite Mode

    @Test
    func overwriteWhenFull() throws {
        let ring = ByteRingBuffer(capacity: 3, overwriteWhenFull: true)

        ring.write(contentsOf: [1, 2, 3])
        ring.write(4) // Overwrites 1
        ring.write(5) // Overwrites 2

        #expect(ring.count == 3)

        let out = ring.read(3)

        #expect(out == [3, 4, 5])
    }

    // MARK: - Non-Overwrite Mode

    @Test
    func noOverwriteWhenFull() throws {
        let ring = ByteRingBuffer(capacity: 3, overwriteWhenFull: false)

        ring.write(contentsOf: [1, 2, 3])
        ring.write(4) // Ignored

        #expect(ring.count == 3)

        let out = ring.read(3)

        #expect(out == [1, 2, 3])
    }

    // MARK: - Discard

    @Test
    func discardBytes() throws {
        let ring = ByteRingBuffer(capacity: 8)

        ring.write(contentsOf: [10, 11, 12, 13, 14])
        ring.discard(2)

        #expect(ring.count == 3)

        let out = ring.read(3)

        #expect(out == [12, 13, 14])
    }

    // MARK: - Peek

    @Test
    func peekDoesNotConsume() throws {
        let ring = ByteRingBuffer(capacity: 8)

        ring.write(contentsOf: [21, 22, 23])

        let b0 = ring.peek(at: 0)
        let b1 = ring.peek(at: 1)

        #expect(b0 == 21)
        #expect(b1 == 22)
        #expect(ring.count == 3)
    }

    // MARK: - Find Sequence

    @Test
    func findSequenceAtStart() throws {
        let ring = ByteRingBuffer(capacity: 16)

        ring.write(contentsOf: [0xAA, 0x55, 0x01, 0x02])

        let idx = ring.findSequence([0xAA, 0x55])

        #expect(idx == 0)
    }

    @Test
    func findSequenceInMiddle() throws {
        let ring = ByteRingBuffer(capacity: 16)

        ring.write(contentsOf: [9, 8, 7, 0xAA, 0x55, 1])

        let idx = ring.findSequence([0xAA, 0x55])

        #expect(idx == 3)
    }

    @Test
    func findSequenceAcrossWrap() throws {
        let ring = ByteRingBuffer(capacity: 6)

        ring.write(contentsOf: [1, 2, 3, 4])
        _ = ring.read(3) // Move head near end
        ring.write(contentsOf: [0xAA, 0x55]) // Wraps

        let idx = ring.findSequence([0xAA, 0x55])

        #expect(idx == 1) // After remaining byte "4"
    }

    @Test
    func findSequenceNotFound() throws {
        let ring = ByteRingBuffer(capacity: 8)

        ring.write(contentsOf: [1, 2, 3, 4])

        let idx = ring.findSequence([9, 9])

        #expect(idx == nil)
    }

    // MARK: - Clear

    @Test
    func clearResetsBuffer() throws {
        let ring = ByteRingBuffer(capacity: 8)

        ring.write(contentsOf: [1, 2, 3])
        ring.clear()

        #expect(ring.count == 0)

        ring.write(9)

        let out = ring.read(1)

        #expect(out == [9])
    }

    // MARK: - Partial Reads

    @Test
    func partialReadMaintainsOrder() throws {
        let ring = ByteRingBuffer(capacity: 8)

        ring.write(contentsOf: [1, 2, 3, 4, 5])

        let a = ring.read(2)
        let b = ring.read(3)

        #expect(a == [1, 2])
        #expect(b == [3, 4, 5])
    }
}
