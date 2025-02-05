# Phase 6 Sharing & Watermark Checklist

## Considerations (Require Decisions)
- [ ] Determine optimal export quality settings for social sharing
- [ ] Define exact 16:9 conversion strategy for different input ratios
- [ ] Finalize watermark design specifications

## Watermark Implementation
- [ ] Set up watermark system
  - [ ] Integrate provided watermark design
  - [ ] Add dynamic elements (dream number, date)
  - [ ] Create top/bottom position toggle
  - [ ] Handle 16:9 positioning properly
- [ ] Implement numbering system
  - [ ] Create dream counter mechanism
  - [ ] Ensure consistent numbering across devices
  - [ ] Handle offline number reservation

## Video Processing
- [ ] Implement aspect ratio conversion
  - [ ] Create 16:9 transformation pipeline
  - [ ] Handle different input ratios gracefully
  - [ ] Implement content-aware positioning
- [ ] Set up video export pipeline
  - [ ] Configure standardized export quality
  - [ ] Optimize processing speed
  - [ ] Handle memory efficiently during processing

## Preview System
- [ ] Create preview interface
  - [ ] Show video with watermark
  - [ ] Display dream title and date
  - [ ] Show position toggle for watermark
  - [ ] Add loading indicators
- [ ] Implement preview playback
  - [ ] Add basic video controls
  - [ ] Handle different video states
  - [ ] Show final aspect ratio correctly

## Sharing Implementation
- [ ] Set up iOS share sheet integration
  - [ ] Configure supported platforms
  - [ ] Add default "Dream #{number}" text
  - [ ] Handle share completion/failure
- [ ] Create sharing pipeline
  - [ ] Implement background export
  - [ ] Handle large file sizes
  - [ ] Add progress indicators
- [ ] Implement error handling
  - [ ] Create user-friendly error messages
  - [ ] Add retry mechanisms
  - [ ] Handle offline scenarios

## Performance Optimization
- [ ] Optimize processing pipeline
  - [ ] Implement efficient video processing
  - [ ] Optimize memory usage
  - [ ] Add processing queue management
- [ ] Add caching system
  - [ ] Cache processed videos temporarily
  - [ ] Implement cleanup strategy
  - [ ] Handle storage limitations

---

## Warnings and Considerations
- ⚠️ Video processing for 16:9 may affect original framing
- ⚠️ Watermark processing may be resource-intensive
- ⚠️ Dream numbering must be reliable across offline/online states
- ⚠️ Export quality vs file size trade-offs need testing
- ⚠️ Memory usage during video processing needs monitoring
- ⚠️ Consider temporary storage needs for processed videos
- ⚠️ Ensure consistent watermark visibility across different video content
- ⚠️ Handle share sheet failures gracefully 