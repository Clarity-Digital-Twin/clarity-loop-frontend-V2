# AWS Amplify Configuration Setup

## IMPORTANT: Configuration Values Needed

The `amplifyconfiguration.json` file has been created with placeholder values that need to be replaced with actual AWS Cognito values:

1. **[COGNITO_IDENTITY_POOL_ID]** - AWS Cognito Identity Pool ID
2. **[COGNITO_USER_POOL_ID]** - AWS Cognito User Pool ID  
3. **[COGNITO_CLIENT_ID]** - AWS Cognito App Client ID

## Backend Configuration

The backend is configured to use:
- **Production URL**: https://clarity.novamindnyc.com
- **AWS Region**: us-east-1
- **S3 Bucket**: clarity-health-uploads
- **DynamoDB Table**: clarity-health-data

## Getting the Configuration Values

To get the actual values, you need to:

1. Access AWS Console → Cognito
2. Find the CLARITY user pool
3. Copy the User Pool ID
4. Go to App Integration → App clients
5. Copy the App Client ID
6. If using Identity Pool, get that ID from Federated Identities

## Security Note

Never commit the actual configuration values to the repository. Use environment variables or secure configuration management for production deployments.