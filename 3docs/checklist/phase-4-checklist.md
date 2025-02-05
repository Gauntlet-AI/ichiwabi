# Phase 4 Video Creation & Processing Checklist

## Considerations (Require Decisions)
- [ ] Determine minimum supported iOS version
- [ ] Research and document device compatibility requirements
- [ ] Evaluate local caching strategies
  - [ ] Document storage implications
  - [ ] Consider user experience impact
- [ ] Document compression trade-offs
  - [ ] Quality vs file size
  - [ ] Processing time impact
- [ ] Configure video parameters
  - [ ] Set initial 64-second maximum duration (configurable)
  - [ ] Define video quality requirements
  - [ ] Plan AI video generation integration

## Video Recording Implementation
- [ ] Set up AVFoundation camera configuration
  - [ ] Implement configurable maximum duration (initial: 64 seconds)
  - [ ] Configure front and back camera support
  - [ ] Add camera switching functionality
  - [ ] Add manual low-light mode (Amazon integration)
  - [ ] Implement notification-based quick-start recording
- [ ] Create dream entry options
  - [ ] Add video recording flow
  - [ ] Implement text-only dream entry
  - [ ] Add UI indicators encouraging video recording
  - [ ] Prepare for AI video generation integration
- [ ] Implement recording UI
  - [ ] Create recording timer display
  - [ ] Add camera switch button
  - [ ] Add low-light mode toggle
  - [ ] Design upload option UI
  - [ ] Create text-only entry interface

## Basic Video Editing
- [ ] Implement video trimming
  - [ ] Create trim UI with preview
  - [ ] Handle trim operations within 64-second limit
- [ ] Create video cutting functionality
  - [ ] Design cut UI with preview
  - [ ] Implement cut operations
- [ ] Add re-record functionality
  - [ ] Handle state management for recording flow
  - [ ] Implement discard and restart option
- [ ] Add basic filters
  - [ ] Integrate Amazon's low-light enhancement
  - [ ] Add dream-appropriate visual effects

## Video Processing
- [ ] Research and document OpenShot integration options
  - [ ] Compare on-device vs cloud processing
  - [ ] Document processing requirements
- [ ] Implement watermark system
  - [ ] Integrate provided watermark design
  - [ ] Add dream date to watermark
  - [ ] Handle different video dimensions
- [ ] Set up video compression
  - [ ] Research optimal compression settings
  - [ ] Implement compression pipeline

## Storage & Upload
- [ ] Configure Firebase Storage
  - [ ] Set up storage rules for both video and text entries
  - [ ] Create upload service
  - [ ] Implement background upload support
- [ ] Implement upload progress tracking
  - [ ] Create progress UI
  - [ ] Add network status monitoring
  - [ ] Implement retry mechanism
- [ ] Handle upload failures
  - [ ] Create error messaging system
  - [ ] Implement state restoration on failure
  - [ ] Add offline queue management

---

## Warnings and Considerations
- ⚠️ AVFoundation implementation may vary across iOS versions
- ⚠️ OpenShot integration decision will significantly impact architecture
- ⚠️ Video processing can be resource-intensive - need to consider older devices
- ⚠️ Firebase Storage costs will scale with video size and user count
- ⚠️ Need to handle interrupted uploads gracefully
- ⚠️ Consider privacy permissions (camera, photo library)
- ⚠️ Test recording in low-light conditions with Amazon solution
- ⚠️ Ensure proper memory management during video processing
- ⚠️ Design notification-based recording to be reliable and quick
- ⚠️ Plan storage structure to support both video and text-only entries
- ⚠️ Prepare video processing pipeline for future AI integration 