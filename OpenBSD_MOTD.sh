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

# Welcome message
clear
cat << EOF1

**********************************************************************
============================= Welcome! ===============================
This script will check for/install: lolcat, curl, and figlet.
It will then set up a few customizations such as a custom banner in a
fun text effect, and also getting system stats and the current weather.
This message displays at each login, even from SSH connections.
figlet and curl are available via pkg_add. lolcat will most likely need
to be compiled from source, but we'll check if its available from pkg_add.
If you would like to build/install lolcat yourself, please do so now. 
If not, the script will offer to build and install it for you.

Let's get started!


Press Enter to continue or Ctrl+C to exit the script. 
EOF1
read </dev/tty

# ===== Check if running as root =====
if [ "$(id -u)" -ne 0 ]; then
    echo ""
    echo "⚠ Warning: Some actions (like writing system-wide MOTD)"
    echo "may fail without root privileges."
    echo "Run this script as root or with sudo privileges."
fi

# ===== General/Generic Error Handling =====
error_exit() {
    status=$?
    if [ $status -ne 0 ]; then
        echo ""
        echo "❌ An error occurred. Exiting script."
    fi
    exit $status
}
trap 'error_exit' EXIT

# ===== MOTD Type Selection =====
clear
echo "Do you want the Message of the Day (MOTD) customization to be system-wide"
echo "or for your user only?"
echo "Please type 'S' for system-wide and 'U' for your user only."
read motd_type </dev/tty
motd_type=$(echo "$motd_type" | tr '[:lower:]' '[:upper:]')

if [ "$motd_type" = "S" ]; then
    MOTD_FILE="/etc/motd"
    MOTD_BACKUP="/etc/motd.backup"
    MOTD_SCRIPT="/usr/local/bin/rc.motd_openbsd"
    PROFILE_FILE="/etc/profile"
    STATE_FILE_LOCATION="/var/tmp/motd_font_index"
elif [ "$motd_type" = "U" ]; then
    HOME_DIR=$(eval echo ~"$USER")
    MOTD_FILE="$HOME_DIR/.motd"
    MOTD_BACKUP="$HOME_DIR/.motd.backup"
    MOTD_SCRIPT="$HOME_DIR/.motd_openbsd"
    PROFILE_FILE="$HOME_DIR/.profile"
    STATE_FILE_LOCATION="$HOME_DIR/.cache/motd_font_index"
else
    echo ""
    echo "Invalid choice. Please enter 'S' for system wide or 'U' for just your user."
    echo "Press Ctrl+C to exit script"
    exit 1
fi

# ===== Backup existing MOTD if not already backed up =====
if [ -f "$MOTD_FILE" ] && [ ! -f "$MOTD_BACKUP" ]; then
    echo ""
    echo "Backing up existing MOTD to $MOTD_BACKUP"
    cp "$MOTD_FILE" "$MOTD_BACKUP"
    rm "$MOTD_FILE"
fi

# ===== Check if required command are installed =====
clear
echo "Checking if required commands are installed..."
REQUIRED_CMDS="figlet curl"
MISSING=""
for cmd in $REQUIRED_CMDS; do
    if ! command -v $cmd >/dev/null 2>&1; then
        MISSING="$MISSING $cmd"
    fi
done
##############
echo "DEBUG: MOTD_SCRIPT is set to: '$MOTD_SCRIPT'"
echo "DEBUG: MISSING is set to: '$MISSING'"
##############
# Check lolcat availability and installation
echo "Checking if lolcat is installed..."
echo "*************************************************"
echo "SCRIPT WILL MOVE TO NEXT SCREEN AUTOMATICALLY"
echo "DO NOT TYPE ANY KEYS / DO NOT PRESS ENTER"
echo "*************************************************"
LOL_PKGADD_AVAILABLE="no"
if pkg_info lolcat >/dev/null 2>&1; then
    LOL_PKGADD_AVAILABLE="yes"
fi
echo "Checking if lolcat is available via pkg_add..."
LOL_INSTALLED="no"
if command -v lolcat >/dev/null 2>&1; then
    LOL_INSTALLED="yes"
    echo "lolcat is already installed."
fi

#############
echo "DEBUG: LOL_PKGADD_AVAILABLE is set to: '$LOL_PKGADD_AVAILABLE'"
echo "DEBUG: LOL_INSTALLED is set to: '$LOL_INSTALLED'"
echo "DEBUG: MISSING is set to: '$MISSING'"
#############

# Only offer lolcat in pkg_add list if available and not installed
OTHER_MISSING="$MISSING"
if [ "$LOL_PKGADD_AVAILABLE" = "yes" ] && [ "$LOL_INSTALLED" = "no" ]; then
    OTHER_MISSING="$OTHER_MISSING lolcat"
