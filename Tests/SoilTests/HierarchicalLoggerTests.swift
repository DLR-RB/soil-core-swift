
import Testing
import Foundation
import Soil

private final class TestStorage: Storage {

    private nonisolated(unsafe) var logLevels: [Path : Sample] = [:]

    func delete(path: Path, from start: Timestamp?, to end: Timestamp?, depth: Int?) -> any Request {
        // Not used
        CompletedRequest()
    }

    func tree(for path: Path, from start: Timestamp?, to end: Timestamp?, depth: Int?, limitPerNode: Int?) async -> SampleTree {
        guard let level = logLevels[path] else {
            return ImmutableSampleTree.empty
        }
        if let start, level.time <= start {
            return ImmutableSampleTree.empty
        }
        if let end, level.time > end {
            return ImmutableSampleTree.empty
        }
        return ImmutableSampleTree(sample: level)
    }

    nonisolated(unsafe) var logged: (path: Path, sample: Sample)?

    func accept(_ tree: any SampleTree, for path: Path) -> any Request {
        guard let sample = tree.samples.first else {
            return CompletedRequest()
        }
        if let raw = path.last, raw == "level" {
            // Store log level
            logLevels[path] = sample.withTimeSet()
            return CompletedRequest()
        }
        logged = (path, sample)
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

@Suite("Hierarchical Logger")
struct HierarchicalLoggerTests {

    @Test("Root logger")
    func testRootLogger() async throws {
        let receiver = TestStorage()

        let logger: Logger = HierarchicalLogger(storage: receiver)
        receiver.expectNoLogEntry()

        // Default level is warning
        #expect(await logger.logLevel() == .warning)

        await logger.error("Error").wait()
        try receiver.expectLogEntry(path: ["error"], value: "Error")
        await logger.warning("Warning").wait()
        try receiver.expectLogEntry(path: ["warning"], value: "Warning")
        await logger.info("Info").wait()
        receiver.expectNoLogEntry()
        await logger.debug("Debug").wait()
        receiver.expectNoLogEntry()
        await logger.trace("Trace").wait()
        receiver.expectNoLogEntry()
    }

    @Test("Root logger level")
    func testRootWithLevelLogger() async throws {
        let receiver = TestStorage()

        let logger: Logger = HierarchicalLogger(storage: receiver)
        receiver.expectNoLogEntry()

        await logger.setLevel(.info).wait()
        receiver.expectNoLogEntry()
        #expect(await logger.logLevel() == .info)

        await logger.error("Error").wait()
        try receiver.expectLogEntry(path: ["error"], value: "Error")
        await logger.warning("Warning").wait()
        try receiver.expectLogEntry(path: ["warning"], value: "Warning")
        await logger.info("Info").wait()
        try receiver.expectLogEntry(path: ["info"], value: "Info")
        await logger.debug("Debug").wait()
        receiver.expectNoLogEntry()
        await logger.trace("Trace").wait()
        receiver.expectNoLogEntry()
    }

    @Test("Child logger")
    func testChildLogger() async throws {
        let receiver = TestStorage()

        let parent: Logger = HierarchicalLogger(storage: receiver)
        receiver.expectNoLogEntry()
        #expect(await parent.logLevel() == .warning)

        let logger = parent.child("some")
        await logger.setLevel(.info).wait()
        receiver.expectNoLogEntry()
        #expect(await logger.logLevel() == .info)

        await logger.error("Error").wait()
        try receiver.expectLogEntry(path: ["some", "error"], value: "Error")
        await logger.warning("Warning").wait()
        try receiver.expectLogEntry(path: ["some", "warning"], value: "Warning")
        await logger.info("Info").wait()
        try receiver.expectLogEntry(path: ["some", "info"], value: "Info")
        await logger.debug("Debug").wait()
        receiver.expectNoLogEntry()
        await logger.trace("Trace").wait()
        receiver.expectNoLogEntry()
    }

    @Test("Child logger: Inherit level")
    func testChildLoggerWithParentLevel() async throws {
        let receiver = TestStorage()

        let parent: Logger = HierarchicalLogger(storage: receiver)
        receiver.expectNoLogEntry()
        await parent.setLevel(.info).wait()
        #expect(await parent.logLevel() == .info)

        let logger = parent.child("some")
        receiver.expectNoLogEntry()
        #expect(await logger.logLevel() == .info)

        await logger.error("Error").wait()
        try receiver.expectLogEntry(path: ["some", "error"], value: "Error")
        await logger.warning("Warning").wait()
        try receiver.expectLogEntry(path: ["some", "warning"], value: "Warning")
        await logger.info("Info").wait()
        try receiver.expectLogEntry(path: ["some", "info"], value: "Info")
        await logger.debug("Debug").wait()
        receiver.expectNoLogEntry()
        await logger.trace("Trace").wait()
        receiver.expectNoLogEntry()
    }

    @Test("Child logger: Override level")
    func testChildLoggerOverridesParentLevel() async throws {
        let receiver = TestStorage()

        let parent: Logger = HierarchicalLogger(storage: receiver)
        receiver.expectNoLogEntry()
        await parent.setLevel(.error).wait()
        #expect(await parent.logLevel() == .error)

        let logger = parent.child("some")
        receiver.expectNoLogEntry()
        await logger.setLevel(.info).wait()
        #expect(await logger.logLevel() == .info)

        await logger.error("Error").wait()
        try receiver.expectLogEntry(path: ["some", "error"], value: "Error")
        await logger.warning("Warning").wait()
        try receiver.expectLogEntry(path: ["some", "warning"], value: "Warning")
        await logger.info("Info").wait()
        try receiver.expectLogEntry(path: ["some", "info"], value: "Info")
        await logger.debug("Debug").wait()
        receiver.expectNoLogEntry()
        await logger.trace("Trace").wait()
        receiver.expectNoLogEntry()
    }

    @Test("Child logger: Clear level")
    func testChildLoggerClearLevel() async throws {
        let receiver = TestStorage()

        let parent: Logger = HierarchicalLogger(storage: receiver)
        receiver.expectNoLogEntry()
        await parent.setLevel(.error).wait()
        #expect(await parent.logLevel() == .error)

        let logger = parent.child("some")
        #expect(await logger.logLevel() == .error)

        await logger.setLevel(.warning).wait()
        #expect(await logger.logLevel() == .warning)

        await logger.setLevel(nil).wait()
        #expect(await logger.logLevel() == .error)
    }
}