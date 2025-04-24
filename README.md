# LinkuyConnect Infrastructure as Code (IaC)

This repository contains the Terraform configuration files for provisioning and managing the infrastructure required by LinkuyConnect. The project is designed to be cost-efficient, leveraging AWS Free Tier resources whenever possible.

## Project Overview

LinkuyConnect is an open-source project designed to enable families to easily set up and deploy a private instance of the application for family members. This repository automates the provisioning of the required cloud infrastructure using Terraform.

## Infrastructure Components

### AWS Services Used

- **VPC**: Default VPC and subnets with custom security groups
- **RDS**: Managed PostgreSQL instance with TimescaleDB extensions
- **Lambda**: Serverless functions for data processing
- **SQS**: Message queuing service for async processing
- **API Gateway**: HTTP API for frontend-backend communication
- **EC2**: Worker instance for processing SQS messages asynchronously
- **IAM**: Role-based access control and permissions management

### Security Groups

- **RDS Security Group**: Controls access to the PostgreSQL database
- **EC2 Security Group**: Manages access to the worker instance

### File Structure

```plaintext
.
├── .terraform/              # Terraform state files
├── builds/                  # Compiled assets (e.g., Lambda ZIP files)
├── lambda/                  # Source code for Lambda functions
├── main.tf                  # Main Terraform configuration
├── outputs.tf               # Output definitions
├── variables.tf             # Input variables
├── terraform.tfvars         # Variable values
├── terraform.tfvars.example # Example variable values
├── install.sh               # Installation script
├── LICENSE                  # Project license
├── README.md                # This file
└── .gitignore               # Git ignore rules
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

   - Copy `terraform.tfvars.example` to `terraform.tfvars`
   - Update `terraform.tfvars` with your environment-specific values

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
   - **API Gateway**: Access endpoints via the generated API Gateway URL
   - **RDS**: Connect to the TimescaleDB instance using the provided credentials
   - **SQS**: Verify message processing via the configured queue
   - **EC2**: Access the worker instance for processing SQS messages

## Environment Variables

The following environment variables are configured for Lambda functions:

- `DB_USERNAME`: Database username
- `DB_PASSWORD`: Database password
- `DB_NAME`: Database name
- `RDS_ENDPOINT`: RDS instance endpoint
- `RDS_ENGINE_VERSION`: PostgreSQL engine version
- `SQS_QUEUE_URL`: SQS queue URL
- `ENVIRONMENT`: Deployment environment (e.g., `dev`, `prod`)

## Security

- Database encryption is configurable via `db_encryption_enabled`
- Security groups restrict access to specific IP ranges
- IAM roles follow the principle of least privilege
- RDS instance is publicly accessible (configurable)

## Contributing

Contributions are welcome! Please submit a pull request or open an issue if you encounter any problems.

## License

This project is licensed under the Apache License 2.0. See the [LICENSE](LICENSE) file for details.

## Support

For questions or support, please contact the project maintainer or create an issue in this repository.
