#!/usr/bin/env python3
"""
Simple TCP test server for BAR Live Data Export Widget
Listens for connections and logs received data
"""

import socket
import threading
import time
import json

class TestServer:
    def __init__(self, host='127.0.0.1', port=9876):
        self.host = host
        self.port = port
        self.server_socket = None
        self.running = False
        self.client_socket = None
        self.client_address = None

    def start(self):
        """Start the test server"""
        self.server_socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server_socket.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            self.server_socket.bind((self.host, self.port))
            self.server_socket.listen(1)
            self.running = True
            print(f"Test server listening on {self.host}:{self.port}")
            print("Waiting for BAR widget connection...")

            # Start accept thread
            accept_thread = threading.Thread(target=self._accept_loop)
            accept_thread.daemon = True
            accept_thread.start()

        except Exception as e:
            print(f"Failed to start server: {e}")
            return False

        return True

    def stop(self):
        """Stop the test server"""
        self.running = False
        if self.client_socket:
            self.client_socket.close()
        if self.server_socket:
            self.server_socket.close()
        print("Test server stopped")

    def _accept_loop(self):
        """Accept incoming connections"""
        while self.running:
            try:
                self.server_socket.settimeout(1.0)  # Check running flag periodically
                client_socket, client_address = self.server_socket.accept()
                self.client_socket = client_socket
                self.client_address = client_address
                print(f"Connected to BAR widget at {client_address}")

                # Start receive thread
                receive_thread = threading.Thread(target=self._receive_loop)
                receive_thread.daemon = True
                receive_thread.start()

            except socket.timeout:
                continue
            except Exception as e:
                if self.running:
                    print(f"Accept error: {e}")
                break

    def _receive_loop(self):
        """Receive and process data from client"""
        buffer = ""
        packet_count = 0

        while self.running and self.client_socket:
            try:
                data = self.client_socket.recv(4096)
                if not data:
                    print("Client disconnected")
                    break

                buffer += data.decode('utf-8', errors='ignore')

                # Process complete packets (newline delimited)
                while '\n' in buffer:
                    line, buffer = buffer.split('\n', 1)
                    if line.strip():
                        packet_count += 1
                        try:
                            packet = json.loads(line)
                            print(f"Packet {packet_count}: Frame {packet.get('game_frame', 'N/A')}, "
                                  f"{len(packet.get('units', []))} units")
                        except json.JSONDecodeError as e:
                            print(f"Invalid JSON in packet {packet_count}: {e}")
                            print(f"Raw data: {line[:100]}...")

            except Exception as e:
                print(f"Receive error: {e}")
                break

        print(f"Total packets received: {packet_count}")

def main():
    server = TestServer()

    try:
        if server.start():
            print("\nCommands:")
            print("  'status' - Show connection status")
            print("  'quit' - Stop server")
            print("")

            while True:
                cmd = input().strip().lower()
                if cmd == 'quit':
                    break
                elif cmd == 'status':
                    if server.client_socket:
                        print(f"Connected to: {server.client_address}")
                    else:
                        print("No client connected")
                else:
                    print("Unknown command")

    except KeyboardInterrupt:
        print("\nInterrupted by user")
    finally:
        server.stop()

if __name__ == "__main__":
    main()