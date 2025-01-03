#!/bin/bash

DB_FILE="train_reservations.db"
SERVER_PORT=6903
CLIENT_PORT=6904

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

check_available_seats() {
    train_id=$1
    sqlite3 $DB_FILE "SELECT available_seats FROM available_seats WHERE train_id = $train_id;"
}

reserve_seats() {
    user_id=$1
    train_id=$2
    requested_seats=$3

    available_seats=$(check_available_seats "$train_id")

    if [[ -z "$available_seats" || "$available_seats" -lt "$requested_seats" ]]; then
        echo "error,Not enough available seats for train $train_id"
        return
    fi

    reservation_date=$(date "+%Y-%m-%d %H:%M:%S")
    sqlite3 $DB_FILE "INSERT INTO reservations (user_id, train_id, reserved_seats, reservation_date) \
                      VALUES ($user_id, $train_id, $requested_seats, '$reservation_date');"

    new_available_seats=$((available_seats - requested_seats))
    sqlite3 $DB_FILE "UPDATE available_seats SET available_seats = $new_available_seats WHERE train_id = $train_id;"

    echo "success,$user_id,$train_id,$requested_seats,$reservation_date"
}

send_available_seats_to_train_ops() {
    train_ids=$1
    response=""

    for train_id in $(echo "$train_ids" | tr "," " "); do
        available_seats=$(check_available_seats "$train_id")
        if [[ -z "$available_seats" ]]; then
            response+="train_id:$train_id,seats:N/A;"
        else
            response+="train_id:$train_id,seats:$available_seats;"
        fi
    done

    echo "$response" | nc -q 0 127.0.0.1 $CLIENT_PORT
}


initialize_db

handle_request() {
    request=$1
    case $(echo "$request" | cut -d"," -f1) in
        add_reservation)
            user_id=$(echo "$request" | cut -d"," -f2)
            train_id=$(echo "$request" | cut -d"," -f3)
            no_of_seats=$(echo "$request" | cut -d"," -f4)
            response=$(reserve_seats "$user_id" "$train_id" "$no_of_seats")
            echo "$response";;
        get_available_seats)
            train_ids=$(echo "$request" | cut -d"," -f2)
            send_available_seats_to_train_ops "$train_ids";;
        *)
            echo "error,Invalid request";;
    esac
}

while true; do
    echo "Listening on port $SERVER_PORT..."
    nc -lk -p $SERVER_PORT | while read -r request; do
        handle_request "$request"
    done
done
