#!/bin/bash

set -e

export HAMMERDIR=$PWD
export WORKDIR=$HAMMERDIR/work
export PREFIX=$WORKDIR/local
export SOURCE=$WORKDIR/build/worldforge
export DEPS_SOURCE=$WORKDIR/build/deps
export MAKEOPTS="-j3"
export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH
export BUILDDIR=`uname -m`
export SUPPORTDIR=$HAMMERDIR/support
#needed to find tolua++ program if installed in prefix
export PATH="$PATH:$PREFIX/bin"
export CPATH="$PREFIX/include:$CPATH"
export LDFLAGS="$LDFLAGS -L$PREFIX/lib"
export LIBRARY_PATH="$PREFIX/lib:$LIBRARY_PATH"
export LD_LIBRARY_PATH="$PREFIX/lib:$LD_LIBRARY_PATH"

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

# Dependencies
CEGUI=CEGUI-0.7.5
CEGUI_DOWNLOAD=CEGUI-0.7.5.tar.gz
OGRE=ogre_1_7_3
OGRE_DOWNLOAD=ogre_src_v1-7-3.tar.bz2

CONFIGURE_EXTRA_FLAGS=""
CMAKE_EXTRA_FLAGS=""

if [[ $OSTYPE == *darwin* ]] ; then
	#the default architecture is universal build: i864;x86_64
	#To save space and time, we will only build x86_64
	CMAKE_EXTRA_FLAGS="-GXcode -DCMAKE_OSX_ARCHITECTURES=x86_64"
	
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
    cd $1 && git remote set-url origin git://github.com/$USER/$1.git && git fetch && git rebase origin/$BRANCH && cd ..
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
    echo "  cegui    -  a free library providing windowing and widgets for "
    echo "              graphics APIs / engines"
    echo "  ogre     -  3D rendering engine"
	echo "Hint: build ogre first then cegui"
  elif [ $1 = "checkout" ] ; then
    echo "Fetch latest source code for worldforge libraries and clients."
    echo ""
    echo "Usage: hammer.sh checkout"
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
  if [ x$MSYSTEM = x"MINGW32" ] ; then
    SCRIPTDIR=`dirname "$0"`
    $SCRIPTDIR/mingw_install_deps.sh
    exit 0
  fi
  if [ $# -ne 2 ] ; then
    echo "Missing required parameter!"
    show_help "install-deps"
    exit 1
  fi

  echo "Installing deps..."

  # Create deps log directory
  mkdir -p $LOGDIR/deps

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
      if [[ $OSTYPE == *darwin* ]] ; then
        cd $DEPS_SOURCE/$OGRE/`ls $DEPS_SOURCE/$OGRE`
        echo "  Patching..."
        ls .
        patch -p1 < $SUPPORTDIR/ogre_cocoa_currentGLContext_support.patch
      fi
    fi
    cd $DEPS_SOURCE/$OGRE/`ls $DEPS_SOURCE/$OGRE`
    mkdir -p $BUILDDIR
    cd $BUILDDIR
    echo "  Configuring..."
	OGRE_EXTRA_FLAGS=""
    cmake .. -DCMAKE_INSTALL_PREFIX="$PREFIX" -DOGRE_BUILD_SAMPLES=false $OGRE_EXTRA_FLAGS $CMAKE_EXTRA_FLAGS > $LOGDIR/deps/ogre/$CONFIGLOG
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
  fi

  # freealut
  if [ $2 = "all" ] && [[ $OSTYPE == *darwin* ]] || [ $2 = "freealut" ] ; then
    echo "  Installing freealut..."
    mkdir -p $LOGDIR/deps/freealut
    cd $DEPS_SOURCE
    
    echo "  Downloading..."
    wget -c http://connect.creativelabs.com/openal/Downloads/ALUT/freealut-1.1.0-src.zip
    unzip -o freealut-1.1.0-src.zip
    cd freealut-1.1.0-src
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
  fi
  
  # tolua++
  if [ $2 = "all" ] && [[ $OSTYPE == *darwin* ]] || [ $2 = "tolua++" ] ; then
    #the "all" keyword will only work on mac, but "tolua++" will work on linux and mac, if you set LUA_CFLAGS and LUA_LDFLAGS.
    #LUA_CFLAGS="`pkg-config --cflags lua5.1`"
    #LUA_LDFLAGS="`pkg-config --libs lua5.1`"
    if [ "x$LUA_CFLAGS" == "x" ] ; then
      LUA_CFLAGS=""
    fi
    if [ "x$LUA_LDFLAGS" == "x" ] ; then
      LUA_LDFLAGS="-llua"
    fi
    cd $DEPS_SOURCE
    wget -c http://www.codenix.com/~tolua/tolua++-1.0.93.tar.bz2
    tar -xjf tolua++-1.0.93.tar.bz2
    cd tolua++-1.0.93
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
  fi

  # CEGUI
  if [ $2 = "all" ] || [ $2 = "cegui" ] ; then
    echo "  Installing CEGUI..."
    mkdir -p $LOGDIR/deps/CEGUI    # create CEGUI log directory
    cd $DEPS_SOURCE
    if [ ! -d $CEGUI ] ; then
      echo "  Downloading..."
      wget -c http://downloads.sourceforge.net/sourceforge/crayzedsgui/$CEGUI_DOWNLOAD
      tar zxvf $CEGUI_DOWNLOAD
      if [[ $OSTYPE == *darwin* ]] ; then
        echo "  Patching..."
        cd $DEPS_SOURCE/$CEGUI
        sed -i "" -e "s/\"macPlugins.h\"/\"implementations\/mac\/macPlugins.h\"/g" cegui/src/CEGUIDynamicModule.cpp
        #Do not change indentation for the include line.
        sed -i "" -e '1i\
#include<CoreFoundation\/CoreFoundation.h>' cegui/include/CEGUIDynamicModule.h
      fi
    fi
    cd $DEPS_SOURCE/$CEGUI
    mkdir -p $BUILDDIR
    cd $BUILDDIR
    echo "  Configuring..."
    ../configure --prefix=$PREFIX  --disable-samples --disable-opengl-renderer --disable-irrlicht-renderer --disable-xerces-c --disable-libxml --disable-expat --disable-directfb-renderer --disable-corona --disable-devil --disable-stb --disable-tga --disable-python-module $CONFIGURE_EXTRA_FLAGS > $LOGDIR/deps/CEGUI/$CONFIGLOG
    echo "  Building..."
    make $MAKEOPTS > $LOGDIR/deps/CEGUI/$MAKELOG
    echo "  Installing..."
    make install > $LOGDIR/deps/CEGUI/$INSTALLLOG
    if [[ $OSTYPE == *darwin* ]] ; then
      #on mac we use -DCEGUI_STATIC, which will disable the plugin interface and we need to link the libraries manually.
      sed -i "" -e "s/-lCEGUIBase/-lCEGUIBase -lCEGUIFalagardWRBase -lCEGUIFreeImageImageCodec -lCEGUITinyXMLParser/g" $PREFIX/lib/pkgconfig/CEGUI.pc
    fi
    echo "  Done."
  fi

  echo "Install Done."

# Source checkout
elif [ $1 = "checkout" ] ; then
  echo "Fetching sources..."

  if [ $2 = "libs" ] || [ $2 = "all" ] ; then

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
  fi

  if [ $2 = "ember" ] || [ $2 = "webember" ] || [ $2 = "all" ] ; then
  # Ember client
  echo "  Ember client..."
  mkdir -p $SOURCE/clients
  cd $SOURCE/clients
  checkoutwf "ember"
  echo "  Done."
  fi

  if [ $2 = "cyphesis" ] || [ $2 = "all" ] ; then
  # Cyphesis
  echo "  Cyphesis..."
  mkdir -p $SOURCE/servers
  cd $SOURCE/servers
  checkoutwf "cyphesis"
  echo "  Done."
  fi

  if [ $2 = "webember" ] || [ $2 = "all" ] ; then
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

  if [ $2 = "ember" ] || [ $2 = "all" ] ; then

  # Ember client
  echo "  Ember client..."
  buildwf "clients/ember"
  echo "  Done."

  if command -v rsync &> /dev/null; then
    echo "Fetching media..."
    cd $SOURCE/clients/ember/$BUILDDIR
    make devmedia
    echo "Media fetched."
  else
    echo "Rsync not found, skipping fetching media. You will need to download and install it yourself."
  fi

  fi

  if [ $2 = "cyphesis" ] || [ $2 = "all" ] ; then

  # Cyphesis
  echo "  Cyphesis..."
  buildwf "servers/cyphesis"
  cyphesis_post_install
  echo "  Done."
  fi


  if [ $2 = "webember" ] || [ $2 = "all" ] ; then
  
  echo "  WebEmber..."
  CONFIGURE_EXTRA_FLAGS="$CONFIGURE_EXTRA_FLAGS --enable-webember"
  #we need to change the BUILDDIR to separate the ember and webember build directories.
  #the strange thing is that if BUILDDIR is 6+ character on win32, the build will fail with missing headers.
  export BUILDDIR="build"
  buildwf "clients/ember" "webember"
  echo "  Done."

  if command -v rsync &> /dev/null; then
    echo "Fetching media..."
    cd $SOURCE/clients/ember/$BUILDDIR
    make devmedia > $LOGDIR/webember/media.log
    echo "Media fetched."
  else
    echo "Rsync not found, skipping fetching media. You will need to download and install it yourself."
  fi

    # WebEmber
    echo "  WebEmber plugin..."
    if [[ x$MSYSTEM = x"MINGW32" ]] ; then
      # Firebreath is not supporting mingw32 yet, we will use msvc prebuilt for webember.
      mkdir -p $SOURCE/clients/ember/$BUILDDIR
      cd $SOURCE/clients/ember/$BUILDDIR
      wget -c http://sajty.elementfx.com/npWebEmber.tar.gz
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
    rm -rf $SOURCE/$2/$BUILDDIR
  fi

else
  echo "Invalid command!"
  show_help "main"
fi