fi
########
echo "DEBUG: OTHER_MISSING is set to: '$OTHER_MISSING' after 'only offer lolcat in pkg_add if availabel and not installed'"
########
OTHER_MISSING=$(echo "$OTHER_MISSING" | xargs)
if [ "$LOL_PKGADD_AVAILABLE" = "no" ]; then
    lolcat_avail="lolcat is not available via pkg_add* and will be offered to be built later.\n*at the time of writing this script."
else
    lolcat_avail=""
fi
########
echo ""
echo "DEBUG: MOTD_SCRIPT is set to: '$MOTD_SCRIPT'"
echo "DEBUG: OTHER_MISSING is set to: '$OTHER_MISSING' "
echo "DEBUG: LOL_PKGADD_AVAILABLE is set to: '$LOL_PKGADD_AVAILABLE'"
echo "DEBUG: LOL_INSTALLED is set to: '$LOL_INSTALLED'"
echo "DEBUG: MISSING is set to: '$MISSING'"
echo "DEBUG: lolcat_avail is set to: '$lolcat_avail'"before 'tell user what packages are missing'
#######
# ===== Tell user what packages are missing =====
if [ -n "$OTHER_MISSING" ]; then
    clear
    echo "Let's get started installing packages."
    echo "The following required programs are missing: $OTHER_MISSING"
    echo "$lolcat_avail"
    echo ""
    echo "Install via: pkg_add $OTHER_MISSING ? [Y/n]"
    read install_choice </dev/tty
    install_choice=${install_choice:-Y}  
    install_choice=$(echo "$install_choice" | tr '[:lower:]' '[:upper:]')

    if [ "$install_choice" = "Y" ]; then
        if pkg_add $OTHER_MISSING; then
            echo "✅ Packages installed successfully."
            echo "Press Enter to continue."
            read </dev/tty
        else
            echo "Some packages failed to install."
            echo "Would you like to retry? [Y/n]: "
            read retry </dev/tty
            retry=${retry:-Y}
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
#################
echo "DEBUG: OTHER_MISSING is ' $OTHER_MISSING ' after 'tell user what packages are missing'"
echo "DEBUG: MISSING is ' $MISSING ' after 'tell user what packages are missing'"
echo "DEBUG: LOL_PKGADD_AVAILABLE is set to: '$LOL_PKGADD_AVAILABLE'"
echo "DEBUG: LOL_INSTALLED is set to: '$LOL_INSTALLED'"
echo "DEBUG: lolcat_avail is set to: '$lolcat_avail'"
echo "DEBUG: MOTD_SCRIPT is set to: '$MOTD_SCRIPT'"
echo ""
#################


# ===== Make sure packages were installed correctly =====
if command -v figlet >/dev/null 2>&1; then
    MISSING=$(echo "$MISSING" | sed 's/figlet//g' | sed 's/^ *//' | sed 's/ *$//')
    else
        echo ""
        echo "Figlet did not install properly. Please re-install."
        read </dev/tty
    fi
if command -v curl >/dev/null 2>&1; then
    MISSING=$(echo "$MISSING" | sed 's/curl//g' | sed 's/^ *//' | sed 's/ *$//')
    else
        echo ""
        echo "curl did not install properly. Please re-install."
        read </dev/tty
    fi
    


# ===== USER INPUT =====

# =================== USER INPUT FOR BANNER TEXT ==================== 
# DO NOT EDIT THIS SECTION!
# TO EDIT YOUR BANNER TEXT RUN THE SCRIPT THEN EDIT AS PER INTRO ABOVE
# ===================================================================

clear
cat << EOF2
Your banner text is displayed at the top of your MOTD, and color will be added
using lolcat (later).
Your banner can be multi-line by including "\n" in the text where you want a
line return to be inserted - do not insert a space before/after the "\n".
Example: 'My new\nServer' in the "big" font will display as:
 __  __                             
|  \/  |                            
| \  / |_   _   _ __   _____      __
| |\/| | | | | | '_ \ / _ \ \ /\ / /
| |  | | |_| | | | | |  __/\ V  V / 
|_|  |_|\__, | |_| |_|\___| \_/\_/  
         __/ |                      
        |___/                       
  _____                          
 / ____|                         
| (___   ___ _ ____   _____ _ __ 
 \___ \ / _ \ '__\ \ / / _ \ '__|
 ____) |  __/ |   \ V /  __/ |   
|_____/ \___|_|    \_/ \___|_|   
 
You can test fonts by running "figlet -f <fontname> 'Your Text Here'" outside
of this script to see how it looks.
Your banner text can be altered after installation by editing the MOTD file.
[Press enter to continue]
EOF2
read </dev/tty
clear

