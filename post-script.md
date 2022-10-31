# Que la máquina tiene montado un disco en el directorio /var/www/html.
ssh -i ~/.ssh/id_ecdsa debian@$10.10.20.186 "df -h"

# Muestra que la máquina tiene 2G de RAM.
ssh -i ~/.ssh/id_ecdsa debian@10.10.20.186 "free -h"

# Que accediendo a la máquina puedes acceder al contenedor.
ssh debian@10.10.20.186 
sudo su
lxc-start -n container1 -d
lxc-attach -n container1

# Que se ha ha creado un snapshot.
virsh -c qemu:///system snapshot-list maquina1