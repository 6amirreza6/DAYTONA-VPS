#!/bin/bash

echo "=========================================================="
echo "🚀 Interactive Ubuntu VM Setup (QEMU + Cloud-init)"
echo "=========================================================="

read -p "👉 Enter RAM in GB (e.g., 4, 8, 16, 32, 64, 128): " VM_RAM
read -p "👉 Enter CPU Cores (e.g., 2, 4, 8, 16, 32, 64): " VM_CPU
read -p "👉 Enter Additional Disk Size in GB (e.g., 20, 50, 100): " VM_DISK

VM_RAM_MB=$((VM_RAM * 1024))

sudo apt-get update
sudo apt-get install -y qemu-system-x86 cloud-image-utils curl wget qemu-utils

mkdir -p /home/daytona/vm
cd /home/daytona/vm

if [ ! -f ubuntu22.img ]; then
    echo "📥 Downloading Ubuntu 22.04 Cloud Image..."
    wget -O ubuntu22.img https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
fi

echo "⚙️ Resizing disk by +${VM_DISK}GB..."
cp ubuntu22.img ubuntu_run.img
qemu-img resize ubuntu_run.img +${VM_DISK}G

echo "🔧 Generating cloud-init configuration..."
cat > user-data.yaml <<EOF
#cloud-config
ssh_pwauth: yes
disable_root: false
chpasswd:
  list: |
    root:root
    ubuntu:root
  expire: false
runcmd:
  - sed -i 's/.*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
  - sed -i 's/.*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
  - rm -f /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
  - systemctl restart ssh
EOF

cloud-localds seed.img user-data.yaml

echo "=========================================================="
echo "🎉 Starting VM in the background..."
echo "⚙️ Resources: ${VM_RAM}GB RAM | ${VM_CPU} Cores"
echo "👤 Username : root  | 🔑 Password : root"
echo "🚀 Port Rule : Host Port 2222 -> VM Port 22"
echo "=========================================================="


nohup qemu-system-x86_64 \
  -machine accel=kvm:tcg \
  -cpu max \
  -smp $VM_CPU \
  -m $VM_RAM_MB \
  -nographic \
  -drive "file=ubuntu_run.img,format=qcow2,if=virtio" \
  -drive "file=seed.img,format=raw,if=virtio" \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net-pci,netdev=net0 > vm_output.log 2>&1 &

echo "📜 Displaying live boot logs..."
echo "⏳ Please wait. This script will automatically exit when installation (Cloud-init) is complete."
echo "----------------------------------------------------------"


tail -f vm_output.log | sed '/Cloud-init.*finished/ q'

echo "----------------------------------------------------------"
echo "✅ Internal installation finished successfully! The VM is ready."
echo "👉 Connect using: ssh -J [ssh-key] -p 2222 root@localhost"
