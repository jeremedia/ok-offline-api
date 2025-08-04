require 'neo4j_ruby_driver'

# Neo4j connection configuration
NEO4J_CONFIG = {
  url: ENV.fetch('NEO4J_URL', 'bolt://localhost:7687'),
  username: ENV.fetch('NEO4J_USERNAME', 'neo4j'),
  password: ENV.fetch('NEO4J_PASSWORD', 'password')
}.freeze

# Connection singleton
module Neo4jConnection
  class << self
    def driver
      @driver ||= Neo4j::Driver::GraphDatabase.driver(
        NEO4J_CONFIG[:url],
        Neo4j::Driver::AuthTokens.basic(
          NEO4J_CONFIG[:username],
          NEO4J_CONFIG[:password]
        ),
        encryption: false # Set to true in production with proper certificates
      )
    end
    
    def session(**options, &block)
      if block_given?
        driver.session(**options, &block)
      else
        driver.session(**options)
      end
    end
    
    def close
      @driver&.close
      @driver = nil
    end
    
    # Verify connection
    def verify_connectivity
      session do |session|
        result = session.run("RETURN 1 as n")
        result.single[:n] == 1
      end
    rescue => e
      Rails.logger.error "Neo4j connection failed: #{e.message}"
      false
    end
    
    # Create constraints and indexes for Burning Man data
    def setup_schema
      session do |session|
        # Create uniqueness constraints
        constraints = [
          "CREATE CONSTRAINT IF NOT EXISTS FOR (i:Item) REQUIRE i.uid IS UNIQUE",
          "CREATE CONSTRAINT IF NOT EXISTS FOR (e:Entity) REQUIRE (e.name, e.pool) IS UNIQUE"
        ]
        
        constraints.each do |constraint|
          session.run(constraint)
        rescue => e
          Rails.logger.warn "Constraint creation warning: #{e.message}"
        end
        
        # Create indexes for performance
        indexes = [
          "CREATE INDEX IF NOT EXISTS FOR (i:Item) ON (i.name)",
          "CREATE INDEX IF NOT EXISTS FOR (i:Item) ON (i.year)",
          "CREATE INDEX IF NOT EXISTS FOR (i:Item) ON (i.type)",
          "CREATE INDEX IF NOT EXISTS FOR (e:Entity) ON (e.name)",
          "CREATE INDEX IF NOT EXISTS FOR (e:Entity) ON (e.pool)",
          "CREATE INDEX IF NOT EXISTS FOR (e:Entity) ON (e.pool, e.name)"
        ]
        
        indexes.each do |index|
          session.run(index)
        rescue => e
          Rails.logger.warn "Index creation warning: #{e.message}"
        end
      end
    end
  end
end

# Ensure connection is closed on exit
at_exit do
  Neo4jConnection.close
end