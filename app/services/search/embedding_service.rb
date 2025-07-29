module Search
  class EmbeddingService
    EMBEDDING_MODEL = "text-embedding-ada-002"
    MAX_TOKENS = 8191 # Maximum for ada-002
    
    def initialize
      @client = OpenAI::Client.new(
        access_token: ENV.fetch('OPENAI_API_KEY'),
        log_errors: Rails.env.development?
      )
    end
    
    def generate_embedding(text)
      return nil if text.blank?
      
      # Truncate text if it's too long
      truncated_text = truncate_to_token_limit(text)
      
      begin
        response = @client.embeddings(
          parameters: {
            model: EMBEDDING_MODEL,
            input: truncated_text
          }
        )
        
        # Extract embedding vector from response
        response.dig("data", 0, "embedding")
      rescue => e
        Rails.logger.error("OpenAI Embedding Error: #{e.message}")
        nil
      end
    end
    
    def generate_embeddings_batch(texts)
      return [] if texts.blank?
      
      # OpenAI can handle multiple texts in one request
      truncated_texts = texts.map { |text| truncate_to_token_limit(text) }
      
      begin
        response = @client.embeddings(
          parameters: {
            model: EMBEDDING_MODEL,
            input: truncated_texts
          }
        )
        
        # Extract all embeddings
        response.dig("data")&.map { |item| item["embedding"] } || []
      rescue => e
        Rails.logger.error("OpenAI Batch Embedding Error: #{e.message}")
        []
      end
    end
    
    private
    
    def truncate_to_token_limit(text)
      # Use tiktoken to count tokens accurately
      encoding = Tiktoken.encoding_for_model(EMBEDDING_MODEL)
      tokens = encoding.encode(text)
      
      if tokens.length > MAX_TOKENS
        # Truncate and decode back to text
        truncated_tokens = tokens.first(MAX_TOKENS)
        encoding.decode(truncated_tokens)
      else
        text
      end
    rescue
      # Fallback to character-based truncation if tiktoken fails
      text.truncate(MAX_TOKENS * 4) # Rough approximation
    end
  end
end