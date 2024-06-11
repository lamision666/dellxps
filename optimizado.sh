#!/bin/env bash

# Limpiar la pantalla del terminal
clear

# Establecer la fuente del terminal a ter-v18n
setfont ter-v18n

# Definir variables de color para la impresión
CRE=$(tput setaf 1)
CYE=$(tput setaf 3)
CGR=$(tput setaf 2)
CBL=$(tput setaf 4)
CNC=$(tput sgr0)

# Definir el comando chroot
CHROOT="arch-chroot /mnt"

# Función para imprimir mensaje "OK" en color verde
okie() {
    printf "\n%s OK...%s\n" "$CGR" "$CNC"
    sleep 2
}

# Función para imprimir opciones de título en colores azul y amarillo
titleopts() {
    local textopts="${1:?}"
    printf " \n%s>>>%s %s%s%s\n" "${CBL}" "${CNC}" "${CYE}" "${textopts}" "${CNC}"
}

# Función para imprimir el logo con un mensaje
logo() {
    local text="${1:?}"
    echo -en "
                   %%%                
            %%%%%//%%%%%              
          %%************%%%           
      (%%//############*****%%
    %%%%%**###&&&&&&&&&###**//
    %%(**##&&&#########&&&##**
    %%(**##*****#####*****##**%%%
    %%(**##     *****     ##**
       //##   @@**   @@   ##//
         ##     **###     ##
         #######     #####//
           ###**&&&&&**###
           &&&         &&&
           &&&////   &&
              &&//@@@**
                ..***                
              z0mbi3 Script\n\n"
    printf ' \033[0;31m[ \033[0m\033[1;93m%s\033[0m \033[0;31m]\033[0m\n\n' "${text}"
    sleep 3
}

# Comprobar modo de arranque de la BIOS y gráficos
logo "Checando modo de arranque"
if [ -d /sys/firmware/efi/efivars ]; then
    bootmode="uefi"
    printf " El script se ejecutará en modo EFI"
else
    bootmode="mbrbios"
    printf " El script se ejecutará en modo BIOS/MBR"
fi
sleep 2
clear

# Comprobar conexión a internet
logo "Checando conexión a internet.."
if ping -c 1 archlinux.org >/dev/null 2>&1; then
    printf " Espera....\n\n"
    sleep 3
    printf " %s¡Si hay Internet!%s" "${CGR}" "${CNC}"
else
    printf " Error: Parece que no hay internet..\n\n Saliendo...."
    sleep 2
    exit 1
fi
sleep 2
clear

# Seleccionar distribución de teclado
logo "Selecciona la distribución de tu teclado"
setkmap='us'
x11keymap="us"
printf '\nCambiando distribución de teclado a US\n'
loadkeys "${setkmap}"
okie
clear

# Seleccionar idioma
logo "Selecciona tu idioma"
PS3="Selecciona tu idioma: "
select idiomains in $(grep UTF-8 /etc/locale.gen | sed 's/\..*$//' | sed '/@/d' | awk '{print $1}' | uniq | sed 's/#//g'); do
    if [ "$idiomains" ]; then break; fi
done
printf '\nCambiando idioma a %s ...\n' "${idiomains}"
echo "${idiomains}.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen >/dev/null 2>&1
export LANG=${idiomains}.UTF-8
okie
clear

# Seleccionar zona horaria
logo "Selecciona tu zona horaria"
tzselection=$(tzselect | tail -n1)
okie
clear

# Solicitar información del usuario
logo "Ingresa la información necesaria"
while true; do
    read -rp "Ingresa tu usuario: " USR
    if [[ "${USR}" =~ ^[a-z_]([a-z0-9_-]{0,31}|[a-z0-9_-]{0,30}\$)$ ]]; then break; fi
    printf "¡Incorrecto! Solo se permiten minúsculas.\n\n"
done

while true; do
    read -rsp "Ingresa tu contraseña: " PASSWD
    echo
    read -rsp "Confirma tu contraseña: " CONF_PASSWD
    echo
    [ "$PASSWD" = "$CONF_PASSWD" ] && break
    printf "¡Las contraseñas no coinciden!\n\n"
done
printf "Contraseña correcta\n"

while true; do
    read -rsp "Ingresa la contraseña para ROOT: " PASSWDR
    echo
    read -rsp "Confirma la contraseña: " CONF_PASSWDR
    echo
    [ "$PASSWDR" = "$CONF_PASSWDR" ] && break
    printf "¡Las contraseñas no coinciden!\n"
done
printf "Contraseña correcta\n"

while true; do
    read -rp "Ingresa el nombre de tu máquina: " HNAME
    if [[ "${HNAME}" =~ ^[a-z][a-z0-9_.-]{0,62}[a-z0-9]$ ]]; then break; fi
    printf "¡Incorrecto! No puede incluir mayúsculas ni símbolos especiales\n"
done
clear

# Seleccionar kernel
kernel='linux'

# Seleccionar gestor de red
logo "Selecciona el cliente para manejar Internet"
redpack='networkmanager'
esys='NetworkManager'

# Seleccionar servidor de audio
audiotitle='PulseAudio'
audiopack='pulseaudio'

# Seleccionar entorno de escritorio
DEN='Bspwm'
DE='bspwm rofi sxhkd dunst lxappearance nitrogen pavucontrol polkit-gnome'
DM='lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings numlockx'
SDM='lightdm'
aurbspwm='picom-jonaburg-fix polybar xtitle termite checkupdates-aur nerd-fonts-jetbrains-mono'

# Configurar particiones y sistemas de archivos
logo "Configurando particiones y sistemas de archivos"
# Borrar todas las particiones en /dev/sda
sgdisk -Z /dev/sda
# Crear una nueva tabla de particiones GPT
sgdisk -a 2048 -o /dev/sda

# Crear particiones en función del modo de arranque
if [ "$bootmode" = "uefi" ]; then
    sgdisk -n 1:0:+250M -t 1:ef00 -c 1:"BOOT" /dev/sda # Partición EFI/BOOT
    sgdisk -n 2:0:+5G -t 2:8200 -c 2:"SWAP" /dev/sda # Partición SWAP
    sgdisk -n 3:0:+50G -t 3:0700 -c 3:"SHARED" /dev/sda # Partición para compartir archivos con Windows
    sgdisk -n 4:0:+100G -t 4:8300 -c 4:"HOME" /dev/sda # Partición del usuario
    sgdisk -n 5:0:0 -t 5:8300 -c 5:"ROOT" /dev/sda # Partición ROOT
else
    sgdisk -n 1:0:+1M -t 1:ef02 -c 1:"BIOS" /dev/sda # Partición BIOS
    sgdisk -n 2:0:+5G -t 2:8200 -c 2:"SWAP" /dev/sda # Partición SWAP
    sgdisk -n 3:0:+50G -t 3:0700 -c 3:"SHARED" /dev/sda # Partición para compartir archivos con Windows
    sgdisk -n 4:0:+100G -t 4:8300 -c 4:"HOME" /dev/sda # Partición del usuario
    sgdisk -n 5:0:0 -t 5:8300 -c 5:"ROOT" /dev/sda # Partición ROOT
fi

# Formatear las particiones
mkfs.fat -F32 /dev/sda1
mkswap /dev/sda2
swapon /dev/sda2
mkfs.ntfs -f /dev/sda3
mkfs.ext4 /dev/sda4
mkfs.ext4 /dev/sda5

# Montar las particiones
mount /dev/sda5 /mnt
mkdir /mnt/boot
mount /dev/sda1 /mnt/boot
mkdir /mnt/home
mount /dev/sda4 /mnt/home

# Instalar el sistema base
logo "Instalando el sistema base"
pacstrap /mnt base base-devel "${kernel}" "${kernel}-firmware" vim sudo
genfstab -U /mnt >> /mnt/etc/fstab

# Configuración básica del sistema
logo "Configuración básica del sistema"
echo "$HNAME" > /mnt/etc/hostname
echo "127.0.0.1 localhost" >> /mnt/etc/hosts
echo "::1       localhost" >> /mnt/etc/hosts
echo "127.0.1.1 $HNAME.localdomain $HNAME" >> /mnt/etc/hosts

# Configurar zona horaria
arch-chroot /mnt ln -sf /usr/share/zoneinfo/"$tzselection" /etc/localtime
arch-chroot /mnt hwclock --systohc

# Configurar idioma
echo "LANG=${idiomains}.UTF-8" > /mnt/etc/locale.conf
echo "LC_COLLATE=C" >> /mnt/etc/locale.conf
arch-chroot /mnt locale-gen

# Configurar teclado
echo "KEYMAP=${setkmap}" > /mnt/etc/vconsole.conf
arch-chroot /mnt localectl set-keymap ${setkmap}
arch-chroot /mnt localectl set-x11-keymap ${x11keymap}

# Configurar red
arch-chroot /mnt systemctl enable "${esys}"

# Configurar usuario
arch-chroot /mnt useradd -m -G wheel -s /bin/bash "$USR"
echo "$USR:$PASSWD" | arch-chroot /mnt chpasswd
echo "root:$PASSWDR" | arch-chroot /mnt chpasswd
sed -i 's/# %wheel ALL=(ALL) ALL/%wheel ALL=(ALL) ALL/g' /mnt/etc/sudoers

# Instalar GRUB
if [ "$bootmode" = "uefi" ]; then
    arch-chroot /mnt pacman -Sy --noconfirm grub efibootmgr os-prober
    arch-chroot /mnt mkdir /boot/EFI
    arch-chroot /mnt mount /dev/sda1 /boot/EFI
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/EFI --bootloader-id=GRUB
else
    arch-chroot /mnt pacman -Sy --noconfirm grub
    arch-chroot /mnt grub-install --target=i386-pc /dev/sda
fi
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# Instalar entorno de escritorio y aplicaciones
logo "Instalando entorno de escritorio y aplicaciones"
arch-chroot /mnt pacman -Sy --noconfirm xorg-server xorg-xinit mesa xf86-video-intel "${audiopack}" "${DE}" "${DM}" neofetch
arch-chroot /mnt systemctl enable "${SDM}"

# Clonar AUR Helper y paquetes
arch-chroot /mnt pacman -Sy --noconfirm git base-devel
arch-chroot /mnt git clone https://aur.archlinux.org/yay.git /home/$USR/yay
arch-chroot /mnt chown -R $USR:$USR /home/$USR/yay
arch-chroot /mnt sudo -u $USR bash -c "cd /home/$USR/yay && makepkg -si --noconfirm"
arch-chroot /mnt sudo -u $USR yay -S --noconfirm ${aurbspwm}

# Configuración de red (copia de iwctl)
logo "Copiando configuración de red de iwctl"
cp /var/lib/iwd/*.psk /mnt/var/lib/iwd/

# Finalizar
logo "Instalación completada"
echo "Puedes reiniciar el sistema."
