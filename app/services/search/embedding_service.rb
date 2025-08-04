module Search
  class EmbeddingService
    # !!!!! CRITICAL: DO NOT CHANGE THIS MODEL !!!!!
    # This model MUST match what was used to generate existing embeddings in the database.
    # Changing this will break vector similarity search for all existing data.
    # The database contains embeddings generated with text-embedding-3-small.
    # If you need to change models, you MUST regenerate ALL embeddings.
    EMBEDDING_MODEL = "text-embedding-3-small"
    MAX_TOKENS = 8191 # Maximum for 3-small

    def initialize
      @client = OpenAI::Client.new(
        api_key: ENV['OPENAI_API_KEY']
      )
    end

    def generate_embedding(text)
      return nil if text.blank?

      # Truncate text if it's too long
      truncated_text = truncate_to_token_limit(text)

      begin
        response = @client.embeddings.create(
          model: EMBEDDING_MODEL,
          input: truncated_text
        )

        # Extract embedding vector from response
        e = response.data&.first&.embedding

        e
      rescue => e
        Rails.logger.error("OpenAI Embedding Error: #{e.message}")
        Rails.logger.error("Backtrace: #{e.backtrace.first(5).join('\n')}")
        nil
      end
    end

    def generate_embeddings_batch(texts)
      return [] if texts.blank?

      # OpenAI can handle multiple texts in one request
      truncated_texts = texts.map { |text| truncate_to_token_limit(text) }

      begin
        response = @client.embeddings.create(
          model: EMBEDDING_MODEL,
          input: truncated_texts
        )

        # Extract all embeddings
        response.data&.map(&:embedding) || []
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
