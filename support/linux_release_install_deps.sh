#!/bin/bash

#this is a modified version of the mingw_install_deps.sh script to build everything on linux WITH "-rpath" option.
#NOTE: you should build it on a clean distro, or configure may find extra packages and increases dependencies.

#prerequisites:
#  sudo apt-get -y install g++ make autoconf automake libtool unzip curl chrpath libxrandr-dev libsdl1.2-dev
# for portability remove libxaw6-dev and install libxaw7-dev
#  sudo apt-get remove libxaw6-dev
#  sudo apt-get install libxaw7-dev
#  on old linux distros you will need to build from source: cmake, git.
#
# download cg and install to prefix from:
#  http://developer.download.nvidia.com/cg/Cg_3.0/Cg-3.0_February2011_x86.tgz
#  http://developer.download.nvidia.com/cg/Cg_3.0/Cg-3.0_February2011_x86_64.tgz
# you may need to download newer curl to handle sourceforge download redirects:
#  http://packages.ubuntu.com/oneiric/i386/curl/download
#  http://packages.ubuntu.com/oneiric/amd64/curl/download
# add these to hammer:
#  export LDFLAGS="$LDFLAGS -Wl,-rpath,../lib -Wl,-rpath,lib -L$PREFIX/lib"
#  export CXXFLAGS="$CXXFLAGS -O2 -g -DCEGUI_STATIC"
# also set makefile jobs to -j1 in hammer, because firebreath needs 600MB/job, which caused for me with -j3 an OS freeze, when out of memory.
#once you have built ember and got a cmake error in webember, install(it will install lot of dev packages): sudo apt-get install libgtk2.0-dev

set -e

#this line is the main reason for this script
export LDFLAGS="-Wl,-rpath,../lib -Wl,-rpath,lib"

export PREFIX="$PWD/work/local"
export PATH="$PREFIX/bin:$PATH"
export CPATH="$PREFIX/include:$CPATH"
export LIBRARY_PATH="$PREFIX/lib:$LIBRARY_PATH"
export LD_LIBRARY_PATH="$PREFIX/lib:$LD_LIBRARY_PATH"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH"
export ACLOCAL_ARGS="$ACLOCAL_ARGS -I $PREFIX/share/aclocal"
export CONFIGURE_EXTRA_FLAGS="--enable-shared --disable-static"
export MAKEOPTS="-j2"

export CFLAGS="-O2 -msse2 $CFLAGS"
export CPPFLAGS="-I$PREFIX/include $CPPFLAGS"
export CXXFLAGS="-O2 -msse2 -DCEGUI_STATIC -I$PREFIX/include $CXXFLAGS"
export LDFLAGS="-L$PREFIX/lib $LDFLAGS"

LOGDIR=$PWD/work/logs/deps
BUILDDEPS=$PWD/work/build/deps
PACKAGEDIR=$BUILDDEPS/packages
DLDIR=$BUILDDEPS/downloads
LOCKDIR=$BUILDDEPS/locks

mkdir -p $LOGDIR
mkdir -p $BUILDDEPS
mkdir -p $PACKAGEDIR
mkdir -p $DLDIR
mkdir -p $LOCKDIR
mkdir -p $PREFIX/bin
mkdir -p $PREFIX/lib
mkdir -p $PREFIX/include

cd $PACKAGEDIR

#this is needed, because tar and bsdtar makes segfaults sometimes.
function extract(){
	if [[ $1 == *.tar.gz ]]; then
		tar -xzf $1
	elif [[ $1 == *.tar.bz2 ]]; then
		tar -xjf $1
	else
		unzip -o -qq $1
	fi
}

