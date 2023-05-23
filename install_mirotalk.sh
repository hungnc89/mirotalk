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

# Create a temporary file for Nginx config
nginx_config="/tmp/mirotalk.conf"
sudo tee "$nginx_config" > /dev/null <<EOF
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

server {
    listen 443 ssl http2;
    server_name $domain_name;

    ssl_certificate /etc/letsencrypt/live/$domain_name/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$domain_name/privkey.pem;

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

# Copy the temporary Nginx config to the actual config file
sudo cp "$nginx_config" /etc/nginx/sites-available/mirotalk

# Enable the site
sudo ln -s /etc/nginx/sites-available/mirotalk /etc/nginx/sites-enabled/mirotalk

# Remove the temporary file
rm "$nginx_config"

# Restart Nginx
sudo systemctl restart nginx

# Install Certbot and obtain SSL certificate
sudo apt install -y certbot python3-certbot-nginx

# Obtain SSL certificate from Let's Encrypt
sudo certbot --nginx --agree-tos --redirect --hsts --staple-ocsp --email your-email@example.com -d $domain_name

# Install PM2 globally
sudo npm install -g pm2

# Start the server using PM2
pm2 start npm --name "mirotalk" -- start

# Save PM2 process list and set it to run on startup
pm2 save
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u $USER --hp /home/$USER

echo "MiroTalk P2P installation completed!"
