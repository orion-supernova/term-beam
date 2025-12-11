.PHONY: build run install clean help

help:
	@echo "Available commands:"
	@echo "  make build    - Build the client"
	@echo "  make run      - Run the client"
	@echo "  make install  - Install to /usr/local/bin"
	@echo "  make clean    - Clean build artifacts"

build:
	swift build -c release

run:
	swift run ChatClient

install: build
	cp .build/release/ChatClient /usr/local/bin/chat-client
	@echo "✅ Installed to /usr/local/bin/chat-client"
	@echo "You can now run: chat-client --username yourname"

clean:
	swift package clean