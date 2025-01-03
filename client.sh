#!/bin/bash

SERVER="127.0.0.1"
SERVER_PORT=6903
CLIENT_PORT=6904

send_train_ops_request() {
    local train_ids=$1

    # Start listening on the CLIENT_PORT in the background for the response
    (nc -l -p $CLIENT_PORT > trainops_response.txt &) &
    listener_pid=$!

    # Send the request to the train reservation service
    echo "$train_ids" | nc $SERVER $SERVER_PORT

    # Wait briefly to ensure the response is captured
    sleep 1

    # Fetch the response from the temporary file
    response=$(cat trainops_response.txt)

    # Clean up
    rm -f trainops_response.txt
    kill $listener_pid

    echo "$response"
}

# Example request
response=$(send_train_ops_request "get_available_seats,6969,1234,1000")
echo "Response: $response"
