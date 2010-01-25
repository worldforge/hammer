#!/bin/bash

set -e

export HAMMERDIR=$PWD/hammer
export PREFIX=$PWD/local
export SOURCE=$PWD/dev/worldforge
export DEPS_SOURCE=$PWD/dev
export MAKEOPTS="-j3"
export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH
export BUILDDIR=`uname -m`

# setup directories
mkdir -p $PREFIX
mkdir -p $DEPS_SOURCE
mkdir -p $SOURCE

# Log Directory
LOGDIR=$PWD/logs
mkdir -p $LOGDIR

# Output redirect logs
AUTOLOG=autogen.log     # Autogen output
CONFIGLOG=config.log    # Configure output
MAKELOG=build.log      # Make output
INSTALLLOG=install.log # Install output

# Dependencies
CEGUI=CEGUI-0.6.2
CEGUI_DOWNLOAD=CEGUI-0.6.2b.tar.gz
OGRE=ogre_1_6_5
OGRE_DOWNLOAD=ogre-v1-6-5.tar.bz2

function buildwf()
{
    mkdir -p $LOGDIR/$1

    cd $SOURCE/forge/$1
    if [ ! -f "configure" ] ; then
      echo "  Running autogen..."
      NOCONFIGURE=1 ./autogen.sh > $LOGDIR/$1/$AUTOLOG
    fi

    mkdir -p $BUILDDIR
    cd $BUILDDIR
    if [ ! -f "Makefile" ] ; then
      echo "  Running configure..."
      ../configure --prefix=$PREFIX > $LOGDIR/$1/$CONFIGLOG
    fi

    echo "  Building..."
    make $MAKEOPTS > $LOGDIR/$1/$MAKELOG
    echo "  Installing..."
    make install > $LOGDIR/$1/$INSTALLLOG
}

function checkoutwf()
{
  if [ ! -d $1 ]; then
    git clone git://git.worldforge.org/$1.git
  else
    cd $1 && git fetch && git rebase origin/master && cd ..
  fi
}

function cyphesis_post_install()
{
  cd $PREFIX/bin

  # Rename real cyphesis binary to cyphesis.bin
  mv cyphesis cyphesis.bin

  # Install our cyphesis.in script as cyphesis
  cp $HAMMERDIR/cyphesis.in cyphesis
  chmod +x cyphesis  
}

function show_help()
{
  if [ $1 = "main" ] ; then
    echo "Script for automating the process of installing dependencies" 
    echo "and compiling Worldforge in a self contained environment."
    echo ""
    echo "Usage: hammer.sh <command> <arguments>"
    echo "Commands:"
    echo "  install-deps -  install all 3rd party dependencies"
    echo "  checkout     -  fetch worldforge source (libraries, clients)"
    echo "  build        -  build the sources and install in environment"
    echo "  clean        -  delete build directory so a fresh build can be performed"
    echo ""
    echo "For more help, type: hammer.sh help <command>"
  elif [ $1 = "install-deps" ] ; then
    echo "Install all 3rd party dependencies into build environment."
    echo ""
    echo "Usage: hammer.sh install-deps <dependency to install>"
    echo "Dependencies Available:"
    echo "  all      -  install all dependencies listed below"
    echo "  cegui    -  a free library providing windowing and widgets for 
                        graphics APIs / engines"
    echo "  ogre     -  3D rendering engine"
	echo "Hint: build cegui first then ogre"
  elif [ $1 = "checkout" ] ; then
    echo "Fetch latest source code for worldforge libraries and clients."
    echo ""
    echo "Usage: hammer.sh checkout"
    echo "NOTE: make sure to perform CVS login first!"
    echo "See http://wiki.worldforge.org/wiki/Compiling_Ember:_Script_New#CVS_Login"
  elif [ $1 = "build" ] ; then
    echo "Build the sources and install in environment."
    echo ""
    echo "Usage: hammer.sh build <target> \"<makeopts>\""
    echo "Available targets:"
    echo "  libs  -  build libraries only"
    echo "  ember -  build ember only"
    echo "  cyphesis - build cyphesis server only"
    echo "makeopts [optional] - options to pass into make"
    echo ""
    echo "Hint: after a checkout use 'all'. To rebuild after changing code"
    echo "only in Ember, use 'ember'. Will build much quicker!"
  elif [ $1 = "clean" ] ; then
    echo "Clean out build files of a project."
    echo ""
    echo "Usage: hammer.sh clean <target>"
    echo "Targets:"
    echo "  cegui, ogre, libs/<name>, clients/<name>, servers/<name>"
  else
    echo "No help page found!"
  fi
}

