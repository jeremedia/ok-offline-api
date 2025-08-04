# Burning Man Chat Interface

I've created a chat interface that uses Turbo Streams and the OpenAI API to provide an interactive assistant for exploring Burning Man data through the Seven Pools of Enliteracy.

## Features

### 1. Two Chat Implementations

#### Standard Chat (Server-Sent Events)
- **URL**: `/chat`
- **API Endpoint**: `POST /api/v1/chat`
- Uses Server-Sent Events for streaming responses
- JavaScript-based frontend
- Good for API integrations

#### Turbo Streams Chat
- **URL**: `/chat/turbo`
- **API Endpoint**: `POST /api/v1_chat_with_turbo`
- Uses Rails Turbo Streams for real-time updates
- No JavaScript required for basic functionality
- Enhanced UI with gradient styling

### 2. Seven Pools Integration

The chat interface leverages our Seven Pools framework to provide context-aware responses:

- **Semantic Search**: Finds relevant items based on meaning
- **Pool Entity Extraction**: Identifies concepts in user queries
- **Cross-Pool Connections**: Shows relationships between different aspects

### 3. Streaming Responses

Both implementations support streaming responses from OpenAI:
- Real-time token streaming
- Visual feedback during generation
- Markdown formatting support

## Usage

### Starting the Chat Interface

1. Make sure your Rails server is running:
```bash
rails server -b 0.0.0.0 -p 3555
```

2. Visit the chat interface:
- Standard: `http://100.104.170.10:3555/chat`
- Turbo Streams: `http://100.104.170.10:3555/chat/turbo`

### Example Queries

Try asking questions like:
- "What art installations involve fire?"
- "Tell me about camps that offer workshops"
- "What's happening at 3:00 & E?"
- "Find experiences related to healing and wellness"
- "What philosophical principles guide Center Camp?"

### API Integration

To integrate the chat API in other applications:

```javascript
// Using Server-Sent Events
const response = await fetch('/api/v1/chat', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ chat: { message: "Your question here" } })
});

const reader = response.body.getReader();
// Process streaming response...
```

## Technical Details

### Context Building

The chat builds context by:
1. Vector search for semantically similar items
2. Pool entity extraction from the query
3. Finding items that share extracted entities
4. Combining all context for the LLM

### Response Generation

1. System prompt includes all relevant context
2. OpenAI streams tokens in real-time
3. Frontend updates progressively
4. Entity highlights show related concepts

### Pool Entity Highlights

After each response, the interface can show:
- Which pools were relevant
- What entities were found
- Links to explore specific items

## Next Steps

1. **Enhanced UI**: Add conversation history, typing indicators
2. **Multi-turn Context**: Remember previous messages
3. **Voice Input**: Add speech-to-text capability
4. **Export Conversations**: Save chat history
5. **Pool Visualizations**: Show entity relationships graphically

## Configuration

Ensure these environment variables are set:
- `OPENAI_API_KEY`: Your OpenAI API key
- Database with indexed Burning Man data
- Pool entities extracted via batch processing

The chat interface demonstrates how the Seven Pools framework can create intelligent, context-aware interactions with the Burning Man dataset!