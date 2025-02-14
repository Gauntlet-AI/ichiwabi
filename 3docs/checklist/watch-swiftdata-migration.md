# Watch App SwiftData Migration Checklist

## Considerations
- [x] Determine if we need to keep Firebase Auth in Watch app
- [x] Decide on sync frequency between Watch and iPhone
- [x] Plan error handling strategy for sync failures
- [x] Consider battery impact of sync operations

## Firebase Cleanup
- [x] Remove Firestore imports from WatchExtensionApp.swift
- [x] Remove Firestore from WatchFirebaseService.swift
- [x] Clean up Firebase-related services in Watch app
- [x] Update project configuration to remove unused Firebase dependencies
- [x] Simplify WatchFirebaseService to handle Auth and Storage only
- [x] Remove unnecessary VideoProcessingService
- [x] Clean up FirebaseConfiguration to only handle Storage
- [x] Remove all Firestore code from FirebaseService

## SwiftData Setup
- [x] Verify SwiftData models are properly shared between Watch and iPhone apps
- [x] Add sync status properties to Dream model
- [x] Add WatchRecordingError enum for error handling
- [x] Create Watch-specific WatchDream model
- [x] Remove unnecessary DreamVideoStyle from Watch app
- [x] Implement API service for transcription and title generation
- [x] Add proper error handling for API calls

## Data Sync Architecture
- [x] Create WatchDataSync service using Watch Connectivity
- [x] Add Watch Connectivity session monitoring
- [x] Implement pending uploads queue system
- [x] Create sync manager on iPhone side
- [ ] Implement background refresh for sync operations
- [x] Add sync status tracking system
- [x] Implement sync trigger on app launch
- [ ] Implement sync trigger on library access
- [x] Add retry mechanism for failed syncs

## iPhone-side Implementation
- [x] Create WatchSyncManager class for handling Watch data
- [x] Implement WCSessionDelegate on iPhone side
- [x] Add message handling for dream data
- [x] Add file transfer handling for audio files
- [x] Implement dream conversion from Watch to iPhone format
- [x] Add Firebase Storage upload after successful sync
- [x] Implement error recovery and retry logic
- [x] Add background processing for received Watch data
- [x] Create sync status tracking and management
- [x] Add proper error handling and user feedback

## User Interface Updates
- [x] Add sync status indicators to Watch app
- [x] Implement offline recording UI feedback
- [x] Add sync progress indicators
- [x] Create error message handling for sync failures
- [ ] Update iPhone app to show Watch data sync status
- [ ] Add Watch dream status in iPhone dream list
- [ ] Create Watch sync management UI in settings

## Testing Requirements
- [ ] Test Watch-to-iPhone sync with good connectivity
- [ ] Test Watch-to-iPhone sync with poor connectivity
- [ ] Test offline recording and delayed sync
- [ ] Verify data integrity after sync
- [ ] Test Firebase Storage upload on iPhone after sync
- [ ] Verify sync status indicators
- [ ] Test error handling scenarios
- [ ] Test API integration for transcription and title generation
- [ ] Test background sync operations

## Documentation
- [ ] Update architecture documentation with new sync flow
- [ ] Document error handling procedures
- [ ] Create troubleshooting guide for sync issues
- [ ] Update user guide with sync information
- [ ] Document API integration and error handling
- [ ] Add Watch sync troubleshooting section

**Warnings:**
- Watch app performance must be monitored closely during sync operations
- Data consistency between Watch and iPhone must be maintained
- Battery usage should be carefully considered for sync frequency
- Error handling must be robust to prevent data loss
- Audio uploads should be queued and handled when connectivity is available
- API calls should be properly rate-limited and errors handled gracefully
- Watch storage should be managed carefully with large audio files

**Considerations:**
- [x] Investigate optimal sync frequency balancing data freshness and battery life: Sync on app launch and library access
- [x] Research best practices for Watch-iPhone data sync using SwiftData
- [PROGRESS] Consider edge cases where Watch app might generate large amounts of data
- [x] Evaluate API rate limiting and error handling strategies
- [ ] Consider implementing cleanup of old Watch recordings after successful sync 