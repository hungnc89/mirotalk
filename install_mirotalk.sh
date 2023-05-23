#!/bin/bash

# Update system packages
sudo apt update
sudo apt upgrade -y

# Install dependencies
sudo apt install -y curl git nginx software-properties-common

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

# Ask for email address
read -p "Enter your email address for SSL certificate: " email_address
sed -i "s/your-email@example.com/$email_address/g" /etc/nginx/sites-available/mirotalk

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

# Install Certbot and obtain SSL certificate
sudo add-apt-repository -y ppa:certbot/certbot
sudo apt update
sudo apt install -y certbot python3-certbot-nginx

# Obtain SSL certificate from Let's Encrypt
sudo certbot --nginx --agree-tos --redirect --hsts --staple-ocsp --email $email_address -d $domain_name

# Install PM2 globally
sudo npm install -g pm2

# Create ecosystem.config.js
echo "module.exports = {
  apps: [{
    name: 'mirotalk',
    script: './app/src/server.js',
    watch: '.',
    instances: 1,
    autorestart: true,
    exec_mode: 'fork',
    env: {
      NODE_ENV: 'production',
      PORT: 3010
    }
  }]
}" >> ecosystem.config.js

# Start the server using PM2
pm2 start ecosystem.config.js

# Save PM2 process list and set it to run on startup
pm2 save
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u $USER --hp /home/$USER

echo "MiroTalk P2P installation completed!"
