# SOIL (States/Outputs/Inputs/Logic)

This package contains an implementation of the SOIL core framework written in [Swift](https://swift.org).
It provides the definitions, protocols and commonly used functions to build SOIL components.

For more information about the concepts, see the [SOIL documentation repository](https://gitlab.gsoc.dlr.de/gitlab/rb/mit/mcs/luna/soil/soil-documentation).

This core library provides:
- Message definitions for the transport layer
- Definitions of primitives like values, paths, and samples
- Storage interface definitions, and an in-memory database
- Components to track subscriptions (both from external components and code)
- Request tracking
- Access control interfaces
- Transport layer definitions and encoding interfaces
- Interfaces to connect to different remote components
- Interfaces to expose local components over connections

## Usage

It's incredibly easy to get started using SOIL.
To create a very simple component that connects to a WebSocket interface to send data:

```swift
let socket = await WebSocket(url: "192.168.1.32", port: 80)
    .apply(encoding: JsonEncoding())

connection.accept(.integer(123), for: ["my", "value"])
```
