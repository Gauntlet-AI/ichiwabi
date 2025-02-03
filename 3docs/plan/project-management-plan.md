
# Project Management Plan

## Overview

We are building a TikTok-like short video creation app with a daily-prompt focus. The goal is to have:
- Secure sign-in with Apple or email (Firebase Auth)  
- A “daily question” that users answer by creating short videos  
- Sharing to external platforms with our watermark  
- Streak tracking based on consecutive daily posts  
- Lightweight local data storage (SwiftData)

## Phases

### Phase 1: Project Setup & Database Planning
1. **Project Initialization**  
    - Create a new repository (e.g., GitHub).  
    - Initialize an Xcode project with Swift.
2. **Firebase (Firestore) & SwiftData Setup**  
    - Register your app in Firebase, add config files.  
    - Install Firebase dependencies (Auth, Firestore).  
    - Set up SwiftData for local persistence.  
    - Define initial data structures (e.g., `Prompt`, `User`, `Video`) in both Firestore and SwiftData.

### Phase 2: Authentication
1. **Firebase Auth Integration**  
    - Implement Sign in with Apple.  
    - Implement email/password sign-in.  
2. **User Data Model**  
    - Decide what user metadata you want to store in Firestore (display name, profile pic?).
    - Ensure you have a Firestore collection for user profiles.

### Phase 3: Daily Prompts (Firestore Integration)
1. **Daily Prompt Configuration**  
    - Create a Firestore collection for daily prompts.  
    - Define the schema for each prompt (title, text, date, etc.).  
2. **Prompt Retrieval**  
    - Implement logic to fetch the daily prompt from Firestore on app launch.  
    - Cache the prompt using SwiftData for offline viewing.

### Phase 4: Video Creation & Basic Editing
1. **Recording with AVFoundation**  
    - Build a minimal UI for video capture.  
    - Provide basic cut/trim functionality.  
2. **(Optional) OpenShot or AWS Integration**  
    - Set up the structure for calling OpenShot if you need advanced editing or watermark features immediately. If not, just focus on local recording and basic editing this early.

### Phase 5: Streak Management
1. **Streak Logic**  
    - Tie video submission to user streak updates in Firestore.  
    - Upon a successful video post for the day, increment the user’s streak count.  
2. **Real-Time Updates**  
    - Use Firestore’s real-time listeners to update streak displays in the UI.

### Phase 6: Sharing & Watermark
1. **Watermark Application**  
    - Integrate OpenShot or an alternative approach to overlay your application’s watermark on the final video.  
2. **Sharing Options**  
    - Provide share sheet to let users share their videos (with watermark) to social platforms.

### Phase 7: Notifications
1. **Push Notifications**  
    - Decide if you’ll use Firebase Cloud Messaging or Apple’s Push Notification Service.  
    - Prompt the user to allow notifications for the new daily prompt.  
2. **In-App Notifications**  
    - Implement a local scheduling or an in-app alert for daily reminders.

### Phase 8: Testing & Quality Assurance
1. **Unit and Integration Tests**  
    - Test your Firebase flows (Auth, Firestore reads/writes) and SwiftData usage.  
    - Verify user flows: from sign-in to prompt retrieval, video recording, submission, etc.
2. **User Experience Testing**  
    - Conduct UI tests to confirm smooth navigation and error handling.

### Phase 9: Deployment & Maintenance
1. **App Store Preparation**  
    - Finalize app icons, provisioning profiles.  
    - Provide marketing materials and a compelling app description.  
2. **Post-Launch Maintenance**  
    - Monitor analytics, crash reports, user feedback.  
    - Iterate and expand features (comments, user-to-user interactions, advanced editing, etc.).

---

**Summary**: By handling your database structure (Firestore) right from the start, you’ll have a clearer picture of how your data flows through the app. This helps integrate each subsequent feature (prompts, user profiles, streaks) more smoothly. If you have further questions or want more detail on any phase, just let me know!
