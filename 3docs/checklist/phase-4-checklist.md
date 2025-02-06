# Phase 4 Video Creation & Processing Checklist

## Considerations (Require Decisions)
- [x] Determine minimum supported iOS version
  - Decided: iOS 17+
- [x] Research and document device compatibility requirements
  - Support all devices capable of running iOS 17
  - iPhone XS and newer
  - iPad Pro (3rd gen) and newer
  - iPad Air (3rd gen) and newer
  - iPad mini (5th gen) and newer
- [x] Evaluate local caching strategies
  - [x] Document storage implications
    - Use FileManager.default.documentDirectory for persistent storage
    - Use FileManager.default.temporaryDirectory for recording
    - Organize videos in dreams/{userId} directory structure
    - Keep local copies of uploaded videos for offline access
    - Implement cleanup of temporary files after successful upload
  - [x] Consider user experience impact
    - Save recordings locally before upload for instant playback
    - Implement background upload with progress tracking
    - Cache downloaded videos for offline viewing
    - Clear cache when storage pressure is high
- [x] Document compression trade-offs
  - [x] Quality vs file size
    - High Quality (1920x1080)
      - Best visual quality
      - ~8 Mbps maximum bitrate
      - Larger storage costs
      - Longer upload times
    - Medium Quality (1280x720) - RECOMMENDED DEFAULT
      - Good balance of quality and size
      - ~5.6 Mbps maximum bitrate (70% of high)
      - Suitable for most mobile viewing
      - Reasonable storage costs
    - Low Quality (960x540)
      - Smallest file size
      - ~4 Mbps maximum bitrate (50% of high)
      - Faster uploads
      - May appear pixelated on larger screens
  - [x] Processing time impact
    - High quality requires more processing time
    - Medium quality provides optimal processing speed
    - Low quality processes fastest but may require re-encoding
    - All qualities use hardware acceleration when available
- [x] Configure video parameters
  - [x] Set initial 180-second maximum duration (configurable)
  - [x] Define video quality requirements
    - Default to 720p (medium quality)
    - Allow user selection of quality level
    - Optimize bitrate based on content
  - [ ] Plan AI video generation integration

## Video Recording Implementation
- [PROGRESS] Set up AVFoundation camera configuration
  - [x] Implement configurable maximum duration (initial: 180 seconds)
  - [x] Configure front and back camera support
  - [x] Add camera switching functionality
  - [x] Add low-light mode
    - [x] Implement native iOS low-light boost
    - [x] Add custom exposure and ISO controls
    - [x] Add white balance optimization
  - [x] Implement notification-based quick-start recording
- [PROGRESS] Create dream entry options
  - [x] Add video recording flow
  - [x] Implement text-only dream entry
- [PROGRESS] Implement recording UI
  - [x] Create recording timer display
  - [x] Add camera switch button
  - [x] Add low-light mode toggle
  - [x] Design upload option UI
  - [x] Create text-only entry interface

## Basic Video Editing
- [PROGRESS] Implement video trimming
  - [x] Create trim UI with preview
  - [x] Handle trim operations within 180-second limit
- [x] Add re-record functionality
  - [x] Handle state management for recording flow
  - [x] Implement discard and restart option

## Video Processing
- [ ] Implement watermark system
  - [ ] Integrate provided watermark design
  - [ ] Add dream date to watermark
  - [ ] Handle different video dimensions
- [x] Set up video compression
  - [x] Research optimal compression settings
  - [x] Implement compression pipeline

## Storage & Upload
- [x] Configure Firebase Storage
  - [x] Set up storage rules for both video and text entries
  - [x] Create upload service
  - [x] Implement background upload support
- [x] Implement upload progress tracking
  - [x] Create progress UI
  - [x] Add network status monitoring
  - [x] Implement retry mechanism
- [x] Handle upload failures
  - [x] Create error messaging system
  - [x] Implement state restoration on failure
  - [x] Add offline queue management

## Video Quality & Performance
- [ ] Implement video quality settings
  - [ ] Add quality selection UI
  - [ ] Handle quality changes during recording
  - [ ] Save quality preferences
- [ ] Add performance monitoring
  - [ ] Track recording metrics
  - [ ] Monitor memory usage
  - [ ] Log performance data
- [ ] Optimize resource usage
  - [ ] Implement cleanup routines
  - [ ] Handle memory warnings
  - [ ] Cache management

---

## Warnings and Considerations
- ⚠️ AVFoundation implementation may vary across iOS versions
- ⚠️ OpenShot integration decision will significantly impact architecture
- ⚠️ Video processing can be resource-intensive - need to consider older devices
- ⚠️ Firebase Storage costs will scale with video size and user count
- ⚠️ Need to handle interrupted uploads gracefully
- ⚠️ Consider privacy permissions (camera, photo library)
- ⚠️ Test recording in low-light conditions with native iOS capabilities
- ⚠️ Ensure proper memory management during video processing
- ⚠️ Design notification-based recording to be reliable and quick
- ⚠️ Plan storage structure to support both video and text-only entries
- ⚠️ Monitor and optimize battery usage during recording
- ⚠️ Implement proper error recovery for failed recordings 