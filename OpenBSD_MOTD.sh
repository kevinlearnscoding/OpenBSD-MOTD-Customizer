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

cat << EOF
============================= Welcome! ===============================
This script will check for/install: lolcat, curl, and figlet.
It will then set up a few customizations such as a custom banner in a
fun text effect, and also getting system stats and the current weather.
This message displays at each login, even from SSH connections.
figlet and curl are available via pkg_add. lolcat will most likely need
to be compiled from source. If you would like to build/install lolcat
yourself, please do so now. If not, the script will offer to build and
install it for you.

Let's get started!

EOF

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
    echo "lolcat is required to run, and is not yet installed. Options:"
    echo "1) Build lolcat yourself and rerun this script later"
    echo "2) Let the script build the high-quality jaseg version for you"
    echo "Enter 1 or 2: "
    read lol_choice </dev/tty

    if [ "$lol_choice" = "1" ]; then
        echo "Please build lolcat manually from"
        echo "https://github.com/jaseg/lolcat and rerun this script."
        echo "(We recommend jaseg's version for its vibrant colors)"
        exit 0

    elif [ "$lol_choice" = "2" ]; then
        echo "Building lolcat from source..."

        # Check if git is available, install if needed
        if ! command -v git >/dev/null 2>&1; then
            echo "git is required for building lolcat."
            echo "Install git? (Y/N)"
            read git_install </dev/tty
            git_install=$(echo "$git_install" | tr '[:lower:]' '[:upper:]')
            
            if [ "$git_install" = "Y" ]; then
                echo "Installing git..."
                if [ "$(id -u)" -eq 0 ]; then
                    if pkg_add git; then
                        echo "✅ git installed successfully!"
                    else
                        echo "❌ Failed to install git."
                        exit 1
                    fi
                else
                    echo "❌ Installing git requires root privileges."
                    echo "Please run as root or install git manually: doas pkg_add git"
                    exit 1
                fi
            else
                echo "Cannot build lolcat without git. Please install git and rerun this script."
                exit 1
            fi
        fi

        # Create temporary directory
        TMP_DIR=$(mktemp -d)
        if [ ! -d "$TMP_DIR" ]; then
            echo "❌ Failed to create temporary directory."
            exit 1
        fi

        cd "$TMP_DIR" || { echo "❌ Failed to enter temp directory. Exiting."; exit 1; }

        # Cloning lolcat repository
        if git clone https://github.com/jaseg/lolcat.git; then
            cd lolcat || { echo "❌ Failed to enter cloned directory."; exit 1; }
            
            # Initializing git submodules
            if git submodule init && git submodule update; then
                :
            else
                echo "❌ Failed to initialize git submodules."
                echo "This is required for jaseg/lolcat build process."
                exit 1
            fi

            # Compiling lolcat
            # Build with explicit make target
            if make lolcat; then
                :
                if [ "$(id -u)" -eq 0 ]; then
                    # Running as root - install system-wide
                    if make install PREFIX=/usr/local; then
                        :
                        # Update PATH if needed for immediate use
                        export PATH="/usr/local/bin:$PATH"
                    else
                        echo "❌ Installation failed."
                        echo "Build completed in: $TMP_DIR/lolcat"
                        echo "To install manually:"
                        echo "   cd $TMP_DIR/lolcat"
                        echo "   doas make install"
                        exit 1
                    fi
                else
                    # Not root - try to install to user's home
                    USER_BIN="$HOME/bin"
                    mkdir -p "$USER_BIN"
                    if cp lolcat "$USER_BIN/" && chmod +x "$USER_BIN/lolcat"; then
                        :
                        # Add to PATH for this session
                        export PATH="$USER_BIN:$PATH"
                    else
                        echo "❌ Failed to install to $USER_BIN."
                        echo "Build completed in: $TMP_DIR/lolcat"
                        echo "To install manually as root:"
                        echo "   cd $TMP_DIR/lolcat"
                        echo "   doas make install"
                        exit 1
                    fi
                fi
                
                # Remove lolcat from missing list since we built it
                MISSING=$(echo "$MISSING" | sed 's/lolcat//g' | sed 's/^ *//' | sed 's/ *$//')
                
                # Verify installation
                if command -v lolcat >/dev/null 2>&1; then
                    :
                else
                    echo "⚠️  lolcat built but may not be in PATH. You may need to:"
                    echo "   export PATH=/usr/local/bin:\$PATH"
                    echo "   or add it to your shell profile"
                fi
            else
                echo "❌ Compilation failed."
                echo "Build directory preserved at: $TMP_DIR/lolcat"
                echo "Common issues:"
                echo "   - Submodules not properly initialized"
                echo "   - Missing build dependencies"
                echo "   - Network issues during submodule download"
                exit 1
            fi
        else
            echo "❌ Failed to clone lolcat repository from GitHub."
            echo "Check your internet connection and try again."
            exit 1
        fi

        # Cleanup on success
        cd ~ || true
        rm -rf "$TMP_DIR"

    else
        echo "Invalid choice. Please enter 1 or 2."
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

