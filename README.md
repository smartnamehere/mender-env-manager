# Mender K8s - Dynamic Mender Test Environments

This project creates a simple web interface to spin up and tear down Mender test environments on AWS.

## Architecture

The application is composed of three main parts:

1.  **Frontend:** A static website hosted on S3 and distributed by CloudFront. It provides a simple UI to create and manage Mender environments.
2.  **Backend:** A serverless backend using API Gateway and Lambda functions to handle the business logic.
3.  **Mender Environment:** Each Mender environment runs on a dedicated EC2 instance.

### Architecture Diagram

```
                           +------------------+
                           |      User        |
                           +------------------+
                                    |
                                    | HTTPS
                                    v
+-------------------------------------------------------------------------+
|                                CloudFront                               |
+-------------------------------------------------------------------------+
       |                           |                           |
       |                           |                           |
       v                           v                           v
+------------------+    +----------------------+    +----------------------+
|   S3 Bucket      |    |   API Gateway        |    | Route 53             |
| (Frontend)       |    +----------------------+    +----------------------+
+------------------+       |        |       |              ^
                           |        |       |              |
                           v        v       v              |
                      +--------+ +--------+ +--------+     |
                      | Create | | Get    | | Delete |     |
                      | Lambda | | Lambda | | Lambda |     |
                      +--------+ +--------+ +--------+     |
                           |        |       |              |
                           |        |       |              |
                           v        v       v              |
                      +----------------------+             |
                      |   DynamoDB Table     |             |
                      | (Environments State) |             |
                      +----------------------+             |
                                |                          |
                                |                          |
                                v                          |
                      +----------------------+             |
                      | EC2 Instance         |-------------+
                      | (Mender Environment) |
                      +----------------------+
```

## Design Decisions

*   **EC2 for Mender Environments:** Using a dedicated EC2 instance per environment is a simple and effective way to isolate environments and manage their lifecycle. While EKS could be used for a more container-native approach, it falls out of the free tier, and for this use case, EC2 provides an alternative option to demostrate the architecture of the solution even if it is not fully functioning, also lacks plenty of security guardrails in terms of public access. 
*   **Serverless Backend:** API Gateway and Lambda provide a scalable, cost-effective, and low-maintenance backend. We only pay for what we use.
*   **DynamoDB for State:** DynamoDB is a perfect fit for storing the state of our environments. It's a fully managed NoSQL database that is fast, scalable, and integrates seamlessly with Lambda.
*   **Terraform for IaC:** Terraform allows us to define our infrastructure as code, which makes it easy to create, update, and delete our application stack in a reproducible and predictable way.

## How to Deploy

1.  **Configure AWS Credentials:** Make sure you have your AWS credentials configured in your environment.
2.  **Initialize Terraform:** `terraform init`
3.  **Deploy:** `terraform apply`

## How to Use

1.  Open the CloudFront URL in your browser.
2.  Click the "Create environment" button.
3.  Wait for the environment to be created. A link to the new environment will appear on the page.
4.  Click the "Take down environment" link to destroy an environment.

## Future Improvements

*   **Use ECS/Fargate:** For better scalability and resource utilization, we could run the Mender environments on ECS or Fargate.
*   **Authentication:** Add authentication to the frontend to restrict who can create and destroy environments.
*   **Cost Control:** Implement a mechanism to automatically shut down environments after a certain period of inactivity to save costs.
*   **Remote State Management:** For a production environment, it is highly recommended to use a remote backend to store the Terraform state file. This provides better security, collaboration, and state locking. You can use an S3 bucket and a DynamoDB table for this purpose. Here is an example configuration:

    ```terraform
    terraform {
      backend "s3" {
        bucket         = "your-terraform-state-bucket-name"
        key            = "menderk8s/terraform.tfstate"
        region         = "us-east-1"
        dynamodb_table = "your-terraform-lock-table-name"
        encrypt        = true
      }
    }
    ```
