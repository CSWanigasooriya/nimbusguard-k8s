#!/bin/bash

echo "Testing direct port access..."
curl -s http://localhost:30237/health
echo -e "\n---\n"

echo "Testing domain access (if configured in /etc/hosts)..."
curl -s http://nimbusguard.local:30237/health
echo -e "\n---\n"

echo "Available endpoints:"
echo "1. API Documentation: http://localhost:30237/docs"
echo "2. Health Check: http://localhost:30237/health"
echo "3. Stats: http://localhost:30237/stats"
echo "4. Main API: http://localhost:30237"

echo -e "\nAlternatively, using domain name:"
echo "1. API Documentation: http://nimbusguard.local:30237/docs"
echo "2. Health Check: http://nimbusguard.local:30237/health"
echo "3. Stats: http://nimbusguard.local:30237/stats"
echo "4. Main API: http://nimbusguard.local:30237" 