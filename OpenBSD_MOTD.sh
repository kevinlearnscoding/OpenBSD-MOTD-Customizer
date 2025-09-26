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
echo "Do you want the MOTD customization to be system-wide or for your user only?"
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
    echo "Invalid choice. Please enter 'S' for system wide or 'U' for just your user."
    echo "Press Ctrl+C to exit script"
    exit 1
fi

# ===== Backup existing MOTD if not already backed up =====
echo "Making backup of existing MOTD if needed..."
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

# ===== Update MISSING variable after package installation =====
if command -v figlet >/dev/null 2>&1; then
    MISSING=$(echo "$MISSING" | sed 's/figlet//g' | sed 's/^ *//' | sed 's/ *$//')
fi

# ===== Ask user weather location and temp unit =====
OTHER_MISSING=$(echo "$MISSING" | xargs)
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

# ===== Comprehensive Figlet Font Management =====
DEFAULT_FONTS="alligator basic big block colossal cosmic dotmatrix epic larry3d letters lean nancyj poison roman speed"

discover_system_fonts() {
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
    
    # Test for built-in/package fonts
    for font in standard small mini block lean slant shadow big banner script bubble digital morse; do
        if figlet -f "$font" "test" >/dev/null 2>&1; then
            if ! echo "$found_fonts" | grep -q "$font"; then
                found_fonts="$found_fonts $font"
            fi
        fi
    done
    
    echo "$found_fonts"
}

download_font_collection() {
    local collection="$1"
    local collection_url=""
    
    case "$collection" in
        "ours")
            collection_url="ftp://ftp.figlet.org/pub/figlet/fonts/ours.tar.gz"
            ;;
        "contributed")
            collection_url="ftp://ftp.figlet.org/pub/figlet/fonts/contributed.tar.gz"
            ;;
        "international")
            collection_url="ftp://ftp.figlet.org/pub/figlet/fonts/international.tar.gz"
            ;;
        "ms-dos")
            collection_url="ftp://ftp.figlet.org/pub/figlet/fonts/ms-dos.tar.gz"
            ;;
        *)
            echo "Unknown collection: $collection"
            return 1
            ;;
    esac
    
    # Create font directory
    if [ "$(id -u)" -eq 0 ]; then
        FONT_DIR="/usr/local/share/figlet"
        mkdir -p "$FONT_DIR"
    else
        FONT_DIR="$HOME/.figlet"
        mkdir -p "$FONT_DIR"
    fi
    
    # Create temporary directory
    TMP_FONT_DIR=$(mktemp -d)
    if [ ! -d "$TMP_FONT_DIR" ]; then
        echo "❌ Failed to create temporary directory."
        return 1
    fi
    
    cd "$TMP_FONT_DIR" || { echo "❌ Failed to enter temp directory"; return 1; }
    
    echo "Downloading $collection collection..."
    if curl -s -o "${collection}.tar.gz" "$collection_url"; then
        echo "Extracting $collection fonts..."
        if tar -xzf "${collection}.tar.gz"; then
            local installed_count=0
            for font_file in *.flf; do
                if [ -f "$font_file" ]; then
                    cp "$font_file" "$FONT_DIR/"
                    installed_count=$((installed_count + 1))
                fi
            done
            echo "✅ Installed $installed_count fonts from $collection collection!"
            cd ~ || true
            rm -rf "$TMP_FONT_DIR"
            return 0
        else
            echo "❌ Failed to extract $collection archive."
            cd ~ || true
            rm -rf "$TMP_FONT_DIR"
            return 1
        fi
    else
        echo "❌ Failed to download $collection collection."
        cd ~ || true
        rm -rf "$TMP_FONT_DIR"
        return 1
    fi
}

validate_font_list() {
    local font_list="$1"
    local valid_fonts=""
    local invalid_fonts=""
    
    for font in $font_list; do
        if figlet -f "$font" "test" >/dev/null 2>&1; then
            valid_fonts="$valid_fonts $font"
        else
            invalid_fonts="$invalid_fonts $font"
        fi
    done
    
    echo "$valid_fonts|$invalid_fonts"
}

