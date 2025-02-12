We have two dynamic flows for video creation.

Initially, the user records a dream. This happens in @DreamRecordingView. AI generates a title and a transcription and all of this, including the audio, is saved to Firestore and the audio files to Firebase Storage. The user also selects from three styles:

- "Realistic"
- "Animated"
- "Cursed"

These styles are also saved to Firestore. They also determine what default video will be used as the video.

When the user generates the video, it will be the video from their style selection on loop for the duration of the audio. There will be a watermark on the video with our branding, the title, and date. This has already been created.

After these things are created, they should be saved to Firestore. There will then be a button to "Make Your Dream Real", which will trigger a function to create a new video.

This function calls our API endpoint for replicate, then continues to ping it until it is ready. It will then retrieve a URL to the video and save it to Firestore. It will apply the saved audio to THIS video now, as well as the water mark. 

Both of these functions have been successfully done, but they are not occuring in the right workflow, and often one is breaking the other. we need to ensure we are doing things correctly.