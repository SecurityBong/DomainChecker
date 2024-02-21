#!/bin/bash

# Function to check if a domain is accessible
check_domain() {
    local domain="$1"
    local response=$(curl -s -o /dev/null -w "%{url_effective} %{http_code}" -L "$domain")
    local http_code=$(echo "$response" | awk '{print $NF}')
    local final_url=$(echo "$response" | awk '{$NF=""; print $0}')
    
    # Check if curl command failed
    if [ $? -ne 0 ]; then
        echo -e "\033[0;31m[$domain] is not accessible (Failed to fetch)\033[0m"
        return
    fi

    if [ "$http_code" = "200" ]; then
        echo -e "\033[0;32m[$domain] is accessible at $final_url\033[0m"
    elif [ "$http_code" -ge 300 ] && [ "$http_code" -lt 400 ]; then
        echo -e "\033[0;33m[$domain] is redirected to $final_url\033[0m"
        check_domain "$final_url"
    else
        echo -e "\033[0;31m[$domain] is not accessible (HTTP $http_code)\033[0m"
    fi
}

export -f check_domain  # Export the function

# Function to check if parallel is installed
check_parallel() {
    if ! command -v parallel &>/dev/null; then
        echo "Error: GNU parallel is not installed."
        read -p "Do you want to install it now? (y/n): " choice
        if [ "$choice" == "y" ]; then
            if [ "$(uname -s)" == "Linux" ]; then
                echo "Installing GNU parallel..."
                if [ -f /etc/debian_version ]; then
                    sudo apt-get install -y parallel
                elif [ -f /etc/redhat-release ]; then
                    sudo yum install -y parallel
                else
                    echo "Unsupported Linux distribution. Please install GNU parallel manually."
                    exit 1
                fi
            else
                echo "Unsupported operating system. Please install GNU parallel manually."
                exit 1
            fi
        else
            echo "Please install GNU parallel and rerun the script."
            exit 1
        fi
    fi
}

# Main function for processing input
main() {
    local parallelism=20  # Default value for parallelism
    local serial=1

    # Check if parallel is installed
    check_parallel

    # Determine the path to the domains.txt file
    local domains_file="${1:-domains.txt}"

    echo "------------------------------------"
    echo "|         DomainChecker            |"
    echo "|             from SecurityBong    |"
    echo "------------------------------------"

    if [ ! -f "$domains_file" ]; then
        echo "Error: $domains_file not found."
        exit 1
    fi

    echo "Checking domains..."

    # Increase maximum number of open files for better performance
    ulimit -n 8192

    # Use GNU parallel for faster processing
    cat "$domains_file" | parallel -j"$parallelism" --tag check_domain {}
}

# Call the main function with the provided argument or default to domains.txt
main "$@"
