
name: CI/CD Pipeline for File Sharing App

on:
  push:
    branches:
      - main

jobs:
  setup:
    name: Setup Environment
    runs-on: ubuntu-latest

    steps:
    - name: Checkout Repository
      uses: actions/checkout@v3

    - name: Setup Node.js
      uses: actions/setup-node@v3
      with:
        node-version: 14

    - name: Install Dependencies
      run: |
        echo "No dependencies to install for static files."

  deploy:
    name: Deploy Application
    runs-on: ubuntu-latest
    needs: setup

    steps:
    - name: Checkout Repository
      uses: actions/checkout@v3

    - name: Configure AWS Credentials
      uses: aws-actions/configure-aws-credentials@v2
      with:
        aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
        aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        aws-region: us-east-1

    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v2
      with:
        terraform_version: 1.4.6

    - name: Terraform Init
      working-directory: ./terraform
      run: terraform init

    - name: Terraform Apply
      working-directory: ./terraform
      run: terraform apply -auto-approve

    - name: Extract Outputs
      id: extract_outputs
      working-directory: ./terraform
      run: |
        echo "Extracting Terraform outputs..."
        S3_WEBSITE_URL=$(terraform output -raw s3_website_url)
        EC2_PUBLIC_IP=$(terraform output -raw ec2_public_ip)
        echo "S3_WEBSITE_URL=$S3_WEBSITE_URL" >> $GITHUB_ENV
        echo "EC2_PUBLIC_IP=$EC2_PUBLIC_IP" >> $GITHUB_ENV

    - name: Output Deployment Details
      run: |
        echo "S3 Website URL: ${{ env.S3_WEBSITE_URL }}"
        echo "EC2 Public IP: ${{ env.EC2_PUBLIC_IP }}"
