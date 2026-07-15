import Testing
import Foundation
@testable import Soil

private actor TestMessageReceiver: MessageReceiver {

    private var count = 0

    @discardableResult
    public nonisolated func accept(message: Message) -> any Request {
        AsyncRequest {
            await self.didReceive(message: message)
        }
    }

    private func didReceive(message: Message) {
        count += 1
    }

    func getCount() -> Int {
        count
    }
}

private actor TestReceiver: Receiver {

    private var count = 0

    private var last: (any SampleTree, Path)?

    nonisolated func accept(_ tree: any SampleTree, for path: Path) -> any Request {
        AsyncRequest {
            await self.store(tree, for: path)
        }
    }

    func store(_ tree: any SampleTree, for path: Path) {
        count += 1
        last = (tree, path)
    }

    func getCount() -> Int {
        count
    }

    func getLast() -> (tree: any SampleTree, path: Path)? {
        last
    }
}

@Suite("Message Splitter")
struct MessageSplitterTests {

    @Test("Split Tree with single samples")
    func splitTree() async {
        let tree = ImmutableSampleTree(
            samples: [.init(value: .string("a"), timeIntervalSince1970: 1)],
            children: [
                "b" : ImmutableSampleTree(
                    samples: [.init(value: .string("b"), timeIntervalSince1970: 2)],
                    children: [
                        "c" : ImmutableSampleTree(value: .string("c"), timestamp: .init(timeIntervalSince1970: 3))
                    ]
                ),
                "d" : ImmutableSampleTree(value: .string("d"), timestamp: .init(timeIntervalSince1970: 4))
            ]
        )
        let connections = await BidirectionalConnection()
        let connection = await connections.one.apply(encoding: JsonEncoding())
        let receivingConnection = await connections.two.apply(encoding: JsonEncoding())
        let receiver = TestMessageReceiver()
        await receivingConnection.setReceiver(receiver).wait()

        let splitter = await DataMessageSplitter(wrapping: connection)

        await splitter.send(message: .tree(tree, for: ["xyz"])).wait()

        let count = await receiver.getCount()
        #expect(count == 4)
    }

    @Test("Receive messages as single tree")
    func recombineMessages() async throws {
        let tree = ImmutableSampleTree(
            samples: [.init(value: .string("a"), timeIntervalSince1970: 1)],
            children: [
                "b" : ImmutableSampleTree(
                    samples: [.init(value: .string("b"), timeIntervalSince1970: 2)],
                    children: [
                        "c" : ImmutableSampleTree(value: .string("c"), timestamp: .init(timeIntervalSince1970: 3))
                    ]
                ),
                "d" : ImmutableSampleTree(value: .string("d"), timestamp: .init(timeIntervalSince1970: 4))
            ]
        )
        let connections = await BidirectionalConnection()
        // Create the connection that sends the batched messages
        let connection = await connections.one.apply(encoding: JsonEncoding())
        let splitter = await DataMessageSplitter(wrapping: connection)

        // Create the receiver that recombines them
        let receivingConnection = await connections.two.apply(encoding: JsonEncoding())
        let receiver = TestReceiver()
        let combiner = await RemoteTransmitter(receiver: receiver, connection: receivingConnection, batchTimeout: 1.5)

        let path = ["xyz"]
        await splitter.send(message: .tree(tree, for: path)).wait()

        try await Task.sleep(nanoseconds: 1000_000_000)
        let count = await receiver.getCount()
        #expect(count == 1)
        let received = try #require(await receiver.getLast())
        #expect(received.path == path)
        #expect(received.tree.isEqual(to: tree))

        // Use variable to prevent warning
        await combiner.setReceiver(receiver).wait()
    }
}