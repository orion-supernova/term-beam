# Testing Guide

## Why You Don't See Linux Errors on macOS

The main issue is that **macOS and Linux have different system libraries**:

- **macOS (Darwin)**: Uses different C library headers where `stdout` is thread-safe
- **Linux (Glibc)**: Uses different headers where `stdout` is NOT thread-safe

This is why your code compiles perfectly on macOS/Xcode but fails on Linux/GitHub Actions.

## Solution: Test Linux Builds Locally

### Option 1: Use Docker (Recommended)

This is the **exact same environment** as GitHub Actions:

```bash
# Test the Linux build
make test-linux

# Or run directly:
./test-linux-build.sh
```

This will:
- Use the same Swift 6.0 Linux container as GitHub Actions
- Show you the exact errors you'd see in CI/CD
- No need to push to GitHub to test!

### Option 2: Use GitHub Actions Locally

Install [act](https://github.com/nektos/act) to run GitHub Actions locally:

```bash
# Install act
brew install act

# Run the build-linux job locally
act -j build-linux
```

### Option 3: Enable Strict Concurrency in Xcode

We already added this to `Package.swift`:

```swift
.enableExperimentalFeature("StrictConcurrency")
```

However, this **won't catch all Linux-specific issues** because:
- Platform differences (Glibc vs Darwin)
- Different default thread safety models
- Missing APIs on Linux

## Recommended Workflow

1. **Develop on macOS**: Use Xcode as normal
2. **Before committing**: Run `make test-linux` to catch Linux errors
3. **Fix any errors** that show up
4. **Commit and push**: Now you're confident it will work!

## Common Linux-Specific Issues

### 1. `stdout` concurrency errors
**macOS**: Compiles fine
**Linux**: `error: reference to var 'stdout' is not concurrency-safe`

**Fix**: Use `nonisolated(unsafe) let stdoutPtr = stdout`

### 2. Missing `FoundationNetworking`
**macOS**: URLSession is in Foundation
**Linux**: URLSession needs `import FoundationNetworking`

**Fix**:
```swift
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
```

### 3. Missing `readpassphrase` on Linux
**macOS**: Has `readpassphrase()` function
**Linux**: Doesn't have this function

**Fix**: Use platform-specific code with `#if os(Linux)`

## Quick Reference

```bash
# Build on macOS
swift build

# Test on Linux (with Docker)
make test-linux

# Install locally
make install

# Clean build
make clean
```

## Requirements

- **Docker Desktop** must be running for `make test-linux`
- Or install `act` for local GitHub Actions testing
