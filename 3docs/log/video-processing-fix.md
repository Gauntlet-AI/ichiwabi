# Video Processing Fix - Error -17390

## Issue
The video processing was failing with error code -17390 (AVFoundation composition error) when trying to combine video, audio, and watermark in a single step.

## Root Cause
The error occurred because we were trying to do too many composition operations simultaneously:
1. Combining video and audio tracks
2. Applying watermark
3. Managing multiple AVComposition objects at once

This was causing AVFoundation to fail with a composition error, likely due to resource constraints or timing issues between the different composition layers.

## Solution
We restructured the video processing to happen in distinct, sequential steps:

1. STEP 1: Basic Video/Audio Composition
```swift
// Create base composition
let composition = AVMutableComposition()

// Add tracks one at a time with error checking
guard let compositionVideoTrack = composition.addMutableTrack(
    withMediaType: .video,
    preferredTrackID: kCMPersistentTrackID_Invalid
) else {
    throw VideoProcessingError.invalidAsset
}

// Add audio and loop video separately
try compositionAudioTrack.insertTimeRange(audioTimeRange, of: sourceAudioTrack, at: .zero)
// Loop video to match audio duration
while currentTime < audioTimeRange.duration {
    let remainingTime = audioTimeRange.duration - currentTime
    let insertDuration = min(remainingTime, videoDuration)
    try compositionVideoTrack.insertTimeRange(
        CMTimeRange(start: .zero, duration: insertDuration),
        of: sourceVideoTrack,
        at: currentTime
    )
    currentTime = CMTimeAdd(currentTime, insertDuration)
}
```

2. STEP 2: Export to Intermediate File
```swift
// Export the basic composition to an intermediate file
let intermediateURL = FileManager.default.temporaryDirectory
    .appendingPathComponent("intermediate_\(UUID().uuidString).mp4")

guard let exportSession = AVAssetExportSession(
    asset: composition,
    presetName: AVAssetExportPreset1280x720
) else {
    throw VideoProcessingError.exportSessionCreationFailed
}

// Use conservative settings
exportSession.outputURL = intermediateURL
exportSession.outputFileType = .mp4
exportSession.shouldOptimizeForNetworkUse = true
exportSession.audioTimePitchAlgorithm = .lowQualityZeroLatency
```

3. STEP 3: Add Watermark
```swift
// Create a new composition just for the watermark
let intermediateAsset = AVAsset(url: intermediateURL)
let watermarkComposition = try await watermarkService.applyWatermark(
    to: intermediateAsset,
    date: Date(),
    title: title
)

// Export final version with watermark
guard let finalExportSession = AVAssetExportSession(
    asset: intermediateAsset,
    presetName: AVAssetExportPreset1280x720
) else {
    throw VideoProcessingError.exportSessionCreationFailed
}

finalExportSession.videoComposition = watermarkComposition
```

## Key Changes
1. Separated complex operations into distinct steps
2. Used intermediate file to avoid composition conflicts
3. Added detailed error logging at each step
4. Used more conservative export settings
5. Fixed CMTime addition using `CMTimeAdd` instead of `+=`

## Results
- The video processing now completes successfully
- Each step can be monitored independently
- Error messages are more specific and actionable
- Resource usage is more predictable

## Notes for Future
- Keep video processing steps separate and sequential
- Use intermediate files for complex compositions
- Monitor system resource usage
- Add cleanup of temporary files
- Consider adding progress monitoring for each step 