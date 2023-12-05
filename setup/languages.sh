sudo apt-get install g++ golang

if ! command -v cargo &> /dev/null
then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
fi