#on linux wget is not following redirects from sourceforge, so we need to use curl.
function download(){
	if [ "$2" == "" ] || [ ! -f $DLDIR/$2 ] ; then
		CURDIR="$PWD"
		cd $DLDIR
		#note: curl 7.20 is needed for -J option!
		curl -L -O -J $1
		cd $CURDIR
	fi
}
function printc(){
	echo -e "\033[33m$1\033[0m"
}
#install package without hacks
#$1: URL
#$2: archive filename to detect http redirection problems.
function installpackage(){
	PKGNAME=$(echo "$2" | sed "s/\.[^\.]*$//;s/\.tar[^\.]*$//") 
	PKGLOGDIR="$LOGDIR/$PKGNAME"
	PKGLOCKFILE="$LOCKDIR/${PKGNAME}_installed.lock"
	if [ ! -f $PKGLOCKFILE ]; then
		printc "Installing $PKGNAME..."
		mkdir -p $PKGLOGDIR
		printc "    Downloading..."
		download $1 $2
		printc "    Extracting..."
		extract $DLDIR/$2
		mkdir -p $PKGNAME/linux_build
		cd $PKGNAME
		if [ ! -f "configure" ] ; then
			printc "    Running autogen..."
			NOCONFIGURE=1 ./autogen.sh > $PKGLOGDIR/autogen.log
		fi
		cd linux_build
		printc "    Running configure..."
		../configure --prefix=$PREFIX $CONFIGURE_EXTRA_FLAGS > $PKGLOGDIR/configure.log
		printc "    Building..."
		make $MAKEOPTS > $PKGLOGDIR/build.log
		
		printc "    Installing..."
		make install > $PKGLOGDIR/install.log
		cd ../..
		touch $PKGLOCKFILE
	fi
}
function installpackage_dirless(){
	PKGNAME=$(echo "$2" | sed "s/\.[^\.]*$//;s/\.tar[^\.]*$//") 
	PKGLOGDIR="$LOGDIR/$PKGNAME"
	PKGLOCKFILE="$LOCKDIR/${PKGNAME}_installed.lock"
	if [ ! -f $PKGLOCKFILE ]; then
		printc "Installing $PKGNAME..."
		mkdir -p $PKGLOGDIR
		printc "    Downloading..."
		download $1 $2
		printc "    Extracting..."
		extract $DLDIR/$2
		cd $PKGNAME
		if [ ! -f "configure" ] ; then
			printc "    Running autogen..."
			NOCONFIGURE=1 ./autogen.sh > $PKGLOGDIR/autogen.log
		fi
		printc "    Running configure..."
		./configure --prefix=$PREFIX
		printc "    Building..."
		make $MAKEOPTS > $PKGLOGDIR/build.log
		
		printc "    Installing..."
		make install > $PKGLOGDIR/install.log
		cd ..
		touch $PKGLOCKFILE
	fi
}
#install 7za
#use your package manager!

#install rsync
#use your package manager!

#install zlib
FILENAME="zlib-1.2.5.tar.bz2"
installpackage_dirless "http://prdownloads.sourceforge.net/libpng/$FILENAME?download" "$FILENAME"

#multiline comment, its never true!
if [ 1 == 0 ] ; then
  #cmake
  curl -C - -OL http://www.cmake.org/files/v2.8/cmake-2.8.5.tar.gz
  tar -xzf cmake-2.8.5.tar.gz
  cd cmake-2.8.5
  ./configure
  make
  sudo make install
  cd ..
  
  #git
  curl -C - -OL http://kernel.org/pub/software/scm/git/git-1.7.6.1.tar.bz2
  tar -xjf git-1.7.6.1.tar.bz2
  cd git-1.7.6.1
  ./configure
  make
  sudo make install
  cd ..

fi

FILENAME="gettext-0.18.1.1.tar.gz"
installpackage "http://ftp.gnu.org/pub/gnu/gettext/$FILENAME" "$FILENAME"

#install glib
FILENAME="glib-2.28.7.tar.bz2"
installpackage "http://ftp.gnome.org/pub/gnome/sources/glib/2.28/$FILENAME" "$FILENAME"

#install pkg-config:
#use your package manager!

