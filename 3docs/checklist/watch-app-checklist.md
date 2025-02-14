- [x] **Setup & Project Structure**  
  - [x] Create a new watchOS target in the project.  
  - [x] Set up the initial watch app skeleton featuring the home screen with a plus button.

- [PROGRESS] **User Interface Adaptation**  
  - [x] Design the home screen to show only the "Record Dream" plus button.  
  - [PROGRESS] Implement navigation from the plus button to the recording view which includes:  
    - [x] Stop button  
    - [x] Playback controls  
    - [ ] Style selection options  
  - [ ] Create a final view that displays the on-device transcription and generated title along with a save button.  
  - [ ] Upon saving, navigate back to the home screen (plus button).

- [PROGRESS] **Audio Recording and On-Device Processing**  
  - [x] Adapt the AudioRecordingService for watchOS if needed.  
  - [x] Implement audio recording functionality on the watch.  
  - [ ] Integrate on-device audio transcription functionality.  
  - [ ] Integrate on-device dream title generation.  
  - [x] Simplify the waveform display (if included) to suit the watch's interface and performance constraints.

- [x] **Haptic Feedback & User Interaction**  
  - [x] Provide haptic feedback when the user taps the "Record Dream" plus button.  
  - [x] Test haptic feedback responsiveness on the Apple Watch.

- [PROGRESS] **Backend Interaction & Authentication**  
  - [x] Ensure the watch app uses the paired iOS authentication/session (no separate auth on watch).  
  - [x] Implement iPhone-side WatchConnectivity session management.
  - [x] Create WatchSyncManager to handle Watch-to-iPhone data sync.
  - [x] Implement dream data conversion and storage on iPhone.
  - [x] Set up audio file transfer and Firebase Storage upload.
  - [ ] Implement the "generate video" functionality to trigger the upload to Firebase once the user saves a dream.  
  - [ ] Since only an upload is required, omit local data persistence apart from recording the current dream.

- [ ] **Testing & Optimization**  
  - [ ] Test the full audio recording, transcription, title generation, and upload workflow on actual Apple Watch hardware.  
  - [ ] Validate UI responsiveness and navigation flows on the smaller screen.  
  - [ ] Optimize battery usage and performance for the watch's hardware constraints.

**Warnings:**  
- Audio processing (transcription and title generation) on the watch could be resource-intensive. Rigorous testing is required to ensure a smooth user experience.  
- The minimal UI is crucial; any feature bloat could impede usability on the smaller screen.
- Watch-to-iPhone sync must be robust against connectivity issues and handle data transfer retries gracefully.
- Battery impact of sync operations should be monitored, especially during audio file transfers.

**Considerations:**  
- [PROGRESS] Investigate any limitations of AVFoundation and APIService on watchOS to ensure smooth on-device processing of transcription and title generation.  
- [PROGRESS] Confirm that triggering backend video generation from watchOS functions reliably under watchOS network constraints.
- [x] Implement proper error handling and recovery for Watch-to-iPhone sync failures.
- [x] Design sync status tracking system to keep users informed of transfer progress.
