#!/bin/bash

set -e

# Define component versions
CEGUI_VER=cegui-0.8.3
CEGUI_DOWNLOAD=cegui-0.8.3.tar.gz
OGRE_VER=ogre_1_9_0
OGRE_DOWNLOAD=v1-9-0.tar.bz2
CG_VER=3.1
CG_FULLVER=${CG_VER}.0013
CG_DOWNLOAD=Cg-3.1_April2012
FREEALUT_VER=1.1.0
TOLUA_VER="tolua++-1.0.93"
VARCONF_VER=1.0.1
ATLASCPP_VER=0.6.3
SKSTREAM_VER=0.3.9
WFMATH_VER=1.0.2
ERIS_VER=1.3.23
WFUT_VER=libwfut-0.2.3
MERCATOR_VER=0.3.3

export HAMMERDIR=$PWD
export WORKDIR=$HAMMERDIR/work
export PREFIX=$WORKDIR/local
export SOURCE=$WORKDIR/build/worldforge
export DEPS_SOURCE=$WORKDIR/build/deps
export MAKEOPTS="-j3"
export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig:$PKG_CONFIG_PATH
export BUILDDIR=`getconf LONG_BIT`
export SUPPORTDIR=$HAMMERDIR/support
#needed to find tolua++ program if installed in prefix
export PATH="$PATH:$PREFIX/bin"
export CPATH="$PREFIX/include:$CPATH"
export LDFLAGS="$LDFLAGS -L$PREFIX/lib"
export LIBRARY_PATH="$PREFIX/lib:$LIBRARY_PATH"
export LD_LIBRARY_PATH="$PREFIX/lib:$LD_LIBRARY_PATH"

# This is set so CEGUI can find its dependencies in the local prefix
export CMAKE_PREFIX_PATH=$PREFIX

# setup directories
mkdir -p $PREFIX
mkdir -p $DEPS_SOURCE
mkdir -p $SOURCE

# Log Directory
LOGDIR=$WORKDIR/logs
mkdir -p $LOGDIR

# Output redirect logs
AUTOLOG=autogen.log     # Autogen output
CONFIGLOG=config.log    # Configure output
MAKELOG=build.log      # Make output
INSTALLLOG=install.log # Install output

CONFIGURE_EXTRA_FLAGS=""

if [[ $OSTYPE == *darwin* ]] ; then
  #the default architecture is universal build: i864;x86_64
  #To save space and time, we will only build x86_64
  CMAKE_EXTRA_FLAGS="$CMAKE_EXTRA_FLAGS -GXcode -DCMAKE_OSX_ARCHITECTURES=x86_64"

  #on mac libtool is called glibtool.
  #Automake should set this, but it has messed up the order of variable definitions.
  export MAKEOPTS="$MAKEOPTS LIBTOOL=glibtool"

  export CXXFLAGS="-O2 -g -DTOLUA_EXPORT -DCEGUI_STATIC -DWITHOUT_SCRAP -I$PREFIX/include -I/opt/local/include $CXXFLAGS"
  export CFLAGS="-O2 -g -DTOLUA_EXPORT -DCEGUI_STATIC -DWITHOUT_SCRAP -I$PREFIX/include -I/opt/local/include $CFLAGS"
  export LDFLAGS="$LDFLAGS -L$PREFIX/lib -L/opt/local/lib"

  #without CPATH cegui is not finding freeimage.
  export CPATH="/opt/local/include:$CPATH"

elif [[ x$MSYSTEM = x"MINGW32" && $1 != "install-deps" ]] ; then
  export CONFIGURE_EXTRA_FLAGS="--enable-shared --disable-static"
  export CXXFLAGS="-O2 -msse2 -mthreads -DBOOST_THREAD_USE_LIB -DCEGUILUA_EXPORTS $CXXFLAGS"
  export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:/usr/local/lib/pkgconfig:/mingw/lib/pkgconfig:/lib/pkgconfig:$PKG_CONFIG_PATH"
  #for msys/mingw we need to specify the include directory
  export CXXFLAGS="-I$PREFIX/include $CXXFLAGS"
fi


