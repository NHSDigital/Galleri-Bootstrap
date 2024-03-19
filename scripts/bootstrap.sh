#!/bin/bash

set -e

STATE_BUCKET_NAME="galleri-github-oidc-tf-aws-tfstates"
STATE_LOCK_TABLE_NAME="terraform-state-lock-dynamo"
AWS_REGION="eu-west-2"
ENVIRONMENT="" #Read "environment-type" environment variable
ACCOUNT_ID="" #Populate from Github secrets

# Create Terraform state s3 bucket
if [[ -z $(aws s3api head-bucket --bucket "${ENVIRONMENT}-${STATE_BUCKET_NAME}" 2>&1) ]]; then
  echo "S3 bucket \"${ENVIRONMENT}-${STATE_BUCKET_NAME}\" already exists"
else
  echo "Creating S3 bucket \"${ENVIRONMENT}-${STATE_BUCKET_NAME}\""
  aws s3api create-bucket --bucket "${ENVIRONMENT}-${STATE_BUCKET_NAME}" --region "${AWS_REGION}" --create-bucket-configuration LocationConstraint="${AWS_REGION}"
fi

# Create dyamodb table for terraform state locking
if aws dynamodb describe-table --table-name $STATE_LOCK_TABLE_NAME 2>/dev/null; then
    echo "DynamoDB Table: $STATE_LOCK_TABLE_NAME found, Skipping DynamoDB table creation ..."
else 
    echo "DynamoDB Table: $STATE_LOCK_TABLE_NAME not found, Creating DynamoDB table ..."
    aws dynamodb create-table --table-name $STATE_LOCK_TABLE_NAME --attribute-definitions AttributeName=LockID,AttributeType=S --key-schema AttributeName=LockID,KeyType=HASH --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5
fi

## Github IAM Role

# Open ID Connect
if aws iam get-open-id-connect-provider --open-id-connect-provider-arn arn:aws:iam::$ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com 2>/dev/null; then
  echo "OIDC Provider already exists"
else
  # aws iam create-open-id-connect-provider \
  #     --cli-input-json file://create-open-id-connect-provider.json 
  aws iam create-open-id-connect-provider --cli-input-json \
  '{
    "Url": "https://token.actions.githubusercontent.com",
    "ClientIDList": ["sts.amazonaws.com"],
    "ThumbprintList": ["1c58a3a8518e8759bf075b76b750d4f2df264fcd"],
    "Tags": [
      {
        "Key": "github",
        "Value": "galleri-client"
      }
    ]
  }
  '
fi

# Custom policies
if aws iam get-policy --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/terraform-states-bucket-access 2>/dev/null; then
  echo "Policy: terraform-states-bucket-access found, Skipping policy creation ..."
else
  aws iam create-policy --policy-name terraform-states-bucket-access --policy-document \
  '{
      "Version": "2012-10-17",
      "Statement": [
          {
              "Effect": "Allow",
              "Action": [
                  "s3:PutObject",
                  "s3:GetObject",
                  "s3:ListBucket"
              ],
              "Resource": [
                  "arn:aws:s3:::galleri-github-oidc-tf-aws-tfstates/*",
                  "arn:aws:s3:::galleri-github-oidc-tf-aws-tfstates"
              ]
          }
      ]
  }'
fi
if aws iam get-policy --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/kms-policy 2>/dev/null; then
  echo "Policy: kms-policy found, Skipping policy creation ..."
else
aws iam create-policy --policy-name kms-policy --policy-document \
'{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Statement1",
            "Effect": "Allow",
            "Action": [
                "kms:*"
            ],
            "Resource": "*"
        }
    ]
}'
fi
if aws iam get-policy --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/IAMCreateRoleCustom 2>/dev/null; then
  echo "Policy: IAMCreateRoleCustom found, Skipping policy creation ..."
else
aws iam create-policy --policy-name IAMCreateRoleCustom --policy-document \
'{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "Role",
            "Effect": "Allow",
            "Action": [
                "iam:CreateRole",
                "iam:ListRolePolicies",
                "iam:ListAttachedRolePolicies",
                "iam:ListInstanceProfilesForRole",
                "iam:DeleteRole",
                "iam:*"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}'
fi

if aws iam get-role --role-name github-oidc-invitations-role 2>/dev/null; then
  echo "Role: github-oidc-invitations-role found, Skipping role creation ..."
