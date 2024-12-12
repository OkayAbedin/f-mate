#!/bin/bash

# Colors
RESET="\e[0m"
BOLD="\e[1m"
UNDERLINE="\e[4m"
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
WHITE="\e[97m"

# Function to handle errors
handle_error() {
    echo -e "${RED}Error: $1${RESET}"
    exit 1
}

# Ensure necessary commands are available
for cmd in awk sed date; do
    command -v $cmd >/dev/null 2>&1 || {
        echo "$cmd not found. Installing..."
        sudo apt-get install -y $cmd || handle_error "Failed to install $cmd."
    }
done

# Get current month and year
current_month=$(date +'%m') || handle_error "Failed to get current month."
current_year=$(date +'%Y') || handle_error "Failed to get current year."

# Define the customer CSV file based on the current month and year (Tab-separated)
customer_file="customers_${current_year}_${current_month}.csv"

# Ensure the customer file exists, create it if it doesn't
if [[ ! -f $customer_file ]]; then
    echo -e "Name\tPhone\tAddress\tProduct SKU\tQuantity\tOrder Date" > "$customer_file" || handle_error "Failed to create customer CSV file."
    echo -e "${GREEN}New customer CSV file created for $current_month/$current_year${RESET}"
fi

# Define the inventory file (Tab-separated)
inventory_file="inventory.csv"

# Ensure the inventory file exists
if [[ ! -f $inventory_file ]]; then
    echo -e "Product Name\tSKU\tSize\tColour\tQuantity\tPrice" > "$inventory_file" || handle_error "Failed to create inventory CSV file."
    echo -e "${GREEN}New inventory CSV file created.${RESET}"
fi

# Function to generate SKU
generate_sku() {
    product_name="$1"
    product_size="$2"
    product_color="$3"

    # Validate inputs
    [[ -z "$product_name" || -z "$product_size" || -z "$product_color" ]] && handle_error "Product name, size, and color must be provided."

    # Get the first letter of each word in product name
    product_name_abbr=$(echo "$product_name" | awk '{
        abbr="";
        for(i=1; i<=NF; i++) abbr=abbr substr($i,1,1);
        print abbr;
    }') || handle_error "Failed to generate SKU."

    # Get the first 3 letters of the color
    product_color_abbr=$(echo "$product_color" | awk '{print substr($0,1,3)}') || handle_error "Failed to generate SKU."

    # Construct the SKU and convert to uppercase
    product_sku="${product_name_abbr}-${product_size}-${product_color_abbr}"
    product_sku="${product_sku^^}"

    # Return the generated SKU
    echo "$product_sku"
}

