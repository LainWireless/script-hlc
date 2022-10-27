#!/bin/bash

# Crea una imagen nueva, que utilice bullseye-base.qcow2 como imagen base y tenga 5 GiB de tamaño máximo. Esta imagen se denominará maquina1.qcow2.
sudo qemu-img create -f qcow2 -b /var/lib/libvirt/images/bullseye-base-sparse.qcow2 /var/lib/libvirt/images/maquina1.qcow2 5G

# Crea una red interna de nombre intra con salida al exterior mediante NAT que utilice la red 10.10.20.0/24.

virsh -c qemu:///system net-define intra.xml
virsh -c qemu:///system net-start intra
virsh -c qemu:///system net-autostart intra

# Crea una máquina virtual (maquina1) conectada a la red intra, con 1 GiB de RAM, que utilice como disco raíz maquina1.qcow2 y que se inicie automáticamente.
virt-install --connect qemu:///system \
    --name maquina1 \
    --ram 1024 \
    --vcpus 1 \
    --disk path=/var/lib/libvirt/images/maquina1.qcow2 \
    --network network=intra \
    --os-type linux \
    --os-variant debian10 \
    --import

virsh -c qemu:///system autostart maquina1

# Arranca la máquina.
virsh -c qemu:///system start maquina1

# Muestra por pantalla la IP de la máquina1 y guardala en una variable.
IP=$(virsh -c qemu:///system domifaddr maquina1 | grep -oP '10.10.20.\d{1,3}')

# Modifica el fichero /etc/hostname con maquina1.
ssh -i /home/ivan/.ssh/id_ecdsa debian@$IP "su root -c 'echo 'maquina1' > /etc/hostname'"

# Crea un volumen adicional de 1 GiB de tamaño en formato RAW ubicado en el pool por defecto.
virsh -c qemu:///system vol-create-as default maquina1-2 1G --format raw

# Una vez iniciada la MV maquina1, conecta el volumen a la máquina, crea un sistema de ficheros XFS en el volumen y móntalo en el directorio /var/www/html. Ten cuidado con los propietarios y grupos que pongas, para que funcione adecuadamente el siguiente punto.

virsh -c qemu:///system attach-disk maquina1 /var/lib/libvirt/images/maquina1-2 vdb --targetbus virtio --persistent
ssh -i /home/ivan/.ssh/id_ecdsa debian@$IP "su root -c '/usr/sbin/mkfs.xfs -f /dev/vdb && mkdir -p /var/www/html && mount /dev/vdb /var/www/html'"
ssh -i /home/ivan/.ssh/id_ecdsa debian@$IP "su root -c 'chown -R www-data:www-data /var/www/html'"
ssh -i /home/ivan/.ssh/id_ecdsa debian@$IP "su root -c 'chmod -R 755 /var/www/html'"

# Instala en maquina1 el servidor web apache2. Copia un fichero index.html a la máquina virtual.

ssh -i /home/ivan/.ssh/id_ecdsa debian@$IP "su root -c 'apt-get update && sudo apt-get install apache2 -y'"
ssh -i /home/ivan/.ssh/id_ecdsa debian@$IP "su root -c 'systemctl enable apache2'"
ssh -i /home/ivan/.ssh/id_ecdsa debian@$IP "su root -c 'echo "Hola mundo" > /var/www/html/index.html'"
ssh -i /home/ivan/.ssh/id_ecdsa debian@$IP "su root -c 'systemctl restart apache2'"

# Muestra por pantalla la dirección IP de máquina1. Pausa el script y comprueba que puedes acceder a la página web.
virsh -c qemu:///system domifaddr maquina1
read -p "Pulsa enter para continuar"

# Instala LXC en la maquina1 y crea un linux container llamado container1.
ssh -i /home/ivan/.ssh/id_ecdsa debian@$IP "su root -c 'apt-get install lxc -y'"
ssh -i /home/ivan/.ssh/id_ecdsa debian@$IP "su root -c 'lxc-create -t download -n container1 -- -d debian -r bullseye -a amd64'"

# Crea una nueva interfaz de red a la máquina virtual y conectala a la red pública (al puente br0).
virsh -c qemu:///system shutdown maquina1 && sleep 15 && virsh -c qemu:///system attach-interface maquina1 bridge br0 --model virtio --config

# Muestra solo la nueva IP que ha recibido la interfaz enp8s0.
virsh -c qemu:///system start maquina1 && sleep 15 && ssh -i /home/ivan/.ssh/id_ecdsa debian@$IP "ip a | grep 'enp8s0' | grep -oP 'inet \K[\d.]+'"
read -p "Mostrando la IP de br0. Pulsa enter para continuar"

# Apaga maquina1 y auméntale la RAM a 2 GiB y vuelve a iniciar la máquina.
virsh -c qemu:///system shutdown maquina1 && sleep 15 && virsh -c qemu:///system setmaxmem maquina1 2G --config && virsh -c qemu:///system start maquina1

# Crea un snapshot de la máquina virtual.
virsh -c qemu:///system snapshot-create-as maquina1 --name snapshot1 --atomic