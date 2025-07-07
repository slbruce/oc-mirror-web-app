#!/bin/bash

# OC Mirror v2 Web Application - Containerized Runner
# This script runs the application in a container without requiring any host installations
# Supports both Docker and Podman

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect container runtime (Docker or Podman)
detect_container_runtime() {
    if command -v docker &> /dev/null && docker info &> /dev/null; then
        CONTAINER_ENGINE="docker"
        print_success "Using Docker as container runtime"
    elif command -v podman &> /dev/null && podman info &> /dev/null; then
        CONTAINER_ENGINE="podman"
        print_success "Using Podman as container runtime"
    else
        print_error "Neither Docker nor Podman is available or running."
        print_error "Please install Docker or Podman and try again."
        exit 1
    fi
}

# Check if container runtime is available
check_container_runtime() {
    detect_container_runtime
    
    if ! $CONTAINER_ENGINE info &> /dev/null; then
        print_error "$CONTAINER_ENGINE is not running or you don't have permission to use it."
        print_error "Please start $CONTAINER_ENGINE and ensure you have proper permissions."
        exit 1
    fi
    
    print_success "$CONTAINER_ENGINE is available and running"
}

# Create necessary directories
create_directories() {
    print_status "Creating data directories..."
    
    mkdir -p data/configs
    mkdir -p data/operations
    mkdir -p data/logs
    mkdir -p data/cache
    
    # Fix permissions for nodejs user (UID 1001)
    print_status "Setting proper permissions for container user..."
    chmod -R 755 data/
    chown -R 1001:1001 data/ 2>/dev/null || {
        print_warning "Could not change ownership (may need sudo). Trying alternative approach..."
        # Alternative: make directories writable by all
        chmod -R 777 data/
    }
    
    print_success "Data directories created with proper permissions"
}

# Build the container image
build_image() {
    print_status "Building container image with $CONTAINER_ENGINE..."
    
    # Build for native architecture (do not force amd64)
    if [ "$CONTAINER_ENGINE" = "podman" ] || [ "$CONTAINER_ENGINE" = "docker" ]; then
        if $CONTAINER_ENGINE build -t oc-mirror-web-app .; then
            print_success "Container image built successfully (native arch)"
        else
            print_error "Failed to build container image (native arch)"
            exit 1
        fi
    else
        print_error "Unsupported container engine: $CONTAINER_ENGINE"
        exit 1
    fi
}

# Run the container
run_container() {
    print_status "Starting OC Mirror Web Application container with $CONTAINER_ENGINE..."
    
    # Check if container is already running
    if $CONTAINER_ENGINE ps --format "table {{.Names}}" | grep -q "oc-mirror-web-app"; then
        print_warning "Container is already running. Stopping it first..."
        $CONTAINER_ENGINE stop oc-mirror-web-app
        $CONTAINER_ENGINE rm oc-mirror-web-app
    fi
    
    # Run the container
    $CONTAINER_ENGINE run -d \
        --name oc-mirror-web-app \
        -p 3000:3001 \
        -v "$(pwd)/data:/app/data" \
        -v "$(pwd)/pull-secret/pull-secret.json:/app/pull-secret.json:ro" \
        -e NODE_ENV=production \
        -e PORT=3001 \
        -e STORAGE_DIR=/app/data \
        --restart unless-stopped \
        oc-mirror-web-app
    
    print_success "Container started successfully"
}

# Show status
show_status() {
    echo ""
    echo "=========================================="
    echo "  OC Mirror v2 Web Application"
    echo "=========================================="
    echo ""
    print_success "Application is running!"
    echo ""
    echo "🌐 Web Interface: http://localhost:3000"
    echo "🔧 API Server: http://localhost:3001"
    echo ""
    echo "📁 Data Directory: $(pwd)/data"
    echo "📋 Container Name: oc-mirror-web-app"
    echo "🔧 Container Engine: $CONTAINER_ENGINE"
    echo ""
    echo "📊 Container Status:"
    $CONTAINER_ENGINE ps --filter "name=oc-mirror-web-app" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    echo "📝 Useful Commands:"
    echo "  View logs:     $CONTAINER_ENGINE logs -f oc-mirror-web-app"
    echo "  Stop app:      $CONTAINER_ENGINE stop oc-mirror-web-app"
    echo "  Remove app:    $CONTAINER_ENGINE rm oc-mirror-web-app"
    echo "  Shell access:  $CONTAINER_ENGINE exec -it oc-mirror-web-app /bin/sh"
    echo ""
}

# Fix permissions for existing installations
fix_permissions() {
    print_status "Checking and fixing data directory permissions..."
    
    if [ -d "data" ]; then
        # Try to change ownership to nodejs user (UID 1001)
        if chown -R 1001:1001 data/ 2>/dev/null; then
            chmod -R 755 data/
            print_success "Permissions fixed successfully"
        else
            print_warning "Could not change ownership. Making directories world-writable..."
            chmod -R 777 data/
            print_success "Made directories world-writable"
        fi
    fi
}

# Main execution
main() {
    echo "=========================================="
    echo "  OC Mirror v2 Web Application"
    echo "  Containerized Runner"
    echo "=========================================="
    echo ""
    
    check_container_runtime
    create_directories
    fix_permissions
    build_image
    run_container
    show_status
}

# Handle script arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --build-only   Only build the container image"
        echo "  --run-only     Only run the container (assumes image exists)"
        echo "  --stop         Stop and remove the container"
        echo "  --logs         Show container logs"
        echo "  --engine       Show detected container engine"
        echo ""
        echo "Examples:"
        echo "  $0              # Build and run the application"
        echo "  $0 --build-only # Only build the image"
        echo "  $0 --stop       # Stop the application"
        echo "  $0 --logs       # View application logs"
        echo ""
        echo "Container Engine Support:"
        echo "  - Docker (if available)"
        echo "  - Podman (if available)"
        exit 0
        ;;
    --build-only)
        check_container_runtime
        build_image
        print_success "Image built successfully. Run with: $0 --run-only"
        exit 0
        ;;
    --run-only)
        check_container_runtime
        run_container
        show_status
        exit 0
        ;;
    --stop)
        detect_container_runtime
        print_status "Stopping and removing container..."
        $CONTAINER_ENGINE stop oc-mirror-web-app 2>/dev/null || true
        $CONTAINER_ENGINE rm oc-mirror-web-app 2>/dev/null || true
        print_success "Container stopped and removed"
        exit 0
        ;;
    --logs)
        detect_container_runtime
        $CONTAINER_ENGINE logs -f oc-mirror-web-app
        exit 0
        ;;
    --engine)
        detect_container_runtime
        echo "Detected container engine: $CONTAINER_ENGINE"
        exit 0
        ;;
    *)
        main
        ;;
esac 