#!/bin/bash

# Define the SQLite database file
DB_FILE="train_reservations.db"

# Function to initialize the database schema
initialize_db() {
    sqlite3 $DB_FILE "CREATE TABLE IF NOT EXISTS reservations (
        id INTEGER PRIMARY KEY,
        user_id INTEGER NOT NULL,
        train_id INTEGER NOT NULL,
        reserved_seats INTEGER NOT NULL,
        reservation_date TEXT NOT NULL
    );"
    
    sqlite3 $DB_FILE "CREATE TABLE IF NOT EXISTS available_seats (
        train_id INTEGER PRIMARY KEY,
        available_seats INTEGER NOT NULL
    );"
}

# Function to communicate with the user microservice (stub function for illustration)
get_user_details() {
    user_id=$1
    # Simulate getting user details from the user microservice
    # In a real-world scenario, replace this with actual socket communication
    echo "Getting details for user ID: $user_id"
    echo "User $user_id: John Doe"
}

# Function to retrieve all trains (example socket communication, replace with actual)
get_all_trains() {
    # Simulate the retrieval of all trains from another microservice
    echo "Fetching all trains from the microservice..."
    echo "Train 1, Train 2, Train 3"
}

# Function to check available seats for a specific train
check_available_seats() {
    train_id=$1
    # Only return the numeric value (available_seats), stripping out extra text
    available_seats=$(sqlite3 $DB_FILE "SELECT available_seats FROM available_seats WHERE train_id = $train_id;")
    
    # Check if the query returned a result
    if [[ -z "$available_seats" ]]; then
        echo "No available seats found for train $train_id."
        return 1
    fi

    # Return the numeric value of available seats
    echo "$available_seats"
}

# Function to reserve seats for a user on a specific train
reserve_seats() {
    user_id=$1
    train_id=$2
    requested_seats=$3

    # Get the available seats
    available_seats=$(check_available_seats $train_id)
    
    # If there are not enough available seats, return an error
    if [[ $available_seats -lt $requested_seats ]]; then
        echo "Not enough available seats on train $train_id."
        return 1
    fi

    # Reserve the seats by adding an entry into the reservations table
    reservation_date=$(date "+%Y-%m-%d %H:%M:%S")
    sqlite3 $DB_FILE "INSERT INTO reservations (user_id, train_id, reserved_seats, reservation_date) 
                      VALUES ($user_id, $train_id, $requested_seats, '$reservation_date');"

    # Update the available seats in the available_seats table
    new_available_seats=$((available_seats - requested_seats))
    sqlite3 $DB_FILE "UPDATE available_seats SET available_seats = $new_available_seats WHERE train_id = $train_id;"

    echo "Successfully reserved $requested_seats seats for user $user_id on train $train_id."
}

# Function to reset available seats for a train after the trip
reset_available_seats() {
    train_id=$1
    # Fetch the total capacity for the train from the database
    total_seats=$(sqlite3 $DB_FILE "SELECT Capacity FROM available_seats WHERE train_id = $train_id;")
    
    if [[ -z "$total_seats" ]]; then
        echo "No capacity found for train $train_id. Cannot reset available seats."
        return 1
    fi

    # Reset available seats to the total capacity
    sqlite3 $DB_FILE "UPDATE available_seats SET available_seats = $total_seats WHERE train_id = $train_id;"
    echo "Available seats for train $train_id have been reset to $total_seats."
}

# Example: Making a reservation (replace with actual dynamic input or requests)
user_id=1
train_id=6969
requested_seats=10

# Reserve seats for the user
reserve_seats $user_id $train_id $requested_seats

# Reset the available seats after the trip (optional)
reset_available_seats $train_id