PKGNAME="FreeImage"
PKGLOGDIR="$LOGDIR/$PKGNAME"
PKGLOCKFILE="$LOCKDIR/${PKGNAME}_installed.lock"
if [ ! -f $PKGLOCKFILE ]; then
	printc "Installing $PKGNAME..."
	mkdir -p $PKGLOGDIR
	printc "    Downloading..."
	download "http://downloads.sourceforge.net/freeimage/FreeImage3150.zip" "FreeImage3150.zip"
	printc "    Extracting..."
	extract $DLDIR/FreeImage3150.zip
	cd $PKGNAME
	printc "    Building..."
	CXXFLAGS_SAVE="$CXXFLAGS"
	CFLAGS_SAVE="$CFLAGS"
	#setting visibility in freeimage is very important te prevent symbol conflicts from GTK+
	#it will hide libpng symbols.
	export CXXFLAGS="$CXXFLAGS -fvisibility=hidden -fvisibility-inlines-hidden"
	export CFLAGS="$CFLAGS -fvisibility=hidden"
	make > $PKGLOGDIR/build.log
	export CXXFLAGS="$CXXFLAGS_SAVE"
	export CFLAGS="$CFLAGS_SAVE"
	printc "    Installing..."
	cp Dist/FreeImage.h $PREFIX/include/FreeImage.h
	#cp Dist/libfreeimage.a $PREFIX/lib/libfreeimage.a
	cp Dist/libfreeimage-3.15.0.so $PREFIX/lib/libfreeimage-3.15.0.so
	ln -sf libfreeimage-3.15.0.so $PREFIX/lib/libfreeimage.so.3
	ln -sf libfreeimage-3.15.0.so $PREFIX/lib/libfreeimage.so
	cd ..
	touch $PKGLOCKFILE
fi

#install cmake
#use your package manager!

#install zziplib
FILENAME="zziplib-0.13.62.tar.bz2"
installpackage "http://sourceforge.net/projects/zziplib/files/zziplib13/0.13.62/$FILENAME/download" "$FILENAME"

#install freetype
FILENAME="freetype-2.4.4.tar.bz2"
installpackage "http://sourceforge.net/projects/freetype/files/freetype2/2.4.4/$FILENAME/download" "$FILENAME"

#install libCURL
FILENAME="curl-7.21.6.tar.bz2"
installpackage "http://curl.haxx.se/download/$FILENAME" "$FILENAME"

#install pcre
FILENAME="pcre-8.12.tar.bz2"
#--enable-unicode-properties is needed for ember.
CONFIGURE_EXTRA_FLAGS_SAVE="$CONFIGURE_EXTRA_FLAGS"
export CONFIGURE_EXTRA_FLAGS="$CONFIGURE_EXTRA_FLAGS --enable-unicode-properties"
installpackage "http://sourceforge.net/projects/pcre/files/pcre/8.12/$FILENAME/download" "$FILENAME"
export CONFIGURE_EXTRA_FLAGS="$CONFIGURE_EXTRA_FLAGS_SAVE"


#install sigc++
#hacks:
#	7za is not supporting PAX, need to use tar
PKGNAME="libsigc++-2.2.9"
PKGLOGDIR="$LOGDIR/$PKGNAME"
PKGLOCKFILE="$LOCKDIR/${PKGNAME}_installed.lock"
if [ ! -f $PKGLOCKFILE ]; then
	printc "Installing $PKGNAME..."
	mkdir -p $PKGLOGDIR
	printc "    Downloading..."
	download http://ftp.gnome.org/pub/GNOME/sources/libsigc++/2.2/$PKGNAME.tar.gz
	printc "    Extracting..."
	tar -xzf  $DLDIR/$PKGNAME.tar.gz
	mkdir -p $PKGNAME/linux_build
	cd $PKGNAME/linux_build
	printc "    Running configure..."
	../configure --prefix=$PREFIX $CONFIGURE_EXTRA_FLAGS > $PKGLOGDIR/configure.log
	printc "    Building..."
	make $MAKEOPTS > $PKGLOGDIR/build.log
	
	printc "    Installing..."
	make install > $PKGLOGDIR/install.log
	cd ../..
	touch $PKGLOCKFILE
fi

