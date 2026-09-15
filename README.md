This was the most advanced part of the assignment, where I containerized my apps and moved to a fully managed, 
production-ready cloud architecture using AWS container services.


What I Did:

Dockerized the Apps: I wrote custom Dockerfiles for both my Flask backend and Express frontend.

Created ECR Repositories: Using Terraform (aws_ecr_repository), I created two private Elastic Container Registry (ECR) repositories. I then built my Docker images locally, tagged them, and pushed them up to AWS ECR.

Built a Production VPC: I provisioned a comprehensive VPC network featuring public and private subnets, route tables, and security groups tailored for ECS.
Set up ECS Clusters and Fargate Services: I created an ECS Cluster via Terraform and defined ECS Task Definitions and ECS Services for both Flask and Express using AWS Fargate (serverless container hosting).

Added an Application Load Balancer (ALB): To route incoming web traffic smoothly, I provisioned an ALB with target groups and listeners so that public users hit the load balancer, which then directs traffic to the correct container service behind the scenes.

How I Verified It: I copied the DNS name of the Application Load Balancer from the AWS console, pasted it into my browser, and confirmed that the entire containerized application stack was running and accessible seamlessly.
