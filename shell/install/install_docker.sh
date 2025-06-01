# Step 1: Add Docker's official GPG key

sudo apt-get update
sudo apt-get install ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Step 2: Add the repository to Apt sources

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

# Step 3: Cài đặt các gói thành phần của docker:

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Step 4: Thêm user hiện tại vào group docker để khi chạy command docker không cần phải cung cấp sudo

sudo usermod -aG docker $USER

# Step 5: 

newgrp docker

# Optional:
# hold
sudo apt-mark hold docker-ce
# un hold
sudo apt-mark unhold docker-ce