#install boost
PKGLOCKFILE="$LOCKDIR/boost_installed.lock"
if [ ! -f $PKGLOCKFILE ]; then
	download "http://sourceforge.net/projects/boost/files/boost/1.46.1/boost_1_46_1.tar.bz2/download" "boost_1_46_1.tar.bz2"
	extract $DLDIR/boost_1_46_1.tar.bz2
	cd boost_1_46_1
	./bootstrap.sh
	./bjam dll-path=../lib --with-thread --with-date_time --prefix=$PREFIX --layout=system variant=release install
	cd ..
	touch $PKGLOCKFILE
fi

#install readline
FILENAME="readline-6.2.tar.gz"
installpackage "ftp://ftp.cwru.edu/pub/bash/$FILENAME" "$FILENAME"

FILENAME="ncurses-5.9.tar.gz"
installpackage "http://ftp.gnu.org/pub/gnu/ncurses/$FILENAME" "$FILENAME"

#install lua
PKGLOCKFILE="$LOCKDIR/lua_installed.lock"
if [ ! -f $PKGLOCKFILE ]; then
	download "http://www.lua.org/ftp/lua-5.1.4.tar.gz" "lua-5.1.4.tar.gz"
	extract $DLDIR/lua-5.1.4.tar.gz
	cd lua-5.1.4
	#hack to build shared instead of static lua
	sed -i "s/liblua\.a/liblua.so/g" Makefile
	sed -i "s/liblua\.a/liblua.so/g" src/Makefile
 	sed -i "s/\$(RANLIB)\ \$@//g" src/Makefile
	sed -i "s/\$(AR)\ \$@\ \$?/\$(CC) -o \$@ -shared \$?/g" src/Makefile
	sed -i "s/\$(LUA_A)\ \$(LIBS)/ \$(LIBS)/g" src/Makefile
        sed -i "s/print.o/print.o \$(CORE_O)/g" src/Makefile
	make linux CFLAGS="$CFLAGS -fPIC -DLUA_USE_LINUX" LIBS="$LDFLAGS -lm -Wl,-E -ldl -lreadline -lhistory -lncurses -llua" $MAKEOPTS
	make install INSTALL_TOP="$PREFIX"
	#install lua5.1.pc
	curl -C - -OL "http://sajty.elementfx.com/lua5.1.pc"
	export PREFIX_ESCAPED=$(echo $PREFIX | sed -e 's/\(\/\|\\\|&\)/\\&/g')
	sed -i "s/TPL_PREFIX/$PREFIX_ESCAPED/g" ./lua5.1.pc 
	mv ./lua5.1.pc $PREFIX/lib/pkgconfig/lua5.1.pc
	cd ..
	touch $PKGLOCKFILE
fi

#install openal-soft
PKGLOCKFILE="$LOCKDIR/openal-soft_installed.lock"
if [ ! -f $PKGLOCKFILE ]; then
	download "http://kcat.strangesoft.net/openal-releases/openal-soft-1.13.tar.bz2" "openal-soft-1.13.tar.bz2"
	extract $DLDIR/openal-soft-1.13.tar.bz2
	cd openal-soft-1.13
	cd build
	cmake -DCMAKE_INSTALL_PREFIX=$PREFIX ..
	make $MAKEOPTS
	make install
	cd ../..
	touch $PKGLOCKFILE
fi

#install freealut
FILENAME="freealut-1.1.0.tar.gz"
installpackage "http://connect.creativelabs.com/openal/Downloads/ALUT/$FILENAME" "$FILENAME"

