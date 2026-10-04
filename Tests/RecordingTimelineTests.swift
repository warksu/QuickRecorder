import CoreMedia
import Foundation
import AudioToolbox
#if !AUDIO_TIMELINE_STANDALONE
import XCTest
#endif

struct RecordingTimelineChecks {
    static func time(_ seconds: Double) -> CMTime {
        CMTime(seconds: seconds, preferredTimescale: 48_000)
    }

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
#if AUDIO_TIMELINE_STANDALONE
        if !condition() {
            fputs("FAIL: \(message)\n", stderr)
            exit(1)
        }
#else
        XCTAssertTrue(condition(), message)
#endif
    }

    static func expectTime(_ actual: CMTime?, _ seconds: Double, _ message: String) {
        expect(actual != nil, message + " (missing timestamp)")
        if let actual = actual { expect(abs(actual.seconds - seconds) < 0.000_001, message) }
    }

    static func checkTimeline() {
        var timeline = RecordingTimeline()
        expect(timeline.presentationTime(for: time(100)) == nil,
               "audio before the writer session must be dropped")
        expect(!timeline.begin(at: .invalid), "invalid timestamps must not start a session")
        expect(timeline.begin(at: time(100)), "first valid sample must start the session")
        expect(!timeline.begin(at: time(101)), "the writer session must only start once")
        expectTime(timeline.sessionStart, 100, "session origin must remain stable")
        expectTime(timeline.presentationTime(for: time(101)), 101, "normal audio retains its time")

        timeline.pause(at: time(102))
        expect(timeline.presentationTime(for: time(103)) == nil, "paused samples must be dropped")
        timeline.resume(at: time(107))
        expectTime(timeline.presentationTime(for: time(108)), 103,
                   "resume must remove five paused seconds from every track")
        expectTime(timeline.offset, 5, "pause offset must use the host clock")

        timeline.pause(at: time(110))
        timeline.pause(at: time(111))
        timeline.resume(at: time(112))
        timeline.resume(at: time(113))
        expect(timeline.presentationTime(for: time(111)) == nil,
               "buffers captured during a pause must still be dropped after resume")
        expectTime(timeline.presentationTime(for: time(114)), 107,
                   "repeated pause and resume calls must not change accumulated pause duration")
        expect(timeline.presentationTime(for: time(99)) == nil,
               "late samples before the session must not reach the writer")
        expect(timeline.presentationTime(for: .invalid) == nil, "invalid samples must be dropped")

        timeline.pause(at: .invalid)
        expect(!timeline.isPaused, "invalid pause events must not leave capture stuck")
        timeline.pause(at: time(120))
        timeline.resume(at: time(119))
        expect(timeline.isPaused, "backwards clock events must not corrupt the timeline")
        timeline.resume(at: time(122))
        expectTime(timeline.offset, 9, "a valid resume must recover after a backwards event")
        for track in ["screen", "system audio", "microphone"] {
            expectTime(timeline.presentationTime(for: time(123)), 114,
                       "\(track) must use the same cumulative pause offset")
        }
        var earlyPause = RecordingTimeline()
        earlyPause.pause(at: time(10))
        earlyPause.resume(at: time(15))
        expect(!earlyPause.begin(at: time(14)), "a paused buffer cannot start the writer after resume")
        expect(earlyPause.begin(at: time(16)), "the first resumed frame must start the writer")
        expectTime(earlyPause.sessionStart, 11, "session start must use the adjusted clock")
        expectTime(earlyPause.presentationTime(for: time(16)), 11,
                   "pausing before the first frame must not discard resumed media")
    }

    static func checkAudioRetiming() {
        var format = AudioStreamBasicDescription(mSampleRate: 48_000,
            mFormatID: kAudioFormatLinearPCM, mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
            mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4,
            mChannelsPerFrame: 1, mBitsPerChannel: 32, mReserved: 0)
        var description: CMAudioFormatDescription?
        expect(CMAudioFormatDescriptionCreate(allocator: nil, asbd: &format,
            layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil,
            extensions: nil, formatDescriptionOut: &description) == noErr, "create PCM format")
        var buffer: CMBlockBuffer?
        expect(CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil,
            blockLength: 4_096, blockAllocator: nil, customBlockSource: nil,
            offsetToData: 0, dataLength: 4_096, flags: 0, blockBufferOut: &buffer) == noErr,
            "create a 1024-frame PCM buffer")
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 48_000),
            presentationTimeStamp: time(108), decodeTimeStamp: .invalid)
        var sampleSize = 4
        var sample: CMSampleBuffer?
        expect(CMSampleBufferCreateReady(allocator: nil, dataBuffer: buffer,
            formatDescription: description, sampleCount: 1_024,
            sampleTimingEntryCount: 1, sampleTimingArray: &timing,
            sampleSizeEntryCount: 1, sampleSizeArray: &sampleSize,
            sampleBufferOut: &sample) == noErr, "create a PCM sample with one timing entry")
        guard let sample = sample, let adjusted = RecordingTimeline.adjusting(sample, by: time(5)) else {
            expect(false, "retiming must produce an audio sample")
            return
        }
        var count = 0
        expect(CMSampleBufferGetSampleTimingInfoArray(adjusted, entryCount: 0,
            arrayToFill: nil, entriesNeededOut: &count) == noErr, "read adjusted timing")
        expect(count == 1, "audio retiming must preserve one timing entry for 1024 frames")
        expect(CMSampleBufferGetNumSamples(adjusted) == 1_024, "retiming must retain every PCM frame")
        expectTime(adjusted.presentationTimeStamp, 103, "audio timestamps must remove the pause")
        expectTime(sample.presentationTimeStamp, 108, "retiming must not mutate the original sample")
        expect(!adjusted.decodeTimeStamp.isValid, "absent decode timestamps must remain invalid")
        expectTime(adjusted.duration, 1_024.0 / 48_000, "retiming must preserve PCM duration")
    }
}

#if AUDIO_TIMELINE_STANDALONE
@main
struct RecordingTimelineRunner {
    static func main() {
        RecordingTimelineChecks.checkTimeline()
        RecordingTimelineChecks.checkAudioRetiming()
        print("PASS: session timing, pause/resume, stale samples, and 1024-frame audio retiming")
    }
}
#else
final class RecordingTimelineTests: XCTestCase {
    func testSessionPauseResumeAndStaleBuffers() { RecordingTimelineChecks.checkTimeline() }
    func testRetimingPreservesAudioFramesAndTimingEntries() { RecordingTimelineChecks.checkAudioRetiming() }
}
#endif
