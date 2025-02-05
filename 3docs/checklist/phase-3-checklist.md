# Phase 3 Dream Recording Core Checklist

## Firestore Dream Structure
- [x] Design Firestore dream collection schema
  - [x] Basic dream structure (id, title, transcript, recorded_date, dream_date)
  - [x] Future-proof schema for potential features (tags, categories)
  - [x] Support for multiple dreams per day
- [x] Create dream management service
- [x] Set up offline support with SwiftData

## Time & Date Management
- [x] Implement local timezone-based system
  - [x] Set up proper date handling
  - [x] Store both recording time and dream date
  - [x] Add timezone awareness to date operations
- [x] Create date modification functionality
  - [x] Allow users to adjust dream date
  - [x] Validate date selections
  - [x] Handle date-based organization

## Calendar Integration
- [x] Design and implement calendar view
  - [x] Show days with recorded dreams
  - [x] Support multiple dreams per day
  - [x] Display streak visualization
- [x] Implement dream browsing by date
  - [x] Create day/week/month views
  - [x] Add quick navigation features
  - [x] Link to library view for date filtering
- [x] Create streak tracking system
  - [x] Track days with at least one dream
  - [x] Visualize recording streaks
  - [x] Handle date changes properly

## Morning Notification System
- [x] Configure APN (Apple Push Notification) certificates
- [x] Implement morning reminder notification
- [x] Create notification settings UI
- [x] Respect device notification settings
- [x] Create engaging notification content
- [x] Handle notification permissions

## Home Screen Implementation
- [x] Design and implement home screen UI
  - [x] Display recent dreams
  - [x] Show calendar/streak visualization
  - [x] Add quick record button
  - [x] Add dream library access
- [PROGRESS] Create dream entry flow
  - [PROGRESS] Video capture and selection
    - [x] Implement camera recording (front/back)
    - [x] Add 3-minute time limit
    - [x] Allow video library selection
    - [x] Add recording preview
    - [x] Support retaking/reselecting
  - [PROGRESS] Video processing
    - [x] Add timeline visualization
    - [x] Preview trimmed content
    - [x] Implement trimming interface
    - [x] Handle video compression
  - [PROGRESS] Dream details entry
    - [x] Auto-transcribe video content
    - [x] Pre-fill current date
    - [x] Allow editing title/transcript/date
    - [x] Validate input fields
  - [PROGRESS] Upload handling
    - [x] Save locally first
    - [x] Upload in background
    - [x] Show upload progress
    - [x] Handle upload errors

## Data Synchronization
- [x] Implement SwiftData-Firestore sync for dreams
- [x] Create caching system for offline access
- [x] Handle dream state persistence
- [x] Implement conflict resolution

---

## Warnings and Considerations
- ⚠️ Ensure proper handling of timezone changes
- ⚠️ Plan for scalability in dream storage
- ⚠️ Consider offline-first approach for morning recordings
- ⚠️ Handle video storage efficiently
- ⚠️ Build flexible dream schema to support future features
- ⚠️ Consider privacy implications of dream content
- ⚠️ Ensure proper error handling for failed uploads
- ⚠️ Test calendar view with various amounts of data 