else
  aws iam create-role --role-name github-oidc-invitations-role --assume-role-policy-document \
  "{
    \"Version\": \"2012-10-17\",
    \"Statement\": [
      {
        \"Effect\": \"Allow\",
        \"Principal\": {
          \"Federated\": \"arn:aws:iam::$ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com\"
        },
        \"Action\": \"sts:AssumeRoleWithWebIdentity\",
        \"Condition\": {
          \"StringEquals\": {
            \"token.actions.githubusercontent.com:aud\": \"sts.amazonaws.com\"
          },
          \"StringLike\": {
            \"token.actions.githubusercontent.com:sub\": \"repo:NHSDigital/Galleri-Invitations:*\"
          }
        }
      }
    ]
  }
  "
  # aws iam create-role --role-name github-oidc-invitations-role --assume-role-policy-document file://test.json
  aws iam attach-role-policy --role-name github-oidc-invitations-role --policy-arn arn:aws:iam::aws:policy/AdministratorAccess-AWSElasticBeanstalk
  aws iam attach-role-policy --role-name github-oidc-invitations-role --policy-arn arn:aws:iam::aws:policy/AmazonAPIGatewayAdministrator
  aws iam attach-role-policy --role-name github-oidc-invitations-role --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess
  aws iam attach-role-policy --role-name github-oidc-invitations-role --policy-arn arn:aws:iam::aws:policy/AmazonEC2FullAccess
  aws iam attach-role-policy --role-name github-oidc-invitations-role --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess
  aws iam attach-role-policy --role-name github-oidc-invitations-role --policy-arn arn:aws:iam::aws:policy/AWSLambda_FullAccess
  aws iam attach-role-policy --role-name github-oidc-invitations-role --policy-arn arn:aws:iam::aws:policy/CloudWatchFullAccess
  aws iam attach-role-policy --role-name github-oidc-invitations-role --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite
  aws iam attach-role-policy --role-name github-oidc-invitations-role --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/IAMCreateRoleCustom
  aws iam attach-role-policy --role-name github-oidc-invitations-role --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/kms-policy
  # aws iam attach-role-policy --role-name github-oidc-invitations-role --policy-arn arn:aws:iam::$ACCOUNT_ID:policy/terraform-states-bucket-access
fi


# S3 - Create bucket and populate with files

## galleri-ons-data bucket
## galleri-test-data bucket
## participating-icb bucket


## SECRETS
# TODO: Move to Terraform

# MESH_URL
if aws secretsmanager describe-secret --secret-id MESH_URL 2>/dev/null; then
  echo "Secret MESH_URL found, skipping"
else
  echo eyAiTUVTSF9VUkwiOiAiaHR0cHM6Ly9tc2cuaW50c3BpbmVzZXJ2aWNlcy5uaHMudWsiIH0K | base64 -d > MESH_URL.json
  aws secretsmanager create-secret --name MESH_URL --secret-string file://MESH_URL.json
fi
# MESH_SHARED_KEY_1
if aws secretsmanager describe-secret --secret-id MESH_SHARED_KEY_1 2>/dev/null; then
  echo "Secret MESH_SHARED_KEY_1 found, skipping"
else
  echo eyAiTUVTSF9TSEFSRURfS0VZIjogIkJhY2tCb25lIiB9Cg== | base64 -d > MESH_SHARED_KEY_1.json
  aws secretsmanager create-secret --name MESH_SHARED_KEY_1 --secret-string file://MESH_SHARED_KEY_1.json
fi
# MESH_SENDER_MAILBOX_ID
if aws secretsmanager describe-secret --secret-id MESH_SENDER_MAILBOX_ID 2>/dev/null; then
  echo "Secret MESH_SENDER_MAILBOX_ID found, skipping"
else
  echo eyAiTUVTSF9TRU5ERVJfTUFJTEJPWF9JRCI6ICJYMjZPVDI2NSIgfQo= | base64 -d > MESH_SENDER_MAILBOX_ID.json
  aws secretsmanager create-secret --name MESH_SENDER_MAILBOX_ID --secret-string file://MESH_SENDER_MAILBOX_ID.json
fi
# MESH_SENDER_MAILBOX_PASSWORD
if aws secretsmanager describe-secret --secret-id MESH_SENDER_MAILBOX_PASSWORD 2>/dev/null; then
  echo "Secret MESH_SENDER_MAILBOX_PASSWORD found, skipping"
