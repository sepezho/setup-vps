#!/bin/bash

clear

set -o pipefail  # Prevents errors in a pipeline from being masked

# Start timer
start_time=$(date +%s)

# Function to update the timer at the top of the terminal
update_timer() {
    while true; do
        current_time=$(date +%s)
        elapsed_time=$(( current_time - start_time ))
        minutes=$(( elapsed_time / 60 ))
        seconds=$(( elapsed_time % 60 ))
        # Move cursor to top left corner and clear the line
        printf "\033[1;1H\033[2K"
        echo "Elapsed time: ${minutes} minutes and ${seconds} seconds"
        sleep 1
    done
}

# Start the timer update function in the background
update_timer &

# Save the PID of the background process
timer_pid=$!

# When the script exits, kill the background process
trap "kill $timer_pid" EXIT

# Fix locale warnings
export LANGUAGE=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
sudo locale-gen en_US.UTF-8 > /dev/null 2>&1
sudo dpkg-reconfigure --frontend=noninteractive locales > /dev/null 2>&1

# Handle the sshd_config prompt automatically
export DEBIAN_FRONTEND=noninteractive

# Array to hold installation results
declare -A install_results
# Array to hold error logs
declare -A error_logs

# Progress variables
total_steps=22  # Increased total steps due to added installations
current_step=0

# Move cursor to the line below the timer
printf "\n"

echo "Starting installation process..."

# Function to run commands and capture logs if errors occur
run_command() {
    local component="$1"
    shift
    local log_file="/tmp/${component// /_}_install.log"
    # Run the command, redirect output to log file
    "$@" > "$log_file" 2>&1
    local status=$?
    current_time=$(date +%s)
    elapsed_time=$(( current_time - start_time ))
    minutes=$(( elapsed_time / 60 ))
    seconds=$(( elapsed_time % 60 ))
    current_step=$(( current_step + 1 ))
    percentage=$(( current_step * 100 / total_steps ))
    echo "Progress: $percentage% completed. (Elapsed time: ${minutes}m ${seconds}s)"
    if [ $status -eq 0 ]; then
        install_results["$component"]="Success"
        # Remove the log file as the installation was successful
        rm -f "$log_file"
    else
        install_results["$component"]="Failed"
        # Store the log file path
        error_logs["$component"]="$log_file"
        echo "An error occurred during installation of $component."
        echo "Attempting to fix with 'sudo dpkg --configure -a'..."
        sudo dpkg --configure -a
    fi
}

echo "whtf is this..."
run_command "Upgrade packages" sudo dpkg --configure -a 

echo "Updating package list..."
run_command "Update package list" sudo apt-get update -y

echo "Upgrading installed packages..."
run_command "Upgrade packages" sudo apt-get upgrade -y

echo "Installing necessary packages..."
run_command "Necessary packages" sudo apt-get install -y xclip curl build-essential libudev-dev pkg-config libclang-dev software-properties-common python3 python3-pip ruby-full neovim tmux ftp lftp fish apt-transport-https ca-certificates locales git rsync

# --- Install npm ---
echo "Installing npm..."
run_command "npm" sudo apt-get install -y npm

# --- Install ts-node ---
echo "Installing ts-node..."
run_command "ts-node" sudo apt-get install -y ts-node

# --- Install Nginx & Certbot ---
echo "Installing nginx & certbot..."
run_command "nginx & certbot" sudo apt install -y nginx certbot python3-certbot-nginx

# --- Install nvm and node (without npm) ---
echo "Installing nvm and node..."
run_command "nvm and node" bash -c "
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash && \
    export NVM_DIR=\"\$HOME/.nvm\" && \
    [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\" && \
    nvm install node && \
    nvm use node"

# --- Install Yarn ---
echo "Installing Yarn..."
run_command "Yarn" bash -c "
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo gpg --dearmor -o /usr/share/keyrings/yarn-archive-keyring.gpg && \
    echo \"deb [signed-by=/usr/share/keyrings/yarn-archive-keyring.gpg] https://dl.yarnpkg.com/debian/ stable main\" | sudo tee /etc/apt/sources.list.d/yarn.list && \
    sudo apt-get update -y && \
    sudo apt-get install -y yarn"

# --- Install TypeScript via npm ---
echo "Installing TypeScript via npm..."
run_command "TypeScript" bash -c "sudo npm install -g typescript"

# --- Install Rust ---
echo "Installing Rust..."
run_command "Rust" bash -c "
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    source \$HOME/.cargo/env"

# --- Install Ruby and Bundler ---
echo "Installing Ruby and Bundler..."
run_command "Ruby and Bundler" gem install bundler --no-document --quiet

