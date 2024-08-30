import socket


def start_tcp_listener(host='127.0.0.1', port=6969):
    try:
        # Create a TCP/IP socket
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as server_socket:
            # Bind the socket to the address and port
            server_socket.bind((host, port))
            print(f"Listening on {host}:{port}")

            # Listen for incoming connections
            server_socket.listen(5)  # The number '5' is the backlog size

            while True:
                # Wait for a connection
                client_socket, client_address = server_socket.accept()
                with client_socket:
                    print(f"Connection from {client_address}")

                    while True:
                        # Receive data from the client
                        data = client_socket.recv(1024)
                        if not data:
                            break

                        # Log the received data
                        print(f"Received bytes: {data}")

                    print(f"Connection from {client_address} closed.")

    except KeyboardInterrupt:
        print("\nServer shutting down.")
    except Exception as e:
        print(f"Error: {e}")


if __name__ == "__main__":
    start_tcp_listener()
