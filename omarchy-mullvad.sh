#!/usr/bin/env bash

# Country name to ISO code mapping
declare -A COUNTRY_CODES=(
  ["Albania"]="AL"
  ["Argentina"]="AR"
  ["Australia"]="AU"
  ["Austria"]="AT"
  ["Belgium"]="BE"
  ["Brazil"]="BR"
  ["Bulgaria"]="BG"
  ["Canada"]="CA"
  ["Chile"]="CL"
  ["Colombia"]="CO"
  ["Croatia"]="HR"
  ["Cyprus"]="CY"
  ["Czech Republic"]="CZ"
  ["Denmark"]="DK"
  ["Estonia"]="EE"
  ["Finland"]="FI"
  ["France"]="FR"
  ["Germany"]="DE"
  ["Greece"]="GR"
  ["Hong Kong"]="HK"
  ["Hungary"]="HU"
  ["Indonesia"]="ID"
  ["Ireland"]="IE"
  ["Israel"]="IL"
  ["Italy"]="IT"
  ["Japan"]="JP"
  ["Malaysia"]="MY"
  ["Mexico"]="MX"
  ["Netherlands"]="NL"
  ["New Zealand"]="NZ"
  ["Nigeria"]="NG"
  ["Norway"]="NO"
  ["Peru"]="PE"
  ["Philippines"]="PH"
  ["Poland"]="PL"
  ["Portugal"]="PT"
  ["Romania"]="RO"
  ["Serbia"]="RS"
  ["Singapore"]="SG"
  ["Slovakia"]="SK"
  ["Slovenia"]="SI"
  ["South Africa"]="ZA"
  ["Spain"]="ES"
  ["Sweden"]="SE"
  ["Switzerland"]="CH"
  ["Thailand"]="TH"
  ["Turkey"]="TR"
  ["Ukraine"]="UA"
  ["UK"]="GB"
  ["USA"]="US"
)

# Country flag emojis
declare -A COUNTRY_FLAGS=(
  ["Albania"]="🇦🇱"
  ["Argentina"]="🇦🇷"
  ["Australia"]="🇦🇺"
  ["Austria"]="🇦🇹"
  ["Belgium"]="🇧🇪"
  ["Brazil"]="🇧🇷"
  ["Bulgaria"]="🇧🇬"
  ["Canada"]="🇨🇦"
  ["Chile"]="🇨🇱"
  ["Colombia"]="🇨🇴"
  ["Croatia"]="🇭🇷"
  ["Cyprus"]="🇨🇾"
  ["Czech Republic"]="🇨🇿"
  ["Denmark"]="🇩🇰"
  ["Estonia"]="🇪🇪"
  ["Finland"]="🇫🇮"
  ["France"]="🇫🇷"
  ["Germany"]="🇩🇪"
  ["Greece"]="🇬🇷"
  ["Hong Kong"]="🇭🇰"
  ["Hungary"]="🇭🇺"
  ["Indonesia"]="🇮🇩"
  ["Ireland"]="🇮🇪"
  ["Israel"]="🇮🇱"
  ["Italy"]="🇮🇹"
  ["Japan"]="🇯🇵"
  ["Malaysia"]="🇲🇾"
  ["Mexico"]="🇲🇽"
  ["Netherlands"]="🇳🇱"
  ["New Zealand"]="🇳🇿"
  ["Nigeria"]="🇳🇬"
  ["Norway"]="🇳🇴"
  ["Peru"]="🇵🇪"
  ["Philippines"]="🇵🇭"
  ["Poland"]="🇵🇱"
  ["Portugal"]="🇵🇹"
  ["Romania"]="🇷🇴"
  ["Serbia"]="🇷🇸"
  ["Singapore"]="🇸🇬"
  ["Slovakia"]="🇸🇰"
  ["Slovenia"]="🇸🇮"
  ["South Africa"]="🇿🇦"
  ["Spain"]="🇪🇸"
  ["Sweden"]="🇸🇪"
  ["Switzerland"]="🇨🇭"
  ["Thailand"]="🇹🇭"
  ["Turkey"]="🇹🇷"
  ["Ukraine"]="🇺🇦"
  ["UK"]="🇬🇧"
  ["USA"]="🇺🇸"
)

# --- Handle "status" arg ---
if [[ "$1" == "status" ]]; then
  status_output=$(mullvad status --json)
  state=$(echo "$status_output" | jq -r '.state')
  country=$(echo "$status_output" | jq -r '.details.location.country')

  # Get country code from mapping
  country_code="${COUNTRY_CODES[$country]}"

  if [[ "$state" == "connected" ]]; then
    if [[ -n "$country_code" ]]; then
      echo "{\"text\":\"$country_code\",\"percentage\":100,\"class\":\"connected\",\"icon\":\"🌎\"}"
    else
      echo "{\"text\":\"$country\",\"percentage\":100,\"class\":\"connected\",\"icon\":\"🌎\"}"
    fi
  else
    if [[ -n "$country_code" ]]; then
      echo "{\"text\":\"$country_code\",\"percentage\":0,\"class\":\"disconnected\",\"icon\":\"🌐\"}"
    else
      echo "{\"text\":\"$country\",\"percentage\":0,\"class\":\"disconnected\",\"icon\":\"🌐\"}"
    fi
  fi
  exit 0
fi