# ===== Main font management logic =====
if command -v figlet >/dev/null 2>&1; then
    echo ""
    echo "===== Font Management Setup ====="
    echo "figlet is installed. Let's configure your fonts!"
    echo ""
    
    # Discover what's available
    available_fonts=$(discover_system_fonts)
    available_count=$(echo "$available_fonts" | wc -w)
    
    echo "Found $available_count fonts currently available on your system:"
    if [ $available_count -gt 0 ]; then
        echo "$available_fonts" | tr ' ' '\n' | sort | column -c 80
    else
        echo "None found."
    fi
    echo ""
    echo "Font Configuration Options:"
    echo "1) Use fonts from base figlet installation only"
    echo "2) Download additional font collections from figlet.org"
    echo "3) Specify custom font directory path"
    echo "4) Manually edit font rotation list"
    echo "Enter your choice (1-4): "
    read font_option </dev/tty
    
    case "$font_option" in
        1)
            echo "Using base installation fonts only."
            if [ $available_count -gt 0 ]; then
                echo "Available fonts: $available_fonts"
                echo "Use all available fonts? (Y/N)"
                read use_all </dev/tty
                use_all=$(echo "$use_all" | tr '[:lower:]' '[:upper:]')
                
                if [ "$use_all" = "Y" ]; then
                    DESIRED_FONTS="$available_fonts"
                else
                    echo "Enter space-separated list of fonts to use:"
                    echo "Available: $available_fonts"
                    read selected_fonts </dev/tty
                    if [ -n "$selected_fonts" ]; then
                        validation=$(validate_font_list "$selected_fonts")
                        valid=$(echo "$validation" | cut -d'|' -f1)
                        invalid=$(echo "$validation" | cut -d'|' -f2)
                        
                        if [ -n "$invalid" ]; then
                            echo "⚠️  Invalid fonts (not available): $invalid"
                        fi
                        
                        if [ -n "$valid" ]; then
                            DESIRED_FONTS="$valid"
                            echo "Using fonts: $valid"
                        else
                            echo "No valid fonts selected. Using fallback."
                            DESIRED_FONTS="standard"
                        fi
                    else
                        DESIRED_FONTS="standard"
                    fi
                fi
            else
                echo "No fonts found in base installation. Using 'standard' fallback."
                DESIRED_FONTS="standard"
            fi
            ;;
            
        2)
            echo "Available font collections:"
            echo "  ours         - Standard figlet fonts (recommended)"
            echo "  contributed  - User-contributed fonts"
            echo "  international- International character sets"
            echo "  ms-dos       - MS-DOS style fonts"
            echo ""
            echo "Enter collections to download (space-separated, e.g., 'ours contributed'):"
            read collections </dev/tty
            
            if [ -n "$collections" ]; then
                for collection in $collections; do
                    download_font_collection "$collection"
                done
                
                # Re-discover fonts after download
                available_fonts=$(discover_system_fonts)
                available_count=$(echo "$available_fonts" | wc -w)
                echo ""
                echo "Now have $available_count fonts available:"
                echo "$available_fonts" | tr ' ' '\n' | sort | column -c 80
                echo ""
                echo "Use all downloaded fonts? (Y/N)"
                read use_all_downloaded </dev/tty
                use_all_downloaded=$(echo "$use_all_downloaded" | tr '[:lower:]' '[:upper:]')
                
                if [ "$use_all_downloaded" = "Y" ]; then
                    DESIRED_FONTS="$available_fonts"
                else
                    echo "Enter space-separated list of fonts to use:"
                    read selected_fonts </dev/tty
                    if [ -n "$selected_fonts" ]; then
                        validation=$(validate_font_list "$selected_fonts")
                        valid=$(echo "$validation" | cut -d'|' -f1)
                        invalid=$(echo "$validation" | cut -d'|' -f2)
                        
                        if [ -n "$invalid" ]; then
                            echo "⚠️  Invalid fonts: $invalid"
                        fi
                        
                        DESIRED_FONTS="${valid:-standard}"
                    else
                        DESIRED_FONTS="standard"
                    fi
                fi
            else
                echo "No collections selected. Using default fonts."
                DESIRED_FONTS="$DEFAULT_FONTS"
            fi
            ;;
            
        3)
            echo "Enter full path to figlet font directory:"
            read custom_font_dir </dev/tty
            
            if [ -d "$custom_font_dir" ]; then
                echo "Scanning $custom_font_dir for fonts..."
                custom_fonts=""
                for font_file in "$custom_font_dir"/*.flf; do
                    if [ -f "$font_file" ]; then
                        font_name=$(basename "$font_file" .flf)
                        if figlet -d "$custom_font_dir" -f "$font_name" "test" >/dev/null 2>&1; then
                            custom_fonts="$custom_fonts $font_name"
                        fi
                    fi
                done
                
                if [ -n "$custom_fonts" ]; then
                    custom_count=$(echo "$custom_fonts" | wc -w)
                    echo "Found $custom_count fonts in $custom_font_dir:"
                    echo "$custom_fonts" | tr ' ' '\n' | sort | column -c 80
                    echo ""
                    echo "Use all fonts from this directory? (Y/N)"
                    read use_custom_all </dev/tty
                    use_custom_all=$(echo "$use_custom_all" | tr '[:lower:]' '[:upper:]')
                    
                    if [ "$use_custom_all" = "Y" ]; then
                        DESIRED_FONTS="$custom_fonts"
                        CUSTOM_FONT_DIR="$custom_font_dir" 
                        # Note: This would require modifying the MOTD script to use -d flag
                        echo "⚠️  Note: Using custom directory requires manual MOTD script editing"
                        echo "    to add '-d $custom_font_dir' to figlet commands."
                    else
                        echo "Enter space-separated list of fonts to use:"
                        read selected_custom </dev/tty
                        DESIRED_FONTS="${selected_custom:-standard}"
                    fi
                else
                    echo "No valid fonts found in $custom_font_dir"
                    DESIRED_FONTS="standard"
                fi
            else
                echo "Directory $custom_font_dir not found. Using defaults."
                DESIRED_FONTS="$DEFAULT_FONTS"
            fi

            if [ -n "$custom_font_dir" ]; then
                FIGLET_CMD="figlet -d \"$custom_font_dir\" -f \"\$FOUND_FONT\" \"\$NAME\""
            else
                FIGLET_CMD='figlet -f "$FOUND_FONT" "$NAME"'
            fi
            ;;
            
        4)
            echo "Current default font list: $DEFAULT_FONTS"
            echo ""
            echo "These fonts are included with this script by default."
            echo "Enter your custom font rotation list (space-separated):"
            echo "Or press Enter to use defaults."
            read custom_list </dev/tty
            
            if [ -n "$custom_list" ]; then
                echo "Validating fonts..."
                validation=$(validate_font_list "$custom_list")
                valid=$(echo "$validation" | cut -d'|' -f1)
                invalid=$(echo "$validation" | cut -d'|' -f2)
                
                if [ -n "$invalid" ]; then
                    echo "⚠️  These fonts are not available and will be skipped: $invalid"
                    echo "Do you want to:"
                    echo "  1) Continue with valid fonts only: $valid"
                    echo "  2) Download missing fonts (if available in collections)"
                    echo "  3) Use default font list instead"
                    read invalid_choice </dev/tty
                    
                    case "$invalid_choice" in
                        1)
                            DESIRED_FONTS="${valid:-standard}"
                            ;;
                        2)
                            echo "Attempting to download standard collection to get missing fonts..."
                            download_font_collection "ours"
                            # Re-validate after download
                            validation=$(validate_font_list "$custom_list")
                            valid=$(echo "$validation" | cut -d'|' -f1)
                            invalid=$(echo "$validation" | cut -d'|' -f2)
                            
                            if [ -n "$invalid" ]; then
                                echo "Still missing: $invalid"
                                echo "Using available fonts: $valid"
                            fi
                            DESIRED_FONTS="${valid:-standard}"
                            ;;
                        3)
                            DESIRED_FONTS="$DEFAULT_FONTS"
                            ;;
                        *)
                            DESIRED_FONTS="${valid:-standard}"
                            ;;
                    esac
                else
                    DESIRED_FONTS="$valid"
                    echo "✅ All fonts validated successfully!"
                fi
            else
                DESIRED_FONTS="$DEFAULT_FONTS"
                echo "Using default font list."
            fi
            ;;
            
        *)
            echo "Invalid choice. Using default font configuration."
            DESIRED_FONTS="$DEFAULT_FONTS"
            ;;
    esac
    
    # Final validation and summary
    final_validation=$(validate_font_list "$DESIRED_FONTS")
    final_valid=$(echo "$final_validation" | cut -d'|' -f1)
    final_invalid=$(echo "$final_validation" | cut -d'|' -f2)
    
    if [ -n "$final_invalid" ]; then
        echo "⚠️  Final check - removing unavailable fonts: $final_invalid"
        DESIRED_FONTS="$final_valid"
    fi
    
    final_count=$(echo "$DESIRED_FONTS" | wc -w)
    echo ""
    echo "✅ Font configuration complete!"
    echo "Using $final_count fonts in rotation: $DESIRED_FONTS"
    
else
    echo "figlet is not available. Using fallback configuration."
    DESIRED_FONTS="standard"
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
STATE_FILE="$STATE_FILE_LOCATION" # File to store current font index

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
    $FIGLET_CMD | colorize
else
    echo "\$NAME" | colorize
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
