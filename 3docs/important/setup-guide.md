# ichiwabi Development Setup Guide

## Prerequisites
- Xcode 15.0 or later
- iOS 17.0 or later (for SwiftData support)
- Firebase account with Firestore enabled
- Git

## Initial Setup

1. **Clone Repository**
   ```bash
   git clone [repository-url]
   cd ichiwabi
   ```

2. **Firebase Configuration**
   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com)
   - Add an iOS app to your Firebase project
   - Download `GoogleService-Info.plist`
   - Place it in the `ichiwabi` directory
   - **Important**: Do not commit this file to version control

3. **Dependencies**
   - Open `ichiwabi.xcodeproj` in Xcode
   - Wait for Swift Package Manager to resolve dependencies
   - If needed, manually resolve:
     ```
     Firebase/Auth
     Firebase/Firestore
     ```

4. **Build and Run**
   - Select an iOS 17.0+ simulator
   - Build and run the project (⌘R)
   - Verify the app launches successfully

## Development Environment

### SwiftData
- Models are in `Core/Models/`
- Schema changes require migration planning
- Use `@Model` attribute for persistent types

### Firebase
- Firestore collections are defined
- Security rules in `firestore.rules`
- Test with Firebase Local Emulator Suite

### Sync Architecture
- Implement `SyncableModel` for new models
- Create model-specific sync services
- Test offline capabilities

## Testing

1. **Sync Tests**
   - Navigate to "Sync Tests" in the app
   - Run all test cases
   - Verify results in the UI

2. **Manual Testing**
   - Test offline scenarios
   - Verify conflict resolution
   - Check real-time updates

## Common Issues

### SwiftData Errors
- Clear derived data if schema errors occur
- Reset simulator if persistent store issues
- Check model relationships

### Firebase Issues
- Verify `GoogleService-Info.plist` is present
- Check Firebase console for errors
- Ensure proper network permissions

### Sync Issues
- Monitor Firestore quotas
- Check network connectivity
- Verify security rules

## Best Practices

1. **Code Organization**
   - Follow existing directory structure
   - Use appropriate access control
   - Document public interfaces

2. **Testing**
   - Add tests for new models
   - Test offline scenarios
   - Verify sync behavior

3. **Git Workflow**
   - Create feature branches
   - Write descriptive commits
   - Test before merging

## Support

- Check `3docs/log` for implementation details
- Review Firebase documentation
- Consult SwiftData documentation
- File issues for bugs 