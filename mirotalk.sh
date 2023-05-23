#!/bin/bash

# Update system packages
sudo apt update
sudo apt upgrade -y

# Install dependencies
sudo apt install -y curl git nginx

# Install Node.js 18.x and npm
curl -sL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs
npm install -g npm@latest

# Clone MiroTalk P2P repository
git clone https://github.com/miroslavpejic85/mirotalk.git
cd mirotalk

# Copy .env.template to .env
cp .env.template .env

# Ask for domain name
read -p "Enter your domain name (e.g., your.domain.name): " domain_name
sed -i "s/your.domain.name/$domain_name/g" /etc/nginx/sites-available/mirotalk

# Install dependencies
npm install

# Build the app
npm run build

# Configure Nginx
sudo tee /etc/nginx/sites-available/mirotalk <<EOF
server {
    listen 80;
    server_name $domain_name;

    location / {
        proxy_pass http://localhost:3010;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/mirotalk /etc/nginx/sites-enabled/mirotalk

# Restart Nginx
sudo systemctl restart nginx

# Install PM2 globally
sudo npm install -g pm2

# Start the server using PM2
pm2 start npm --name "mirotalk" -- start

# Save PM2 process list and set it to run on startup
pm2 save
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u $USER --hp /home/$USER

echo "MiroTalk P2P installation completed!"