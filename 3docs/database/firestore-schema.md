# Firestore Schema Design

## Collections Overview

### Users Collection (`users/{userId}`)
```typescript
{
  // Core user data (synced with SwiftData)
  id: string                  // matches Auth UID
  username: string           
  displayName: string
  catchphrase: string?
  avatarURL: string?
  createdAt: timestamp
  lastActiveAt: timestamp
  
  // Public profile data
  followerCount: number
  followingCount: number
  responseCount: number
  
  // Settings & Preferences (minimal, most settings stay local)
  privacyMode: 'public' | 'friendsOnly' | 'private'
  
  // Metadata
  isActive: boolean
  isBanned: boolean
  role: 'user' | 'moderator' | 'admin'
}
```

### Prompts Collection (`prompts/{promptId}`)
```typescript
{
  // Core prompt data
  id: string
  text: string
  createdAt: timestamp
  activeDate: timestamp      // When this prompt becomes active
  expiresAt: timestamp?     // Optional expiration
  
  // Categorization
  category: 'daily' | 'weekly' | 'challenge' | 'community' | 'special'
  tags: string[]
  difficulty: 'easy' | 'medium' | 'hard' | 'expert'
  
  // Metadata
  isActive: boolean
  isUserGenerated: boolean
  createdBy: string?        // User ID of creator (if user-generated)
  totalResponses: number
  
  // Engagement metrics
  viewCount: number
  responseRate: number      // % of active users who responded
}
```

### Responses Collection (`responses/{responseId}`)
```typescript
{
  // Core response data
  id: string
  userId: string           // Creator's ID
  promptId: string        // Associated prompt
  createdAt: timestamp
  updatedAt: timestamp
  
  // Content metadata
  duration: number        // in seconds
  thumbnailURL: string?
  videoURL: string        // Cloud Storage URL
  transcription: string?
  
  // Status
  status: 'draft' | 'uploading' | 'processing' | 'published' | 'failed' | 'deleted'
  
  // Engagement metrics
  viewCount: number
  likeCount: number
  commentCount: number
  shareCount: number
  
  // Privacy
  visibility: 'public' | 'friendsOnly' | 'private'
  allowComments: boolean
}
```

### Comments Collection (`responses/{responseId}/comments/{commentId}`)
```typescript
{
  id: string
  userId: string         // Commenter's ID
  text: string
  createdAt: timestamp
  updatedAt: timestamp
  parentCommentId: string?  // For threaded comments
  likeCount: number
  isEdited: boolean
}
```

### Reports Collection (`reports/{reportId}`)
```typescript
{
  id: string
  type: 'user' | 'video' | 'comment' | 'prompt' | 'technical'
  reason: string
  description: string?
  reporterId: string
  targetId: string      // ID of reported content/user
  createdAt: timestamp
  status: 'pending' | 'inReview' | 'resolved' | 'dismissed' | 'escalated'
  moderatorNotes: string?
  moderatedBy: string?
  moderatedAt: timestamp?
  actionTaken: string?
}
```

## Subcollections

### User Relationships (`users/{userId}/relationships/{otherUserId}`)
```typescript
{
  type: 'following' | 'follower' | 'blocked'
  createdAt: timestamp
  status: 'pending' | 'accepted' | 'rejected'  // For follow requests
}
```

### User Activity (`users/{userId}/activity/{activityId}`)
```typescript
{
  type: 'like' | 'comment' | 'follow' | 'response'
  targetId: string      // ID of content interacted with
  createdAt: timestamp
}
```

## Security Rules Overview

1. **User Data**
   - Users can read public profiles
   - Users can only write their own data
   - Admin/moderators can update user status

2. **Prompts**
   - Anyone can read active prompts
   - Only admins can create official prompts
   - Users can create community prompts (if enabled)

3. **Responses**
   - Public responses visible to all
   - Private responses only visible to creator
   - FriendsOnly visible to followers

4. **Comments**
   - Readable if parent response is readable
   - Creator can edit/delete own comments
   - Response owner can delete any comments

5. **Reports**
   - Any user can create reports
   - Only moderators/admins can read/update reports

## Indexing Strategy

Required indexes for common queries:
1. Prompts by activeDate and category
2. Responses by promptId and createdAt
3. Responses by userId and createdAt
4. Comments by responseId and createdAt
5. Reports by status and createdAt

## Optimization Notes

1. **Denormalization**
   - Store minimal user data with responses/comments
   - Cache active prompt data locally
   - Keep engagement counts at document level

2. **Batch Operations**
   - Use batch writes for relationship changes
   - Implement counter sharding for high-traffic metrics

3. **Query Optimization**
   - Paginate all list queries
   - Use cursor-based pagination for infinite scrolls
   - Implement local caching for frequent queries 