#install Ogre3D
PKGLOCKFILE="$LOCKDIR/Ogre_installed.lock"
if [ ! -f $PKGLOCKFILE ]; then
	download "http://sourceforge.net/projects/ogre/files/ogre/1.7/ogre_src_v1-7-3.tar.bz2/download" "ogre_src_v1-7-3.tar.bz2"
	extract $DLDIR/ogre_src_v1-7-3.tar.bz2
	cd ogre_src_v1-7-3
	mkdir -p build
	cd build
	cmake -DCMAKE_INSTALL_PREFIX=$PREFIX \
	-DOGRE_INSTALL_DEPENDENCIES=false -DOGRE_BUILD_SAMPLES=false -DOGRE_BUILD_PLUGIN_BSP=false \
	-DOGRE_BUILD_PLUGIN_OCTREE=false -DOGRE_BUILD_PLUGIN_PCZ=false -DOGRE_BUILD_RENDERSYSTEM_D3D9=false \
	-DOGRE_BUILD_COMPONENT_RTSHADERSYSTEM=false -DOGRE_FULL_RPATH=true -DCMAKE_SKIP_BUILD_RPATH=false \
	-DCMAKE_BUILD_WITH_INSTALL_RPATH=false -DCMAKE_BUILD_TYPE="Release" -DCMAKE_INSTALL_RPATH="../lib" ..
	make all $MAKEOPTS
	make install
	cd ../..
	touch $PKGLOCKFILE
fi

#install tolua++
#hacks:
#	tolua uses scons, which needs python, which is big.
PKGLOCKFILE="$LOCKDIR/tolua++_installed.lock"
if [ ! -f $PKGLOCKFILE ]; then
	LUA_CFLAGS="`pkg-config --cflags lua5.1`"
	LUA_LDFLAGS="`pkg-config --libs lua5.1`"
	download "http://www.codenix.com/~tolua/tolua++-1.0.93.tar.bz2" "tolua++-1.0.93.tar.bz2"
	extract $DLDIR/tolua++-1.0.93.tar.bz2
	cd tolua++-1.0.93
	cp include/tolua++.h $PREFIX/include/tolua++.h
	cd src/lib
	gcc $CFLAGS -c -fPIC -I$PREFIX/include *.c $LUA_CFLAGS $CFLAGS -fPIC
	mkdir -p $PREFIX/lib
        gcc  -shared -Wl,-soname,libtolua++.so -o libtolua++.so  *.o $LUA_LDFLAGS -lm $LDFLAGS
        cp libtolua++.so $PREFIX/lib/libtolua++.so
        cd ../bin
	echo $LDFLAGS
        gcc -o tolua++ -I$PREFIX/include -L$PREFIX/lib tolua.c toluabind.c -ltolua++ $LUA_CFLAGS $LUA_LDFLAGS -ldl $CFLAGS $LDFLAGS
        mkdir -p $PREFIX/bin
	cp tolua++ $PREFIX/bin/tolua++
	cd ../../..
	touch $PKGLOCKFILE
fi

#install CEGUI
PKGLOCKFILE="$LOCKDIR/CEGUI_installed.lock"
if [ ! -f $PKGLOCKFILE ]; then
	download  "http://sourceforge.net/projects/crayzedsgui/files/CEGUI%20Mk-2/0.7.5/CEGUI-0.7.5.tar.gz/download" "CEGUI-0.7.5.tar.gz"
	extract $DLDIR/CEGUI-0.7.5.tar.gz
	cd CEGUI-0.7.5
	./configure --prefix=$PREFIX --disable-samples --disable-opengl-renderer --disable-irrlicht-renderer --disable-xerces-c \
	--disable-libxml --disable-expat --disable-python-module --disable-directfb-renderer \
	--disable-corona --disable-devil --disable-stb --disable-tga \
	--enable-freeimage --enable-ogre-renderer --enable-lua-module --enable-external-toluapp \
	FreeImage_CFLAGS="-DUSE_FREEIMAGE_LIBRARY -I$PREFIX/include" FreeImage_LIBS="-lFreeImage" \
	toluapp_CFLAGS="-I$PREFIX/include" toluapp_LIBS="-ltolua++" \
	$CONFIGURE_EXTRA_FLAGS
	make $MAKEOPTS
	make install
	sed -i -e "s/-lCEGUIBase/-lCEGUIBase -lCEGUIFalagardWRBase -lCEGUIFreeImageImageCodec -lCEGUITinyXMLParser/g" $PREFIX/lib/pkgconfig/CEGUI.pc
	cd ..
	touch $PKGLOCKFILE
fi

#install SDL
#FILENAME="SDL-1.2.14.tar.gz"
#installpackage "http://www.libsdl.org/release/$FILENAME" "$FILENAME"
