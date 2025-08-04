#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'fileutils'

# Download Burning Man JSON Archive data from 2015-2024
# Note: 2020-2021 were pandemic years with no official event

BASE_URL = 'https://bm-innovate.s3.amazonaws.com/archive'
YEARS = (2015..2024).to_a - [2020, 2021] # Skip pandemic years
TYPES = ['art', 'camps', 'events']

def download_file(url, dest_path)
  puts "Downloading: #{url}"
  uri = URI(url)
  
  begin
    response = Net::HTTP.get_response(uri)
    
    if response.code == '200'
      File.write(dest_path, response.body)
      puts "✓ Saved to: #{dest_path}"
      true
    else
      puts "✗ Failed: HTTP #{response.code} for #{url}"
      false
    end
  rescue => e
    puts "✗ Error downloading #{url}: #{e.message}"
    false
  end
end

def main
  base_dir = File.join(File.dirname(__FILE__), '../../db/data/json_archive')
  
  YEARS.each do |year|
    year_dir = File.join(base_dir, year.to_s)
    FileUtils.mkdir_p(year_dir)
    
    puts "\n=== Downloading #{year} data ==="
    
    TYPES.each do |type|
      url = "#{BASE_URL}/#{year}/#{type}.json"
      dest_path = File.join(year_dir, "#{type}.json")
      
      # Skip if already downloaded
      if File.exist?(dest_path)
        puts "✓ Already exists: #{dest_path}"
        next
      end
      
      download_file(url, dest_path)
      sleep(0.5) # Be nice to their servers
    end
  end
  
  puts "\n=== Download Summary ==="
  YEARS.each do |year|
    year_dir = File.join(base_dir, year.to_s)
    files = Dir.glob(File.join(year_dir, '*.json'))
    puts "#{year}: #{files.size} files"
  end
end

main if __FILE__ == $0