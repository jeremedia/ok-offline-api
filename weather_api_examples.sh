#!/bin/bash

# Weather API Examples for OK-OFFLINE

echo "Weather API Examples"
echo "==================="
echo ""

# Base URL - update if different
BASE_URL="http://localhost:3020"

# Test coordinates (Monterey, CA)
LAT="36.598341500150156"
LON="-121.8744153547224"

echo "1. Get Weather Data"
echo "-------------------"
echo "curl -X GET \"$BASE_URL/weather?lat=$LAT&lon=$LON\""
echo ""
echo "Response:"
curl -s -X GET "$BASE_URL/weather?lat=$LAT&lon=$LON" | jq '.' || echo "Failed to fetch weather. Is the server running on port 3020?"
echo ""
echo ""

echo "2. Clear Cache for Specific Coordinates"
echo "---------------------------------------"
echo "curl -X DELETE \"$BASE_URL/weather/cache?lat=$LAT&lon=$LON\""
echo ""
echo "Response:"
curl -s -X DELETE "$BASE_URL/weather/cache?lat=$LAT&lon=$LON" | jq '.' || echo "Failed to clear cache"
echo ""
echo ""

echo "3. Clear All Weather Caches"
echo "---------------------------"
echo "curl -X DELETE \"$BASE_URL/weather/cache\""
echo ""
echo "Response:"
curl -s -X DELETE "$BASE_URL/weather/cache" | jq '.' || echo "Failed to clear all caches"
echo ""
echo ""

echo "4. Test Invalid Coordinates"
echo "---------------------------"
echo "curl -X GET \"$BASE_URL/weather?lat=999&lon=999\""
echo ""
echo "Response:"
curl -s -X GET "$BASE_URL/weather?lat=999&lon=999" | jq '.' || echo "Failed"
echo ""
echo ""

echo "5. Test Missing Parameters"
echo "--------------------------"
echo "curl -X GET \"$BASE_URL/weather\""
echo ""
echo "Response:"
curl -s -X GET "$BASE_URL/weather" | jq '.' || echo "Failed"