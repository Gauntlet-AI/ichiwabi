# Phase 1 Setup Checklist

## Considerations
- [x] Decide on minimum iOS version to support (suggestion: iOS 17.0 for SwiftData support)

## Repository & Environment Setup
- [x] Create new GitHub repository for ichiwabi
- [x] Initialize Xcode project with SwiftUI
- [x] Configure .gitignore for Xcode and Swift
- [ ] Configure GitHub repository settings (main branch protection)
- [x] Set up Cursor editor configurations
- [x] Test Git integration in both Xcode and Cursor

## Xcode Project Configuration
- [x] Configure basic project settings (deployment target, device support)
- [x] Set up project organization structure (Views, Models, Services directories)
- [x] Configure SwiftUI preview settings
- [x] Set up basic app icon placeholder
- [x] Configure basic launch screen

## Dependencies Setup
- [x] Initialize Swift Package Manager
- [x] Add Firebase SDK via SPM
  - [x] Firebase/Auth
  - [x] Firebase/Firestore
- [x] Set up SwiftData basic configuration
- [x] Create initial Firebase project in Firebase Console
- [x] Download and integrate GoogleService-Info.plist
- [x] Configure Firebase in AppDelegate/App initialization

## Initial Data Structure Setup
- [x] Create basic SwiftData models
  - [x] User model
    - [x] Define core user properties (id, name, catchphrase, etc.)
    - [x] Plan for authentication metadata storage
  - [x] Prompt model
    - [x] Define prompt properties (id, text, date, status)
    - [x] Plan for future extensibility (categories, user-generated)
  - [x] Video/Response model
    - [x] Define video metadata structure
    - [x] Plan storage strategy for video content
  - [x] Additional models (Comment, Notification, Settings, Report)
- [x] Set up Firestore basic collections structure
  - [x] Design users collection schema
  - [x] Design prompts collection schema
  - [x] Design responses/videos collection schema
  - [x] Plan collection access rules
- [x] Implement basic SwiftData-Firestore sync architecture
  - [x] Define sync strategy (immediate vs. batch)
    - [x] Implement BaseSyncService with generic sync operations
    - [x] Add offline support with pending changes tracking
    - [x] Implement conflict detection and resolution
  - [x] Plan offline capabilities
    - [x] Add network monitoring
    - [x] Implement pending changes queue
    - [x] Add automatic sync on network restore
  - [x] Create basic sync service structure
    - [x] Implement SyncableModel protocol
    - [x] Create model-specific sync services (UserSyncService)
    - [x] Add comprehensive test suite with SyncTestService
    - [x] Integrate test UI into app navigation

## Basic Project Documentation
- [x] Create documentation structure in project
  - [x] Implementation log in 3docs/log
  - [x] Setup guide in 3docs/important
- [x] Document development environment setup steps
- [x] Document build and run instructions
- [x] Create architecture decision log


---

## Warnings and Considerations
- ⚠️ Some of this will require more of a walkthrough of what to do in XCode, so be aware and prompt me accordingly
- ⚠️ Ensure Firebase free tier limitations are understood before proceeding
- ⚠️ SwiftData is relatively new - may encounter unexpected issues during implementation
- ⚠️ Consider implementing proper error handling from the start
- ⚠️ Make sure to never commit GoogleService-Info.plist to version control
- ⚠️ Test Git workflow in both Cursor and Xcode to avoid potential conflicts
- ⚠️ Ensure data model supports future features like user-generated prompts
- ⚠️ Consider data migration strategy for future schema updates
- ⚠️ Plan for scalability in Firestore collection design 