function buildwf()
{
    if [ x"$2" = x"" ]; then
      PRJNAME="$1"
    else
      PRJNAME="$2"
    fi

    mkdir -p $LOGDIR/$PRJNAME

    cd $SOURCE/$1
    if [ ! -f "configure" ] ; then
      echo "  Running autogen..."
      NOCONFIGURE=1 ./autogen.sh > $LOGDIR/$PRJNAME/$AUTOLOG
    fi

    mkdir -p $BUILDDIR
    cd $BUILDDIR
    if [ ! -f "Makefile" ] ; then
      echo "  Running configure..."
      ../configure --prefix=$PREFIX $CONFIGURE_EXTRA_FLAGS > $LOGDIR/$PRJNAME/$CONFIGLOG
    fi

    echo "  Building..."
    make $MAKEOPTS > $LOGDIR/$PRJNAME/$MAKELOG
    echo "  Installing..."
    make install > $LOGDIR/$PRJNAME/$INSTALLLOG
}

function checkoutwf()
{
  if [ x"$2" = x"" ]; then
    USER="worldforge"
  else
    USER="$2"
  fi
  if [ x"$3" = x"" ]; then
    BRANCH="master"
  else
    BRANCH="$3"
  fi
  if [ ! -d $1 ]; then
    git clone git://github.com/$USER/$1.git -b $BRANCH
  else
    cd $1
    if [ x$HAMMERALWAYSSTASH = xyes ]; then
      git stash save "Hammer stash"
    fi
    git remote set-url origin git://github.com/$USER/$1.git && git fetch && git rebase origin/$BRANCH && cd ..
  fi
}

function cyphesis_post_install()
{
  cd $PREFIX/bin

  # Rename real cyphesis binary to cyphesis.bin
  mv cyphesis cyphesis.bin

  # Install our cyphesis.in script as cyphesis
  cp $SUPPORTDIR/cyphesis.in cyphesis
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
    echo "  install-deps  -  install all 3rd party dependencies"
    echo "  checkout      -  fetch worldforge source (libraries, clients)"
    echo "  build         -  build the sources and install in environment"
    echo "  clean         -  delete build directory so a fresh build can be performed"
    echo "  release_ember -  change ember to a specific release"
    echo ""
    echo "For more help, type: hammer.sh help <command>"
  elif [ $1 = "install-deps" ] ; then
    echo "Install all 3rd party dependencies into build environment."
    echo ""
    echo "Usage: hammer.sh install-deps <dependency to install>"
    echo "Dependencies Available:"
    echo "  all      -  install all dependencies listed below"
    echo "  cegui    -  a free library providing windowing and widgets for "
    echo "              graphics APIs / engines"
    echo "  ogre     -  3D rendering engine"
    echo "  cg       -  interactive effects toolkit"
    echo "Hint: build ogre first then cegui"
  elif [ $1 = "checkout" ] ; then
    echo "Fetch latest source code for worldforge libraries and clients."
    echo "If you want Hammer to stash away any local changes, use the"
    echo "environment variable HAMMERALWAYSSTASH=yes."
    echo ""
    echo "Usage: hammer.sh checkout <target>"
    echo "Available targets:"
    echo "  all      - fetch everything"
    echo "  libs     - fetch libraries only"
    echo "  ember    - fetch ember only"
    echo "  webember - fetch ember and webember"
    echo "  cyphesis - fetch cyphesis server only"
    echo "  worlds   - fetch worlds only"
  elif [ $1 = "build" ] ; then
    echo "Build the sources and install in environment."
    echo ""
    echo "Usage: hammer.sh build <target> \"<makeopts>\""
    echo "Available targets:"
    echo "  all      - build everything"
    echo "  libs     - build libraries only"
    echo "  ember    - build ember only"
    echo "  webember - build webember only"
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
  elif [ $1 = "release_ember" ] ; then
    echo "Build a specific release of Ember, including latest stable libraries."
    echo "Do not run this command as root, AppImage building will fail."
    echo ""
    echo "Usage: hammer.sh release_ember <version number> [<target>]"
    echo "Available targets [optional]:"
    echo "  dir        - build into a standard directory structure"
    echo "  image      - build an AppImage or AppBundle (Default)"
    echo ""
    echo "e.g. hammer.sh release_ember 0.7.1 dir"
  else
    echo "No help page found!"
  fi
}

