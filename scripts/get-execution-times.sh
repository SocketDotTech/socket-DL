#!/bin/bash

# Socket DL Message Execution Time Analyzer
# Usage: ./scripts/get-execution-times.sh <messageId1> <messageId2> ...
# Example: ./scripts/get-execution-times.sh 0x000021053eb5b734ad67de2af9fb43a4bf1d676d50256d050000000000025990

set -e

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

# Configuration
DL_API="https://prod.dlapi.socket.tech/message"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to get timestamp from transaction receipt
get_timestamp() {
    local tx_hash=$1
    local rpc_url=$2

    # Get receipt
    local receipt=$(cast receipt "$tx_hash" --rpc-url "$rpc_url" --json 2>/dev/null)

    if [ ! -z "$receipt" ]; then
        # Try to get blockTimestamp from logs (Lyra format)
        local timestamp_hex=$(echo "$receipt" | jq -r '.logs[0].blockTimestamp // empty' 2>/dev/null)

        # If not found, get from block
        if [ -z "$timestamp_hex" ] || [ "$timestamp_hex" = "null" ]; then
            local block_num=$(echo "$receipt" | jq -r '.blockNumber' 2>/dev/null)
            if [ ! -z "$block_num" ] && [ "$block_num" != "null" ]; then
                timestamp_hex=$(cast block "$block_num" --rpc-url "$rpc_url" --json 2>/dev/null | jq -r '.timestamp' 2>/dev/null)
            fi
        fi

        if [ ! -z "$timestamp_hex" ] && [ "$timestamp_hex" != "null" ]; then
            # Convert hex to decimal
            local timestamp_dec=$(cast to-dec "$timestamp_hex" 2>/dev/null)
            echo "$timestamp_dec"
            return 0
        fi
    fi
    echo ""
    return 1
}

# Function to get RPC URL for a chain slug
get_rpc_url() {
    local chain_slug=$1
    case "$chain_slug" in
        "8453")
            echo "$BASE_RPC"
            ;;
        "42161")
            echo "$ARBITRUM_RPC"
            ;;
        "957")
            echo "$LYRA_RPC"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Function to get chain name from slug
get_chain_name() {
    local chain_slug=$1
    case "$chain_slug" in
        "8453")
            echo "Base"
            ;;
        "42161")
            echo "Arbitrum"
            ;;
        "957")
            echo "Lyra"
            ;;
        *)
            echo "Unknown"
            ;;
    esac
}

# Function to process a single message
process_message() {
    local message_id=$1

    echo -e "${BLUE}Processing: ${message_id}${NC}"

    # Fetch message details from DL API
    local response=$(curl -s "${DL_API}?messageId=${message_id}")

    # Check if request was successful
    local status=$(echo "$response" | jq -r '.status' 2>/dev/null)
    if [ "$status" != "SUCCESS" ]; then
        echo -e "${RED}  ✗ Failed to fetch message details${NC}"
        return 1
    fi

    # Extract details
    local src_chain_slug=$(echo "$response" | jq -r '.result.from.srcChainSlug')
    local dest_chain_slug=$(echo "$response" | jq -r '.result.to.destChainSlug')
    local outbound_tx=$(echo "$response" | jq -r '.result.outboundTx')
    local inbound_tx=$(echo "$response" | jq -r '.result.inboundTx')
    local exec_status=$(echo "$response" | jq -r '.result.status')

    # Get chain names
    local src_chain=$(get_chain_name "$src_chain_slug")
    local dest_chain=$(get_chain_name "$dest_chain_slug")

    echo -e "  Route: ${src_chain} (${src_chain_slug}) → ${dest_chain} (${dest_chain_slug})"
    echo -e "  Status: ${exec_status}"

    # Check if execution was successful
    if [ "$exec_status" != "EXECUTION_SUCCESS" ]; then
        echo -e "${YELLOW}  ⚠ Message not successfully executed${NC}"
        return 0
    fi

    # Get RPC URLs
    local src_rpc=$(get_rpc_url "$src_chain_slug")
    local dest_rpc=$(get_rpc_url "$dest_chain_slug")

    if [ -z "$src_rpc" ] || [ -z "$dest_rpc" ]; then
        echo -e "${RED}  ✗ Unsupported chain${NC}"
        return 1
    fi

    # Get timestamps
    echo -n "  Fetching outbound timestamp... "
    local outbound_ts=$(get_timestamp "$outbound_tx" "$src_rpc")
    if [ -z "$outbound_ts" ]; then
        echo -e "${RED}FAILED${NC}"
        return 1
    fi
    echo -e "${GREEN}${outbound_ts}${NC}"

    echo -n "  Fetching inbound timestamp...  "
    local inbound_ts=$(get_timestamp "$inbound_tx" "$dest_rpc")
    if [ -z "$inbound_ts" ]; then
        echo -e "${RED}FAILED${NC}"
        return 1
    fi
    echo -e "${GREEN}${inbound_ts}${NC}"

    # Calculate execution time
    local exec_time=$((inbound_ts - outbound_ts))

    # Format dates
    local outbound_date=$(date -u -d "@$outbound_ts" "+%Y-%m-%d %H:%M:%S UTC" 2>/dev/null || date -u -r "$outbound_ts" "+%Y-%m-%d %H:%M:%S UTC" 2>/dev/null)
    local inbound_date=$(date -u -d "@$inbound_ts" "+%Y-%m-%d %H:%M:%S UTC" 2>/dev/null || date -u -r "$inbound_ts" "+%Y-%m-%d %H:%M:%S UTC" 2>/dev/null)

    # Print result
    echo -e "  ${GREEN}✓ Execution Time: ${exec_time} seconds${NC}"
    echo ""

    # Store for summary (using global array)
    EXEC_TIMES+=("$exec_time")
    RESULTS+=("${src_chain}→${dest_chain}|${exec_time}s|${message_id:0:20}...${message_id: -10}")
}

