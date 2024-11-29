#!/bin/bash

# Create the script file and write contents to user-pool.sh
cat << 'EOF' > user-pool.sh
#!/bin/bash

# Prompt the user for the User Pool Domain Prefix
read -p "Please enter the User Pool Domain Prefix (e.g., labbirdapp-####): " user_input

# Validate user input
if [[ -z "$user_input" ]]; then
    echo "Error: You must enter a value."
    read -p "Please enter the User Pool Domain Prefix (e.g., labbirdapp-####): " user_input
    exit 1
fi

echo "You entered: $user_input"

# Fetch the first CloudFront domain name
CLOUDFRONT_DOMAIN=$(aws cloudfront list-distributions \
    --query "DistributionList.Items[0].DomainName" \
    --output text)

if [[ -z "$CLOUDFRONT_DOMAIN" ]]; then
    echo "Error: No CloudFront distributions found."
    exit 1
fi

# Check if the User Pool already exists
USER_POOL_ID=$(aws cognito-idp list-user-pools --max-results 10 \
    --query "UserPools[?Name=='bird_app'].Id" \
    --output text)

if [[ -z "$USER_POOL_ID" ]]; then
    echo "Creating User Pool..."
    USER_POOL_ID=$(aws cognito-idp create-user-pool \
        --pool-name bird_app \
        --policies '{"PasswordPolicy":{"MinimumLength":8,"RequireUppercase":false,"RequireLowercase":false,"RequireNumbers":false,"RequireSymbols":false,"TemporaryPasswordValidityDays":7}}' \
        --username-configuration '{"CaseSensitive":false}' \
        --auto-verified-attributes "email" \
        --account-recovery-setting '{"RecoveryMechanisms":[{"Priority":1,"Name":"verified_email"}]}' \
        --admin-create-user-config '{"AllowAdminCreateUserOnly":true}' \
        --email-verification-message "Your verification code is {####}" \
        --email-verification-subject "Verify your email for bird_app" \
        --query "Id" \
        --output text)
else
    echo "User Pool already exists with ID: $USER_POOL_ID"
fi

# Wait for 120 seconds 
sleep 120

# Check if the User Pool Domain already exists
EXISTING_DOMAIN=$(aws cognito-idp describe-user-pool-domain \
    --domain "$user_input" \
    --query "DomainDescription.Domain" \
    --output text 2>/dev/null)

if [[ "$EXISTING_DOMAIN" == "$user_input" ]]; then
    echo "User Pool Domain already exists: $user_input"
else
    echo "Creating User Pool Domain..."
    aws cognito-idp create-user-pool-domain \
        --domain "$user_input" \
        --user-pool-id "$USER_POOL_ID" || {
        echo "Error: Failed to create User Pool Domain.";
    }
fi

# Check if the User Pool Client already exists
EXISTING_CLIENT=$(aws cognito-idp list-user-pool-clients \
    --user-pool-id "$USER_POOL_ID" \
    --query "UserPoolClients[?ClientName=='bird_app_client'].ClientId" \
    --output text)

if [[ -z "$EXISTING_CLIENT" ]]; then
    echo "Creating User Pool Client..."
    aws cognito-idp create-user-pool-client \
        --user-pool-id "$USER_POOL_ID" \
        --client-name bird_app_client \
        --generate-secret \
        --explicit-auth-flows "ALLOW_USER_PASSWORD_AUTH" "ALLOW_REFRESH_TOKEN_AUTH" \
        --supported-identity-providers "COGNITO" \
        --callback-urls "https://$CLOUDFRONT_DOMAIN/callback.html" \
        --logout-urls "https://$CLOUDFRONT_DOMAIN/logout.html" \
        --allowed-o-auth-flows "code" "implicit" \
        --allowed-o-auth-scopes "email" "openid" \
        --allowed-o-auth-flows-user-pool-client || {
        echo "Error: Failed to create User Pool Client.";
    }
else
    echo "User Pool Client already exists with ID: $EXISTING_CLIENT"
fi

# Output results
echo -e "\nScript completed successfully!\n"
echo "CloudFront Domain: $CLOUDFRONT_DOMAIN"
echo "User Pool ID: $USER_POOL_ID"
echo "Cognito Domain Prefix: $user_input"
EOF

# Make the script executable
chmod +x user-pool.sh

# Notify the user
echo "The script has been written to user-pool.sh and is ready to run."

./user-pool.sh
