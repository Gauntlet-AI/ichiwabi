# Audio Recording and Video Generation Workflow Checklist

## Considerations
[x] Decide on whether to allow editing of transcribed text
[x] Decide on whether to allow editing of generated title
[x] Determine storage location for base video file
[x] Choose video processing approach (pre-process vs real-time playback)
[x] Decide on audio storage strategy (separate vs. extraction from video) - Store separately in Firebase
[x] Determine video compression/optimization requirements - Implement if quality maintained
[x] Define local caching strategy for dreams - Cache 10 most recent dreams
[x] Confirm style-specific base videos in Assets catalog

## Implementation Tasks

### Audio Recording and Transcription
[x] Implement audio recording UI with waveform visualization
[x] Add audio recording service with pause/resume functionality
[x] Add audio playback functionality
[x] Implement audio level monitoring and visualization
[x] Integrate with /transcribe-speech API endpoint
[x] Add loading state for transcription process
[x] Add text editing capability for transcription
- [ ] Store transcribed text in dreamDescription
- [ ] Implement audio file upload to Firebase Storage

### Title Generation
[x] Integrate with /generate-title API endpoint
[x] Add loading state for title generation
[x] Store generated title in Dream object
[x] Add title editing capability

### Video Processing
[x] Add base video files to Assets.xcassets:
  [x] DreamBaseImageRealistic.mp4
  [x] DreamBaseImageAnimated.mp4
  [x] DreamBaseImageCursed.mp4
[x] Create video asset loading utility with style support
[x] Implement video processing service
  [x] Add audio overlay functionality
  [x] Implement style-based video selection
  [x] Handle video duration synchronization
[x] Add video compression/optimization (quality-dependent)
[PROGRESS] Implement video upload to Firebase Storage
- [ ] Add preview functionality before saving

### Database and Storage
[x] Update Dream model with new fields:
  [x] Audio URL (Firebase Storage)
  [x] Video URL (Firebase Storage)
  [x] Processing status
  [x] Last modified date
  [x] Cache status
[PROGRESS] Implement Firebase Storage service
  [PROGRESS] Audio upload/download
  [PROGRESS] Video upload/download
- [ ] Update SwiftData schema
- [ ] Implement local caching system (10 most recent dreams)
- [ ] Add cleanup logic for temporary files
- [ ] Update DreamSyncService for new storage requirements

### UI/UX
- [ ] Design loading states for all async operations:
  - [ ] Transcription
  - [ ] Title generation
  - [ ] Video processing
  - [ ] Upload progress
- [ ] Create preview screen for final video with audio
- [ ] Add progress indicators for all processing steps
- [ ] Implement error handling and user feedback
- [ ] Design confirmation flow before saving
- [ ] Add edit capabilities for text fields

## Warnings
1. Video processing may be resource-intensive and impact app performance
2. Need to consider storage space for processed videos
3. Network connectivity required for API calls
4. Long audio recordings may result in longer processing times
5. Need to handle API rate limits and timeouts
6. Firebase Storage costs may increase with audio/video storage
7. Consider implementing retry logic for failed uploads 