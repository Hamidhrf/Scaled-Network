#!/usr/bin/env bash
set -euo pipefail

# Peering Configuration Manager
# This script helps manage which clients should peer to the hub

PEERING_CONFIG_FILE="./shared/peering-config.txt"
HUB="client26"

usage() {
    cat << EOF
Usage: $0 <command> [arguments]

Commands:
    init                    Initialize with default peering (clients 1-10)
    show                    Show current peering configuration
    add <client_name>       Add a client to peer with hub
    remove <client_name>    Remove a client from peering
    set <client_list>       Set complete list of clients (space-separated)
    validate                Validate current configuration
    apply                   Apply configuration (restart affected containers)

Examples:
    $0 init
    $0 show
    $0 add client11
    $0 remove client5
    $0 set "client1 client2 client3 client26 client27"
    $0 apply

EOF
}

init_config() {
    local default_peers="client1 client2 client3 client4 client5 client6 client7 client8 client9 client10"
    echo "$default_peers" > "$PEERING_CONFIG_FILE"
    echo "Initialized peering configuration with: $default_peers"
}

show_config() {
    if [[ ! -f "$PEERING_CONFIG_FILE" ]]; then
        echo "No peering configuration found. Run '$0 init' first."
        return 1
    fi
    
    echo "Current peering configuration:"
    echo "Hub: $HUB"
    echo -n "Peers: "
    cat "$PEERING_CONFIG_FILE"
}

add_client() {
    local client="$1"
    if [[ ! -f "$PEERING_CONFIG_FILE" ]]; then
        init_config
    fi
    
    local current_peers=$(cat "$PEERING_CONFIG_FILE")
    if echo "$current_peers" | grep -q "\b$client\b"; then
        echo "$client is already in the peering configuration"
        return 0
    fi
    
    echo "$current_peers $client" > "$PEERING_CONFIG_FILE"
    echo "Added $client to peering configuration"
}

remove_client() {
    local client="$1"
    if [[ ! -f "$PEERING_CONFIG_FILE" ]]; then
        echo "No peering configuration found"
        return 1
    fi
    
    local current_peers=$(cat "$PEERING_CONFIG_FILE")
    local new_peers=$(echo "$current_peers" | sed "s/\b$client\b//g" | tr -s ' ' | sed 's/^ *//;s/ *$//')
    
    echo "$new_peers" > "$PEERING_CONFIG_FILE"
    echo "Removed $client from peering configuration"
}

set_config() {
    local new_peers="$*"
    echo "$new_peers" > "$PEERING_CONFIG_FILE"
    echo "Set peering configuration to: $new_peers"
}

validate_config() {
    if [[ ! -f "$PEERING_CONFIG_FILE" ]]; then
        echo "ERROR: No peering configuration found"
        return 1
    fi
    
    local peers=$(cat "$PEERING_CONFIG_FILE")
    echo "Validating configuration..."
    echo "Hub: $HUB"
    echo "Peers: $peers"
    
    # Check if hub is not in peers list
    if echo "$peers" | grep -q "\b$HUB\b"; then
        echo "WARNING: Hub $HUB should not be in the peers list (it will be ignored)"
    fi
    
    # Validate client naming
    for peer in $peers; do
        if [[ ! "$peer" =~ ^client[0-9]+$ ]]; then
            echo "WARNING: $peer doesn't follow client naming convention"
        fi
    done
    
    echo "Configuration validation completed"
}

apply_config() {
    if [[ ! -f "$PEERING_CONFIG_FILE" ]]; then
        echo "ERROR: No peering configuration found. Run '$0 init' first."
        return 1
    fi
    
    echo "This will restart the affected containers to apply the new peering configuration."
    echo "Current configuration:"
    show_config
    echo
    read -p "Continue? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled"
        return 0
    fi
    
    local peers=$(cat "$PEERING_CONFIG_FILE")
    echo "Applying configuration..."
    
    # Copy config file to shared directory so containers can access it
    #cp "$PEERING_CONFIG_FILE" "./shared/peering-config.txt"
    
    # Restart hub first
    echo "Restarting hub: $HUB"
    docker restart "clab-frr01-$HUB" 2>/dev/null || echo "Could not restart $HUB (container may not exist)"
    
    # Wait a bit for hub to come up
    sleep 10
    
    # Restart peer clients
    for peer in $peers; do
        if [[ "$peer" != "$HUB" ]]; then
            echo "Restarting peer: $peer"
            docker restart "clab-frr01-$peer" 2>/dev/null || echo "Could not restart $peer (container may not exist)"
            sleep 2  # Small delay between restarts
        fi
    done
    
    echo "Configuration applied. Monitor container logs for peering status."
}

# Main script logic
case "${1:-}" in
    init)
        init_config
        ;;
    show)
        show_config
        ;;
    add)
        if [[ $# -ne 2 ]]; then
            echo "ERROR: add command requires client name"
            usage
            exit 1
        fi
        add_client "$2"
        ;;
    remove)
        if [[ $# -ne 2 ]]; then
            echo "ERROR: remove command requires client name"
            usage
            exit 1
        fi
        remove_client "$2"
        ;;
    set)
        if [[ $# -lt 2 ]]; then
            echo "ERROR: set command requires client list"
            usage
            exit 1
        fi
        shift  
        set_config "$@"
        ;;
    validate)
        validate_config
        ;;
    apply)
        apply_config
        ;;
    *)
        usage
        exit 1
        ;;
esac