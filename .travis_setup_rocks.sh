# A script for setting up broken Lua rocks for travis-ci testing.

sudo luarocks install dkjson --deps-mode=none

mkdir lanes
wget -O - https://api.github.com/repos/mpeterv/lanes/tarball/lua53-fixes | tar xz -C lanes --strip-components=1
cd lanes
sudo luarocks make lanes-3.9.6-1.rockspec
cd ..

mkdir busted
wget -O - https://api.github.com/repos/Olivine-Labs/busted/tarball/master | tar xz -C busted --strip-components=1
cd busted
sudo luarocks make busted-scm-0.rockspec
cd ..
