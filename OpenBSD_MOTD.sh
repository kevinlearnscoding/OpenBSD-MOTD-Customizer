#!/bin/sh

############################# WELCOME ###########################
# ============================ INTRO ============================
# This script will prompt the user for input to set their banner text,
# weather location, and temperature system unit. 
# The user input is then hardcoded into the resulting script
# that runs at every login, which generates a fresh MOTD file.
# The MOTD file is static - to edit the contents of the template
# that generates the MOTD, edit:
# "/usr/local/bin/rc.motd_openbsd" if the script runs system wide
# "~/.motd_openbsd" if the script runs on your user account only.
##################################################################

# ===== START OF THE SCRIPT =====
set -e

echo "============================= Welcome! ==============================="
echo "This script will check for/install: lolcat, curl, and figlet." 
echo "It will then set up a few customizations such as a custom banner in a"
echo "fun text effect, and also getting system stats and the current weather."
echo "This message displays at each login, even from SSH connections."
echo "figlet and curl are available via pkg_add. lolcat will most likely need"
echo "to be compiled from source. If you would like to build/install lolcat"
echo "yourself, please do so now. If not, the script will offer to build and"
echo "install it for you."  
echo ""
echo "Let's get started!"
echo ""

# ===== Check if running as root =====
if [ "$(id -u)" -ne 0 ]; then
    echo "⚠ Warning: Some actions (like writing system-wide MOTD)"
    echo "may fail without root privileges."
    echo "Run this script as root or with sudo privileges."
fi

# ===== Error Handling =====
error_exit() {
    status=$?
    if [ $status -ne 0 ]; then
        echo "❌ An error occurred. Exiting script."
    fi
    exit $status
}
trap 'error_exit' EXIT

# ===== MOTD Type Selection =====
echo "Do you want the MOTD to be system-wide or for your user only? (S/U)"
read motd_type </dev/tty
motd_type=$(echo "$motd_type" | tr '[:lower:]' '[:upper:]')

if [ "$motd_type" = "S" ]; then
    MOTD_FILE="/etc/motd"
    MOTD_BACKUP="/etc/motd.backup"
    MOTD_SCRIPT="/usr/local/bin/rc.motd_openbsd"
    PROFILE_FILE="/etc/profile"
elif [ "$motd_type" = "U" ]; then
    HOME_DIR=$(eval echo ~"$USER")
    MOTD_FILE="$HOME_DIR/.motd"
    MOTD_BACKUP="$HOME_DIR/.motd.backup"
    MOTD_SCRIPT="$HOME_DIR/.motd_openbsd"
    PROFILE_FILE="$HOME_DIR/.profile"
else
    echo "Invalid choice. Please enter 'S' for system wide or 'U' for just your user."
    echo "Press Ctrl+C to exit script"
    exit 1
fi

# ===== Backup existing MOTD if not already backed up =====
if [ -f "$MOTD_FILE" ] && [ ! -f "$MOTD_BACKUP" ]; then
    echo "Backing up existing MOTD to $MOTD_BACKUP"
    cp "$MOTD_FILE" "$MOTD_BACKUP"
fi

# ===== Check for required commands =====
REQUIRED_CMDS="figlet curl lolcat"
MISSING=""
for cmd in $REQUIRED_CMDS; do
    if ! command -v $cmd >/dev/null 2>&1; then
        MISSING="$MISSING $cmd"
    fi
done

