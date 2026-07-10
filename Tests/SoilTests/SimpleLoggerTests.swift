
import Testing
import Foundation
import Soil

private final class TestReceiver: Receiver {

    nonisolated(unsafe) var logged: (path: Path, sample: Sample)?

    func accept(_ tree: SampleTree, for path: Path) -> any Request {
        if let sample = tree.samples.first {
            logged = (path, sample)
        }
        #expect(tree.samples.count == 1)
        #expect(tree.children.isEmpty)
        return CompletedRequest()
    }

    func expectLogEntry(path: Path? = nil, value: String? = nil, timestamp: Timestamp? = nil) throws {
        let got = try #require(logged)
        if let path {
            #expect(got.path == path)
        }
        if let value {
            #expect(got.sample.value.stringValue == value)
        }
        if let timestamp {
            #expect(got.sample.timestamp == timestamp)
        }
        logged = nil
    }

    func expectNoLogEntry() {
        #expect(logged == nil)
        logged = nil
    }
}

@Suite("Simple Logger")
struct LoggingTests {

    @Test("Simple Root logger")
    func testSimpleRootLogger() throws {
        let receiver = TestReceiver()

        let logger: Logger = SimpleLogger(path: [], receiver: receiver)
        receiver.expectNoLogEntry()
        // Default level is warning
        logger.error("Error")
        try receiver.expectLogEntry(path: ["error"], value: "Error")
        logger.warning("Warning")
        try receiver.expectLogEntry(path: ["warning"], value: "Warning")
        logger.info("Info")
        receiver.expectNoLogEntry()
        logger.debug("Debug")
        receiver.expectNoLogEntry()
        logger.trace("Trace")
        receiver.expectNoLogEntry()
    }

    @Test("Simple Root logger level")
    func testSimpleRootLoggerLevel() throws {
        let receiver = TestReceiver()

        let logger: Logger = SimpleLogger(path: [], receiver: receiver)
        receiver.expectNoLogEntry()

        logger.setLevel(.error)

        logger.error("Error")
        try receiver.expectLogEntry(path: ["error"], value: "Error")
        logger.warning("Warning")
        receiver.expectNoLogEntry()
        logger.info("Info")
        receiver.expectNoLogEntry()
        logger.debug("Debug")
        receiver.expectNoLogEntry()
        logger.trace("Trace")
        receiver.expectNoLogEntry()

        logger.setLevel(.warning)

        logger.error("Error")
        try receiver.expectLogEntry(path: ["error"], value: "Error")
        logger.warning("Warning")
        try receiver.expectLogEntry(path: ["warning"], value: "Warning")
        logger.info("Info")
        receiver.expectNoLogEntry()
        logger.debug("Debug")
        receiver.expectNoLogEntry()
        logger.trace("Trace")
        receiver.expectNoLogEntry()

        logger.setLevel(.info)

        logger.error("Error")
        try receiver.expectLogEntry(path: ["error"], value: "Error")
        logger.warning("Warning")
        try receiver.expectLogEntry(path: ["warning"], value: "Warning")
        logger.info("Info")
        try receiver.expectLogEntry(path: ["info"], value: "Info")
        logger.debug("Debug")
        receiver.expectNoLogEntry()
        logger.trace("Trace")
        receiver.expectNoLogEntry()

        logger.setLevel(.debug)

        logger.error("Error")
        try receiver.expectLogEntry(path: ["error"], value: "Error")
        logger.warning("Warning")
        try receiver.expectLogEntry(path: ["warning"], value: "Warning")
        logger.info("Info")
        try receiver.expectLogEntry(path: ["info"], value: "Info")
        logger.debug("Debug")
        try receiver.expectLogEntry(path: ["debug"], value: "Debug")
        logger.trace("Trace")
        receiver.expectNoLogEntry()

        logger.setLevel(.trace)

        logger.error("Error")
        try receiver.expectLogEntry(path: ["error"], value: "Error")
        logger.warning("Warning")
        try receiver.expectLogEntry(path: ["warning"], value: "Warning")
        logger.info("Info")
        try receiver.expectLogEntry(path: ["info"], value: "Info")
        logger.debug("Debug")
        try receiver.expectLogEntry(path: ["debug"], value: "Debug")
        logger.trace("Trace")
        try receiver.expectLogEntry(path: ["trace"], value: "Trace")
    }

    @Test("Simple Child logger")
    func testSimpleLoggerChild() throws {
        let receiver = TestReceiver()

        let root: Logger = SimpleLogger(path: [], receiver: receiver)
        receiver.expectNoLogEntry()

        let child = root.child("some")

        child.warning("Warning")
        try receiver.expectLogEntry(path: ["some", "warning"], value: "Warning")
    }

    @Test("Simple Child logger with level")
    func testSimpleLoggerChildWithLevel() throws {
        let receiver = TestReceiver()

        let root: Logger = SimpleLogger(path: [], receiver: receiver)
        receiver.expectNoLogEntry()

        let child = root.child("some", level: .info)

        child.info("Info")
        try receiver.expectLogEntry(path: ["some", "info"], value: "Info")
    }
}