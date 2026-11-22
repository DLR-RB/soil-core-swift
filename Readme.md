# SOIL (States/Outputs/Inputs/Logic)

This package contains an implementation of the SOIL core framework written in [Swift](https://swift.org).
It provides the definitions, protocols and commonly used functions to build SOIL components.

For more information about the concepts, see the [SOIL documentation repository](https://github.com/DLR-RB/soil-documentation).

## Purpose

SOIL is a component model for building modular, network-transparent data systems.
This core library defines the abstractions that make it possible to compose components
that exchange *timestamped values* over *hierarchical paths*, whether in-process or across
a network.

In particular, this core library provides:

- **Primitives**: values, paths, samples, timestamps and sample trees
- **Storage** interface definitions and an in-memory database
- **Components** to track subscriptions (both from external components and code)
- **Request tracking** and timeout handling for network calls
- **Access control** interfaces
- **Transport layer** definitions and encoding interfaces
- **Connection adapters** to expose local components over connections, and to use remote
  components as if they were local

The core protocols are:

| Protocol         | Description                                                        |
| ---------------- | ------------------------------------------------------------------ |
| `Receiver`       | Receives values that are sent to it, without being asked.          |
| `Provider`       | Provides values in response to a time-range request.               |
| `Storage`        | Stores and retrieves timestamped data (`Receiver` + `Provider`).   |
| `Observable`     | Tracks and responds to subscriptions.                              |
| `Distributor`    | Forwards data to attached receivers.                               |

## Installation

This package supports [Swift Package Manager](https://swift.org/package-manager/).

Add the package as a dependency in your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/DLR-RB/soil-core-swift.git", from: "1.0.0")
],
```

and add the `Soil` product to any target that needs it:

```swift
.targets: [
    .target(
        name: "MyComponent",
        dependencies: ["Soil"]
    )
]
```

Alternatively, add it through Xcode via *File ▸ Add Packages…* and entering the repository URL.

**Supported platforms:** macOS 13+, iOS 15+, tvOS 15+, watchOS 8+, Linux, Windows (Swift 6.1).

## Basic Usage

### Building a component

A component is typically a type that conforms to `Receiver`, `Provider`, and/or
`Observable`. The simplest building block is an in-memory storage:

```swift
import Soil

let storage = InMemoryStorage()

// Receive a value without being asked for it
await storage.accept(.integer(123), for: ["my", "value"], at: .current())

// Read the current value of a path
let current = await storage.currentValue(for: ["my", "value"])
// current == .integer(123)
```

### Working with Swift types

Types conforming to `ValueConvertible` can be stored and read directly.
Conformances exist for common types (integers, `Bool`, `Double`, `String`, `Data`, `Date`, `UUID`, `URL`,
optionals, arrays, sets and dictionaries), and enums with raw values as well as `Codable` types
only need to declare the conformance:

```swift
enum Mode: String, ValueConvertible {
    case idle, active
}

struct Position: Codable, ValueConvertible {
    var x: Double
    var y: Double
}

// Converting a value throws if it can't be represented (e.g. `UInt64.max`)
try storage.accept(Position(x: 1, y: 2), for: ["robot", "position"])
let position = await storage.currentValue(for: ["robot", "position"], as: Position.self)

// Typed nodes only accept and return values of a single type
let mode = storage.valueNode(at: ["robot", "mode"], as: Mode.self)
try mode.set(.active)
let current = await mode.value() // Mode?
```

Literals can be used wherever a `Value` is expected, e.g. `storage.accept(123, for: ["my", "value"])`.

### Storing Swift types as trees

While `ValueConvertible` types are stored as a single value, types conforming to `SampleTreeConvertible`
are spread over a tree, so that other components can read and subscribe to individual parts.
`Codable` types only need to declare the conformance: keyed properties become child nodes,
and all other values (including lists) are stored at their node.
`ValueConvertible` types are stored as a single value at the root node.

```swift
struct Robot: Codable, SampleTreeConvertible {
    var name: String       // Stored at ["robot", "name"]
    var position: Position // Stored at ["robot", "position", "x"] and ["robot", "position", "y"]
}

try storage.accept(tree: Robot(name: "R2", position: .init(x: 1, y: 2)), for: ["robot"])
let robot = await storage.currentTree(for: ["robot"], as: Robot.self)

// Updates to individual nodes are reflected in the converted value
storage.accept(5.0, for: ["robot", "position", "y"])

// Tree nodes only accept and return trees of a single type
let node = storage.treeNode(at: ["robot"], as: Robot.self)
try node.set(Robot(name: "C3PO", position: .init(x: 0, y: 0)))
let current = await node.value() // Robot?
```

Trees can also be sent directly using `Message.tree(_:for:)`.

### Connecting two components over a network

The core library lets you expose a local component over a connection and use a remote
component as if it were local. The pattern below works with any transport that satisfies the
public [`Connection`](Sources/Soil/Transport/Connection.swift) /
[`FrameConnection`](Sources/Soil/Framing/FrameConnection.swift) protocol — you supply the
bytes, and this package handles the framing and messaging on top.

The two building blocks are:

- `Hosted*` — wraps a local component so it can be used by a remote peer.
- `Remote*` — wraps a remote connection and exposes it like a local component.

A raw byte stream can be promoted straight to a message connection by applying both
framing and encoding in one step, via `apply(framing:encoding:)`. The two building blocks
are:

```swift
import Soil

// `transport` is any StreamConnection your transport supplies (e.g. a socket).
let hostConnection: any StreamConnection = /* your socket */
let clientConnection: any StreamConnection = /* your socket */

// --- Host side: publish local data over the connection ---
let host = await hostConnection.apply(framing: SyncByteLengthFraming(), encoding: JsonEncoding())
await HostedStorage(hosting: InMemoryStorage(), through: host)

// --- Client side: use the remote as if it were local ---
let client = await clientConnection.apply(framing: SyncByteLengthFraming(), encoding: JsonEncoding())
let remoteStorage = await RemoteStorage(connection: client)

// Send data from the host side, then read it back from the client side
let now = Timestamp.current()
let path: Path = ["a", "b"]
await host.accept(.integer(123), for: path, at: now).wait()
let sample = await remoteStorage.currentSample(for: path)
// sample.value == .integer(123)
```

> **Note:** The concrete socket/websocket wiring that produces a `StreamConnection` is **not**
> bundled in this core package yet. Provide your own transport (any type conforming to
> `StreamConnection`), or adapt an existing byte stream to that protocol.

For observable components (where a client subscribes to changes rather than polling), use
`HostedObservableStorage` together with `RemoteObservableStorage`:

```swift
let remoteStorage = ObservingStorage(wrapping: InMemoryStorage())
let localConnectionToRemote = await connection.two
    .apply(framing: SyncByteLengthFraming())
    .apply(encoding: JsonEncoding())
let client = await RemoteObservableStorage(connection: localConnectionToRemote)

// Subscribe to a path; updates will be pushed to `localStorage`
let localStorage = InMemoryStorage()
await client.setReceiver(localStorage).wait()
await client.include(["a", "b"], depth: 0).wait()
```

### Decoding and framing

Transport is layered. A raw `Connection` carries bytes, which can be:

1. **Framed** with `apply(framing:)` to split a byte stream into framed messages
   (e.g. `SyncByteLengthFraming`).
2. **Decoded** with `apply(encoding:)` to turn frames into `Message` values
   (e.g. `JsonEncoding` or `CompactJsonEncoding`).

The lower-level `DecodedConnection(wrapping:encoding:)` convenience combines both steps.

## Development

```sh
swift build   # compile the library
swift test    # run the test suite
```

## Copyright and license

### Copyright

SOIL Core Implementation in Swift (soil-core-swift)

Copyright 2026 DLR - Deutsches Zentrum für Luft- und Raumfahrt e.V.

This product was developed at DLR - GSOC (German Space Operations Center at the German Aerospace Center DLR, https://www.dlr.de/).

### License

This repository is provided under the [MIT license](LICENSE.txt).

## Contributing

Contributions to this project are welcome.
You may open issues, fix or expand documentation, provide new functionality or create more and better tests.
If you have a minor contribution you can open a pull request right away.
For any major contribution please open an issue first or discuss with the repository maintainer.
Please also note that you need to fill out and sign a [contributor license agreement](SOIL%20Individual%20Contributor%20Agreement.pdf).
