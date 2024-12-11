#!/bin/bash

# Function to handle errors
handle_error() {
    echo "Error: $1"
    exit 1
}

# Define the customer and inventory files
current_month=$(date +'%m')
current_year=$(date +'%Y')
customer_file="customers_${current_year}_${current_month}.csv"
inventory_file="inventory.csv"

# Function to backup customer and inventory files to GitHub
backup_files_to_github() {
    echo "--- Backup Files to GitHub ---"

    # Ensure git is installed
    command -v git >/dev/null 2>&1 || handle_error "git command not found. Please install it."

    # Ensure the repository is initialized
    if [[ ! -d .git ]]; then
        git init || handle_error "Failed to initialize git repository."
        git remote add origin git@github.com:OkayAbedin/f-mate.git || handle_error "Failed to add remote repository."
    fi

    # Add files to the repository
    git add "$customer_file" "$inventory_file" || handle_error "Failed to add files to git."

    # Commit the changes
    commit_message="Backup on $(date +'%Y-%m-%d %H:%M:%S')"
    git commit -m "$commit_message" || handle_error "Failed to commit changes."

    # Push the changes to the remote repository
    git push origin master || handle_error "Failed to push changes to GitHub."

    echo "Backup completed successfully!"
}

# Call the backup function
backup_files_to_github