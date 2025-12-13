.PHONY: build run install clean test-linux help

help:
	@echo "Available commands:"
	@echo "  make build       - Build the client"
	@echo "  make run         - Run the client"
	@echo "  make install     - Install to /usr/local/bin"
	@echo "  make test-linux  - Test Linux build with Docker (catches Linux-specific errors)"
	@echo "  make clean       - Clean build artifacts"

build:
	swift build -c release

run:
	swift run term-beam

install: build
	cp .build/release/term-beam /usr/local/bin/term-beam
	@echo "✅ Installed to /usr/local/bin/term-beam"
	@echo "You can now run: term-beam"

test-linux:
	@./test-linux-build.sh

clean:
	swift package clean