provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    bucket = "terraform-state-storage-shaan"
    key    = "file-sharing-app/terraform.tfstate"
    region = "us-east-1"
  }
}

resource "aws_instance" "app_instance" {
  ami           = "ami-12345678" # Update with a valid AMI ID
  instance_type = "t2.micro"

  user_data = <<-EOF
              #!/bin/bash
              curl -fsSL https://deb.nodesource.com/setup_14.x | bash -
              apt-get install -y nodejs
              mkdir -p /app
              cd /app
              echo "export PORT=3000" >> /etc/environment
              echo "export NODE_ENV=production" >> /etc/environment
              cat << EOM > package.json
              {
                \"name\": \"file-sharing-app\",
                \"version\": \"1.0.0\",
                \"main\": \"app.js\",
                \"dependencies\": {\"express\": \"^4.18.2\"}
              }
              EOM
              npm install express
              cat << EOM > app.js
              const express = require('express');
              const app = express();
              app.get('/', (req, res) => res.send('File Sharing App Running'));
              app.listen(3000);
              EOM
              node app.js
  EOF

  tags = {
    Name = "File Sharing App Instance"
  }
}

output "app_url" {
  value = aws_instance.app_instance.public_ip
}
