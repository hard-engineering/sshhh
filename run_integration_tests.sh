#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "🔨 Building app..."
bash bundler.sh

echo ""
echo "🔨 Building integration tests..."
swift build --target IntegrationTests

echo ""
echo "🧪 Running integration tests..."
echo "   Note: Accessibility permissions required for key simulation"
echo ""

swift run IntegrationTests ./sshhh.app
