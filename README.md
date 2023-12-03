# DEPRECATED

This tool isn't used anymore as we've moved to a build system based on Conan. See more at [the Worldforge repository](https://github.com/worldforge/worldforge). 

# Worldforge Hammer Script

[![Join us on Gitter!](https://badges.gitter.im/Worldforge.svg)](https://gitter.im/Worldforge/Lobby)

Tool for installing deps, checking out source, and compiling the application.
Execute hammer.sh for help.

All build artifacts are placed in the "work" directory.

## Building the client

If you want to build the Worldforge client, Ember, execute these commands.

```
./hammer.sh install-deps all
./hammer.sh checkout all
./hammer.sh build libs
./hammer.sh build ember
```

You can then run the client through
```
./work/bin/ember
```

## Building the server

If you want to build the Worldforge server, Cyphesis, execute these commands.

```
./hammer.sh install-deps all
./hammer.sh checkout all
./hammer.sh build libs
./hammer.sh build cyphesis
```

You can then run the client through
```
./work/bin/cyphesis
```

This will start a server instance and populate with the default world. If you haven't configured Postgres no data will be stored. I.e. the world will be wiped when shut down.

# Linux

You will need a couple of dependencies in order to build everything. On Ubuntu, install these
```
sudo apt-get -y install g++ make liblua5.1-0-dev libtolua++5.1-dev libzzip-dev libfreetype6-dev \
                   libbz2-dev libxaw7-dev libopenal-dev libalut-dev libsigc++-2.0-dev libcurl4-openssl-dev \
                   libjpeg62-dev libpng-dev libpcre3-dev libxrandr-dev libxdg-basedir-dev \
                   libgcrypt20-dev libboost-all-dev cmake libfreeimage-dev curl rsync \
                   libtinyxml-dev libsdl2-dev libglew-dev libbullet-dev libsqlite3-dev python3-dev libpugixml-dev
```
