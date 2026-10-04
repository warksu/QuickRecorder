import CoreMedia

struct RecordingTimeline {
    private(set) var sessionStart: CMTime?
    private(set) var offset: CMTime = .zero
    private(set) var isPaused = false
    private var pauseTime: CMTime?
    private var minimumSourceTime: CMTime?

    mutating func begin(at time: CMTime) -> Bool {
        guard sessionStart == nil, accepts(time) else { return false }
        sessionStart = CMTimeSubtract(time, offset)
        return true
    }

    mutating func pause(at time: CMTime) {
        guard !isPaused, time.isNumeric else { return }
        pauseTime = time
        isPaused = true
    }

    mutating func resume(at time: CMTime) {
        guard let pauseTime = pauseTime, time.isNumeric,
              CMTimeCompare(time, pauseTime) >= 0 else { return }
        offset = CMTimeAdd(offset, CMTimeSubtract(time, pauseTime))
        minimumSourceTime = time
        self.pauseTime = nil
        isPaused = false
    }

    func presentationTime(for time: CMTime) -> CMTime? {
        guard let sessionStart = sessionStart, accepts(time) else { return nil }
        let adjusted = CMTimeSubtract(time, offset)
        guard CMTimeCompare(adjusted, sessionStart) >= 0 else { return nil }
        return adjusted
    }

    private func accepts(_ time: CMTime) -> Bool {
        guard !isPaused, time.isNumeric else { return false }
        if let minimumSourceTime = minimumSourceTime {
            return CMTimeCompare(time, minimumSourceTime) >= 0
        }
        return true
    }

    static func adjusting(_ sample: CMSampleBuffer, by offset: CMTime) -> CMSampleBuffer? {
        guard CMSampleBufferGetFormatDescription(sample) != nil else { return nil }
        var count = 0
        guard CMSampleBufferGetSampleTimingInfoArray(sample, entryCount: 0,
            arrayToFill: nil, entriesNeededOut: &count) == noErr, count > 0 else { return nil }
        var timing = [CMSampleTimingInfo](repeating: CMSampleTimingInfo(), count: count)
        guard CMSampleBufferGetSampleTimingInfoArray(sample, entryCount: count,
            arrayToFill: &timing, entriesNeededOut: nil) == noErr else { return nil }
        for index in timing.indices {
            if timing[index].presentationTimeStamp.isNumeric {
                timing[index].presentationTimeStamp = CMTimeSubtract(timing[index].presentationTimeStamp, offset)
            }
            if timing[index].decodeTimeStamp.isNumeric {
                timing[index].decodeTimeStamp = CMTimeSubtract(timing[index].decodeTimeStamp, offset)
            }
        }
        var adjusted: CMSampleBuffer?
        guard CMSampleBufferCreateCopyWithNewTiming(allocator: nil, sampleBuffer: sample,
            sampleTimingEntryCount: count, sampleTimingArray: &timing,
            sampleBufferOut: &adjusted) == noErr else { return nil }
        return adjusted
    }
}
