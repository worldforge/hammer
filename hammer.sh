#!/bin/bash

set -e

export PREFIX=$PWD/local
export SOURCE=$PWD/dev/worldforge
export DEPS_SOURCE=$PWD/dev
export MAKEOPTS="-j3"
export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig
export BUILDDIR=`uname -m`


function buildwf()
{
    cd $SOURCE/forge/$1
    export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig
    if [ ! -f "configure" ] ; then
      echo "  Running autogen..."
      NOCONFIGURE=1 ./autogen.sh
    fi

    mkdir -p $BUILDDIR
    cd $BUILDDIR
    if [ ! -f "Makefile" ] ; then
      echo "  Running confgure..."
      ../configure --prefix=$PREFIX
    fi
    make
    make install
}


function checkoutwf()
{
  if [ ! -d $1 ]; then
    git clone git://git.worldforge.org/$1.git
  else
    cd $1 && git fetch && git rebase origin/master && cd ..
  fi
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
      wget -c http://downloads.sourceforge.net/sourceforge/crayzedsgui/CEGUI-0.6.2b.tar.gz
      tar zxvf CEGUI-0.6.2b.tar.gz
    fi
    cd CEGUI-0.6.2/
    mkdir -p $BUILDDIR
    cd $BUILDDIR
    ../configure --prefix=$PREFIX  --disable-samples --disable-opengl-renderer --disable-irrlicht-renderer --disable-xerces-c --disable-libxml --disable-expat --disable-directfb-renderer
    make
    make install
    echo "  Done."
  fi
  
  # Ogre3D
  if [ $2 = "all" ] || [ $2 = "ogre" ] ; then
    echo "  Installing Ogre..."
    cd $DEPS_SOURCE
    if [ ! -d "ogre_1_6_1" ]; then
      wget -c http://downloads.sourceforge.net/sourceforge/ogre/ogre-v1-6-1.tar.bz2
      mkdir -p "ogre_1_6_1"
      cd "ogre_1_6_1"
      tar -xjf ../ogre-v1-6-1.tar.bz2
    fi
    cd $DEPS_SOURCE/ogre_1_6_1/ogre
    mkdir -p $BUILDDIR
    cd $BUILDDIR
    export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig
    ../configure --prefix=$PREFIX --disable-freeimage --disable-ogre-demos
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

  echo "Fetching media..."
  cd $SOURCE/forge/clients/ember/$BUILDDIR
  make devmedia
  echo "Media fetched."

  fi

  echo "Build Done."

fi

