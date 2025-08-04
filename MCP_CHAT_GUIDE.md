# 🌊 Seven Pools MCP Chat - The Future of AI Conversations

## What Makes This Special?

This isn't just another chat interface. It's the first chat UI that demonstrates **real-time enliteracy** through the Model Context Protocol. Every conversation taps into 718,233 entities across the Seven Pools of Enliteracy.

## Access the Chat

Visit: http://localhost:3555/chat/mcp

## Key Features

### 1. **Real-Time Pool Activation** 🌊
Watch as different pools light up based on your conversation:
- 💭 **Idea Pool** - Concepts, principles, philosophies
- 🏗️ **Manifest Pool** - Physical structures, camps, art
- ✨ **Experience Pool** - Transformative moments, emotions
- 🤝 **Relational Pool** - Community connections
- 📈 **Evolutionary Pool** - Historical changes
- 🔧 **Practical Pool** - How-to knowledge
- 🌟 **Emanation Pool** - Spiritual insights

### 2. **MCP Tool Transparency** 🔧
See exactly which tools the AI is using:
- **search** - Vector search across 54,555 items
- **fetch** - Detailed item information
- **analyze_pools** - Real-time Seven Pools analysis
- **pool_bridge** - Cross-pool connections

### 3. **Enliteracy Metrics** 📊
- Query enliteracy score (0-100%)
- Entity count discovered
- Tools used counter

### 4. **Conversation Continuity** 🔄
The Responses API tracks conversation state automatically via `response_id`, enabling true multi-turn conversations.

## Example Queries to Try

### Basic Search
```
"Tell me about fire art installations at Burning Man"
```
*Watch the search tool activate and see results with pool entities*

### Seven Pools Analysis
```
"Analyze this for Seven Pools: The temple creates a sacred space where 
community members gather to share transformative experiences"
```
*All seven pools will light up as entities are extracted*

### Cross-Pool Exploration
```
"What connects the manifest and experience pools at Burning Man?"
```
*The pool_bridge tool will find items that bridge these dimensions*

### Deep Exploration
```
"Find camps that teach practical skills while building community connections"
```
*Multiple tools will work together to find the perfect matches*

## Technical Architecture

```
User Input
    ↓
Responses API (gpt-4.1)
    ↓
Remote MCP Server (https://offline.oknotok.com/api/v1/mcp/sse)
    ↓
Four MCP Tools
    ├── SearchTool → Vector Search
    ├── FetchTool → Item Details
    ├── AnalyzePoolsTool → Real-time Enliteracy
    └── PoolBridgeTool → Cross-pool Discovery
    ↓
718,233 Entities across Seven Pools
```

## What's Happening Behind the Scenes?

1. **No Manual Tool Handling** - The Responses API discovers and calls our MCP tools automatically
2. **Real-Time Analysis** - AnalyzePoolsTool processes text in ~0.1 seconds
3. **Semantic Understanding** - Every query benefits from 461K+ pool entities
4. **Graph Connections** - Results include related entities and cross-references

## Development Tips

### Testing Different Models
Edit `app/controllers/api/v1/responses_chat_controller.rb`:
```ruby
model: "gpt-4.1"  # or "gpt-4.1" when available
```

### Adjusting MCP Tools
Control which tools are available:
```ruby
allowed_tools: ["search", "analyze_pools"]  # Limit to specific tools
```

### Enable Approval Flow
For production, change:
```ruby
require_approval: "auto"  # Instead of "never"
```

## The Enliteracy Experience

This chat interface demonstrates the core concept of **enliteracy** - granting literacy to data. Every conversation:

1. **Understands** - Natural language is parsed for intent
2. **Connects** - Relevant pools are activated
3. **Discovers** - Entities are found across dimensions
4. **Enriches** - Results include semantic connections
5. **Evolves** - Each query builds on previous understanding

## Future Enhancements

- **Visual Knowledge Graph** - See entity connections in real-time
- **Pool Deep Dives** - Click a pool to explore its contents
- **Entity Timeline** - Track how entities evolve over years
- **Wisdom Capture** - Save insights back to the dataset

## Try It Now!

1. Start the Rails server: `rails server -p 3555`
2. Visit: http://localhost:3555/chat/mcp
3. Ask about anything Burning Man related
4. Watch the Seven Pools come alive!

---

*Built with the Model Context Protocol and 718,233 enliterated entities*