# Customer Order Management Function
add_customer_order() {
    echo -e "${CYAN}--- Customer Order Management ---${RESET}"
    
    echo -e "${YELLOW}Enter customer name:${RESET}"
    while true; do
        read customer_name
        [[ -z "$customer_name" ]] && echo -e "${RED}Customer name cannot be empty. Please enter again:${RESET}" || break
    done

echo -e "${YELLOW}Enter customer phone (e.g., 01758459556):${RESET}"
while true; do
    read customer_phone
    if [[ -z "$customer_phone" || ! "$customer_phone" =~ ^[0-9]{11}$ ]]; then
        echo -e "${RED}Invalid phone number. Please enter exactly 11 digits:${RESET}"
    else
        customer_phone="+88$customer_phone"
        break
    fi
done

    echo -e "${YELLOW}Enter customer address:${RESET}"
    while true; do
        read customer_address
        [[ -z "$customer_address" ]] && echo -e "${RED}Customer address cannot be empty. Please enter again:${RESET}" || break
    done

    # Ask for product details
    echo -e "${YELLOW}Enter product name (e.g., 'T-shirt'):${RESET}"
    while true; do
        read product_name
        [[ -z "$product_name" ]] && echo -e "${RED}Product name cannot be empty. Please enter again:${RESET}" || break
    done

    echo -e "${YELLOW}Enter product size (e.g., XL, XXL):${RESET}"
    while true; do
        read product_size
        [[ -z "$product_size" ]] && echo -e "${RED}Product size cannot be empty. Please enter again:${RESET}" || break
    done

    echo -e "${YELLOW}Enter product color (e.g., Red, Blue):${RESET}"
    while true; do
        read product_color
        [[ -z "$product_color" ]] && echo -e "${RED}Product color cannot be empty. Please enter again:${RESET}" || break
    done

    # Call generate_sku function to create SKU
    product_sku=$(generate_sku "$product_name" "$product_size" "$product_color")

    # Check if the product SKU exists in the inventory
    product_in_inventory=$(awk -F"\t" -v sku="$product_sku" '$2 == sku {print $1}' "$inventory_file")

    if [[ -z "$product_in_inventory" ]]; then
        echo -e "${RED}Error: Product SKU '$product_sku' not found in inventory! Please check the SKU.${RESET}"
        return
    fi

    # Get available quantity from inventory
    available_quantity=$(awk -F"\t" -v sku="$product_sku" '$2 == sku {print $5}' "$inventory_file")
    
    while true; do
        echo -e "${YELLOW}Enter quantity to order (Available: $available_quantity):${RESET}"
        read product_quantity
        if [[ -z "$product_quantity" || ! "$product_quantity" =~ ^[0-9]+$ ]]; then
            echo -e "${RED}Invalid quantity. Please enter a positive number:${RESET}"
        elif [[ "$product_quantity" -gt "$available_quantity" || "$product_quantity" -le 0 ]]; then
            echo -e "${RED}Error: Ordered quantity exceeds available stock or is negative. Please enter a quantity less than or equal to $available_quantity.${RESET}"
        else
            break
        fi
    done

    # Get today's date as default, but user can modify it
    current_date=$(date +'%Y-%m-%d')
    while true; do
        echo -e "${YELLOW}Order Date (default is $current_date). Press Enter to accept or enter the date (YYYY-MM-DD):${RESET}"
        read -e order_date
        order_date=${order_date:-$current_date}  # If no input, use today's date
        if [[ "$order_date" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            break
        else
            echo -e "${RED}Invalid date format. Please enter the date in YYYY-MM-DD format:${RESET}"
        fi
    done

    # Save customer order to the current month's CSV (Tab-separated)
    echo -e "$customer_name\t$customer_phone\t$customer_address\t$product_sku\t$product_quantity\t$order_date" >> "$customer_file" || handle_error "Failed to add customer order."
    echo -e "${GREEN}Customer order added to $customer_file${RESET}"

    # Automatically update inventory after purchase
    update_inventory "$product_sku" "$product_quantity"
    count_product_orders "$product_sku"
}

# Stock Inventory Management Function
manage_inventory() {
    echo -e "${CYAN}--- Stock Inventory Management ---${RESET}"
    echo -e "${YELLOW}Choose action: (1) Add product (2) Update stock (3) Check low stock (4) Delete Stock${RESET}"
    read action

    case $action in
        1) # Add Product
            echo -e "${YELLOW}Enter product name:${RESET}"
            while true; do
                read product_name
                [[ -z "$product_name" ]] && echo -e "${RED}Product name cannot be empty. Please enter again:${RESET}" || break
            done

            echo -e "${YELLOW}Enter product size (e.g., XL, XXL):${RESET}"
            while true; do
                read product_size
                [[ -z "$product_size" ]] && echo -e "${RED}Product size cannot be empty. Please enter again:${RESET}" || break
            done

            echo -e "${YELLOW}Enter product color (e.g., Red, Blue):${RESET}"
            while true; do
                read product_color
                [[ -z "$product_color" ]] && echo -e "${RED}Product color cannot be empty. Please enter again:${RESET}" || break
            done

            echo -e "${YELLOW}Enter product quantity:${RESET}"
            while true; do
                read product_quantity
                [[ -z "$product_quantity" || ! "$product_quantity" =~ ^[0-9]+$ ]] && echo -e "${RED}Invalid quantity. Please enter a positive number:${RESET}" || break
            done

            echo -e "${YELLOW}Enter product price:${RESET}"
            while true; do
                read product_price
                [[ -z "$product_price" || ! "$product_price" =~ ^[0-9]+(\.[0-9]{1,2})?$ ]] && echo -e "${RED}Invalid price. Please enter a valid number:${RESET}" || break
            done

            # Call generate_sku function to create SKU
            product_sku=$(generate_sku "$product_name" "$product_size" "$product_color")

            # Add product to inventory (Tab-separated)
            echo -e "$product_name\t$product_sku\t$product_size\t$product_color\t$product_quantity\t$product_price" >> "$inventory_file" || handle_error "Failed to add product to inventory."
            echo -e "${GREEN}Product added successfully!${RESET}"
            ;;
        2) # Update Stock
            echo -e "${YELLOW}Enter product SKU to update stock:${RESET}"
            while true; do
            read product_sku
            [[ -z "$product_sku" ]] && echo -e "${RED}Product SKU cannot be empty. Please enter again:${RESET}" || break
            done

            # Show current available stock
            current_stock=$(awk -F"\t" -v sku="$product_sku" '$2 == sku {print $5}' "$inventory_file")
            if [[ -z "$current_stock" ]]; then
            echo -e "${RED}Product SKU '$product_sku' not found in inventory!${RESET}"
            break
            fi
            echo -e "${YELLOW}Current stock for SKU '$product_sku' is $current_stock. Enter new stock quantity:${RESET}"

            while true; do
            read new_stock
            [[ -z "$new_stock" || ! "$new_stock" =~ ^[0-9]+$ ]] && echo -e "${RED}Invalid quantity. Please enter a positive number:${RESET}" || break
            done

            # Show current price
            current_price=$(awk -F"\t" -v sku="$product_sku" '$2 == sku {print $6}' "$inventory_file")
            echo -e "${YELLOW}Current price for SKU '$product_sku'is $current_price. Enter new price:${RESET}"

            while true; do
            read new_price
            [[ -z "$new_price" || ! "$new_price" =~ ^[0-9]+(\.[0-9]{1,2})?$ ]] && echo -e "${RED}Invalid price. Please enter a valid number:${RESET}" || break
            done

            # Update product stock and price in inventory (Tab-separated)
            awk -F"\t" -v sku="$product_sku" -v stock="$new_stock" -v price="$new_price" 'BEGIN{OFS=FS} $2 == sku {$5 = stock; $6 = price} {print $0}' "$inventory_file" > temp && mv temp "$inventory_file" || handle_error "Failed to update stock and price."
            echo -e "${GREEN}Stock and price updated successfully!${RESET}"
            #notify_low_stock
            ;;
        3) # Check Low Stock
            echo -e "${CYAN}Checking for products with low stock (less than 3)...${RESET}"
            awk -F"\t" '$5 < 3 {print "Product Name: "$1, "SKU: "$2, "Size: "$3, "Color: "$4, "Quantity: "$5, "Price: "$6}' "$inventory_file"
            ;;
        4) #Delete Stock
            echo -e "${YELLOW}Enter product SKU to delete:${RESET}"
            while true; do
            read product_sku
            [[ -z "$product_sku" ]] && echo -e "${RED}Product SKU cannot be empty. Please enter again:${RESET}" || break
            done

            # Show current available stock
            current_stock=$(awk -F"\t" -v sku="$product_sku" '$2 == sku' "$inventory_file")
            if [[ -z "$current_stock" ]]; then
            echo -e "${RED}Product SKU '$product_sku' not found in inventory!${RESET}"
            break
            fi

            # Delete product from inventory
            awk -F"\t" -v sku="$product_sku" '$2 != sku' "$inventory_file" > temp && mv temp "$inventory_file" || handle_error "Failed to delete product from inventory."
            echo -e "${GREEN}Product with SKU '$product_sku' deleted successfully!${RESET}"
            ;;
        *)
            echo -e "${RED}Invalid choice. Please try again.${RESET}"
            ;;
    esac
}

