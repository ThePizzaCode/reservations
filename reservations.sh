#!/bin/bash

DB_FILE="../reservations/train_reservations.db"

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
        echo "error,not enough available seats for train $train_id"
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
    train_ids=($@)
    response=()

    for train_id in ${train_ids[@]}; do
        available_seats=$(check_available_seats "$train_id")
        if [[ -z "$available_seats" ]]; then
            response+=("-")
        else
            response+=("$available_seats")
        fi
    done

    echo ${response[@]}
}


initialize_db

handle_request() {
    IFS="," read -r -a request <<< "$1"
    
    endpoint=${request[0]}

    case $endpoint in
        avail)
            id=${request[1]}
            response=$(check_available_seats $id)
            if [[ -z $response ]] then 
                echo "error,train_id not found"
            else 
                echo $response 
            fi
            ;;

        reserve)
            user_id=${request[1]}
            train_id=${request[2]}
            no_of_seats=${request[3]}

            response=$(reserve_seats $user_id $train_id $no_of_seats)
            echo $response
            ;;

        avail_multi)
            train_ids=${request[@]:1}
            response_array=($(send_available_seats_to_train_ops ${request[@]:1}))

            response=$(printf "%s," "${response_array[@]}")
            response=${response%,} 

            echo $response
            ;;

        *)
            echo 404;;
    esac

    echo CLOSE
}

handle_request "$1"