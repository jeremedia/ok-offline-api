# Filter out embedding vectors from ActiveRecord logs to reduce noise
if Rails.env.development?
  # Monkey patch the log method to filter embedding vectors
  module ActiveRecord
    class LogSubscriber < ActiveSupport::LogSubscriber
      # Store the original sql method
      alias_method :original_sql, :sql
      
      def sql(event)
        payload = event.payload
        return if payload[:cached]

        # Get the original SQL
        sql = payload[:sql]
        
        # Skip logging if it contains embedding vectors (they're very long)
        if sql && sql.include?('<=>') && sql.include?('embedding')
          # Extract just the query type and table
          query_type = sql.split(' ').first
          table_match = sql.match(/FROM\s+"?(\w+)"?/i)
          table_name = table_match ? table_match[1] : 'unknown'
          
          # Log a simplified version
          name = "#{payload[:name]} (#{event.duration.round(1)}ms)"
          logger.debug "  #{name}  #{query_type} with embedding vector on #{table_name} table [vector data suppressed]"
          return
        end
        
        # Otherwise, use the original logging
        original_sql(event)
      end
    end
  end
end