function install_deps_Cg()
{
  # Cg Toolkit
    echo "  Installing Cg Toolkit..."
    if [[ $OSTYPE == *darwin* ]] ; then
      CG_DOWNLOAD+=".dmg"
      CG_LIB_LOCATION="Library/Frameworks/Cg.framework/Versions/1.0/Cg"
    elif [[ $OSTYPE == linux-gnu ]] ; then
      if [[ $BUILDDIR == 64 ]] ; then
        CG_DOWNLOAD+="_x86_64.tgz"
        CG_LIB_LOCATION="usr/lib64/libCg.so"
      elif [[ $BUILDDIR == 32 ]] ; then
        CG_DOWNLOAD+="_x86.tgz"
        CG_LIB_LOCATION="usr/lib/libCg.so"
      fi
    fi
    mkdir -p $LOGDIR/deps/cg
    cd $DEPS_SOURCE
    if [ ! -d Cg_$CG_FULLVER ]; then
      echo "  Downloading..."
      curl -C - -OL http://developer.download.nvidia.com/cg/Cg_$CG_VER/$CG_DOWNLOAD
      if [[ $OSTYPE == *darwin* ]] ; then
        hdiutil mount $CG_DOWNLOAD
        cp "/Volumes/Cg-${CG_FULLVER}/Cg-${CG_FULLVER}.app/Contents/Resources/Installer Items/NVIDIA_Cg.tgz" .
        hdiutil unmount "/Volumes/Cg-$CG_FULLVER/"
        CG_DOWNLOAD="NVIDIA_Cg.tgz"
      fi
      mkdir -p Cg_$CG_FULLVER
      cd Cg_$CG_FULLVER
      tar -xf ../$CG_DOWNLOAD
    fi
    mkdir -p $PREFIX/lib
    cp $DEPS_SOURCE/Cg_${CG_FULLVER}/$CG_LIB_LOCATION $PREFIX/lib
    echo "  Done."
}

