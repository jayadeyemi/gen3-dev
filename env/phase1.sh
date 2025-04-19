#!/bin/bash

# status=0

##################################################################################################################
# Phase 1: VPC, Subnets, and EC2-v1 with In-Memory Database
##################################################################################################################

echo "-------------------------------------------------------------------------------------------------------------"
echo "############################################################################################################"
echo "# Starting Phase 1: VPC, Subnets, and EC2-v1 with In-Memory Database"
echo "############################################################################################################"
echo -e "\n\n\n"
# echo status code
echo "Status code: $status"
# Create a VPC
if [[ $status -eq 0 ]]; then
    execute_command "MAIN_VPC_ID=\$(aws ec2 create-vpc --cidr-block \"$VPC_CIDR\" --query 'Vpc.VpcId' --output text)"
    status=$?
fi

# Name the VPC
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 create-tags --resources \"$MAIN_VPC_ID\" --tags Key=Name,Value=\"$VPC_NAME\""
    status=$?
fi

# Enable DNS hostnames and support in the VPC
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 modify-vpc-attribute --vpc-id $MAIN_VPC_ID --enable-dns-hostnames '{\"Value\":true}'"
    execute_command "aws ec2 modify-vpc-attribute --vpc-id $MAIN_VPC_ID --enable-dns-support '{\"Value\":true}'"
    status=$?
fi

# Wait for the VPC to be available
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 wait vpc-available --vpc-ids \"$MAIN_VPC_ID\""
    status=$?
fi

# Create the Public Subnet1
if [[ $status -eq 0 ]]; then
    execute_command "PUB_SUBNET1=\$(aws ec2 create-subnet --vpc-id \"$MAIN_VPC_ID\" --cidr-block \"$PUB_SUBNET1_CIDR\" --availability-zone $AVAILABILITY_ZONE1 --query 'Subnet.SubnetId' --output text)"
    status=$?
fi

# Name the Public Subnet1
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 create-tags --resources \"$PUB_SUBNET1\" --tags Key=Name,Value=\"$PUB_SUBNET1_NAME\""
    status=$?
fi

# Create the Public Subnet2
if [[ $status -eq 0 ]]; then
    execute_command "PUB_SUBNET2=\$(aws ec2 create-subnet --vpc-id \"$MAIN_VPC_ID\" --cidr-block \"$PUB_SUBNET2_CIDR\" --availability-zone $AVAILABILITY_ZONE2 --query 'Subnet.SubnetId' --output text)"
    status=$?
fi

# Name the Public Subnet2
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 create-tags --resources \"$PUB_SUBNET2\" --tags Key=Name,Value=\"$PUB_SUBNET2_NAME\""
    status=$?
fi

# Create the Private Subnet1
if [[ $status -eq 0 ]]; then
    execute_command "PRIV_SUBNET1=\$(aws ec2 create-subnet --vpc-id \"$MAIN_VPC_ID\" --cidr-block \"$PRIV_SUBNET1_CIDR\" --availability-zone $AVAILABILITY_ZONE1 --query 'Subnet.SubnetId' --output text)"
    status=$?
fi

# Name the Private Subnet1
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 create-tags --resources \"$PRIV_SUBNET1\" --tags Key=Name,Value=\"$PRIV_SUBNET1_NAME\""
    status=$?
fi

# Create the Private Subnet2
if [[ $status -eq 0 ]]; then
    execute_command "PRIV_SUBNET2=\$(aws ec2 create-subnet --vpc-id \"$MAIN_VPC_ID\" --cidr-block \"$PRIV_SUBNET2_CIDR\" --availability-zone $AVAILABILITY_ZONE2 --query 'Subnet.SubnetId' --output text)"
    status=$?
fi

# Name the Private Subnet2
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 create-tags --resources \"$PRIV_SUBNET2\" --tags Key=Name,Value=\"$PRIV_SUBNET2_NAME\""
    status=$?
fi

# Wait for all subnets to be available
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 wait subnet-available --subnet-ids \"$PUB_SUBNET1\" \"$PUB_SUBNET2\" \"$PRIV_SUBNET1\" \"$PRIV_SUBNET2\""
    status=$?
fi

# Modify the Public Subnet1 to enable auto-assign public IP on launch
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 modify-subnet-attribute --subnet-id \"$PUB_SUBNET1\" --map-public-ip-on-launch"
    status=$?
fi

# Modify the Public Subnet2 to enable auto-assign public IP on launch
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 modify-subnet-attribute --subnet-id \"$PUB_SUBNET2\" --map-public-ip-on-launch"
    status=$?