# Main script
main() {
    if [ $# -eq 0 ]; then
        echo "Usage: $0 <messageId1> [messageId2] [messageId3] ..."
        echo ""
        echo "Example:"
        echo "  $0 0x000021053eb5b734ad67de2af9fb43a4bf1d676d50256d050000000000025990"
        echo ""
        exit 1
    fi

    # Check dependencies
    if ! command -v cast &> /dev/null; then
        echo -e "${RED}Error: 'cast' command not found. Please install foundry.${NC}"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: 'jq' command not found. Please install jq.${NC}"
        exit 1
    fi

    if ! command -v curl &> /dev/null; then
        echo -e "${RED}Error: 'curl' command not found. Please install curl.${NC}"
        exit 1
    fi

    # Check RPC environment variables
    if [ -z "$LYRA_RPC" ]; then
        echo -e "${RED}Error: LYRA_RPC environment variable is not set.${NC}"
        exit 1
    fi

    if [ -z "$ARBITRUM_RPC" ]; then
        echo -e "${RED}Error: ARBITRUM_RPC environment variable is not set.${NC}"
        exit 1
    fi

    if [ -z "$BASE_RPC" ]; then
        echo -e "${RED}Error: BASE_RPC environment variable is not set.${NC}"
        exit 1
    fi

    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Socket DL Message Execution Time Analyzer${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo ""

    # Initialize arrays for results
    declare -a EXEC_TIMES
    declare -a RESULTS

    # Process each message ID
    local success_count=0
    local fail_count=0

    for message_id in "$@"; do
        if process_message "$message_id"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    done

    # Print summary
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Summary${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo ""

    echo "Total Messages: $#"
    echo -e "Successfully Processed: ${GREEN}${success_count}${NC}"
    if [ $fail_count -gt 0 ]; then
        echo -e "Failed: ${RED}${fail_count}${NC}"
    fi
    echo ""

    if [ ${#EXEC_TIMES[@]} -gt 0 ]; then
        echo "Execution Times:"
        for result in "${RESULTS[@]}"; do
            IFS='|' read -r route time msg <<< "$result"
            printf "  %-20s %10s  (%s)\n" "$route" "$time" "$msg"
        done
        echo ""

        # Calculate statistics
        local total=0
        local min=${EXEC_TIMES[0]}
        local max=${EXEC_TIMES[0]}

        for time in "${EXEC_TIMES[@]}"; do
            total=$((total + time))
            if [ $time -lt $min ]; then
                min=$time
            fi
            if [ $time -gt $max ]; then
                max=$time
            fi
        done

        local avg=$((total / ${#EXEC_TIMES[@]}))

        echo "Statistics:"
        echo "  Average: ${avg}s"
        echo "  Min: ${min}s"
        echo "  Max: ${max}s"
    fi
}

# Run main function with all arguments
main "$@"
