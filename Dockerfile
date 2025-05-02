# Stage 1: Download and extract Go 1.24.2
FROM debian:bookworm-slim AS go-downloader
RUN apt-get update && apt-get install -y curl tar
WORKDIR /tmp
RUN curl -sSL https://go.dev/dl/go1.24.2.linux-amd64.tar.gz -o go.tar.gz && \
    tar -C /usr/local -xzf go.tar.gz

# Stage 2: Build Go binary
FROM debian:bookworm-slim AS go-builder
COPY --from=go-downloader /usr/local/go /usr/local/go
ENV PATH="/usr/local/go/bin:${PATH}"
RUN apt-get update && apt-get install -y git gcc

WORKDIR /app
COPY whatsapp-bridge/ .
# Run go mod tidy first to update dependencies
RUN go mod tidy
RUN CGO_ENABLED=1 go build -o whatsapp-bridge main.go

# Stage 3: Final image
FROM python:3.10-slim

RUN apt-get update && apt-get install -y \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Install required Python packages directly
RUN pip install --upgrade pip setuptools
RUN pip install mcp fastapi uvicorn pydantic requests

WORKDIR /app

# Copy the Go bridge executable
COPY --from=go-builder /app/whatsapp-bridge /app/whatsapp-bridge
COPY whatsapp-mcp-server/ /app/whatsapp-mcp-server/

# Create a startup script
RUN echo '#!/bin/bash\n\
mkdir -p /app/data/store\n\
cd /app\n\
./whatsapp-bridge &\n\
cd /app/whatsapp-mcp-server\n\
python main.py\n\
' > /app/start.sh && chmod +x /app/start.sh

# Expose the port
EXPOSE 8080

# Run the startup script
CMD ["/app/start.sh"]