# --- Handle "switch" arg ---
if [[ "$1" == "switch" ]]; then
  # Toggle connection
  if [[ "$(mullvad status --json | jq -r '.state')" == "connected" ]]; then
    mullvad disconnect
  else
    mullvad connect
  fi
  exit $?
fi

# --- Handle "setup" arg ---
if [[ "$1" == "setup" ]]; then
  echo ""
  echo "=== Waybar Configuration ==="
  echo ""
  echo "Add this to your waybar config (~/.config/waybar/config):"
  echo ""
  echo '  "custom/mullvad": {'
  echo '    "format": "{icon} {text}",'
  echo '    "return-type": "json",'
  echo '    "interval": 2,'
  echo '    "format-icons": ['
  echo '      "🌐",'
  echo '      "🌍"'
  echo '    ],'
  echo '    "tooltip": false,'
  echo "    \"exec\": \"$0 status\","
  echo "    \"on-click\": \"$0\""
  echo '  },'
  echo ""
  echo "Then add \"custom/mullvad\" to your waybar bar module."
  echo ""
  echo "=== Hyprland Keybinding ==="
  echo ""
  echo "Add this to your hyprland keybindings (~/.config/hypr/hyprland.conf):"
  echo ""
  echo "  bind = SUPER SHIFT, V, mullvad, exec, $0"
  echo ""
  exit 0
fi

# --- Default (Walker Menu) ---
# Update relay list first
mullvad relay update

# Check current connection status
current_state=$(mullvad status --json | jq -r '.state')

# Load relay list dynamically from Mullvad CLI
relay_data="$(mullvad relay list)"

declare -A CITIES
declare -A SERVERS
declare -A MULLVAD_OWNED

current_country=""
current_city=""

# Parse the relay list output
while IFS= read -r line; do

  # Country: 'Albania (al)'
  if [[ $line =~ ^([A-Za-z\ \-]+)\ \([a-z]{2}\)$ ]]; then
    current_country="${BASH_REMATCH[1]}"
    CITIES["$current_country"]=""
    continue
  fi

  # City: '    Tirana (tia)'
  if [[ $line =~ ^[[:space:]]+([A-Za-z\ \-]+)\ \([a-z]{3}\) ]]; then
    current_city="${BASH_REMATCH[1]}"
    CITIES["$current_country"]+="$current_city|"
    SERVERS["$current_country|$current_city"]=""
    MULLVAD_OWNED["$current_country|$current_city"]=""
    continue
  fi

  # Server: '        al-tia-wg-003 (...)'
  if [[ $line =~ ^[[:space:]]{2,}([a-z]{2}-[a-z]{3}-wg-[0-9]{3}) ]]; then
    server="${BASH_REMATCH[1]}"
    SERVERS["$current_country|$current_city"]+="$server|"
    
    # Check if Mullvad-owned
    if [[ $line =~ Mullvad-owned ]]; then
      MULLVAD_OWNED["$current_country|$current_city"]+="$server|"
    fi
  fi

done <<<"$relay_data"

# -------- Walker Menus ---------

pick_country() {
  for country in "${!CITIES[@]}"; do
    flag="${COUNTRY_FLAGS[$country]}"
    echo "$flag $country"
  done | sort -k2 | walker -d --placeholder "Select Country" | sed 's/^[^ ]* //'
}

pick_city() {
  local country="$1"
  IFS="|" read -ra list <<<"${CITIES[$country]}"
  for city in "${list[@]}"; do
    echo "🏙️ $city"
  done | sort -k2 | walker -d --placeholder "Select City ($country)" | sed 's/^[^ ]* //'
}

pick_server() {
  local country="$1"
  local city="$2"
  local key="$country|$city"
  IFS="|" read -ra all_servers <<<"${SERVERS[$key]}"
  IFS="|" read -ra mullvad_servers <<<"${MULLVAD_OWNED[$key]}"
  
  {
    # First show Mullvad-owned servers with special icon
    for server in "${mullvad_servers[@]}"; do
      [[ -n "$server" ]] && echo "🏢 (Mullvad) $server"
    done | sort -k3
    
    # Then show other servers
    for server in "${all_servers[@]}"; do
      # Skip if already shown as Mullvad-owned
      if [[ ! " ${mullvad_servers[*]} " =~ " ${server} " ]]; then
        [[ -n "$server" ]] && echo "🖥️ (rented) $server"
      fi
    done | sort -k3
  } | walker -d --placeholder "Select Server ($city, $country)" | sed 's/^[^ ]* ([^ ]*) //'
}

# -------- Menu Flow ---------

# If connected, show disconnect option first
if [[ "$current_state" == "connected" ]]; then
  action=$(echo -e "🔌 Disconnect\n🌍 Connect to relay" | walker -d --placeholder "Currently Connected - Choose Action")
  case "$action" in
    "🔌 Disconnect")
      mullvad disconnect
      exit 0
      ;;
    "🌍 Connect to relay")
      # Continue to relay selection
      ;;
    *)
      exit 0
      ;;
  esac
fi

country="$(pick_country)"
[ -z "$country" ] && exit

city="$(pick_city "$country")"
[ -z "$city" ] && exit

server="$(pick_server "$country" "$city")"
[ -z "$server" ] && exit

# -------- Connect to Selected Server ---------

# Reset any conflicting constraints first
mullvad relay set provider any

# Set the relay location
mullvad relay set location "$server"

# Connect to the VPN
mullvad connect