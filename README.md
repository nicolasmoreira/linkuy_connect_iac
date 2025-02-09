# LinkuyConnect Infrastructure as Code (IaC)

This repository contains the Terraform configuration files for provisioning and managing the infrastructure required by LinkuyConnect. The project is designed to be cost-efficient, leveraging AWS Free Tier resources whenever possible.

## Project Overview

LinkuyConnect is an open-source project designed to enable families to easily set up and deploy a private instance of the application for family members. This repository automates the provisioning of the required cloud infrastructure using Terraform.

## Infrastructure Components

### AWS Services Used
- **VPC**: Default VPC and subnets.
- **RDS**: Managed PostgreSQL instance with TimescaleDB extensions.
- **Lambda**: For serverless function execution.
- **SQS**: Message queuing service for async processing.
- **SNS**: Simple Notification Service for alerts and event-driven messaging.
- **API Gateway**: HTTP API for frontend-backend communication.
- **EC2**: Worker instance for processing SQS messages asynchronously.

### File Structure
```plaintext
.
├── .terraform/             # Terraform state files
├── builds/                 # Compiled assets (e.g., Lambda ZIP files)
├── lambda/                 # Source code for Lambda functions
├── main.tf                 # Main Terraform configuration
├── outputs.tf              # Output definitions
├── variables.tf            # Input variables
├── terraform.tfvars        # Variable values
├── LICENSE                 # Project license
├── README.md               # This file
└── .gitignore              # Git ignore rules
```

## Requirements

- Terraform v1.5 or higher
- AWS CLI configured with appropriate credentials
- An AWS account with permissions to manage the listed resources

## Usage

1. **Clone the Repository**
   ```bash
   git clone https://github.com/nicolasmoreira/linkuy_connect_iac
   cd linkuy_connect_iac
   ```

2. **Configure Variables**
   Update `terraform.tfvars` with your environment-specific values.

3. **Initialize Terraform**
   ```bash
   terraform init
   ```

4. **Plan Infrastructure Changes**
   ```bash
   terraform plan
   ```

5. **Apply Changes**
   ```bash
   terraform apply
   ```

6. **Access Resources**
   - **API Gateway**: Access endpoints via the generated API Gateway URL.
   - **RDS**: Connect to the TimescaleDB instance using the provided credentials.
   - **SQS**: Verify message processing via the configured queue.
   - **SNS**: Monitor event-driven alerts and notifications.

## Environment Variables for Lambda

The following environment variables are configured for Lambda functions:
- `DB_HOST`: RDS endpoint
- `DB_NAME`: Database name
- `DB_USER`: Database username
- `DB_PASS`: Database password
- `SQS_QUEUE_URL`: SQS queue URL
- `SNS_TOPIC_ARN`: SNS topic ARN for notifications
- `ENVIRONMENT`: Deployment environment (e.g., `dev`, `prod`)

## Contributing

Contributions are welcome! Please submit a pull request or open an issue if you encounter any problems.

## License

This project is licensed under the Apache License 2.0. See the [LICENSE](LICENSE) file for details.

## Support

For questions or support, please contact the project maintainer or create an issue in this repository.
