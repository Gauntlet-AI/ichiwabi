# Phase 1 Setup Checklist

## Considerations
- [x] Decide on minimum iOS version to support (suggestion: iOS 17.0 for SwiftData support)

## Repository & Environment Setup
- [PROGRESS] Create new GitHub repository for ichiwabi
- [x] Initialize Xcode project with SwiftUI
- [x] Configure .gitignore for Xcode and Swift
- [ ] Set up initial README.md with project description
- [ ] Configure GitHub repository settings (main branch protection)
- [x] Set up Cursor editor configurations
- [ ] Test Git integration in both Xcode and Cursor

## Xcode Project Configuration
- [PROGRESS] Configure basic project settings (deployment target, device support)
- [PROGRESS] Set up project organization structure (Views, Models, Services directories)
- [ ] Configure SwiftUI preview settings
- [ ] Set up basic app icon placeholder
- [ ] Configure basic launch screen

## Dependencies Setup
- [ ] Initialize Swift Package Manager
- [ ] Add Firebase SDK via SPM
  - [ ] Firebase/Auth
  - [ ] Firebase/Firestore
- [ ] Set up SwiftData basic configuration
- [ ] Create initial Firebase project in Firebase Console
- [ ] Download and integrate GoogleService-Info.plist
- [ ] Configure Firebase in AppDelegate/App initialization

## Initial Data Structure Setup
- [ ] Create basic SwiftData models
  - [ ] User model
    - [ ] Define core user properties (id, name, catchphrase, etc.)
    - [ ] Plan for authentication metadata storage
  - [ ] Prompt model
    - [ ] Define prompt properties (id, text, date, status)
    - [ ] Plan for future extensibility (categories, user-generated)
  - [ ] Video/Response model
    - [ ] Define video metadata structure
    - [ ] Plan storage strategy for video content
- [ ] Set up Firestore basic collections structure
  - [ ] Design users collection schema
  - [ ] Design prompts collection schema
  - [ ] Design responses/videos collection schema
  - [ ] Plan collection access rules
- [ ] Implement basic SwiftData-Firestore sync architecture
  - [ ] Define sync strategy (immediate vs. batch)
  - [ ] Plan offline capabilities
  - [ ] Create basic sync service structure

## Basic Project Documentation
- [ ] Create documentation structure in project
- [ ] Document development environment setup steps
- [ ] Document build and run instructions
- [ ] Create architecture decision log

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