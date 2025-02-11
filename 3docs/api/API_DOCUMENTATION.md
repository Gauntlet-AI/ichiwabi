I need to create the actual file. Here's how to do that:

# Dream Analysis Chat API Documentation

## Overview
This API provides an interface for interactive dream analysis conversations with simulated versions of Carl Jung and Sigmund Freud. The API maintains conversation state and allows for ongoing dialogue about dream interpretation.

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
- Uses OpenAI's GPT-4 model
- Requires valid OpenAI API key in environment variables
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
```

## Limitations
- In-memory storage (conversations are lost on server restart)
- No authentication/authorization
- No rate limiting
- No persistent storage

## Dependencies
- FastAPI
- Pydantic
- OpenAI Python Client
- Python-dotenv
```