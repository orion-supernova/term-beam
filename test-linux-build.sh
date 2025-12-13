#!/bin/bash

# Test Linux build locally using Docker
# This simulates the GitHub Actions Linux environment

echo "🐧 Testing Linux build locally..."
echo ""

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker Desktop."
    exit 1
fi

echo "🔨 Building with Swift 6.0 on Linux (Ubuntu)..."
echo ""

# Run the build in the same container as GitHub Actions
docker run --rm -v "$PWD:/workspace" -w /workspace swift:6.0 \
    bash -c "swift build 2>&1"

BUILD_EXIT_CODE=$?

echo ""
if [ $BUILD_EXIT_CODE -eq 0 ]; then
    echo "✅ Linux build successful!"
else
    echo "❌ Linux build failed with exit code $BUILD_EXIT_CODE"
    echo ""
    echo "💡 Tip: The errors shown above are what you'd see in GitHub Actions."
fi

exit $BUILD_EXIT_CODE
