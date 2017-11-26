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
