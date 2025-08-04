# OpenAI Ruby Gem Learnings

## Common Pitfall: File Upload Requirements

### The Issue
When uploading files to OpenAI's API using the ruby-openai gem, the `file` parameter must be a **File object**, not a string path. This is a frequent mistake that occurs every time we implement file uploads.

### ❌ Wrong Way (String Path)
```ruby
response = @client.files.upload(
  parameters: {
    file: filepath,        # ❌ String path doesn't work
    purpose: 'batch'
  }
)
# Error: Invalid file - must be a StringIO object or a path to a file
```

### ✅ Correct Way (File Object)
```ruby
response = @client.files.upload(
  parameters: {
    file: File.open(filepath),  # ✅ File object works
    purpose: 'batch'
  }
)
```

### Why This Happens
1. Most Ruby file operations accept string paths
2. The error message is misleading - it says "path to a file" but actually needs a File object
3. The OpenAI gem uses multipart form upload which requires an IO object

### Best Practice Pattern
```ruby
def upload_batch_file(filepath)
  File.open(filepath) do |file|
    response = @client.files.upload(
      parameters: {
        file: file,
        purpose: 'batch'
      }
    )
    response['id']
  end
ensure
  # Clean up the file after upload
  File.delete(filepath) if File.exist?(filepath)
end
```

## Other OpenAI Gem Learnings

### 1. Batch API File Format
- Must be JSONL (JSON Lines) format
- Each line is a complete JSON object
- No trailing newlines or empty lines

### 2. Model Names
- Use exact model names: `"gpt-4.1-nano-2025-04-14"` not `"gpt-4-nano"`
- Check available models with `@client.models.list`

### 3. Response Format
- Use `response_format: { type: "json_object" }` for structured output
- The model will always return valid JSON when this is set

### 4. Error Handling
```ruby
begin
  response = @client.chat(parameters: {...})
rescue => e
  # OpenAI errors include useful details
  Rails.logger.error "OpenAI Error: #{e.message}"
  # e.response often has more details about rate limits, etc.
end
```

### 5. Timeout Configuration
```ruby
@client = OpenAI::Client.new(
  access_token: ENV['OPENAI_API_KEY'],
  request_timeout: 240  # Important for batch operations
)
```

## Batch API Specifics

### Token Usage & Cost Data
- Usage data (`usage` field) is **only available after batch completion**
- While `in_progress`, only `request_counts` are available
- Cost calculation must wait until `status: "completed"`
- The actual token counts may differ from estimates by 10-20%

### GPT-4.1-nano Pricing (as of August 2025)
- Input: $0.20 per 1M tokens
- Output: $0.20 per 1M tokens  
- Same price for both (unlike other models)
- Batch API provides 50% discount automatically

## Memory Aid
**"Files need Files, not strings"** - When uploading to OpenAI, always wrap your filepath in `File.open()`