enter_banner_text() {
while true; do
cat << EOF3 
************************************
Force line return: "\n"
************************************
Enter your banner text: 
EOF3
    read banner_text </dev/tty

    if [ -z "$banner_text" ]; then
        echo "Banner text cannot be empty. Please enter banner text."
        echo "Press Ctrl+C to exit script"
    else
        break
    fi
done
}
enter_banner_text




# ================= USER INPUT FOR WEATHER LOCATION ================= 
# DO NOT EDIT THIS SECTION!
# TO EDIT YOUR WEATHER LOCATION RUN THE SCRIPT THEN EDIT AS PER INTRO ABOVE
# ===================================================================
clear
cat << EOF4
Your weather location is used to fetch the current weather conditions.
Supported location types are:
Type                  
/paris                # city name (+ for spaces)
/~Eiffel+tower        # any location (+ for spaces)
/Москва               # Unicode name of any location in any language
/JFK                  # airport code (3 letters)
/@stackoverflow.com   # domain name
/94107                # area codes
/-78.46,106.79        # GPS coordinates
to automatically detect your location type 'auto-locate' (with hyphen)
or leave blank.
NOTE: 
auto-locate is unreliable, it is suggested to provide a location or region
for best results.
Please enter your location: 
EOF4
read city_input </dev/tty

if [ -z "$city_input" ] || [ "$(echo "$city_input" | tr '[:upper:]' '[:lower:]')" = "auto-locate" ]; then
    city_url=""
else
    city_url=$(echo "$city_input" | tr ' ' '+')
fi
clear
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
        echo ""
        echo "Invalid input. Please enter 'F' or 'C'."
    fi
done

# EDIT THIS URL TO MAKE ADJUSTMENTS TO YOUR WEATHER REPORT
weather_url="wttr.in/${city_url}?format=3${unit_suffix}" 


clear
# ===== Comprehensive Figlet Font Management =====
DEFAULT_FONTS="alligator basic big block colossal cosmic epic larry3d letters lean nancyj poison roman speed"

