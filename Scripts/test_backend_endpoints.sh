#!/bin/bash

# CLARITY Backend API Endpoint Test Script
# Base URL: https://clarity.novamindnyc.com

BASE_URL="https://clarity.novamindnyc.com"
echo "Testing CLARITY Backend API Endpoints"
echo "Base URL: $BASE_URL"
echo "========================================"

# Test 1: Root endpoint
echo -e "\n1. Testing root endpoint (/):"
curl -s -w "\nHTTP Status: %{http_code}\n" "$BASE_URL/"

# Test 2: Health check endpoint
echo -e "\n2. Testing health endpoint (/health):"
curl -s -w "\nHTTP Status: %{http_code}\n" "$BASE_URL/health"

# Test 3: API v1 root
echo -e "\n3. Testing API v1 root (/api/v1):"
curl -s -w "\nHTTP Status: %{http_code}\n" "$BASE_URL/api/v1"

# Test 4: Auth endpoints (without auth)
echo -e "\n4. Testing auth endpoints:"
echo -e "\n4a. GET /api/v1/auth/me (should return 401):"
curl -s -w "\nHTTP Status: %{http_code}\n" "$BASE_URL/api/v1/auth/me"

echo -e "\n4b. POST /api/v1/auth/login (should return 400 or 422 without body):"
curl -s -X POST -w "\nHTTP Status: %{http_code}\n" "$BASE_URL/api/v1/auth/login" -H "Content-Type: application/json"

# Test 5: Insights endpoints
echo -e "\n5. Testing insights endpoints:"
echo -e "\n5a. GET /api/v1/insights (should return 401 or 405):"
curl -s -w "\nHTTP Status: %{http_code}\n" "$BASE_URL/api/v1/insights"

echo -e "\n5b. POST /api/v1/insights (should return 401 without auth):"
curl -s -X POST -w "\nHTTP Status: %{http_code}\n" "$BASE_URL/api/v1/insights" -H "Content-Type: application/json"

echo -e "\n5c. POST /api/v1/insights/chat (the broken endpoint):"
curl -s -X POST -w "\nHTTP Status: %{http_code}\n" "$BASE_URL/api/v1/insights/chat" -H "Content-Type: application/json"

echo -e "\n5d. GET /api/v1/insights/alerts (service status):"
curl -s -w "\nHTTP Status: %{http_code}\n" "$BASE_URL/api/v1/insights/alerts"

# Test 6: Health data endpoints
echo -e "\n6. Testing health data endpoints:"
echo -e "\n6a. GET /api/v1/health-data/metrics (should return 401):"
curl -s -w "\nHTTP Status: %{http_code}\n" "$BASE_URL/api/v1/health-data/metrics"

echo -e "\n6b. POST /api/v1/health-data/upload (should return 401):"
curl -s -X POST -w "\nHTTP Status: %{http_code}\n" "$BASE_URL/api/v1/health-data/upload" -H "Content-Type: application/json"

# Test 7: PAT Analysis endpoints
echo -e "\n7. Testing PAT analysis endpoints:"
echo -e "\n7a. POST /api/v1/pat-analysis/step-data (should return 401):"
curl -s -X POST -w "\nHTTP Status: %{http_code}\n" "$BASE_URL/api/v1/pat-analysis/step-data" -H "Content-Type: application/json"

echo -e "\n7b. GET /api/v1/pat-analysis/health (service health):"
curl -s -w "\nHTTP Status: %{http_code}\n" "$BASE_URL/api/v1/pat-analysis/health"

echo -e "\n\nTest completed!"