# Phase 6 Sharing & Watermark Checklist

## Considerations (Require Decisions)
- [ ] Determine maximum export resolution requirements
- [ ] Decide on video quality options for export
- [ ] Finalize aspect ratio requirements (likely 16:9)
- [ ] Research OpenShot integration requirements
- [ ] Determine video caching strategy for processed videos
- [ ] Choose watermark opacity levels

## Watermark Implementation
- [ ] Set up watermark asset system
  - [ ] Import and validate watermark assets (SVG/PNG)
  - [ ] Create text overlay system for prompts
  - [ ] Implement streak counter overlay
- [ ] Create watermark positioning system
  - [ ] Implement top/bottom position options
  - [ ] Handle different video dimensions
  - [ ] Create preview system for positioning
- [ ] Implement local watermark processing
  - [ ] Create video composition pipeline
  - [ ] Handle OpenShot integration
  - [ ] Implement progress tracking

## Video Preview System
- [ ] Create preview interface
  - [ ] Implement video player with watermark overlay
  - [ ] Add position adjustment controls
  - [ ] Show loading state for uploaded videos
- [ ] Implement preview controls
  - [ ] Add play/pause functionality
  - [ ] Create scrubbing interface
  - [ ] Add cancel option

## Export System
- [ ] Implement video export pipeline
  - [ ] Create export queue management
  - [ ] Handle aspect ratio conversion
  - [ ] Implement cancel functionality
- [ ] Create export error handling
  - [ ] Design error messaging
  - [ ] Implement state restoration
  - [ ] Add retry functionality

## Sharing Implementation
- [ ] Set up iOS share sheet integration
  - [ ] Configure supported activity types
  - [ ] Add default "Ichiwabi {number}" text
  - [ ] Handle share completion/failure
- [ ] Implement share analytics
  - [ ] Track successful shares
  - [ ] Log share destinations if possible
  - [ ] Monitor share failures

---

## Warnings and Considerations
- ⚠️ OpenShot integration complexity may impact timeline
- ⚠️ Local processing may be resource-intensive
- ⚠️ Test watermark rendering on various video resolutions
- ⚠️ Consider memory usage during video processing
- ⚠️ Ensure proper cleanup of temporary export files
- ⚠️ Handle share sheet permissions appropriately
- ⚠️ Test export cancellation thoroughly
- ⚠️ Monitor processing time for different video lengths
- ⚠️ Consider storage impact of video processing 