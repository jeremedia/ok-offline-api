# OK-OFFLINE API Test Scripts

This directory contains various test and utility scripts for the OK-OFFLINE API.

## Directory Structure

### batch_processing/
Scripts for testing OpenAI Batch API integration, pool entity extraction, and cost tracking.

### search/
Scripts for testing search functionality, entity extraction, and normalization.

### weather/
Scripts for testing weather API integrations (Apple Weather, OpenWeatherMap).

### visual/
Scripts for testing OpenGraph image generation and visual components.

### utilities/
General utility and debugging scripts.

## Running Tests

Most scripts can be run directly:
```bash
ruby test/batch_processing/test_100_items_batch.rb
```

Or use rails runner:
```bash
rails runner test/search/test_pool_extraction.rb
```

## Key Test Scripts

- `batch_processing/verify_automation.rb` - Verifies the full automated batch pipeline
- `batch_processing/test_100_items_batch.rb` - Tests larger batch processing
- `search/test_pool_extraction_diverse.rb` - Tests pool extraction across item types
- `utilities/test_solid_queue.rb` - Tests background job processing
