#! /bin/bash
cd "$(dirname $0)"

# Help function to display usage information
function display_help() {
  echo "Usage: $(basename $0) <domain_name> [zone]"
  echo "Update the firewall rules with the resolved IP address of the given domain name."
  echo "Arguments:"
  echo "  domain_name     The domain name whose IP address needs to be updated in the firewall."
  echo "  zone            (Optional) The firewall zone where the IP address should be updated. Default is 'trusted' zone."
  echo "Options:"
  echo "  -h, --help      Display this help message."
}

# Check if the script was invoked with the -h or --help option
if [[ $1 == "-h" || $1 == "--help" ]]; then
  display_help
  exit 0
fi

# Check if the domain name argument is missing
if [[ -z $1 ]]; then
  echo "Error: Domain name argument is missing."
  display_help
  exit 1
fi

# Using positional vars $1 domain name $2 zone
dyn_name="$1"
# defaults to trusted zone
if [[ $2 = "" ]]; then
  zone="trusted"
else
  zone="$2"
fi

# Function to log error messages
function log_error() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $@"
  logger "$(basename $0): [ERROR] $@"
}

# Function to log info messages
function log_info() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') [INFO] $@"
  logger "$(basename $0): [INFO] $@"
}

# Check response from dig - must not be empty (not resolved / no connection)
function fn_dig_check() {
  if [[ $newip == "" ]]; then
    log_error "Domain not resolved: domain=$dyn_name zone=$zone"
    exit 2
  fi
}

# Check if new IP present in the firewall. If present in the desired zone, exit.
# If present in a different zone, exit with an error.
function fn_in_firewall() {
  if firewall-cmd --get-active-zones | grep -q "$newip"; then
    if ! firewall-cmd --list-sources --zone="$zone" | grep -q "$newip"; then
      log_error "Source conflict: domain=$dyn_name zone=$zone ip=$newip"
      exit 2
    else
      exit
    fi
  fi
}

# Check if the old IP is in the firewall. Update firewall.
function fn_update() {
  oldip="$(/bin/cat ./ip_of_$dyn_name 2>/dev/null)"
  if firewall-cmd --list-sources --zone="$zone" | grep -q "$oldip" && [[ ! $oldip == "" ]]; then
    firewall-cmd --remove-source="$oldip" --zone="$zone"
    log_info "Rule changed, IP removed: domain=$dyn_name zone=$zone oldip=$oldip"
    fn_update_action
  else
    fn_update_action
  fi
}

# For compact code
function fn_update_action() {
  firewall-cmd --add-source="$newip" --zone="$zone"
  echo "$newip" > ./ip_of_$dyn_name
  log_info "Rule changed, IP added: domain=$dyn_name zone=$zone newip=$newip"
}

# Main script execution
newip="$(/usr/bin/dig "$dyn_name" +short | head -1)"
fn_dig_check
fn_in_firewall
fn_update
exit