I need to create the actual file. Here's how to do that:

# Dream Analysis Chat API Documentation

## Overview
This API provides an interface for interactive dream analysis conversations with simulated versions of Carl Jung and Sigmund Freud. Additional features include dream title generation, speech transcription, and dream-based video generation.

## Base URL
`https://yorutabi-api.vercel.app/`

## Endpoints

### 1. Start Chat Session
Initiates a new conversation with either Jung or Freud about a dream.

**Endpoint:** `POST /start-chat`

#### Request Body
```json
{
    "analyst": "jung",  // or "freud"
    "dream": "Description of the dream",
    "messages": []  // Optional: previous messages
}
```

#### Response
```json
{
    "chat_id": 1,
    "response": "Initial analysis from the chosen analyst",
    "analyst": "jung"
}
```

### 2. Continue Chat
Continues an existing conversation by sending a new message.

**Endpoint:** `POST /chat/{chat_id}`

#### Request Body
```json
[
    {
        "role": "user",
        "content": "Your message here"
    }
]
```

#### Response
```json
{
    "response": "Analyst's reply",
    "analyst": "jung"
}
```

### 3. Generate Dream Title
Generates a concise, engaging title for a dream description.

**Endpoint:** `POST /generate-title`

#### Request Body
```json
{
    "dream": "Description of the dream"
}
```

#### Response
```json
{
    "title": "Short dream title"
}
```

### 4. Transcribe Speech
Transcribes an audio recording of a dream description.

**Endpoint:** `POST /transcribe-speech`

#### Request
- Content-Type: `multipart/form-data`
- Body: 
  - `audio_file`: M4A audio file

#### Response
```json
{
    "transcription": "Transcribed text of the audio"
}
```

### 5. Generate Video
Generates a video visualization of a dream description in a specified style using Replicate's Luma-Ray model.

**Endpoint:** `POST /generate-video`

#### Request Body
```json
{
    "dream": "Description of the dream",
    "style": "Realistic"  // Options: "Realistic", "Animated", "Cursed"
}
```

#### Response
```json
{
    "video_url": "URL to the generated video"
}
```

**Notes:**
- Videos are generated in portrait orientation (9:16 aspect ratio, 720x1280)
- Duration is fixed at 9 seconds
- Available styles:
  - Realistic: Photorealistic, cinematic, surreal, dreamlike visuals
  - Animated: Beautiful, cute, Japanese animation woodblock style
  - Cursed: Dark, unsettling, surreal, uncanny valley, hallucinogenic visuals
- Video generation is asynchronous and may take several minutes
- The endpoint polls the generation status until completion
- The returned URL is a direct link to the generated video

**Process:**
1. Dream description is combined with style-specific prompts
2. Video request is sent to Luma-Ray model
3. Generation status is monitored until completion
4. Final video URL is returned when ready

## Implementation Details

### ChatService Class
The core functionality is handled by the `ChatService` class, which:
- Maintains conversation history
- Manages analyst-specific prompts
- Handles interaction with the OpenAI API

### Conversation Management
- Each chat session is assigned a unique ID
- Conversations are stored in memory (active_chats dictionary)
- Full conversation history is maintained for context

### Analyst Personalities
Two distinct analytical approaches are available:
- **Jung**: Focuses on archetypes, collective unconscious, and symbolic meaning
- **Freud**: Emphasizes psychosexual development and repressed desires

## Error Handling
The API includes basic error handling for:
- Invalid chat IDs (404 Not Found)
- OpenAI API errors (500 Internal Server Error)

## Technical Notes
- Built with FastAPI
- Uses OpenAI's GPT-4 model for chat and title generation
- Uses OpenAI's Whisper model for speech transcription
- Uses Replicate's Luma-Ray model for video generation
- Requires valid API keys for OpenAI and Replicate in environment variables
- Async implementation for better performance

## Example Usage

```python
# Start a new chat
response = requests.post("http://localhost:8000/start-chat", 
    json={
        "analyst": "jung",
        "dream": "I was flying over a dark forest"
    }
)
chat_id = response.json()["chat_id"]

# Continue the conversation
response = requests.post(f"http://localhost:8000/chat/{chat_id}",
    json=[
        {
            "role": "user",
            "content": "What does the forest symbolize?"
        }
    ]
)

# Generate a title
response = requests.post("http://localhost:8000/generate-title", 
    json={
        "dream": "I was flying over a dark forest"
    }
)

# Transcribe speech
with open('dream_recording.m4a', 'rb') as f:
    files = {'audio_file': f}
    response = requests.post("http://localhost:8000/transcribe-speech", 
        files=files
    )

# Generate video
response = requests.post("http://localhost:8000/generate-video",
    json={
        "dream": "I was flying over a dark forest",
        "style": "Realistic"
    }
)
```

## Limitations
- In-memory storage (conversations are lost on server restart)
- No authentication/authorization
- No rate limiting
- No persistent storage
- M4A format only for audio transcription
- Video generation may take time to process
- 10-second limit on generated videos

## Dependencies
- FastAPI
- Pydantic
- OpenAI Python Client
- Python-dotenv
- Python-multipart
- Replicate