# Function to notify low stock
notify_low_stock() {
    # Check inventory for any product with stock less than 3
    low_stock_notified=()
    while IFS=$'\t' read -r name sku size color quantity price; do
        # Only trigger alert if the quantity is less than 3 and notification hasn't been sent
        if [[ "$quantity" -lt 3 && "$quantity" -gt 0 && ! " ${low_stock_notified[@]} " =~ " ${sku} " ]]; then
            # Send email notification
            echo -e "Product \"$name\" (SKU: $sku) is low on stock. Only $quantity remaining." | mail -s "Low Stock Alert" minhazulabedin039@gmail.com
            echo -e "${RED}ALERT: Product '$name' (SKU: $sku) is low on stock! Only $quantity remaining.${RESET}"
            echo -e "${GREEN}Low stock alert email sent to minhazulabedin039@gmail.com${RESET}"
            low_stock_notified+=("$sku")
        fi
    done < "$inventory_file"
}

# Function to automatically update inventory when a product is purchased
update_inventory() {
    purchased_product_sku="$1"
    purchased_quantity="$2"
    
    # Check if the product exists in the inventory
    product_in_inventory=$(awk -F"\t" -v sku="$purchased_product_sku" '$2 == sku {print $1}' "$inventory_file")
    
    if [[ -z "$product_in_inventory" ]]; then
        echo -e "${RED}Product SKU '$purchased_product_sku' not found in inventory!${RESET}"
    else
        # Reduce the stock by the quantity for the purchased product
        awk -F"\t" -v sku="$purchased_product_sku" -v qty="$purchased_quantity" 'BEGIN{OFS="\t"} $2 == sku {$5=$5-qty} {print $0}' "$inventory_file" > temp && mv temp "$inventory_file" || handle_error "Failed to update inventory."
        echo -e "${GREEN}Inventory updated. $purchased_quantity item(s) with SKU '$purchased_product_sku' have been sold.${RESET}"
        notify_low_stock
    fi
}