# ===== lolcat build logic =====
if echo "$MISSING" | grep -q "lolcat"; then
    echo "lolcat is missing. Options:"
    echo "1) Build lolcat yourself and rerun this script later"
    echo "2) Let the script build lolcat for you now"
    echo "Enter 1 or 2: "
    read lol_choice </dev/tty

    if [ "$lol_choice" = "1" ]; then
        echo "Please build lolcat manually from https://github.com/jaseg/lolcat and rerun this script."
        exit 0

    elif [ "$lol_choice" = "2" ]; then
        echo "Building lolcat from source..."

        # Ensure curl or ftp is available
        if command -v curl >/dev/null 2>&1; then
            FETCH_CMD="curl -L -o"
        elif command -v ftp >/dev/null 2>&1; then
            FETCH_CMD="ftp -o"
        else
            echo "Neither curl nor ftp found. Please install one and rerun."
            exit 1
        fi

        TMP_DIR=$(mktemp -d)
        cd "$TMP_DIR" || { echo "Failed to enter temp directory. Exiting."; exit 1; }

        echo "Downloading lolcat source..."
        if $FETCH_CMD lolcat.tar.gz https://github.com/jaseg/lolcat/archive/refs/heads/master.tar.gz; then
            echo "Extracting source..."
            tar -xzf lolcat.tar.gz || { echo "Failed to extract archive. Exiting."; exit 1; }
            cd lolcat-master || { echo "Source directory missing. Exiting."; exit 1; }

            echo "Compiling and installing..."
            if make && make install; then
                echo "✅ lolcat built and installed successfully!"
                # Remove lolcat from missing list
                MISSING=$(echo "$MISSING" | sed 's/lolcat//g')
            else
                echo "❌ Build or install failed. You can retry manually from:"
                echo "   $TMP_DIR/lolcat-master"
                exit 1
            fi
        else
            echo "❌ Failed to download lolcat source."
            echo "You can manually download from:"
            echo "  https://github.com/jaseg/lolcat/archive/refs/heads/master.tar.gz"
            exit 1
        fi

        # Cleanup
        cd ~ || true
        rm -rf "$TMP_DIR"
        echo "lolcat built successfully, resuming script..."

    else
        echo "Invalid choice. Exiting."
        exit 1
    fi
fi



# ===== Install other missing packages =====
OTHER_MISSING=$(echo "$MISSING" | xargs)
if [ -n "$OTHER_MISSING" ]; then
    echo "The following required programs are missing: $OTHER_MISSING"
    echo "Install via: pkg_add $OTHER_MISSING ? (Y/N)"
    read install_choice </dev/tty
    install_choice=$(echo "$install_choice" | tr '[:lower:]' '[:upper:]')

    if [ "$install_choice" = "Y" ]; then
        if ! pkg_add $OTHER_MISSING; then
            echo "Some packages failed to install."
            echo "Would you like to retry? (Y/N): "
            read retry </dev/tty
            retry=$(echo "$retry" | tr '[:lower:]' '[:upper:]')
            if [ "$retry" = "Y" ]; then
                pkg_add $OTHER_MISSING || { echo "Still failing. Exiting."; exit 1; }
            else
                echo "Exiting."
                exit 1
            fi
        fi
    fi
fi


# ===== USER INPUT =====

# =================== USER INPUT FOR BANNER TEXT ==================== 
# DO NOT EDIT THIS SECTION!
# TO EDIT YOUR BANNER TEXT RUN THE SCRIPT THEN EDIT AS PER INTRO ABOVE
# ===================================================================
echo "Enter your banner text:"
read banner_text </dev/tty

# ================= USER INPUT FOR WEATHER LOCATION ================= 
# DO NOT EDIT THIS SECTION!
# TO EDIT YOUR WEATHER LOCATION RUN THE SCRIPT THEN EDIT AS PER INTRO ABOVE
# ===================================================================
echo "Enter your weather location - supported location types:"
echo "/paris                # city name (+ for spaces)"
echo "/~Eiffel+tower        # any location (+ for spaces)"
echo "/Москва               # Unicode name of any location in any language"
echo "/JFK                  # airport code (3 letters)"
echo "/@stackoverflow.com   # domain name"
echo "/94107                # area codes"
echo "/-78.46,106.79        # GPS coordinates"
echo "to automatically detect your location type 'auto-locate' (with hyphen)"
echo "auto-locate is unreliable, it is suggested to provide a location or region"
read city_input </dev/tty

if [ "$(echo "$city_input" | tr '[:upper:]' '[:lower:]')" = "auto-locate" ]; then
    city_url=""
else
    city_url=$(echo "$city_input" | tr ' ' '+')
fi


while true; do
    echo "Do you want the temperature in Fahrenheit or Celsius? (F/C)"
    read unit </dev/tty
    unit=$(echo "$unit" | tr '[:lower:]' '[:upper:]')
    if [ "$unit" = "F" ]; then
        unit_suffix="&u"
        break
    elif [ "$unit" = "C" ]; then
        unit_suffix=""
        break
    else
        echo "Invalid input. Please enter 'F' or 'C'."
    fi
done

# EDIT THIS URL TO MAKE ADJUSTMENTS TO YOUR WEATHER REPORT
weather_url="wttr.in/${city_url}?format=3${unit_suffix}" 