fi

# Retrieve the Main Route Table ID
if [[ $status -eq 0 ]]; then
    execute_command "MAIN_ROUTE_TABLE_ID=\$(aws ec2 describe-route-tables --filters \"Name=vpc-id,Values=$MAIN_VPC_ID\" \"Name=association.main,Values=true\" --query \"RouteTables[0].RouteTableId\" --output text)"
    status=$?
fi

# Rename the main route table to public route table
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 create-tags --resources \"$MAIN_ROUTE_TABLE_ID\" --tags \"Key=Name,Value=$PUB_ROUTE_TABLE_NAME\""
    status=$?
    # Change the variable name to reflect the new name
    PUB_ROUTE_TABLE_ID=$MAIN_ROUTE_TABLE_ID
fi

# Create a route table for the private subnets
if [[ $status -eq 0 ]]; then
    execute_command "PRIV_ROUTE_TABLE_ID=\$(aws ec2 create-route-table --vpc-id \"$MAIN_VPC_ID\" --query 'RouteTable.RouteTableId' --output text)"
    status=$?
fi

# Name the private route table
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 create-tags --resources \"$PRIV_ROUTE_TABLE_ID\" --tags Key=Name,Value=\"$PRIV_ROUTE_TABLE_NAME\""
    status=$?
fi

# Create a route table for the database subnets
if [[ $status -eq 0 ]]; then
    execute_command "DB_ROUTE_TABLE_ID=\$(aws ec2 create-route-table --vpc-id \"$MAIN_VPC_ID\" --query 'RouteTable.RouteTableId' --output text)"
    status=$?
fi

# Associate main route table with public subnet 1
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 associate-route-table --route-table-id \"$PUB_ROUTE_TABLE_ID\" --subnet-id \"$PUB_SUBNET1\" --output text"
    status=$?
fi

# Associate main route table with public subnet 2
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 associate-route-table --route-table-id \"$PUB_ROUTE_TABLE_ID\" --subnet-id \"$PUB_SUBNET2\" --output text"
    status=$?
fi

# Associate private route table with private subnet 1
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 associate-route-table --route-table-id \"$PRIV_ROUTE_TABLE_ID\" --subnet-id \"$PRIV_SUBNET1\" --output text"
    status=$?
fi

# Associate private route table with private subnet 2
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 associate-route-table --route-table-id \"$PRIV_ROUTE_TABLE_ID\" --subnet-id \"$PRIV_SUBNET2\" --output text"
    status=$?
fi

# Create an Internet Gateway
if [[ $status -eq 0 ]]; then
    execute_command "IGW_ID=\$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)"
    status=$?
fi

# Name the Internet Gateway
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 create-tags --resources \"$IGW_ID\" --tags Key=Name,Value=\"$IGW_TAG\""
    status=$?
fi

# Attach the Internet Gateway to the VPC
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 attach-internet-gateway --vpc-id \"$MAIN_VPC_ID\" --internet-gateway-id \"$IGW_ID\""
    status=$?
fi

# Create a route in the main route table to the Internet Gateway
if [[ $status -eq 0 ]]; then
    execute_command "ROUTE3=\$(aws ec2 create-route --route-table-id \"$PUB_ROUTE_TABLE_ID\" --destination-cidr-block \"$INTERNET_CIDR\" --gateway-id \"$IGW_ID\" --output text)"
    status=$?
fi

# Create a security group for EC2-V1 instance in the main VPC
if [[ $status -eq 0 ]]; then
    execute_command "EC2_V1_SG_ID=\$(aws ec2 create-security-group --group-name \"$EC2_V1_SG_NAME\" --description \"Inventory Server Security Group\" --vpc-id \"$MAIN_VPC_ID\" --query 'GroupId' --tag-specifications \"ResourceType=security-group,Tags=[{Key=Name,Value=$EC2_V1_SG_NAME}]\" --output text)"
    status=$?
fi

# Authorize SSH access to the EC2-V1 security group from the user's Public IP for Remote Access
if [[ $status -eq 0 ]]; then
    execute_command "EC2_V1_SG_USER_ACCESS=\$(aws ec2 authorize-security-group-ingress --group-id \"$EC2_V1_SG_ID\" --protocol tcp --port 22 --cidr \"$USER_CIDR\" --query 'SecurityGroupRules[0].SecurityGroupRuleId' --output text)"
    status=$?
fi