# ===== Figlet Font Management for error handling =====
DESIRED_FONTS="alligator basic big block colossal cosmic dotmatrix epic larry3d letters lean nancyj poison roman speed"

check_figlet_fonts() {
    local available_count=0
    local missing_fonts=""
    
    for font in $DESIRED_FONTS; do
        if figlet -f "$font" "test" >/dev/null 2>&1; then
            available_count=$((available_count + 1))
        else
            missing_fonts="$missing_fonts $font"
        fi
    done
    
    echo "$available_count:$missing_fonts"
}

install_standard_fonts() {
    echo "Downloading and installing standard figlet fonts..."
    
    # Create font directory
    if [ "$(id -u)" -eq 0 ]; then
        FONT_DIR="/usr/local/share/figlet"
        mkdir -p "$FONT_DIR"
    else
        FONT_DIR="$HOME/.figlet"
        mkdir -p "$FONT_DIR"
        echo "Installing fonts to user directory: $FONT_DIR"
    fi
    
    # Standard figlet.org font collection URLs
    FONT_BASE_URL="http://www.figlet.org/fonts"
    STANDARD_FONTS="3d 3x5 5lineoblique acrobatic alligator alphabet avatar banner basic bell big block broadway bubble bulbhead calgphy2 chunky coinstak colossal computer contessa cosmic crawford cyberlarge cybermedium cybersmal dancing decimal doh doom dotmatrix drpepper eftichess eftifont eftipiti eftirobot eftitalic eftiwall eftiwater electronic elite epic fender fire flowerpower fourtops fraktur fuzzy georgi georgia11x19 ghost goofy gothic graceful gradient graffiti greek henry3d hollywood invita isometric3 isometric4 ivrit jazmine jerusalem katakana kban larry3d lcd lean letters linux maxi mini mirror mnemonic morse moscow nancyj-fancy nancyj-improved nancyj niagara ntgreek o8 ogre old pawp pepper poison puffy rectangles relief relief2 rev roman rot13 rounded rowancap rozzo runic runyc sblood script serifcap shadow slant slide slscript small smisome1 smkeyboard smscript smshadow smslant speed stampatello standard starwars stellar stop straight tanja thick thin threepoint ticks times2 tinker-toy tombstone trek tubular twopoint univers usaflag varsity wavy weird whimsy"
    
    # Download fonts (subset of standard ones that are commonly used)
    local success_count=0
    local total_attempted=0
    
    for font in $STANDARD_FONTS; do
        if echo "$DESIRED_FONTS" | grep -q "$font"; then
            total_attempted=$((total_attempted + 1))
            echo "Downloading $font.flf..."
            if curl -s -o "$FONT_DIR/${font}.flf" "$FONT_BASE_URL/${font}.flf"; then
                # Verify the font file is valid
                if figlet -f "$font" "test" >/dev/null 2>&1; then
                    success_count=$((success_count + 1))
                    echo "✅ $font installed successfully"
                else
                    echo "⚠️  $font downloaded but may not be valid"
                    rm -f "$FONT_DIR/${font}.flf"
                fi
            else
                echo "❌ Failed to download $font"
            fi
        fi
    done
    
    echo "Font installation complete: $success_count/$total_attempted fonts installed"
    return 0
}

