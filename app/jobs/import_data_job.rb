class ImportDataJob < ApplicationJob
  queue_as :default
  
  def perform(year, types = ['camp', 'art', 'event'])
    Rails.logger.info("Starting data import job for year #{year}, types: #{types}")
    
    import_service = Search::DataImportService.new
    
    types.each do |type|
      case type
      when 'camp'
        import_service.import_camps(year)
      when 'art'
        import_service.import_art(year)
      when 'event'
        import_service.import_events(year)
      else
        Rails.logger.warn("Unknown type: #{type}")
      end
    end
    
    Rails.logger.info("Data import job completed for year #{year}")
  end
end