# Phase 3 Prompt & Daily Ritual Checklist

## Firestore Prompt Structure
- [ ] Design Firestore prompt collection schema
  - [ ] Basic prompt structure (id, text, date)
  - [ ] Future-proof schema for potential features (categories, user-generated prompts)
- [ ] Create initial set of prompts
- [ ] Implement prompt scheduling system
- [ ] Set up Cloud Functions for daily prompt activation

## Time Management
- [ ] Implement JST (Japan Standard Time) based system
  - [ ] Set up server-side timestamp management
  - [ ] Handle timezone conversions
- [ ] Create prompt availability window logic
  - [ ] Activate new prompts at 00:00 JST
  - [ ] Deactivate prompts after 24 hours
- [ ] Implement countdown timer functionality

## Push Notification System
- [ ] Set up Firebase Cloud Messaging
- [ ] Configure APN (Apple Push Notification) certificates
- [ ] Implement notification scheduling for 00:00 JST
- [ ] Create notification payload structure
- [ ] Handle notification permissions
- [ ] Test notification delivery across time zones

## Home Screen Implementation
- [ ] Design and implement home screen UI
  - [ ] Display current user info (name, catch phrase)
  - [ ] Show streak counter
  - [ ] Add response button
  - [ ] Add video library access
- [ ] Create countdown timer component
- [ ] Implement prompt display
- [ ] Handle prompt state (responded/not responded)

## Streak Management
- [ ] Design streak tracking system
  - [ ] Create streak counter in user model
  - [ ] Implement streak calculation logic
- [ ] Set up streak verification system
  - [ ] Verify responses within 24-hour window
  - [ ] Update streak count based on responses
- [ ] Create achievement-ready architecture
  - [ ] Design extensible achievement system structure
  - [ ] Prepare hooks for future achievement implementation

## Data Synchronization
- [ ] Implement SwiftData-Firestore sync for prompts
- [ ] Create caching system for offline access
- [ ] Handle prompt state persistence
- [ ] Implement response tracking system

---

## Warnings and Considerations
- ⚠️ Ensure robust handling of timezone edge cases
- ⚠️ Plan for scalability in prompt storage and delivery
- ⚠️ Consider network connectivity issues for prompt delivery
- ⚠️ Make sure notification timing is precise across devices
- ⚠️ Build flexible prompt schema to support future features
- ⚠️ Consider rate limiting for prompt responses
- ⚠️ Ensure proper error handling for failed notifications
- ⚠️ Test streak calculation thoroughly across date boundaries 