# Function to count the number of orders for a specific product SKU
count_product_orders() {
    product_sku="$1"
    product_count=$(grep -c "$product_sku" "$customer_file") || handle_error "Failed to count product orders."
    echo -e "${MAGENTA}Total orders for product SKU '$product_sku': $product_count${RESET}"
}

# Function to generate sales report
generate_sales_report() {
    echo -e "${CYAN}--- Sales Report ---${RESET}"
    echo -e "${YELLOW}Generating sales report for $current_month/$current_year...${RESET}"
    
    # Check if the customer file exists
    if [[ ! -f $customer_file ]]; then
        echo -e "${RED}No customer orders found for $current_month/$current_year.${RESET}"
        return
    fi

    # Display the sales report
    awk -F"\t" 'BEGIN {print ""} {print $0}' "$customer_file"
}

# Function to generate inventory status
generate_inventory_status() {
    echo -e "${CYAN}--- Inventory Status ---${RESET}"
    echo -e "${YELLOW}Generating current inventory status...${RESET}"
    
    # Check if the inventory file exists
    if [[ ! -f $inventory_file ]]; then
        echo -e "${RED}No item found in inventory.${RESET}"
        return
    fi

    # Display the inventory status
    awk -F"\t" 'BEGIN {print ""} {print $0}' "$inventory_file"
}

# Function to generate business summary report
generate_summary_report() {
    echo -e "${CYAN}--- Business Summary Report ---${RESET}"
    echo -e "${YELLOW}Generating business summary report for $current_month/$current_year...${RESET}"
    
    # Check if the customer file exists
    if [[ ! -f $customer_file ]]; then
        echo -e "${RED}No customer orders found for $current_month/$current_year.${RESET}"
        return
    fi

    # Calculate total sales and total quantity sold
    total_sales=0
    total_quantity=0
    while IFS=$'\t' read -r name phone address sku quantity date; do
        total_quantity=$((total_quantity + quantity))
        price=$(awk -F"\t" -v sku="$sku" '$2 == sku {print $6}' "$inventory_file")
        total_sales=$(echo "$total_sales + ($price * $quantity)" | bc)
    done < <(tail -n +2 "$customer_file")  # Skip the header line

    echo -e "${GREEN}Total Sales: $total_sales${RESET}"
    echo -e "${GREEN}Total Quantity Sold: $total_quantity${RESET}"
}

# Function to backup customer and inventory files to GitHub
backup_files_to_github() {
    echo -e "${CYAN}--- Backup Files to GitHub ---${RESET}"

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

    echo -e "${GREEN}Backup completed successfully!${RESET}"
}

# Main Menu
while true; do
    echo -e "${BLUE}---------------------------------${RESET}"
    echo -e "${BOLD}${CYAN}Business Manager Tool - Choose an option:${RESET}"
    echo -e "${YELLOW}1) Customer Order Management"
    echo "2) Stock Inventory Management"
    echo "3) Sales Report"
    echo "4) Business Summary Report"
    echo "5) Inventory Status"
    echo "6) Backup Files to GitHub"
    echo -e "${BOLD}${RED}0) Exit${RESET}"
    echo -e "${BLUE}---------------------------------${RESET}"
    echo -e "${BOLD}${CYAN}Choose an option:${RESET}"
    read choice

    case $choice in
        1) add_customer_order ;;
        2) manage_inventory ;;
        3) generate_sales_report ;;
        4) generate_summary_report ;;
        5) generate_inventory_status ;;
        6) backup_files_to_github ;;
        0) exit ;;
        *) echo -e "${RED}Invalid option. Please try again.${RESET}" ;;
    esac
done