# --- Install Neovim ---
echo "Installing Neovim..."
run_command "Neovim" bash -c "
    sudo add-apt-repository ppa:neovim-ppa/stable -y && \
    sudo apt-get update -y && \
    sudo apt-get install -y neovim"

# --- Install and configure Fish shell ---
echo "Installing and configuring Fish shell..."
run_command "Fish shell" bash -c "
    sudo apt-get install -y fish && \
    sudo chsh -s /usr/bin/fish \$USER"

# --- Install Oh My Fish ---
echo "Installing Oh My Fish..."
run_command "Oh My Fish" bash -c "
    curl -L https://get.oh-my.fish | fish"

# --- Install Docker ---
echo "Installing Docker..."
run_command "Docker" bash -c "
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list && \
    sudo apt-get update -y && \
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io && \
    sudo systemctl start docker && \
    sudo systemctl enable docker && \
    docker --version && \
    sudo docker run hello-world"

# Install Docker Compose
echo "Installing Docker Compose..."
run_command "Docker Compose" bash -c "
    sudo curl -L \"https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose && \
    sudo chmod +x /usr/local/bin/docker-compose && \
    docker-compose --version"

# --- Clone Dotfiles ---
echo "Cloning and setting up dotfiles..."
run_command "Dotfiles" bash -c "
    mkdir -p ~/.config && \
    cd ~/.config && \
    if [ -d 'dotfiles' ]; then rm -rf dotfiles; fi && \
    git clone https://github.com/sepezho/dotfiles.git && \
    rsync -a dotfiles/ ./ && \
    rm -rf dotfiles && \
    git clone https://github.com/tmux-plugins/tpm ~/.config/tmux/plugins/tpm && \
    chmod +x ~/.config/tmux/copy.sh && \
    tmux source ~/.config/tmux/tmux.conf"

# Install tmux plugins
echo "Installing tmux plugins..."
run_command "tmux plugins" bash -c "~/.config/tmux/plugins/tpm/bin/install_plugins"

echo "Configuring Git..."
run_command "Git configuration" bash -c "
    git config --global user.email \"sepezho@gmail.com\" && \
    git config --global user.name \"sepezho\""

# Install SQLite3
echo "Installing SQLite3..."
run_command "SQLite3" sudo apt-get install -y sqlite3

# Source tmux and fish configurations
echo "Sourcing tmux and fish configurations..."
tmux source-file ~/.config/tmux/tmux.conf
fish -c 'source ~/.config/fish/config.fish'

# Configure tmux to auto-start on SSH login
echo "Configuring tmux to auto-start on SSH login with Fish shell..."
cat << 'EOF' >> ~/.config/fish/config.fish

# Start tmux automatically on SSH login
if status is-interactive
    if not set -q TMUX
        if test -n "$SSH_TTY"
            tmux attach-session -t default || tmux new-session -s default
        end
    end
end
EOF

echo "Installation process completed!"

# Output installation results
echo ""
echo "--------------------------"
echo "       Installations      "
echo "--------------------------"
for component in "${!install_results[@]}"; do
    echo "$component: ${install_results[$component]}"
done

# Verify installations
echo ""
echo "--------------------------"
echo "     Verification Check   "
echo "--------------------------"

verify_installation() {
    local cmd="$1"
    local name="$2"
    if command -v $cmd > /dev/null 2>&1; then
        echo "$name is installed."
    else
        echo "$name is NOT installed."
    fi
}

verify_installation "node" "Node.js"
verify_installation "npm" "npm"
verify_installation "ts-node" "ts-node"
verify_installation "yarn" "Yarn"
verify_installation "tsc" "TypeScript"
verify_installation "rustc" "Rust"
verify_installation "bundler" "Bundler"
verify_installation "nvim" "Neovim"
verify_installation "fish" "Fish shell"
verify_installation "docker" "Docker"
verify_installation "docker-compose" "Docker Compose"
verify_installation "sqlite3" "SQLite3"
verify_installation "nginx" "Nginx" # Added Nginx verification

echo ""
echo "All checks completed!"

# Display error logs for failed installations
if [ ${#error_logs[@]} -ne 0 ]; then
    echo ""
    echo "--------------------------"
    echo "  Error Logs for Failures "
    echo "--------------------------"
    for component in "${!error_logs[@]}"; do
        echo ""
        echo "----- $component -----"
        cat "${error_logs[$component]}"
    done
fi

# End timer
end_time=$(date +%s)
elapsed_time=$(( end_time - start_time ))
minutes=$(( elapsed_time / 60 ))
seconds=$(( elapsed_time % 60 ))
echo "Total time elapsed: ${minutes} minutes and ${seconds} seconds"

# Kill the background timer process
kill $timer_pid