else
  echo eyAiTUVTSF9TRU5ERVJfTUFJTEJPWF9QQVNTV09SRCI6ICJkcXNiT0V3S2VRM2EiIH0K | base64 -d > MESH_SENDER_MAILBOX_PASSWORD.json
  aws secretsmanager create-secret --name MESH_SENDER_MAILBOX_PASSWORD --secret-string file://MESH_SENDER_MAILBOX_PASSWORD.json
fi
# MESH_RECEIVER_MAILBOX_ID
if aws secretsmanager describe-secret --secret-id MESH_RECEIVER_MAILBOX_ID 2>/dev/null; then
  echo "Secret MESH_RECEIVER_MAILBOX_ID found, skipping"
else
  echo eyAiTUVTSF9SRUNFSVZFUl9NQUlMQk9YX0lEIjogIlgyNk9UMjY0IiB9Cg== | base64 -d > MESH_RECEIVER_MAILBOX_ID.json
  aws secretsmanager create-secret --name MESH_RECEIVER_MAILBOX_ID --secret-string file://MESH_RECEIVER_MAILBOX_ID.json
fi
# MESH_RECEIVER_MAILBOX_PASSWORD
if aws secretsmanager describe-secret --secret-id MESH_RECEIVER_MAILBOX_PASSWORD 2>/dev/null; then
  echo "Secret MESH_RECEIVER_MAILBOX_PASSWORD found, skipping"
else
  echo eyAiTUVTSF9SRUNFSVZFUl9NQUlMQk9YX1BBU1NXT1JEIjogIjh1NFYwTjFhMm5BNSIgfQo= | base64 -d > MESH_RECEIVER_MAILBOX_PASSWORD.json
  aws secretsmanager create-secret --name MESH_RECEIVER_MAILBOX_PASSWORD --secret-string file://MESH_RECEIVER_MAILBOX_PASSWORD.json
fi
# GTMS_MESH_MAILBOX_ID
if aws secretsmanager describe-secret --secret-id GTMS_MESH_MAILBOX_ID 2>/dev/null; then
  echo "Secret GTMS_MESH_MAILBOX_ID found, skipping"
else
  echo eyAiR1RNU19NRVNIX01BSUxCT1hfSUQiOiAiWDI2T1QyNjYiIH0K | base64 -d > GTMS_MESH_MAILBOX_ID.json
  aws secretsmanager create-secret --name GTMS_MESH_MAILBOX_ID --secret-string file://GTMS_MESH_MAILBOX_ID.json
fi
# GTMS_MESH_MAILBOX_PASSWORD
if aws secretsmanager describe-secret --secret-id GTMS_MESH_MAILBOX_PASSWORD 2>/dev/null; then
  echo "Secret GTMS_MESH_MAILBOX_PASSWORD found, skipping"
else
  echo eyAiR1RNU19NRVNIX01BSUxCT1hfUEFTU1dPUkQiOiAiM1loNjVmMDE3VU9BIiB9Cg== | base64 -d > GTMS_MESH_MAILBOX_PASSWORD.json
  aws secretsmanager create-secret --name GTMS_MESH_MAILBOX_PASSWORD --secret-string file://GTMS_MESH_MAILBOX_PASSWORD.json
fi
# CAAS_MESH_MAILBOX_ID
if aws secretsmanager describe-secret --secret-id CAAS_MESH_MAILBOX_ID 2>/dev/null; then
  echo "Secret CAAS_MESH_MAILBOX_ID found, skipping"
else
  echo eyAiQ0FBU19NRVNIX01BSUxCT1hfSUQiOiAiWDI2T1QyNjciIH0K | base64 -d > CAAS_MESH_MAILBOX_ID.json
  aws secretsmanager create-secret --name CAAS_MESH_MAILBOX_ID --secret-string file://CAAS_MESH_MAILBOX_ID.json
fi
# CAAS_MESH_MAILBOX_PASSWORD
if aws secretsmanager describe-secret --secret-id CAAS_MESH_MAILBOX_PASSWORD 2>/dev/null; then
  echo "Secret CAAS_MESH_MAILBOX_PASSWORD found, skipping"
else
  echo eyAiQ0FBU19NRVNIX01BSUxCT1hfUEFTU1dPUkQiOiAiUnY2VTIzakIwMU9WIiB9Cg== | base64 -d > CAAS_MESH_MAILBOX_PASSWORD.json
  aws secretsmanager create-secret --name CAAS_MESH_MAILBOX_PASSWORD --secret-string file://CAAS_MESH_MAILBOX_PASSWORD.json
fi