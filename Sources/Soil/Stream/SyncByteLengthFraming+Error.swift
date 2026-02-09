

extension SyncByteLengthFraming {

    /**
    An error occuring during framing of a message for the stream.
    */
    public enum FramingError: Error {

        /// The message is too large to fit in a frame
        case payloadTooLarge
    }
}
