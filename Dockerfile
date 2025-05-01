FROM golang:1.20 AS go-builder

# Install required dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY whatsapp-bridge/ .
RUN CGO_ENABLED=1 go build -o whatsapp-bridge main.go

FROM python:3.9-slim

# Install required dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy the Go bridge executable
COPY --from=go-builder /app/whatsapp-bridge /app/whatsapp-bridge
COPY whatsapp-mcp-server/ /app/whatsapp-mcp-server/

# Install Python dependencies
RUN pip install --no-cache-dir -r /app/whatsapp-mcp-server/requirements.txt

# Create a volume for persistent data storage
VOLUME /app/data

# Create a startup script
RUN echo '#!/bin/bash\n\
mkdir -p /app/data/store\n\
cd /app\n\
./whatsapp-bridge &\n\
cd /app/whatsapp-mcp-server\n\
python main.py\n\
' > /app/start.sh && chmod +x /app/start.sh

# Expose the ports
EXPOSE 8080

# Run the startup script
CMD ["/app/start.sh"]
