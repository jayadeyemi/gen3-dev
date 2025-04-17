#!/bin/bash
##################################################################################################################
# Phase 5: Cleanup
##################################################################################################################

echo -e "/n/n/n"
echo "############################################################################################################"
echo "# Starting Phase 5: Cleanup of provisioned Resources"
echo "############################################################################################################"
echo -e "\n\n\n"
# Helper function
check_command_success() {
    if [ $? -eq 0 ]; then
        echo "$1 succeeded."
    else
        echo "$1 failed or resource does not exist. Skipping..."
    fi
}

# Delete key pairs
for key_name in "$PUBLIC_KEY" "$PRIVATE_KEY"; do
    if [ -n "$key_name" ]; then
        aws ec2 delete-key-pair \
            --key-name "$key_name" || true
        # Reference the current file location
        rm 
        check_command_success ""
    fi
done

# Scale down ASG before deletion
aws autoscaling update-auto-scaling-group --auto-scaling-group-name "$ASG_NAME" --min-size 0 --desired-capacity 0 || true
check_command_success ""

# Terminate EC2 instances
for instance_id in "$INSTANCE_ID" "$NEW_INSTANCE_ID"; do
    if [ -n "$instance_id" ]; then
        aws ec2 terminate-instances --instance-ids "$instance_id" --output text > /dev/null 2>&1
        check_command_success ""

    fi
done

# Delete Launch Template
echo "Deleting Launch Template..."
if aws ec2 describe-launch-templates --launch-template-names "$LAUNCH_TEMPLATE_NAME" >/dev/null 2>&1; then
    aws ec2 delete-launch-template --launch-template-name "$LAUNCH_TEMPLATE_NAME"
    check_command_success ""
fi

# Deregister Server V1 AMI
if [ -n "$SERVER_V1_IMAGE_ID" ]; then
    aws ec2 deregister-image --image-id "$SERVER_V1_IMAGE_ID"
    check_command_success ""
fi

# Deregister Server V2 AMI
if [ -n "$SERVER_V2_IMAGE_ID" ]; then
    aws ec2 deregister-image --image-id "$SERVER_V2_IMAGE_ID"
    check_command_success ""
fi

# Delete RDS instance
if aws rds describe-db-instances --db-instance-identifier "$RDS_IDENTIFIER" >/dev/null 2>&1; then
    aws rds delete-db-instance --db-instance-identifier "$RDS_IDENTIFIER" --skip-final-snapshot > /dev/null 2>&1
    check_command_success ""
fi

# Delete Load Balancer and Target Group
if [ -n "$LB_ARN" ]; then
    aws elbv2 delete-load-balancer --load-balancer-arn "$LB_ARN"
    check_command_success ""
    sleep 30
fi

# Delete Target Group
if [ -n "$TG_ARN" ]; then
    aws elbv2 delete-target-group --target-group-arn "$TG_ARN"
    check_command_success ""
fi
# Delete listener
if [ -n "$LB_ARN" ]; then
    aws elbv2 delete-listener --load-balancer-arn "$LB_ARN" --port 80
    check_command_success ""
fi

# List and process ingress rules for the Cloud9 security group
for sg_id in "$EC2_V1_SG_ID" "$RDS_SG" "$LB_SG", "$EC2_V1_SG_ID", "$ASG_SG_ID"; do
    # Retrieve ingress rule IDs for the specified security group
    rule_ids=$(aws ec2 describe-security-group-rules \
        --filters Name="group-id",Values="$CLOUD9_SG_ID" Name="is-egress",Values="false" \
        --query "SecurityGroupRules[?GroupId=='$CLOUD9_SG_ID'].SecurityGroupRuleId" \
        --output text)

    # Check if there are any rules to revoke
    if [[ -n "$rule_ids" ]]; then
        # Revoke the ingress rules
        aws ec2 revoke-security-group-ingress --group-id "$CLOUD9_SG_ID" --security-group-rule-ids $rule_ids
        check_command_success ""
    else
        echo "No ingress rules found for security group $CLOUD9_SG_ID"
    fi
done

# Delete Auto Scaling Group
if aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "$EC2_ASG_NAME" >/dev/null 2>&1; then
    aws autoscaling delete-auto-scaling-group --auto-scaling-group-name "$EC2_ASG_NAME" --force-delete
    check_command_success ""
fi

# List of security group IDs
for sg_id in "$EC2_V1_SG_ID" "$RDS_SG_ID" "$EC2_V2_SG_ID", "$LB_SG_ID", "$ASG_SG_ID"; do
    if [[ -n "$sg_id" ]]; then
        echo "Processing Security Group: $sg_id"

        # Fetch all ingress rule IDs for the security group
        rule_ids=$(aws ec2 describe-security-group-rules \
            --filters Name="group-id",Values="$sg_id" Name="is-egress",Values="false" \
            --query "SecurityGroupRules[?GroupId=='$sg_id'].SecurityGroupRuleId" \
            --output text)

        # Revoke each rule
        if [[ -n "$rule_ids" ]]; then
            for rule in $rule_ids; do
                # Revoke each rule and log the result
                if aws ec2 revoke-security-group-ingress --group-id "$sg_id" --security-group-rule-ids "$rule" --output text; then
                    check_command_success ""
                else
                    echo "Failed to revoke rule $rule from $sg_id" 
                fi
            done
        else
            echo "No ingress rules found for Security Group: $sg_id"
        fi
    else
        echo "Security Group ID is empty, skipping."
    fi