# Show main help page if no arguments given
if [ $# -eq 0 ] ; then
  show_help "main"

# If help command given, show help page
elif [ $1 = "help" ] ; then
  if [ $# -eq 2 ] ; then
    show_help $2
  else
    show_help "main"
  fi

mkdir -p $PREFIX $SOURCE $DEPS_SOURCE

# Dependencies install
elif [ $1 = "install-deps" ] ; then
  if [ $# -ne 2 ] ; then
    echo "Missing required parameter!"
    show_help "install-deps"
    exit 1
  fi

  echo "Installing deps..."

  # Create deps log directory
  mkdir -p $LOGDIR/deps

  # CEGUI
  if [ $2 = "all" ] || [ $2 = "cegui" ] ; then
    echo "  Installing CEGUI..."
    mkdir -p $LOGDIR/deps/CEGUI    # create CEGUI log directory
    cd $DEPS_SOURCE
    if [ ! -d $CEGUI ] ; then
      echo "  Downloading..."
      wget -c http://downloads.sourceforge.net/sourceforge/crayzedsgui/$CEGUI_DOWNLOAD
      tar zxvf $CEGUI_DOWNLOAD
    fi
    cd $CEGUI
    mkdir -p $BUILDDIR
    cd $BUILDDIR
    echo "  Configuring..."
    ../configure --prefix=$PREFIX  --disable-samples --disable-opengl-renderer --disable-irrlicht-renderer --disable-xerces-c --disable-libxml --disable-expat --disable-directfb-renderer > $LOGDIR/deps/CEGUI/$CONFIGLOG
    echo "  Building..."
    make $MAKEOPTS > $LOGDIR/deps/CEGUI/$MAKELOG
    echo "  Installing..."
    make install > $LOGDIR/deps/CEGUI/$INSTALLLOG
    echo "  Done."
  fi
  
  # Ogre3D
  if [ $2 = "all" ] || [ $2 = "ogre" ] ; then
    echo "  Installing Ogre..."
    mkdir -p $LOGDIR/deps/ogre
    cd $DEPS_SOURCE
    if [ ! -d $OGRE ]; then
      echo "  Downloading..."
      wget -c http://downloads.sourceforge.net/sourceforge/ogre/$OGRE_DOWNLOAD
      mkdir -p $OGRE
      cd $OGRE
      tar -xjf ../$OGRE_DOWNLOAD
    fi
    cd $DEPS_SOURCE/$OGRE/ogre
    mkdir -p $BUILDDIR
    cd $BUILDDIR
    echo "  Configuring..."
    ../configure --prefix=$PREFIX --enable-threading=semi --disable-ogre-demos > $LOGDIR/deps/ogre/$CONFIGLOG
    echo "  Building..."
    make $MAKEOPTS > $LOGDIR/deps/ogre/$MAKELOG
    echo "  Installing..."
    make install > $LOGDIR/deps/ogre/$INSTALLLOG
    echo "  Done."
  fi

  echo "Install Done."

# Source checkout
elif [ $1 = "checkout" ] ; then
  echo "Fetching sources..."

  mkdir -p $SOURCE/forge/libs
  cd $SOURCE/forge/libs

  # Varconf
  echo "  Varconf..."
  checkoutwf "varconf"
  echo "  Done."

  # Atlas-C++
  echo "  Atlas-C++..."
  checkoutwf "atlas-c++"
  echo "  Done."

  # Skstream
  echo "  Skstream..."
  checkoutwf "skstream"
  echo "  Done."

  # Wfmath
  echo "  Wfmath..."
  checkoutwf "wfmath"
  echo "  Done."

  # Eris
  echo "  Eris..."
  checkoutwf "eris"
  echo "  Done."

  # Libwfut
  echo "  Libwfut..."
  checkoutwf "libwfut"
  echo "  Done."

  # Mercator
  echo "  Mercator..."
  checkoutwf "mercator"
  echo "  Done."

  # Ember client
  echo "  Ember client..."
  mkdir -p $SOURCE/forge/clients
  cd $SOURCE/forge/clients
  checkoutwf "ember"
  echo "  Done."

  # Cyphesis
  echo "  Cyphesis..."
  mkdir -p $SOURCE/forge/servers
  cd $SOURCE/forge/servers
  checkoutwf "cyphesis"
  echo "  Done."

  echo "Checkout Done."

# Build source
elif [ $1 = "build" ] ; then
  if [ $# -lt 2 ] ; then
    echo "Missing required parameter!"
    show_help "build"
    exit 1
  fi

  # Check for make options
  if [ $# -ge 3 ] ; then
    MAKEOPTS=$3
  fi

  echo "Building sources..."

  # Build libraries
  if [ $2 = "libs" ] || [ $2 = "all" ] ; then

  # Varconf
  echo "  Varconf..."
  buildwf "libs/varconf"
  echo "  Done."

  # Skstream
  echo "  Skstream..."
  buildwf "libs/skstream"
  echo "  Done."

  # Wfmath
  echo "  Wfmath..."
  buildwf "libs/wfmath"
  echo "  Done."

  # Atlas-C++
  echo "  Atlas-C++..."
  buildwf "libs/atlas-c++"
  echo "  Done."

  # Mercator
  echo "  Mercator..."
  buildwf "libs/mercator"
  echo "  Done."

  # Eris
  echo "  Eris..."
  buildwf "libs/eris"
  echo "  Done."

  # Libwfut
  echo "  Libwfut..."
  buildwf "libs/libwfut"
  echo "  Done."

  fi

  if [ $2 = "ember" ] || [ $2 = "all" ] ; then

  # Ember client
  echo "  Ember client..."
  buildwf "clients/ember"
  echo "  Done."

  echo "Fetching media..."
  cd $SOURCE/forge/clients/ember/$BUILDDIR
  make devmedia
  echo "Media fetched."

  fi

  if [ $2 = "cyphesis" ] || [ $2 = "all" ] ; then

  # Cyphesis
  echo "  Cyphesis..."
  buildwf "servers/cyphesis"
  cyphesis_post_install
  echo "  Done."

  fi

  echo "Build Done."

elif [ $1 = "clean" ] ; then
  if [ $# -ne 2 ] ; then
    echo "Missing required parameter!"
    show_help "clean"
    exit 1
  fi

  # Delete build directory
  if [ $2 = "cegui" ] ; then
    rm -rf $DEPS_SOURCE/$CEGUI/$BUILDDIR
  elif [ $2 = "ogre" ] ; then
    rm -rf $DEPS_SOURCE/$OGRE/ogre/$BUILDDIR
  else
    rm -rf $SOURCE/forge/$2/$BUILDDIR
  fi

else
  echo "Invalid command!"
  show_help "main"
fi
