# Video Generation System Documentation

## Overview
This system implements an asynchronous video generation service using FastAPI's background tasks. It allows clients to request video generation and poll for status updates, avoiding timeout issues with long-running processes.

## Key Components

### 1. Data Models
- `VideoStyle`: Enum defining available video styles (Realistic, Animated, Cursed)
- `VideoGenerationStatus`: Enum tracking generation states (pending, processing, completed, failed)
- `VideoGeneration`: Pydantic model containing all task information

### 2. Storage
- Uses in-memory dictionary `video_tasks` to store task information
- Each task is identified by a unique UUID
- No persistence (tasks are lost on server restart)

### 3. API Endpoints

#### Generate Video
```http
POST /generate-video?dream={dream_description}&style={video_style}

Query Parameters:
- dream: string (required) - Description of the dream to generate
- style: string (required) - One of: "Realistic", "Animated", "Cursed"

Response: {
    "task_id": string,
    "status": "pending"
}
```

#### Check Status
```http
GET /video-status/{task_id}
Response: {
    "task_id": string,
    "status": "pending" | "processing" | "completed" | "failed",
    "dream": string,
    "style": string,
    "video_url": string | null,
    "error": string | null,
    "created_at": datetime,
    "updated_at": datetime
}
```

## How It Works

1. **Video Generation Request**
   - Client sends dream description and style as query parameters
   - Server generates UUID for the task
   - Creates task entry in memory
   - Starts background processing
   - Immediately returns task ID to client

2. **Background Processing**
   - Updates task status to "processing"
   - Sends request to Replicate API
   - Polls Replicate API every 5 seconds for completion
   - Updates task with final video URL or error

3. **Status Checking**
   - Client polls `/video-status/{task_id}`
   - Returns current state of video generation
   - Includes video URL when complete

## Client Implementation Guide

1. Start Generation:
   ```swift
   POST /generate-video with dream and style as query parameters
   Store returned task_id
   ```

2. Poll for Status:
   ```swift
   Periodically GET /video-status/{task_id}
   If status == "completed": 
       Use video_url
   If status == "failed":
       Handle error
   ```

3. Recommended Polling Strategy:
   - Start with 5-second intervals
   - Implement exponential backoff
   - Stop polling when status is "completed" or "failed"

## Error Handling
- Task not found: 404 error
- Missing parameters: 422 error with detailed validation messages
- Generation failures: Stored in task with error message
- API errors: Standard HTTP error responses
