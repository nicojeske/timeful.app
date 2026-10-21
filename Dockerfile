# All-in-one image: Go server with the built frontend baked in.
# Used by .github/workflows/upstream-sync.yml; compose.yaml still uses the
# per-service Dockerfiles in frontend/ and server/.

# Frontend build stage
FROM node:18-alpine AS frontend

WORKDIR /app

# Copy package files
COPY frontend/package*.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY frontend/ .

# Build arguments for frontend configuration
ARG VUE_APP_POSTHOG_API_KEY=""
ARG VUE_APP_GOOGLE_CLIENT_ID=""
ARG VUE_APP_MICROSOFT_CLIENT_ID=""

ENV VUE_APP_POSTHOG_API_KEY=$VUE_APP_POSTHOG_API_KEY
ENV VUE_APP_GOOGLE_CLIENT_ID=$VUE_APP_GOOGLE_CLIENT_ID
ENV VUE_APP_MICROSOFT_CLIENT_ID=$VUE_APP_MICROSOFT_CLIENT_ID

RUN npm run build

# Server build stage
FROM golang:1.25-alpine AS server

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache git

# Copy all source code
COPY server/ .

# Download dependencies and build
RUN go build -buildvcs=false -o server .

# Runtime stage
FROM alpine:3.23

WORKDIR /app

# Install runtime dependencies
RUN apk add --no-cache ca-certificates tzdata

# Create non-root user
RUN adduser -D -g '' appuser

# Copy binary and frontend (server looks for ./frontend/dist)
COPY --from=server /app/server .
COPY --from=frontend /app/dist ./frontend/dist

# Create logs directory
RUN mkdir -p /app/logs && chown -R appuser:appuser /app

USER appuser

EXPOSE 3002

# Run in release mode
CMD ["./server", "-release=true"]
