#! /bin/bash

VMID=9001
STORAGE=data

set -x
rm -f noble-server-cloudimg-amd64.img
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img
qemu-img resize noble-server-cloudimg-amd64.img 10G
qm destroy $VMID
qm create $VMID --name "ubuntu-24.04-template" --ostype l26 \
    --memory 1024 --balloon 0 \
    --agent enabled=1,fstrim_cloned_disks=1,type=virtio \
    --bios ovmf --machine q35,viommu=virtio --efidisk0 $STORAGE:0,pre-enrolled-keys=0 \
    --cpu host --cores 1 --numa 1 \
    --vga serial0 --serial0 socket  \
    --net0 virtio,bridge=vmbr0,mtu=1
qm importdisk $VMID noble-server-cloudimg-amd64.img $STORAGE
qm set $VMID --scsihw virtio-scsi-pci --virtio0 $STORAGE:vm-$VMID-disk-1,discard=on
qm set $VMID --boot order=virtio0
qm set $VMID --ide2 $STORAGE:cloudinit

cat << EOF | tee /mnt/pve/snippets/snippets/ubuntu-noble.yaml
#cloud-config
locale: en_US.UTF-8
timezone: Asia/Singapore
write_files:
  - path: /etc/sysctl.d/10-disable-ipv6.conf
    permissions: 0644
    owner: root
    content: |
      net.ipv6.conf.eth0.disable_ipv6 = 1
runcmd:
    - apt-get update
    - apt-get install -y qemu-guest-agent htop nano nfs-common git zsh
    - systemctl enable ssh
    - reboot
# Taken from https://forum.proxmox.com/threads/combining-custom-cloud-init-with-auto-generated.59008/page-3#post-428772
EOF

qm set $VMID --cicustom "vendor=k8s:snippets/ubuntu-noble.yaml"
qm set $VMID --tags ubuntu-template,noble,cloudinit
qm set $VMID --ciuser aaron
qm set $VMID --sshkeys ~/.ssh/aaron.pub
qm set $VMID --ipconfig0 ip=dhcp
qm template $VMID