# ========== Main font management logic ==========
if command -v figlet >/dev/null 2>&1; then
    echo "Checking available fonts for banner rotation..."
 
    # Get figlet's default font directory and count fonts
    FONT_DIR=$(figlet -I2)
    total_fonts=$(ls "$FONT_DIR"/*.flf 2>/dev/null | wc -l)
    for font in "$FONT_DIR"/*.flf; do
                # Run figlet for each font with 'TEST'
                if figlet -f "$font" 'TEST' >/dev/null 2>&1; then
                    # If successful, increment the counter
                    success_count=$((success_count + 1))
                fi
    done
    if [ -n "$total_fonts" ]; then
        echo "✅ Found $total_fonts fonts on your system."
        echo "To view available fonts, run: 'figlet -I2'"
        echo "This script uses a 'default' set of fonts for the banner rotation."
        echo "You can edit the font list later in the MOTD script if desired."
        echo "Edit the list at"
        echo "$MOTD_SCRIPT"
        echo  "after installation."
        FONT_LIST="$DEFAULT_FONTS"
    fi
else
    echo "figlet not available. Please try reinstalling."
    FONT_LIST="standard"
fi

echo "Press Enter to continue..."
read </dev/tty
clear

# ===== lolcat build logic =====
install_lolcat() {
        # Check if git is available, install if needed
        if ! command -v git >/dev/null 2>&1; then
            echo "git is required for building lolcat."
            echo "Install git? [Y/N]"
            read git_install </dev/tty
            git_install=${git_install:-Y}
            git_install=$(echo "$git_install" | tr '[:lower:]' '[:upper:]')
            
            if [ "$git_install" = "Y" ]; then
                echo "Installing git..."
                if [ "$(id -u)" -eq 0 ]; then
                    if pkg_add git; then
                        echo "✅ git installed successfully!"
                        echo "Using git to install lolcat..."
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
}

# ===== Install Lolcat if not isntalled =====
if ! command -v lolcat >/dev/null 2>&1; then
    echo "lolcat is required to provide colorful text banners. If you want to"
    echo "use lolcat, it is not yet installed. Options:"
    echo "1) Build lolcat yourself and rerun this script later"
    echo "2) Let the script build the high-quality jaseg version for you"
    echo "3) Do not use lolcat - cannot be changed later."
    echo 
    echo "!!! lolcat being installed later will be automatically detected, and used."
    echo "If you wish to have plaintext banners only you will need to"
    echo "edit the MOTD script manually to remove lolcat functionality."
    echo "Enter 1, 2, or 3: "
    read lol_choice </dev/tty

    if [ "$lol_choice" = "1" ]; then
        echo "Please build lolcat manually from"
        echo "https://github.com/jaseg/lolcat and rerun this script."
        echo "(We recommend jaseg's version for its vibrant colors)"
        echo "Exiting script for now."
        echo "lolcat can be installed later and the MOTD will automatically detect it."
        exit 0

    elif [ "$lol_choice" = "2" ]; then
        echo "Building lolcat from source..."
        install_lolcat
    
    elif [ "$lol_choice" = "3" ]; then
        echo "Proceeding without lolcat. Banners will be in plain text."
    fi
fi

#################################
echo "DEBUG: MOTD_SCRIPT is set to: '$MOTD_SCRIPT'"
if [ -z "$MOTD_SCRIPT" ]; then
    echo "ERROR: MOTD_SCRIPT is not set!"
    exit 1
fi
#################################

# === FILE CREATION SECTION ===
touch "$MOTD_SCRIPT"
# ===== CREATE DYNAMIC MOTD SCRIPT =====
cat << EOF5 > "$MOTD_SCRIPT"
#!/bin/sh

# ====== WELCOME! =====
# Edit these lines to make adjustments:
# Line      Adjustment
# 15        Banner text
# 16        List of fonts for banner - see figlet.org for more info
# 25        Lolcat options - see "lolcat --help" for more options on coloring
# 32        Divider character and length
# 93        Banner style options - see 'figlet.org/figlet-man' for more info
# 101-107   Emoji's used 

# For weather reports adjustments see "wttr.in/:help" for more info

NAME="$banner_text" # EDIT THIS LINE TO CHANGE YOUR BANNER TEXT
FONT_LIST="$FONT_LIST"
STATE_FILE="$STATE_FILE_LOCATION" # File to store current font index

has_cmd() { command -v "\$1" >/dev/null 2>&1; }

# REMOVE OR EDIT THE FOLLOWING LINES TO CHANGE LOLCAT OPTIONS
# TO REMOVE LOLCAT, SIMPLY DELETE OR COMMENT OUT THE colorize FUNCTION
# AND ITS USAGE BELOW

colorize() {
    if has_cmd lolcat; then
        lolcat -f
    else
        ;
    fi
}
divider() {
    printf "%s\n" "------------------------------------------------------------"
}

# ===== Font Rotation with skip if not installed =====
set -- \$FONT_LIST
NUM_FONTS=\$#

# Handle case where no fonts are available
if [ \$NUM_FONTS -eq 0 ]; then
    FOUND_FONT="standard"
else
    if [ -f "\$STATE_FILE" ]; then
        INDEX=\$(cat "\$STATE_FILE")
    else
        INDEX=0
    fi

    FOUND_FONT=""
    count=0
    for FONT in "\$@"; do
        if [ \$count -ge \$INDEX ]; then
            if figlet -f "\$FONT" "test" >/dev/null 2>&1; then
                FOUND_FONT="\$FONT"
                break
            else
                echo "⚠ Font '\$FONT' not installed."
                echo "  Edit font list in \$MOTD_SCRIPT"
                echo "  Download fonts: https://www.figlet.org"
                echo "  Install fonts in /usr/local/share/figlet or ~/.figlet"
            fi
        fi
        count=\$((count + 1))
    done

    # Fallback
    [ -z "\$FOUND_FONT" ] && FOUND_FONT="standard"

    # Save next index (only if we have fonts)
    NEXT_INDEX=\$(( (INDEX + 1) % NUM_FONTS ))
    echo "\$NEXT_INDEX" > "\$STATE_FILE"
fi


# ===== Get Memory Info (OpenBSD) =====
get_mem_info() {
    mem_used=\$(vmstat -s | awk '/active memory/ {print \$1}')
    mem_total=\$(sysctl hw.physmem | awk '{print \$2}')
    mem_used_mb=\$((mem_used / 1024 / 1024))
    mem_total_mb=\$((mem_total / 1024 / 1024))
    echo "\$mem_used_mb MiB used / \$mem_total_mb MiB total"
}

# ===== Get Disk Info =====
get_disk_info() {
    df -h / | awk 'NR==2 {print \$3 " used / " \$2}'
}

# ===== Display MOTD Output =====
echo
if has_cmd figlet; then
    figlet -f $FOUND_FONT "$NAME" | colorize
else
    printf "\$NAME" | colorize
fi
echo ""
echo "Font used: \$FOUND_FONT"

divider | colorize
echo " 🖥️ Hostname : \$(hostname)"
echo " ⏱️ Uptime   : \$(uptime | sed 's/.*up //; s/,.*//' | awk '{\$1=\$1};1')"
echo " 🧠 Memory   : \$(get_mem_info)"
echo " 💽 Disk     : \$(get_disk_info)"
divider | colorize
if has_cmd curl; then
    echo " 🌦️  Weather:"
    curl -s "$weather_url" || echo " (unavailable)"
fi
echo
divider | colorize
echo

EOF5

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
