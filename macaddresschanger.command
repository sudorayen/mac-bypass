
#!/bin/bash

INTERFACE=$(networksetup -listallhardwareports | awk '/Hardware Port: Wi-Fi/{getline; print $2}')
ORIGINAL_MAC=$(ifconfig "$INTERFACE" | awk '/ether/{print $2; exit}')

while true; do
    clear
    echo "1) Change MAC Address"
    echo "2) Back to Default"
    echo "3) Exit"
    echo ""
    read -p "Select an option: " choice

    case "$choice" in
        1)
            NEW_MAC=$(openssl rand -hex 6 | sed 's/\(..\)/\1:/g; s/:$//')
            NEW_MAC="02${NEW_MAC:2}"
            echo ""
            echo "New MAC: $NEW_MAC"
            sudo ifconfig "$INTERFACE" down
            sudo ifconfig "$INTERFACE" ether "$NEW_MAC"
            sudo ifconfig "$INTERFACE" up
            echo "MAC address changed."
            read -p "Press Enter to continue..."
            ;;
        2)
            echo ""
            echo "Restoring hardware MAC address..."
            sudo ifconfig "$INTERFACE" down
            sudo ifconfig "$INTERFACE" ether "$ORIGINAL_MAC"
            sudo ifconfig "$INTERFACE" up
            echo "Restored to: $ORIGINAL_MAC"
            read -p "Press Enter to continue..."
            ;;
        3)
            exit 0
            ;;
        *)
            echo "Invalid option."
            sleep 1
            ;;
    esac
done