done

for sg_id in "$EC2_V1_SG_ID" "$RDS_SG_ID" "$EC2_V2_SG_ID", "$LB_SG_ID", "$ASG_SG_ID"; do
    echo "Deleting Security Groups..."
    if [ -n "$sg_id" ]; then
        aws ec2 delete-security-group --group-id "$sg_id" || true
        check_command_success ""
    fi
done

# wait for db instance to be deleted before deleting the security group
if [ -n "$RDS_IDENTIFIER" ]; then
    aws rds wait db-instance-deleted --db-instance-identifier "$RDS_IDENTIFIER" || true
fi
# Delete RDS DB Subnet Group
echo "Deleting DB Subnet Group..."
aws rds delete-db-subnet-group \
    --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" || true
check_command_success ""

aws ec2 delete-route --route-table-id "$ROUTE_TABLE_ID" --destination-cidr-block "$VPC_CIDR"
check_command_success ""

# Delete NAT Gateway and Elastic IP
echo "Deleting NAT Gateway..."
if [ -n "$NAT_GW_ID" ]; then
    aws ec2 delete-nat-gateway --nat-gateway-id "$NAT_GW_ID" || true
    aws ec2 wait nat-gateway-deleted --nat-gateway-ids "$NAT_GW_ID" || true
    check_command_success ""
fi
#wait for the NAT Gateway to be deleted before releasing the Elastic IP
if [ -n "$NAT_GW_ID" ]; then
    aws ec2 wait nat-gateway-deleted --nat-gateway-ids "$NAT_GW_ID" || true
fi

echo "Releasing Elastic IP..."
if [ -n "$EIP_ALLOC" ]; then
    aws ec2 release-address --allocation-id "$EIP_ALLOC" || true
    check_command_success ""
fi

echo "Detaching and deleting Internet Gateway..."
if [ -n "$IGW_ID" ] && [ -n "$MAIN_VPC_ID" ]; then
    sleep 10
    aws ec2 detach-internet-gateway --internet-gateway-id "$IGW_ID" --vpc-id "$MAIN_VPC_ID" || true
    sleep 10
    aws ec2 delete-internet-gateway --internet-gateway-id "$IGW_ID" || true
    check_command_success ""
fi
# Delete VPC Peering Connection and Routes
echo "Deleting Route Tables for VPC Peering Connection..."
if [ -n "$DEFAULT_ROUTE_TABLE_ID" ]; then
    aws ec2 delete-route --route-table-id "$DEFAULT_ROUTE_TABLE_ID" --destination-cidr-block "$VPC_CIDR" || true
    check_command_success ""
fi

echo "Deleting VPC Peering Connection..."
if [ -n "$PEERING_CONNECTION_ID" ]; then
    aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id "$PEERING_CONNECTION_ID" || true
    check_command_success ""
fi

# Delete Subnets
echo "Deleting Subnets..."
for subnet_id in "$PUB_SUBNET1" "$PUB_SUBNET2" "$PRIV_SUBNET1" "$PRIV_SUBNET2" "$DB_SUBNET1" "$DB_SUBNET2"; do
    if [ -n "$subnet_id" ]; then
        aws ec2 delete-subnet \
            --subnet-id "$subnet_id" || true
    check_command_success ""
    fi
done

# Delete Route Tables
if [ -n "$PUB_ROUTE_TABLE_ID" ]; then
    aws ec2 delete-route-table --route-table-id "$PUB_ROUTE_TABLE_ID" || true
    check_command_success ""
fi

if [ -n "$PRIV_ROUTE_TABLE_ID" ]; then
    aws ec2 delete-route-table --route-table-id "$PRIV_ROUTE_TABLE_ID" || true
    check_command_success ""
fi

if [ -n "$DB_ROUTE_TABLE_ID" ]; then
    aws ec2 delete-route-table --route-table-id "$DB_ROUTE_TABLE_ID" || true
    check_command_success ""
fi

# Wait one minute and Delete VPC
echo "Deleting VPC..."
if [ -n "$MAIN_VPC_ID" ]; then
    sleep 10
    aws ec2 delete-vpc --vpc-id "$MAIN_VPC_ID" || true
    check_command_success ""
fi
echo -e "\n\n\n"
echo "############################################################################################################"
echo "# DB Secret must not be deleted."
echo "# VPC needs to be deleted manually."
echo "# Phase 5: Cleanup complete."
echo "############################################################################################################"
echo -e "\n\n\n"

##################################################################################################################
# End of Phase 5
##################################################################################################################