search_system_fonts() {
    echo "Searching for available figlet fonts on system..."
    local found_fonts=""
    
    # Search common font directories
    for font_dir in "/usr/local/share/figlet" "/usr/share/figlet" "$HOME/.figlet"; do
        if [ -d "$font_dir" ]; then
            for font_file in "$font_dir"/*.flf; do
                if [ -f "$font_file" ]; then
                    font_name=$(basename "$font_file" .flf)
                    if figlet -f "$font_name" "test" >/dev/null 2>&1; then
                        found_fonts="$found_fonts $font_name"
                    fi
                fi
            done
        fi
    done
    
    # Also check built-in fonts by testing common ones
    for font in standard small mini block lean; do
        if figlet -f "$font" "test" >/dev/null 2>&1; then
            if ! echo "$found_fonts" | grep -q "$font"; then
                found_fonts="$found_fonts $font"
            fi
        fi
    done
    
    echo "$found_fonts"
}

# Main font management logic
if echo "$MISSING" | grep -q "figlet"; then
    echo "figlet will be installed via pkg_add, which includes basic fonts."
else
    # figlet is already installed, check for desired fonts
    font_check=$(check_figlet_fonts)
    available_count=$(echo "$font_check" | cut -d: -f1)
    missing_fonts=$(echo "$font_check" | cut -d: -f2-)
    
    if [ "$available_count" -eq 0 ]; then
        echo "figlet is installed but none of the desired fonts are available."
        echo "Missing fonts:$missing_fonts"
        echo ""
        echo "Options:"
        echo "1) Download and install standard figlet fonts"
        echo "2) Search system for existing fonts and edit the font list"
        echo "3) Continue with basic fonts only"
        echo "Enter 1, 2, or 3: "
        read font_choice </dev/tty
        
        case "$font_choice" in
            1)
                if install_standard_fonts; then
                    echo "Standard fonts installed successfully!"
                else
                    echo "Some fonts may have failed to install, but continuing..."
                fi
                ;;
            2)
                system_fonts=$(search_system_fonts)
                if [ -n "$system_fonts" ]; then
                    echo ""
                    echo "Available fonts found on system:"
                    echo "$system_fonts" | tr ' ' '\n' | sort | column -c 80
                    echo ""
                    echo "Current font list: $DESIRED_FONTS"
                    echo ""
                    echo "Enter new font list (space-separated), or press Enter to keep current:"
                    read new_font_list </dev/tty
                    if [ -n "$new_font_list" ]; then
                        DESIRED_FONTS="$new_font_list"
                        echo "Font list updated to: $DESIRED_FONTS"
                    fi
                else
                    echo "No additional fonts found. Using basic fonts."
                fi
                ;;
            3)
                echo "Continuing with basic fonts only."
                DESIRED_FONTS="standard"
                ;;
            *)
                echo "Invalid choice. Continuing with basic fonts."
                DESIRED_FONTS="standard"
                ;;
        esac
        
    elif [ "$available_count" -lt 5 ]; then
        echo "figlet is installed with $available_count desired fonts available."
        echo "Missing fonts:$missing_fonts"
        echo "Download additional fonts? (Y/N)"
        read download_choice </dev/tty
        download_choice=$(echo "$download_choice" | tr '[:lower:]' '[:upper:]')
        
        if [ "$download_choice" = "Y" ]; then
            install_standard_fonts
        fi
    else
        echo "figlet is installed with $available_count fonts available. Good to go!"
    fi
fi

# Update FONT_LIST variable for use in MOTD script
FONT_LIST="$DESIRED_FONTS"

# === FILE CREATION SECTION ===
# ===== CREATE DYNAMIC MOTD SCRIPT =====
cat << MOTD_GENERATOR_SCRIPT > "$MOTD_SCRIPT"
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
FONT_LIST="$FONT_LIST"
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

# Handle case where no fonts are available
if [ $NUM_FONTS -eq 0 ]; then
    FOUND_FONT="standard"
else
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

    # Save next index (only if we have fonts)
    NEXT_INDEX=$(( (INDEX + 1) % NUM_FONTS ))
    echo "$NEXT_INDEX" > "$STATE_FILE"
fi


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
MOTD_GENERATOR_SCRIPT

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
