import Foundation

/**
 A ring buffer to store bytes of a binary stream
 */
public final class ByteRingBuffer {

    /// The raw storage for the ring buffer data
    private var buffer: [UInt8]

    /// The index of the first element (if count > 0)
    private(set) var head: Int = 0

    /// The index where the next element is inserted
    private(set) var tail: Int = 0

    /// The number of elements currently in the buffer
    private(set) public var count: Int = 0

    /// The total capacity of the buffer
    public let capacity: Int

    /// Indicate if new elements should overwrite the oldest if the buffer is full
    public var overwriteWhenFull: Bool

    /**
     Create a ring buffer to store bytes.
     - Parameter capacity: The size (in bytes) of the buffer (must be larger than zero)
     - Parameter overwriteWhenFull: Indicate if new bytes should overwrite the oldest if the buffer is full (default: `true`)
     */
    public init(
        capacity: Int,
        overwriteWhenFull: Bool = true
    ) {
        precondition(capacity > 0, "Capacity must be > 0")

        self.capacity = capacity
        self.buffer = Array(repeating: 0, count: capacity)
        self.overwriteWhenFull = overwriteWhenFull
    }

    // MARK: - Write

    /**
     Insert a byte into the buffer.
     - Parameter byte: The byte to insert.
     - Note: If the buffer is full, and `overwriteWhenFull` is specified,
       then the oldest element will be overwritten.
       Otherwise the new element will be discarded.
     */
    public func write(_ byte: UInt8) {
        if count == capacity {

            guard overwriteWhenFull else {
                return
            }

            // Overwrite oldest
            head = (head + 1) % capacity
            count -= 1
        }

        buffer[tail] = byte
        tail = (tail + 1) % capacity
        count += 1
    }

    /**
     Insert a sequence of bytes into the buffer.
     - Parameter sequence: The bytes to insert
     */
    public func write<S: Sequence>(contentsOf sequence: S) where S.Element == UInt8 {
        for byte in sequence {
            write(byte)
        }
    }

    // MARK: Read

    /**
     Read a number of bytes.
     - Parameter count: The number of bytes to read
     - Returns: The `count` bytes from the beginning of the buffer.
     - Warning: This function requires sufficient bytes in the buffer,
       and will crash if this is not the case.
     */
    public func read(_ count: Int) -> [UInt8] {
        precondition(count <= self.count, "Not enough data")

        var out: [UInt8] = []
        out.reserveCapacity(count)

        for _ in 0..<count {
            out.append(buffer[head])
            head = (head + 1) % capacity
        }

        self.count -= count
        return out
    }

    // MARK: Discard

    /**
     Discard a number of bytes.
     - Parameter count: The number of bytes to discard
     - Warning: The buffer must contain sufficient bytes to discard,
       or it will crash the program.
     */
    public func discard(_ count: Int) {
        precondition(count <= self.count, "Not enough data")

        head = (head + count) % capacity
        self.count -= count
    }

    /**
     Remove all bytes in the buffer.
     */
    public func clear() {
        head = 0
        tail = 0
        count = 0
    }

    // MARK: Peek

    /**
     Check a bytes at an offset without advancing the buffer.
     - Parameter offset: The offset from the start of the contained bytes.
     - Returns: The byte at the offset
     - Warning: The buffer must contain sufficient bytes, or it will crash
     */
    public func peek(at offset: Int) -> UInt8 {
        precondition(offset < count, "Offset out of range")
        return buffer[(head + offset) % capacity]
    }

    // MARK: Search

    /**
     Finds first occurrence of byte sequence.
     - Parameter sequence: The byte sequence to locate in the buffer.
     - Returns: The offset where the sequence starts, or `nil`` if the sequence could not be found.
     */
    public func findSequence(_ sequence: [UInt8]) -> Int? {

        guard !sequence.isEmpty else { return nil }
        guard count >= sequence.count else { return nil }

        for i in 0...(count - sequence.count) {

            var match = true

            for j in 0..<sequence.count {
                if peek(at: i + j) != sequence[j] {
                    match = false
                    break
                }
            }

            if match {
                return i
            }
        }

        return nil
    }
}