function install_deps_Ogre()
{
  # Ogre3D
    echo "  Installing Ogre..."
    mkdir -p $LOGDIR/deps/ogre
    cd $DEPS_SOURCE
    if [ ! -d $OGRE_VER ]; then
      echo "  Downloading..."
      curl -C - -OL https://bitbucket.org/sinbad/ogre/get/$OGRE_DOWNLOAD
      mkdir -p $OGRE_VER
      cd $OGRE_VER
      tar -xjf ../$OGRE_DOWNLOAD
      OGRE_SOURCE=$DEPS_SOURCE/$OGRE_VER/`ls $DEPS_SOURCE/$OGRE_VER`
      if [[ $OSTYPE == *darwin* ]] ; then
        cd $OGRE_SOURCE
        echo "  Patching..."
        ls .
        patch -p1 < $SUPPORTDIR/ogre_cocoa_currentGLContext_support.patch
      fi
    fi
    cd $OGRE_SOURCE || cd $DEPS_SOURCE/$OGRE_VER/`ls $DEPS_SOURCE/$OGRE_VER`
    mkdir -p $BUILDDIR
    cd $BUILDDIR
    echo "  Configuring..."
    OGRE_EXTRA_FLAGS=""
    cmake .. -DCMAKE_INSTALL_PREFIX="$PREFIX" -DOIS_INCLUDE_DIR="/usr/lib" -DOGRE_BUILD_SAMPLES="OFF" $OGRE_EXTRA_FLAGS $CMAKE_EXTRA_FLAGS > $LOGDIR/deps/ogre/$CONFIGLOG
    if [[ $OSTYPE == *darwin* ]] ; then
      echo "  Building..."
        xcodebuild -configuration RelWithDebInfo > $LOGDIR/deps/ogre/$MAKELOG
        echo "  Installing..."
        xcodebuild -configuration RelWithDebInfo -target install > $LOGDIR/deps/ogre/$INSTALLLOG
        cp -r lib/RelWithDebInfo/* $PREFIX/lib
        #on mac, we have only Ogre.framework
        sed -i "" -e "s/-L\$[{]libdir[}]\ -lOgreMain/-F\${libdir} -framework Ogre/g" $PREFIX/lib/pkgconfig/OGRE.pc
        echo "  Done."
    else
        echo "  Building..."
        make $MAKEOPTS > $LOGDIR/deps/ogre/$MAKELOG
        echo "  Installing..."
        make install > $LOGDIR/deps/ogre/$INSTALLLOG
        echo "  Done."
    fi
}

function install_deps_freealut()
{
  # freealut
    echo "  Installing freealut..."
    mkdir -p $LOGDIR/deps/freealut
    cd $DEPS_SOURCE

    echo "  Downloading..."
    curl -C - -OL http://connect.creativelabs.com/openal/Downloads/ALUT/freealut-${FREEALUT_VER}-src.zip
    unzip -o freealut-${FREEALUT_VER}-src.zip
    cd freealut-${FREEALUT_VER}-src
    if [[ $OSTYPE == *darwin* ]] ; then
      cp $SUPPORTDIR/openal.pc $PREFIX/lib/pkgconfig/openal.pc
    fi
    echo "  Running autogen..."
    autoreconf --install --force --warnings=all

    mkdir -p $BUILDDIR
    cd $BUILDDIR

    echo "  Running configure..."
    ../configure --prefix=$PREFIX $CONFIGURE_EXTRA_FLAGS \
    CFLAGS="$CFLAGS `pkg-config --cflags openal`" LDFLAGS="$LDFLAGS `pkg-config --libs openal`" > $LOGDIR/deps/freealut/$CONFIGLOG

    echo "  Building..."
    make $MAKEOPTS > $LOGDIR/deps/freealut/$MAKELOG
    echo "  Installing..."
    make install > $LOGDIR/deps/freealut/$INSTALLLOG
}

function install_deps_tolua++()
{
  # tolua++
    #the "all" keyword will only work on mac, but "tolua++" will work on linux and mac, if you set LUA_CFLAGS and LUA_LDFLAGS.
    NORMAL_LUA_VERSION="`pkg-config --modversion lua`"
    if [[ ! $NORMAL_LUA_VERSION == 5.1* ]]; then
        LUA_CFLAGS="`pkg-config --cflags lua5.1`"
        LUA_LDFLAGS="`pkg-config --libs lua5.1`"
    fi
    if [ "x$LUA_CFLAGS" == "x" ] ; then
      LUA_CFLAGS=""
    fi
    if [ "x$LUA_LDFLAGS" == "x" ] ; then
      LUA_LDFLAGS="-llua"
    fi
    cd $DEPS_SOURCE
    if [ ! -d $TOLUA_VER ] ; then
        curl -OL http://www.codenix.com/~tolua/${TOLUA_VER}.tar.bz2
        tar -xjf ${TOLUA_VER}.tar.bz2
    fi
    cd $TOLUA_VER
    mkdir -p $PREFIX/include
    cp include/tolua++.h $PREFIX/include/tolua++.h
    cd src/lib
    gcc $CFLAGS -c -fPIC -I$PREFIX/include *.c $LUA_CFLAGS
    mkdir -p $PREFIX/lib
    if [[ $OSTYPE == *darwin* ]] ; then
      ar cq libtolua++.a *.o
      cp libtolua++.a $PREFIX/lib/libtolua++.a
    else
      gcc -shared -Wl,-soname,libtolua++.so -o libtolua++.so  *.o
      cp libtolua++.so $PREFIX/lib/libtolua++.so
    fi
    cd ../bin
    gcc $CFLAGS $LDFLAGS -o tolua++ -I$PREFIX/include $LUA_CFLAGS $LUA_LDFLAGS -L$PREFIX/lib tolua.c toluabind.c -ltolua++
    mkdir -p $PREFIX/bin
    cp tolua++ $PREFIX/bin/tolua++
    cd ../../..
}

function install_deps_CEGUI()
{
  # CEGUI
    echo "  Installing CEGUI..."
    mkdir -p $LOGDIR/deps/CEGUI    # create CEGUI log directory
    cd $DEPS_SOURCE
    if [ ! -d $CEGUI_VER ] ; then
      echo "  Downloading..."
      curl -C - -OL http://downloads.sourceforge.net/sourceforge/crayzedsgui/$CEGUI_DOWNLOAD
      tar -xzf $CEGUI_DOWNLOAD
      if [[ $OSTYPE == *darwin* ]] ; then
        echo "  Patching..."
        cd $DEPS_SOURCE/$CEGUI_VER
        sed -i "" -e "s/\"macPlugins.h\"/\"implementations\/mac\/macPlugins.h\"/g" cegui/src/CEGUIDynamicModule.cpp
        sed -i "" -e '1i\#include<CoreFoundation\/CoreFoundation.h>' cegui/include/CEGUIDynamicModule.h
      fi
    fi
    cd $DEPS_SOURCE/$CEGUI_VER
    mkdir -p $BUILDDIR
    cd $BUILDDIR
    echo "  Configuring..."
    cmake -DCMAKE_INSTALL_PREFIX="$PREFIX" -C ${SUPPORTDIR}/CEGUI_defaults.cmake $CMAKE_EXTRA_FLAGS ..  > $LOGDIR/deps/CEGUI/$CONFIGLOG 
    echo "  Building..."
    make $MAKEOPTS > $LOGDIR/deps/CEGUI/$MAKELOG
    echo "  Installing..."
    make install > $LOGDIR/deps/CEGUI/$INSTALLLOG
    if [[ $OSTYPE == *darwin* ]] ; then
      #on mac we use -DCEGUI_STATIC, which will disable the plugin interface and we need to link the libraries manually.
      sed -i "" -e "s/-lCEGUIBase/-lCEGUIBase -lCEGUIFalagardWRBase -lCEGUIFreeImageImageCodec -lCEGUITinyXMLParser/g" $PREFIX/lib/pkgconfig/CEGUI.pc
    fi
    echo "  Done."
}

function ember_fetch_media()
{
  if [ $1 = "dev" ] ; then
    MEDIAURL="http://amber.worldforge.org/media/media-dev/"
    MEDIAVERSION="devmedia"
    MEDIA_PREFETCH="set +e"
    MEDIA_POSTFETCH="set -e"
  else
    MEDIAURL="http://downloads.sourceforge.net/worldforge/ember-media-${1}.tar.bz2"
    MEDIAVERSION="releasemedia"
    MEDIA_PREFETCH=""
    MEDIA_POSTFETCH=""
  fi
  # Fetch Ember Media
    if command -v rsync &> /dev/null; then
      echo "Fetching media..."
      cd $SOURCE/clients/ember/$BUILDDIR
      $MEDIA_PREFETCH
      make $MEDIAVERSION &> $LOGDIR/clients/ember/media.log
      if [ $? != 0 ] ; then
        echo "Could not fetch media. This may be caused by the media server being down, by the network being down, or by a firewall which prevents rsync from running. You need to get the media manually from $MEDIAURL"
      else
        echo "Media fetched."
      fi
      $MEDIA_POSTFETCH
    else
      echo "Rsync not found, skipping fetching of media. You will need to download and install it yourself from $MEDIAURL"
    fi
}

# Show main help page if no arguments given
if [ $# -eq 0 ] ; then
  show_help "main"

# If help command given, show help page
elif [ "$1" = "help" ] ; then
  if [ $# -eq 2 ] ; then
    show_help $2
  else
    show_help "main"
  fi

  mkdir -p $PREFIX $SOURCE $DEPS_SOURCE

# Dependencies install
elif [ "$1" = "install-deps" ] ; then
  if [ x$MSYSTEM = x"MINGW32" ] ; then
    $HAMMERDIR/support/mingw_install_deps.sh
    exit 0
  fi
  if [ $# -ne 2 ] ; then
    echo "Missing required parameter!"
    show_help "install-deps"
    exit 1
  fi

  echo "Installing 3rd party dependencies..."

  # Create deps log directory
  mkdir -p $LOGDIR/deps

  # Cg Toolkit
  if [ "$2" = "all" ] || [ "$2" = "cg" ] ; then
    install_deps_Cg
  fi

  # Ogre3D
  if [ "$2" = "all" ] || [ "$2" = "ogre" ] ; then
    install_deps_Ogre
  fi

  # freealut
  if [ "$2" = "all" ] && [[ $OSTYPE == *darwin* ]] || [ "$2" = "freealut" ] ; then
    install_deps_freealut
  fi

  # tolua++
  if [ "$2" = "all" ] && [[ $OSTYPE == *darwin* ]] || [ "$2" = "tolua++" ] ; then
    install_deps_tolua++
  fi

  # CEGUI
  if [ "$2" = "all" ] || [ "$2" = "cegui" ] ; then
    install_deps_CEGUI
  fi

  echo "Install of 3rd party dependencies is complete."

# Source checkout
elif [ "$1" = "checkout" ] ; then
  if [ $# -ne 2 ] ; then
    echo "Missing required parameter!"
    show_help "checkout"
    exit 1
  fi
  echo "Checking out sources..."

  if [ "$2" = "libs" ] || [ "$2" = "all" ] ; then

    mkdir -p $SOURCE/libs
    cd $SOURCE/libs

    # Varconf
    echo "  Varconf..."
    checkoutwf "varconf"
    echo "  Done."

    # Atlas-C++
    echo "  Atlas-C++..."
    checkoutwf "atlas-cpp"
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
  fi

  if [ "$2" = "worlds" ] || [ "$2" = "all" ] ; then
    # Worlds
    echo "  Worlds..."
    mkdir -p $SOURCE
    cd $SOURCE
    checkoutwf "worlds"
    echo "  Done."
  fi

  if [ "$2" = "ember" ] || [ "$2" = "webember" ] || [ "$2" = "all" ] ; then
    # Ember client
    echo "  Ember client..."
    mkdir -p $SOURCE/clients
    cd $SOURCE/clients
    checkoutwf "ember"
    echo "  Done."
  fi

  if [ "$2" = "cyphesis" ] || [ "$2" = "all" ] ; then
    # Cyphesis
    echo "  Cyphesis..."
    mkdir -p $SOURCE/servers
    cd $SOURCE/servers
    checkoutwf "cyphesis"
    echo "  Done."
  fi

  if [ "$2" = "metaserver-ng" ] ; then
    # Metaserver
    echo "  Metaserver-ng..."
    mkdir -p $SOURCE/servers
    cd $SOURCE/servers
    checkoutwf "metaserver-ng"
    echo "  Done."
  fi

  if [ "$2" = "webember" ] || [ "$2" = "all" ] ; then
    if [[ x$MSYSTEM != x"MINGW32" ]] ; then
      echo "  FireBreath..."
      mkdir -p $SOURCE/clients/webember
      cd $SOURCE/clients/webember
      checkoutwf "FireBreath" "sajty"
      echo "  Done."
      echo "  WebEmber..."
      checkoutwf "webember"
      echo "  Done."
    fi
  fi

  echo "Checkout complete."

# Build source
elif [ "$1" = "build" ] ; then
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
  if [ "$2" = "libs" ] || [ "$2" = "all" ] ; then

    # Varconf
    echo "  Varconf..."
    buildwf "libs/varconf"
    echo "  Done."

    # Wfmath
    echo "  Wfmath..."
    buildwf "libs/wfmath"
    echo "  Done."

    # Atlas-C++
    echo "  Atlas-C++..."
    buildwf "libs/atlas-cpp"
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

  if [ "$2" = "worlds" ] || [ "$2" = "all" ] ; then

    # Worlds
    echo "  Worlds..."
    buildwf "worlds"
    echo "  Done."
  fi

  if [ "$2" = "ember" ] || [ "$2" = "all" ] ; then

    # Ember client
    echo "  Ember client..."
    buildwf "clients/ember"
    echo "  Done."

    # Ember media
    ember_fetch_media "dev"

  fi

  if [ "$2" = "cyphesis" ] || [ "$2" = "all" ] ; then

    # Cyphesis
    echo "  Cyphesis..."
    buildwf "servers/cyphesis"
    cyphesis_post_install
    echo "  Done."
  fi

  if [ "$2" = "metaserver-ng" ] ; then

    # metaserver-ng
    # change sysconfdir in order to conform with the manner
    # of WF builds
    echo "  metaserver-ng..."
    CONFIGURE_EXTRA_FLAGS="--sysconfdir=$PREFIX/etc/metaserver-ng";
    buildwf "servers/metaserver-ng"
    CONFIGURE_EXTRA_FLAGS="";
    echo "  Done."
  fi

  if [ "$2" = "webember" ] || [ "$2" = "all" ] ; then

    echo "  WebEmber..."
    CONFIGURE_EXTRA_FLAGS="$CONFIGURE_EXTRA_FLAGS --enable-webember"
    #we need to change the BUILDDIR to separate the ember and webember build directories.
    #the strange thing is that if BUILDDIR is 6+ character on win32, the build will fail with missing headers.
    export BUILDDIR=web${BUILDDIR}
    buildwf "clients/ember" "webember"
    echo "  Done."

    # WebEmber media
    ember_fetch_media "dev"

    # WebEmber
    echo "  WebEmber plugin..."
    if [[ x$MSYSTEM = x"MINGW32" ]] ; then
      # Firebreath is not supporting mingw32 yet, we will use msvc prebuilt for webember.
      mkdir -p $SOURCE/clients/ember/$BUILDDIR
      cd $SOURCE/clients/ember/$BUILDDIR
      curl -C - -OL http://sajty.elementfx.com/npWebEmber.tar.gz
      tar -xzf npWebEmber.tar.gz
      cp npWebEmber.dll $PREFIX/bin/npWebEmber.dll
      regsvr32 -s $PREFIX/bin/npWebEmber.dll
      #To uninstall: regsvr32 -u $PREFIX/bin/npWebEmber.dll
    else
      mkdir -p $LOGDIR/webember_plugin
      mkdir -p $SOURCE/clients/webember/FireBreath/$BUILDDIR
      cd $SOURCE/clients/webember/FireBreath/$BUILDDIR

      cmake -DCMAKE_INSTALL_PREFIX=$PREFIX -DFB_PROJECTS_DIR=$SOURCE/clients/webember/webember/plugin $CMAKE_EXTRA_FLAGS .. > $LOGDIR/webember_plugin/cmake.log
      if  [[ $OSTYPE == *darwin* ]] ; then
        echo "  Building..."
        xcodebuild -configuration RelWithDebInfo > $LOGDIR/webember_plugin/$MAKELOG
        echo "  Installing..."
        cp -r projects/WebEmber/RelWithDebInfo/webember.plugin $PREFIX/lib
      else
        echo "  Building..."
        make $MAKEOPTS > $LOGDIR/webember_plugin/build.log
        echo "  Installing..."
        mkdir -p ~/.mozilla/plugins
        cp bin/WebEmber/npWebEmber.so ~/.mozilla/plugins/npWebEmber.so
      fi
    fi
    export BUILDDIR=`getconf LONG_BIT`
    echo "  Done."
  fi

  echo "Build complete."

elif [ "$1" = "clean" ] ; then
  if [ $# -ne 2 ] ; then
    echo "Missing required parameter!"
    show_help "clean"
    exit 1
  fi

  # Delete build directory
  if [ "$2" = "cegui" ] ; then
    rm -rf $DEPS_SOURCE/$CEGUI_VER/$BUILDDIR
  elif [ "$2" = "ogre" ] ; then
    rm -rf $DEPS_SOURCE/$OGRE_VER/ogre/$BUILDDIR
  else
    rm -rf $SOURCE/$2/$BUILDDIR
  fi

elif [ "$1" = "release_ember" ] ; then
  # Set configuration for building a release
  if [[ $OSTYPE != *darwin* ]] ; then
    export CXXFLAGS="$CXXFLAGS -O3 -g0 -s"
    export CFLAGS="$CFLAGS -O3 -g0 -s"
  fi
  export APP_DIR_ROOT="$WORKDIR/Ember.AppDir"

  # Install external dependencies
  echo "Installing 3rd party dependencies..."
  # Create deps log directory
  mkdir -p $LOGDIR/deps
  install_deps_Cg
  install_deps_Ogre
  if [[ $OSTYPE == *darwin* ]] ; then
    install_deps_freealut
    install_deps_tolua++
  fi
  install_deps_CEGUI
  echo "Install of 3rd party dependencies is complete."

  # Source checkout
  echo "Checking out sources..."
    mkdir -p $SOURCE/libs
    cd $SOURCE/libs
    echo "  Varconf..."
    checkoutwf "varconf"
    cd $SOURCE/libs/varconf
    git checkout $VARCONF_VER
    echo "  Done."
    cd $SOURCE/libs
    echo "  Atlas-C++..."
    checkoutwf "atlas-cpp"
    cd $SOURCE/libs/atlas-cpp
    git checkout $ATLASCPP_VER
    echo "  Done."
# Needs to be removed for Ember version 0.8.0 and above
    cd $SOURCE/libs
    echo "  Skstream..."
    checkoutwf "skstream"
    cd $SOURCE/libs/skstream
    git checkout $SKSTREAM_VER
    echo "  Done."
    cd $SOURCE/libs
    echo "  Wfmath..."
    checkoutwf "wfmath"
    cd $SOURCE/libs/wfmath
    git checkout $WFMATH_VER
    echo "  Done."
    cd $SOURCE/libs
    echo "  Eris..."
    checkoutwf "eris"
    cd $SOURCE/libs/eris
    git checkout $ERIS_VER
    echo "  Done."
    cd $SOURCE/libs
    echo "  Libwfut..."
    checkoutwf "libwfut"
    cd $SOURCE/libs/libwfut
    git checkout $WFUT_VER
    echo "  Done."
    cd $SOURCE/libs
    echo "  Mercator..."
    checkoutwf "mercator"
    cd $SOURCE/libs/mercator
    git checkout $MERCATOR_VER
    echo "  Done."
    echo "  Ember client..."
    mkdir -p $SOURCE/clients
    cd $SOURCE/clients
    checkoutwf "ember"
    cd $SOURCE/clients/ember
    git checkout "release-$2"
    echo "  Done."
  echo "Checkout complete."

  # Build source
  echo "Building sources..."
    # Build libraries
    echo "  Varconf..."
    buildwf "libs/varconf"
    echo "  Done."
# Needs to be removed for Ember version 0.8.0 and above
    echo "  Skstream..."
    buildwf "libs/skstream"
    echo "  Done."
    echo "  Wfmath..."
    buildwf "libs/wfmath"
    echo "  Done."
    echo "  Atlas-C++..."
    buildwf "libs/atlas-cpp"
    echo "  Done."
    echo "  Mercator..."
    buildwf "libs/mercator"
    echo "  Done."
    echo "  Eris..."
    buildwf "libs/eris"
    echo "  Done."
    echo "  Libwfut..."
    buildwf "libs/libwfut"
    echo "  Done."
    # Build Ember client
    echo "  Ember client..."
    buildwf "clients/ember"
    echo "  Done."
    # Fetch Ember media
    ember_fetch_media $2
  echo "Build complete."

  # Check for Ember release target option
  if [ x"$3" = x"" ] || [ "$3" = "image" ] ; then
    # making an AppImage/AppBundle
    if [[ $OSTYPE == *darwin* ]] ; then
      echo "Creating AppBundle."
      . $HAMMERDIR/support/AppBundler.sh
      echo "AppBundle creation complete."
    else
      echo "Creating AppImage."
      mkdir -p $LOGDIR/AppImage/
      . $HAMMERDIR/support/linux_AppDir_create.sh 2>&1 | tee $LOGDIR/AppImage/AppDir.log
      echo "AppImage will be created from the AppDir at $APP_DIR_ROOT and placed into $WORKDIR."
      python $HAMMERDIR/../AppImageKit/AppImageAssistant.AppDir/package $APP_DIR_ROOT $WORKDIR/ember-${2}-x86_$BUILDDIR create new 2>&1 | tee $LOGDIR/AppImage/AppImage.log
      echo "AppImage creation complete."
    fi
  else 
    # making a standard directory
    echo "Creating release directory."
    cd $HAMMERDIR
    . $HAMMERDIR/support/linux_release_bundle.sh
    echo "Release directory created."
  fi

else
  echo "Invalid command!"
  show_help "main"
fi
