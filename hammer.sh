#!/bin/bash

set -e

export PREFIX=$PWD/local
export SOURCE=$PWD/dev/worldforge
export DEPS_SOURCE=$PWD/local/src
export MAKEOPTS="-j3"
export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig

function buildwf()
{
    cd $SOURCE/forge/$1
    export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig
    if [ ! -f "Makefile" ] ; then
      echo "  Generating makefile..."
      ./autogen.sh
      ./configure --prefix=$PREFIX
    fi
    make
    make install
}

mkdir -p $PREFIX $SOURCE $DEPS_SOURCE

# Dependencies install
if [ $1 = "install-deps" ] ; then
  echo "Installing deps..."

  # CEGUI
  if [ $2 = "all" ] || [ $2 = "cegui" ] ; then
    echo "  Installing CEGUI..."
    cd $DEPS_SOURCE
    if [ ! -d "CEGUI-0.6.2" ] ; then
      wget -c http://voxel.dl.sourceforge.net/sourceforge/crayzedsgui/CEGUI-0.6.2b.tar.gz
      tar zxvf CEGUI-0.6.2b.tar.gz
    fi
    cd CEGUI-0.6.2/
    ./configure --prefix=$PREFIX  --disable-samples --disable-opengl-renderer --disable-irrlicht-renderer --disable-xerces-c --disable-libxml --disable-expat
    make
    make install
    echo "  Done."
  fi
  
  # Ogre3D
  if [ $2 = "all" ] || [ $2 = "ogre" ] ; then
    echo "  Installing Ogre..."
    cd $DEPS_SOURCE
    if [ ! -d "ogre" ]; then
      wget -c http://voxel.dl.sourceforge.net/sourceforge/ogre/ogre-v1-6-1.tar.bz2
      tar -xjf ogre-v1-6-1.tar.bz2
    fi
    cd ogre
    export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig
    ./configure --prefix=$PREFIX --disable-freeimage --disable-ogre-demos
    make
    make install
    echo "  Done."
  fi

  echo "Install Done."

# Source checkout
elif [ $1 = "checkout" ] ; then
  echo "Fetching sources..."

  cd $SOURCE
  
  # Varconf
  echo "  Varconf..."
  cvs -z3 -d :pserver:cvsanon@cvs.worldforge.org:/home/cvspsrv/worldforge -q co forge/libs/varconf
  echo "  Done."

  # Atlas-C++  
  echo "  Atlas-C++..."
  cvs -z3 -d :pserver:cvsanon@cvs.worldforge.org:/home/cvspsrv/worldforge -q co forge/libs/Atlas-C++
  echo "  Done."

  cd $SOURCE/forge/libs

  # Skstream
  echo "  Skstream..."
  git clone git://git.worldforge.org/skstream.git
  echo "  Done."

  # Wfmath
  echo "  Wfmath..."
  git clone git://git.worldforge.org/wfmath.git
  echo "  Done."

  # Eris
  echo "  Eris..."
  git clone git://git.worldforge.org/eris.git
  echo "  Done."

  # Libwfut
  echo "  Libwfut..."
  git clone git://git.worldforge.org/libwfut.git
  echo "  Done."

  # Mercator
  echo "  Mercator..."
  git clone git://git.worldforge.org/mercator.git
  echo "  Done."

  # Ember client
  echo "  Ember client..."
  mkdir -p $SOURCE/forge/clients
  cd $SOURCE/forge/clients
  git clone git://git.worldforge.org/ember.git
  echo "  Done."

  echo "Checkout Done."

# Build source
elif [ $1 = "build" ] ; then
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
  buildwf "libs/Atlas-C++"
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

  fi

  echo "Build Done."

# Media
elif [ $1 = "fetch-media" ] ; then
  echo "Fetching media..."
  cd $SOURCE/forge/clients/ember
  make devmedia
  echo "Media fetched."
fi

