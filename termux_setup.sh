# Install with:
# wget https://raw.githubusercontent.com/jmeagher/dotfiles/master/termux_setup.sh -O - | sh

# Pretty much straight copy of the steps in https://blog.lessonslearned.org/building-a-more-secure-development-chromebook/


# Setup the basics
apt update   
apt upgrade -y
apt install -y coreutils
pkg upgrade -y
pkg install -y termux-tools proot util-linux net-tools 
pkg install -y openssh tracepath tree git

# Install a few extras
pkg install -y vim


termux-setup-storage

mkdir -p storage/downloads/termux/ssh
ln -s storage/downloads/termux .

if [ ! -e storage/downloads/termux/ssh/id_rsa ] ; then
  ssh-keygen -t rsa -b 4096 -f storage/downloads/termux/ssh/id_rsa
  cat storage/downloads/termux/ssh/id_rsa.pub > .ssh/authorized_keys
fi

echo '
if [ "$(pwd)" != "/home" ] ; then echo "[Starting chroot...]" && termux-chroot; else echo "[chroot is running]"; fi
if ! pgrep "sshd" >/dev/null ; then echo "[Starting sshd...]" && sshd && echo "[OK]"; else echo "[ssh is running]"; fi
echo "ssh is up and running, connect with $(whoami)@$(ifconfig arc0 | grep "inet " | cut -f10 -d" ")"
' > .bash_profile

echo "Restart Termux and everything should be setup"
