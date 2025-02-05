# Project Management Plan

## Overview

We are building a TikTok-like short video creation app focused on dream sharing. The goal is to have:
- Secure sign-in with Apple or email (Firebase Auth)
- A platform for recording and sharing dream experiences through short videos
- Calendar-based organization of dream recordings
- Multiple dream recordings per day with flexible date assignment
- Sharing to external platforms with our watermark
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
    - Define initial data structures (e.g., `Dream`, `User`, `Video`, `Prompt`) in both Firestore and SwiftData.
    - Maintain backward compatibility with prompt-based data model

### Phase 2: Authentication
1. **Firebase Auth Integration**  
    - Implement Sign in with Apple.  
    - Implement email/password sign-in.  
2. **User Data Model**  
    - Decide what user metadata you want to store in Firestore (display name, profile pic?).
    - Ensure you have a Firestore collection for user profiles.

### Phase 3: Dream Recording Core (Firestore Integration)
1. **Dream Data Model**
    - Create a Firestore collection for dream records
    - Define the schema for each dream (title, description, recorded_date, dream_date, tags, etc.)
    - Implement flexible date assignment functionality
2. **Dream Management**
    - Implement logic to store and retrieve dreams from Firestore
    - Cache dreams using SwiftData for offline viewing
    - Add tagging and categorization features
3. **Calendar Integration**
    - Create calendar view for dream visualization
    - Implement date-based filtering and organization
    - Support multiple dreams per day in the calendar view

### Phase 4: Video Creation & Basic Editing
1. **Recording with AVFoundation**
    - Build an intuitive UI for quick video capture (important for morning dream recording)
    - Provide basic cut/trim functionality
2. **(Optional) OpenShot or AWS Integration**
    - Set up the structure for calling OpenShot if you need advanced editing or watermark features immediately
    - If not, focus on local recording and basic editing

### Phase 5: Calendar & Organization
1. **Calendar View**
    - Implement an intuitive calendar interface
    - Show dream entries with visual indicators for days with recordings
    - Support multiple dream entries per day
2. **Date Management**
    - Add ability to modify dream dates post-recording
    - Implement date validation and timezone handling
    - Provide batch date modification capabilities

### Phase 6: Sharing & Watermark
1. **Watermark Application**  
    - Integrate OpenShot or an alternative approach to overlay your application's watermark on the final video.  
2. **Sharing Options**  
    - Provide share sheet to let users share their videos (with watermark) to social platforms.

### Phase 7: Discovery & Engagement
1. **Dream Feed**
    - Implement a feed for browsing other users' shared dreams
    - Add filtering and search capabilities
    - Include calendar-based browsing option
2. **Engagement Features**
    - Add reactions and possibly comments
    - Implement privacy controls for dream sharing
    - Add date-based sharing restrictions if needed

### Phase 8: Testing & Quality Assurance
1. **Unit and Integration Tests**
    - Test your Firebase flows (Auth, Firestore reads/writes) and SwiftData usage
    - Verify user flows: from sign-in to dream recording, video creation, submission, etc.
2. **User Experience Testing**
    - Conduct UI tests to confirm smooth navigation and error handling
    - Test the app's usability specifically during early morning hours

### Phase 9: Deployment & Maintenance
1. **App Store Preparation**  
    - Finalize app icons, provisioning profiles.  
    - Provide marketing materials and a compelling app description.  
2. **Post-Launch Maintenance**  
    - Monitor analytics, crash reports, user feedback.  
    - Iterate and expand features (comments, user-to-user interactions, advanced editing, etc.).

---

**Summary**: The focus has shifted to a calendar-based dream recording system while maintaining the core technical infrastructure. The key changes involve implementing flexible date management, multiple recordings per day, and calendar visualization, while preserving compatibility with the existing prompt-based data model. The morning timing of dreams and date management add important dimensions to the UX considerations.