# === FILE CREATION SECTION ===
# ===== CREATE DYNAMIC MOTD SCRIPT =====
cat << EOF > "$MOTD_SCRIPT"
#!/bin/sh

# ====== WELCOME! =====
# Edit these lines to make adjustments:
# Line      Adjustment
# 15        Banner text
# 16        List of fonts for banner - see figlet.org for more info
# 23        Lolcat options - see "lolcat --help" for more options
# 30        Divider character and length
# 74        Banner style options - see 'figlet.org/figlet-man' for more info
# 81-88     Emoji's used 

# For weather reports adjustments see "wttr.in/:help" for more info

NAME="$banner_text" # EDIT THIS LINE TO CHANGE YOUR BANNER TEXT
FONT_LIST="alligator basic big block colossal cosmic dotmatrix epic larry3d letters lean nancyj poison roman speed"
STATE_FILE="/tmp/motd_font_index"

has_cmd() { command -v "\$1" >/dev/null 2>&1; }

colorize() {
    if has_cmd lolcat; then
        lolcat -f
    else
        cat
    fi
}

divider() {
    printf "%s\n" "------------------------------------------------------------"
}

# ===== Font Rotation with skip if not installed =====
set -- $FONT_LIST
NUM_FONTS=$#
if [ -f "$STATE_FILE" ]; then
    INDEX=$(cat "$STATE_FILE")
else
    INDEX=0
fi

FOUND_FONT=""
count=0
for FONT in "$@"; do
    if [ $count -ge $INDEX ]; then
        if figlet -f "$FONT" "test" >/dev/null 2>&1; then
            FOUND_FONT="$FONT"
            break
        else
            echo "⚠ Font '$FONT' not installed."
            echo "  Edit font list in $MOTD_SCRIPT"
            echo "  Download fonts: https://www.figlet.org"
            echo "  Install fonts in /usr/local/share/figlet or ~/.figlet"
        fi
    fi
    count=$((count + 1))
done

# Fallback
[ -z "$FOUND_FONT" ] && FOUND_FONT="standard"

# Save next index
NEXT_INDEX=$(( (INDEX + 1) % NUM_FONTS ))
echo "$NEXT_INDEX" > "$STATE_FILE"


# ===== Memory Info (OpenBSD) =====
get_mem_info() {
    mem_used=\$(vmstat -s | awk '/active memory/ {print \$1}')
    mem_total=\$(sysctl hw.physmem | awk '{print \$2}')
    mem_used_mb=\$((mem_used / 1024 / 1024))
    mem_total_mb=\$((mem_total / 1024 / 1024))
    echo "\$mem_used_mb MiB used / \$mem_total_mb MiB total"
}

# ===== Disk Info =====
get_disk_info() {
    df -h / | awk 'NR==2 {print \$3 " used / " \$2}'
}

# ===== MOTD Output =====
echo
if has_cmd figlet; then
    figlet -f "\$FOUND_FONT" "\$NAME" | colorize
else
    echo "\$NAME" | colorize
fi
echo ""
echo "Font used: \$FOUND_FONT"

divider | colorize
echo " 🖥️ Hostname : \$(hostname)"
echo " ⏱️ Uptime   : \$(uptime | sed 's/.*up //; s/,.*//' | awk '{\$1=\$1};1')"
echo " 🧠 Memory    : \$(get_mem_info)"
echo " 💽 Disk      : \$(get_disk_info)"
divider | colorize
if has_cmd curl; then
    echo " 🌦️  Weather:"
    curl -s "$weather_url" || echo " (unavailable)"
fi
echo
divider | colorize
echo
EOF

chmod +x "$MOTD_SCRIPT"

# ===== Ensure script runs at login =====
if ! grep -q "$MOTD_SCRIPT" "$PROFILE_FILE"; then
    echo "[ -x $MOTD_SCRIPT ] && $MOTD_SCRIPT" >> "$PROFILE_FILE"
fi

# ===== Final Message =====
echo ""
echo "======================================================"
echo "           *** Finished installing! ***           "
echo "Your dynamic MOTD script is installed at and can be edited at:"
echo "$MOTD_SCRIPT"
echo "Backup of original MOTD is at:"
echo "$MOTD_BACKUP"
echo "It will run at login via $PROFILE_FILE"
echo "======================================================"
echo ""