# Authorize HTTP access to the EC2-V1 security group from the Internet
if [[ $status -eq 0 ]]; then
    execute_command "EC2_V1_SG_INTERNET_ACCESS=\$(aws ec2 authorize-security-group-ingress --group-id \"$EC2_V1_SG_ID\" --protocol tcp --port 80 --cidr \"$INTERNET_CIDR\" --query 'SecurityGroupRules[0].SecurityGroupRuleId' --output text)"
    status=$?
fi

# Create a key pair for the EC2 instance
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 create-key-pair --key-name \"$PUBLIC_KEY\" --key-type rsa --key-format \"$KEY_FORMAT\" --query 'KeyMaterial' --output text > \"$PUB_KEY\""
    status=$?
fi

# Set the correct permissions for saving the key pair
if [[ $status -eq 0 ]]; then
    # Ensure SSH directory exists
    mkdir -p "$HOME/.ssh"
    # Remove any old copy of this key
    rm -f "$HOME/.ssh/$(basename "$PUB_KEY")"
    # Move the key into place and tighten permissions
    mv "$PUB_KEY" "$HOME/.ssh/$(basename "$PUB_KEY")"
    chmod 600 "$HOME/.ssh/$(basename "$PUB_KEY")"
    status=$?
fi

# Launch the EC2 instance
if [[ $status -eq 0 ]]; then
    echo "Launching EC2-v1 instance..."
    execute_command "INSTANCE_ID=\$(aws ec2 run-instances --image-id \"$AMI_ID\" --count 1 --instance-type t2.micro --key-name \"$PUBLIC_KEY\" --security-group-ids \"$EC2_V1_SG_ID\" --subnet-id \"$PUB_SUBNET1\" --user-data file://\"$USER_DATA_FILE_V1\" --tag-specifications \"ResourceType=instance,Tags=[{Key=Name,Value=\"$EC2_V1_NAME\"}]\" --query 'Instances[0].InstanceId' --output text)"
    status=$?
fi

# Wait for the instance to be running
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 wait instance-running --instance-ids \"$INSTANCE_ID\""
    status=$?
fi

# Wait for the instance to be in a okay status
if [[ $status -eq 0 ]]; then
    execute_command "aws ec2 wait instance-status-ok --instance-ids \"$INSTANCE_ID\" --cli-read-timeout 0"
    status=$?
fi

# Obtain the public IP address of the EC2 instance
if [[ $status -eq 0 ]]; then
    execute_command "INSTANCE_PUBLIC_IP=\$(aws ec2 describe-instances --instance-ids \"$INSTANCE_ID\" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)"
    status=$?
fi

# Obtain the private IP address of the EC2 instance
if [[ $status -eq 0 ]]; then
    execute_command "INSTANCE_PRIVATE_IP=\$(aws ec2 describe-instances --instance-ids \"$INSTANCE_ID\" --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)"
    status=$?
fi

if [[ $status -eq 0 ]]; then
    SSH_FILE="$(dirname "$0")/SSH_code.sh"
    EC2_HOST="ec2-${INSTANCE_PUBLIC_IP//./-}.compute-1.amazonaws.com"

    # Remove old script if it exists
    [[ -f "$SSH_FILE" ]] && rm -f "$SSH_FILE"

    # Write new SSH wrapper
    cat > "$SSH_FILE" <<EOF
#!/usr/bin/env bash
set -euo pipefail

# SSH into the EC2 instance
ssh -t \\
    -i "\$HOME/.ssh/$(basename "$PUB_KEY")" \\
    -o StrictHostKeyChecking=no \\
    ubuntu@"$EC2_HOST"
EOF

    # Make it executable
    chmod +x "$SSH_FILE"
fi


if [[ $status -eq 0 ]]; then
    echo -e "\n\n\n"
    echo "############################################################################################################"
    echo "# Phase 1 Completed Successfully."
    echo "# You can access the application at http://$INSTANCE_PUBLIC_IP"
    echo "# Please wait for the instance to be ready."
    echo "# Insert data into the application DB on the web page"
    echo "############################################################################################################"
    echo "-------------------------------------------------------------------------------------------------------------"
else
    echo -e "\n\n\n"
    echo "############################################################################################################"
    echo "# Phase 1 Failed: Please check the last error message above."
    echo "# Please check log files dumped in the Cloud9 directory for more information."
    echo "############################################################################################################"
    echo "-------------------------------------------------------------------------------------------------------------"
fi
echo -e "\n\n\n"

##################################################################################################################
# End of Phase 1
##################################################################################################################
