#!/bin/bash

set -o pipefail  # Prevents errors in a pipeline from being masked

# Start timer
start_time=$(date +%s)

# Log file for main logs
main_log_file="/tmp/install_script.log"
> "$main_log_file"  # Clear the log file at the start

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

echo "Starting installation process..." | tee -a "$main_log_file"

# Function to run commands and capture logs if errors occur
run_command() {
    local component="$1"
    shift
    local log_file="/tmp/${component// /_}_install.log"
    echo "Running $component..." | tee -a "$main_log_file"
    
    # Run the command, redirect output to log file
    "$@" > "$log_file" 2>&1
    local status=$?
    
    # Calculate elapsed time
    current_time=$(date +%s)
    elapsed_time=$(( current_time - start_time ))
    minutes=$(( elapsed_time / 60 ))
    seconds=$(( elapsed_time % 60 ))
    
    # Progress tracking
    current_step=$(( current_step + 1 ))
    percentage=$(( current_step * 100 / total_steps ))
    echo "Progress: $percentage% completed. (Elapsed time: ${minutes}m ${seconds}s)" | tee -a "$main_log_file"
    
    if [ $status -eq 0 ]; then
        install_results["$component"]="Success"
        echo "$component: Success" | tee -a "$main_log_file"
        # Remove the log file as the installation was successful
        rm -f "$log_file"
    else
        install_results["$component"]="Failed"
        # Store the log file path
        error_logs["$component"]="$log_file"
        echo "An error occurred during installation of $component." | tee -a "$main_log_file"
        echo "Attempting to fix with 'sudo dpkg --configure -a'..." | tee -a "$main_log_file"
        sudo dpkg --configure -a | tee -a "$main_log_file"
    fi
}

run_command "Upgrade packages" sudo dpkg --configure -a 

echo "Updating package list..." | tee -a "$main_log_file"
run_command "Update package list" sudo apt-get update -y

echo "Upgrading installed packages..." | tee -a "$main_log_file"
run_command "Upgrade packages" sudo apt-get upgrade -y

echo "Installing necessary packages..." | tee -a "$main_log_file"
run_command "Necessary packages" sudo apt-get install -y xclip curl build-essential libudev-dev pkg-config libclang-dev software-properties-common python3 python3-pip ruby-full neovim tmux ftp lftp fish apt-transport-https ca-certificates locales git rsync

# --- Install npm ---
run_command "npm" sudo apt-get install -y npm

# --- Install ts-node ---
run_command "ts-node" sudo apt-get install -y ts-node

# --- Install Nginx & Certbot ---
run_command "nginx & certbot" sudo apt install -y nginx certbot python3-certbot-nginx

# --- Install nvm and node (without npm) ---
run_command "nvm and node" bash -c "
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.4/install.sh | bash && \
    export NVM_DIR=\"\$HOME/.nvm\" && \
    [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\" && \
    nvm install node && \
    nvm use node"

# --- Install Yarn ---
run_command "Yarn" bash -c "
    curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo gpg --dearmor -o /usr/share/keyrings/yarn-archive-keyring.gpg && \
    echo \"deb [signed-by=/usr/share/keyrings/yarn-archive-keyring.gpg] https://dl.yarnpkg.com/debian/ stable main\" | sudo tee /etc/apt/sources.list.d/yarn.list && \
    sudo apt-get update -y && \
    sudo apt-get install -y --force-yes yarn"

# --- Install TypeScript via npm ---
run_command "TypeScript" bash -c "sudo npm install -g typescript"

# --- Install Rust ---
run_command "Rust" bash -c "
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y && \
    source \$HOME/.cargo/env"

# --- Install Ruby and Bundler ---
run_command "Ruby and Bundler" gem install bundler --no-document --quiet

# --- Install Neovim ---
run_command "Neovim" bash -c "
    sudo add-apt-repository ppa:neovim-ppa/stable -y && \
    sudo apt-get update -y && \
    sudo apt-get install -y neovim"

# --- Install and configure Fish shell ---
run_command "Fish shell" bash -c "
    sudo apt-get install -y fish && \
    sudo chsh -s /usr/bin/fish \$USER"

# --- Install Oh My Fish ---
run_command "Oh My Fish" bash -c "
    curl -L https://get.oh-my.fish | fish"

# --- Install Docker ---
run_command "Docker" bash -c "
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable\" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    sudo apt-get update -y && \
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io && \
    sudo systemctl start docker && \
    sudo systemctl enable docker && \
    docker --version && \
    sudo docker run hello-world"

# Install Docker Compose
run_command "Docker Compose" bash -c "
    sudo curl -L \"https://github.com/docker/compose/releases/latest/download/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose && \
    sudo chmod +x /usr/local/bin/docker-compose && \
    docker-compose --version"

# --- Clone Dotfiles ---
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
run_command "tmux plugins" bash -c "~/.config/tmux/plugins/tpm/bin/install_plugins"

# Configure Git
run_command "Git configuration" bash -c "
    git config --global user.email \"sepezho@gmail.com\" && \
    git config --global user.name \"sepezho\""

# Install SQLite3
run_command "SQLite3" sudo apt-get install -y sqlite3

echo "Installation process completed!" | tee -a "$main_log_file"

# Output installation results
echo ""
echo "--------------------------" | tee -a "$main_log_file"
echo "       Installations      " | tee -a "$main_log_file"
echo "--------------------------" | tee -a "$main_log_file"
for component in "${!install_results[@]}"; do
    echo "$component: ${install_results[$component]}" | tee -a "$main_log_file"
done

# Verify installations
echo ""
echo "--------------------------" | tee -a "$main_log_file"
echo "     Verification Check   " | tee -a "$main_log_file"
echo "--------------------------" | tee -a "$main_log_file"

verify_installation() {
    local cmd="$1"
    local name="$2"
    if command -v $cmd > /dev/null 2>&1; then
        echo "$name is installed." | tee -a "$main_log_file"
    else
        echo "$name is NOT installed." | tee -a "$main_log_file"
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
echo "All checks completed!" | tee -a "$main_log_file"

# Display error logs for failed installations
if [ ${#error_logs[@]} -ne 0 ]; then
    echo ""
    echo "--------------------------" | tee -a "$main_log_file"
    echo "  Error Logs for Failures " | tee -a "$main_log_file"
    echo "--------------------------" | tee -a "$main_log_file"
    for component in "${!error_logs[@]}"; do
        echo ""
        echo "----- $component -----" | tee -a "$main_log_file"
        cat "${error_logs[$component]}" | tee -a "$main_log_file"
    done
fi

# End timer
end_time=$(date +%s)
elapsed_time=$(( end_time - start_time ))
minutes=$(( elapsed_time / 60 ))
seconds=$(( elapsed_time % 60 ))
echo "Total time elapsed: ${minutes} minutes and ${seconds} seconds" | tee -a "$main_log_file"


