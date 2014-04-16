#!/bin/bash

macs=( junk 52:54:00:f2:e7:60 52:54:00:16:d5:1e 52:54:00:ab:30:39 52:54:00:ed:e0:2b 52:54:00:17:18:a9 52:54:00:c0:83:a8 52:54:00:0e:48:7b 52:54:00:9f:2f:98 52:54:00:e2:38:8d 52:54:00:31:9d:dc )

for x in $(seq 1 6); do
  VMNAME="compute60G_${x}"

  # Delete old hdd
  rm /var/lib/libvirt/images/${VMNAME}.qcow2
  # Create new hdd
  qemu-img create -f qcow2 /var/lib/libvirt/images/${VMNAME}.qcow2 60G

  virt-install --connect qemu:///system --name $VMNAME --ram=6144 --vcpus=1 --os-type=linux \
    --disk path=/var/lib/libvirt/images/$VMNAME.qcow2,format=qcow2,bus=ide,cache=none --network=bridge:br1,mac=${macs[x]} --network=bridge:br2 --network=bridge:br3 \
    --accelerate --vnc --noautoconsole --keymap=en-us  --pxe
done
