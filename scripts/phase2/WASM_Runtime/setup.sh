#!/bin/bash
set -e

# Color coding for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    log_error "Please do not run this script as root or with sudo"
fi

# Install Rust if not installed
if ! command -v rustc &> /dev/null; then
    echo "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    
    # Add wasm32-unknown-unknown target
    rustup target add wasm32-unknown-unknown
fi

# Create project structure
mkdir -p src/hello_wasm/src
mkdir -p build
mkdir -p k8s

# Initialize Rust project
cd src/hello_wasm

# Create Cargo.toml
cat > Cargo.toml << 'EOF'
[package]
name = "hello_wasm"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib"]

[dependencies]
wasm-bindgen = "0.2"
console_error_panic_hook = "0.1.7"

EOF

# Create the Rust source file
cat > src/lib.rs << 'EOF'
use wasm_bindgen::prelude::*;
use std::net::{TcpListener, TcpStream};
use std::io::{Read, Write};

#[wasm_bindgen]
pub fn init_panic_hook() {
    console_error_panic_hook::set_once();
}

fn handle_client(mut stream: TcpStream) {
    let mut buffer = [0; 1024];
    stream.read(&mut buffer).unwrap();

    let response = "HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\n\r\nHello from WebAssembly!";
    stream.write(response.as_bytes()).unwrap();
    stream.flush().unwrap();
}

#[wasm_bindgen(start)]
pub fn main() {
    println!("Starting HTTP server on port 8080...");
    let listener = TcpListener::bind("0.0.0.0:8080").unwrap();

    for stream in listener.incoming() {
        match stream {
            Ok(stream) => {
                println!("New connection established!");
                handle_client(stream);
            }
            Err(e) => {
                println!("Error: {}", e);
            }
        }
    }
}


EOF

log_success "Project structure created successfully!" 