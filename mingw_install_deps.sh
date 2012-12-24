#!/bin/bash

set -e

export PREFIX="$PWD/work/local"
export PATH="$PREFIX/bin:$PATH"
export CPATH="$PREFIX/include:$CPATH"
export LIBRARY_PATH="$PREFIX/lib:$LIBRARY_PATH"
export LD_LIBRARY_PATH="$PREFIX/lib:$LD_LIBRARY_PATH"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:/mingw/lib/pkgconfig:/lib/pkgconfig:$PKG_CONFIG_PATH"
export ACLOCAL_ARGS="$ACLOCAL_ARGS -I $PREFIX/share/aclocal"
export CONFIGURE_EXTRA_FLAGS="--enable-shared --disable-static"
if [ "$NUMBER_OF_PROCESSORS" == "" ]; then
	export MAKEOPTS="-j3"
else
	export MAKEOPTS="-j$NUMBER_OF_PROCESSORS"
fi

#ogre gets linking error with freeimage if we don't disable flags.
if [ "$CFLAGS" != "" ] ; then
	echo "WARNING: Unsetting your CFLAGS environment variable for some libs."
	CFLAGS_SAVE="$CFLAGS"
	unset CFLAGS
fi
if [ "$CXXFLAGS" != "" ] ; then
	echo "WARNING: Unsetting your CXXFLAGS environment variable for some libs."
	CXXFLAGS_SAVE="$CXXFLAGS"
	unset CXXFLAGS
fi
if [ "$LDFLAGS" != "" ] ; then
	echo "WARNING: Unsetting your LDFLAGS environment variable for some libs."
	LDFLAGS_SAVE="$LDFLAGS"
	unset LDFLAGS
fi

LOGDIR=$PWD/work/logs/deps
BUILDDEPS=$PWD/work/build/deps
PACKAGEDIR=$BUILDDEPS/packages
DLDIR=$BUILDDEPS/downloads
LOCKDIR=$BUILDDEPS/locks
SUPPORTDIR=$PWD/support

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
	if [[ $1 == *.tar* ]]; then
		7za x -y -so $1 | 7za x -y -si -ttar > /dev/null
	else
		7za x -y $1 > /dev/null
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
		wget -q -c -P $DLDIR $1
		printc "    Extracting..."
		extract $DLDIR/$2 2> $PKGLOGDIR/extract.log
		mkdir -p $PKGNAME/mingw_build
		cd $PKGNAME
		if [ ! -f "configure" ] ; then
			printc "    Running autogen..."
			NOCONFIGURE=1 ./autogen.sh > $PKGLOGDIR/autogen.log
		fi
		cd mingw_build
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

#install 7za
#hacks:
#	this is needed, because tar and bsdtar makes segfaults sometimes.
PKGLOCKFILE="$LOCKDIR/7za_installed.lock"
if [ ! -f $PKGLOCKFILE ]; then
	printc "Installing 7za..."
	mkdir -p 7za
	cd 7za
	wget -q -c -P $DLDIR http://downloads.sourceforge.net/sevenzip/7za920.zip
	bsdtar -xf $DLDIR/7za920.zip
	cp ./7za.exe $PREFIX/bin/7za.exe
	cd ..
	touch $PKGLOCKFILE
fi

#install rsync
#maybe we should host this file
#wget -c -P $DLDIR http://download1039.mediafire.com/p2h9ja9uzvtg/g35fh308hmdklz5/rsync-3.0.8.tar.lzma
#wget -c -P $DLDIR http://k002.kiwi6.com/hotlink/w8nv7zl9qh/rsync_3_0_8_tar.lzma
PKGLOCKFILE="$LOCKDIR/rsync_installed.lock"
if [ ! -f $PKGLOCKFILE ]; then
	printc "Installing rsync..."
	mkdir -p rsync
	cd rsync
	wget -q -c -P $DLDIR http://sajty.elementfx.com/rsync-3.0.8.tar.lzma
	extract $DLDIR/rsync-3.0.8.tar.lzma 2> /dev/null
	cp rsync.exe $PREFIX/bin/rsync.exe
	cd ..
	touch $PKGLOCKFILE
fi

#install glib
FILENAME="glib-2.28.7.tar.bz2"
installpackage "http://ftp.gnome.org/pub/gnome/sources/glib/2.28/$FILENAME" "$FILENAME"

#install pkg-config:
export GLIB_CFLAGS="-I$PREFIX/include/glib-2.0 -I$PREFIX/lib/glib-2.0/include -mms-bitfields"
export GLIB_LIBS="-L$PREFIX/lib/ -lglib-2.0 -lintl " 
FILENAME="pkg-config-0.26.tar.gz"
installpackage "http://pkgconfig.freedesktop.org/releases/$FILENAME" "$FILENAME"

#install freeimage
#hacks:
#	you need to force mingw makefile, or it will use gnu makefile.
#	Do not set *FLAGS or it will fail.
#	FREEIMAGE_LIBRARY_TYPE needs to be static or it will make .lib instead of .a file.
#	DLLTOOLFLAGS needs to be "" or ogre will get linker errors.
#	it will try to install .lib, so we need to install it manually
#	it needs python to build documentation. You can't disable documentation.
PKGNAME="FreeImage"
PKGLOGDIR="$LOGDIR/$PKGNAME"
PKGLOCKFILE="$LOCKDIR/${PKGNAME}_installed.lock"
if [ ! -f $PKGLOCKFILE ]; then
	printc "Installing $PKGNAME..."
	mkdir -p $PKGLOGDIR
	printc "    Downloading..."
	wget -q -c -P $DLDIR http://downloads.sourceforge.net/freeimage/FreeImage3150.zip
	printc "    Extracting..."
	extract $DLDIR/FreeImage3150.zip 2> $PKGLOGDIR/extract.log
	cd $PKGNAME
	printc "    Building..."
	make -f Makefile.minGW FREEIMAGE_LIBRARY_TYPE=STATIC DLLTOOLFLAGS="" > $PKGLOGDIR/build.log
	printc "    Installing..."
	cp Dist/FreeImage.a $PREFIX/lib/libFreeImage.a
	cp Dist/FreeImage.h $PREFIX/include/FreeImage.h
	cd ..
	touch $PKGLOCKFILE
fi

#install cmake
#hacks:
#	if you set the *FLAGS environment variables, it may fail on a test.
#	make install copies to the wrong location
PKGNAME="cmake-2.8.10"
PKGLOGDIR="$LOGDIR/$PKGNAME"
PKGLOCKFILE="$LOCKDIR/${PKGNAME}_installed.lock"
if [ ! -f $PKGLOCKFILE ]; then
	printc "Installing $PKGNAME..."
	mkdir -p $PKGLOGDIR
	printc "    Downloading..."
	wget -q -c -P $DLDIR http://www.cmake.org/files/v2.8/$PKGNAME.tar.gz
	printc "    Extracting..."
	extract $DLDIR/$PKGNAME.tar.gz 2> $PKGLOGDIR/extract.log
	mkdir -p $PKGNAME/mingw_build
	cd $PKGNAME/mingw_build
	printc "    Running configure..."
	../configure --prefix=$PREFIX > $PKGLOGDIR/configure.log
	printc "    Building..."
	make $MAKEOPTS > $PKGLOGDIR/build.log
	printc "    Installing..."
	cp bin/cmake.exe $PREFIX/bin/cmake.exe
	make install > $PKGLOGDIR/install.log
	cd ../..
	touch $PKGLOCKFILE
fi

export CFLAGS="-O2 -msse2 -mthreads -DNDEBUG -I$PREFIX/include $CFLAGS_SAVE"
export CXXFLAGS="-O2 -msse2 -mthreads -DNDEBUG -DBOOST_THREAD_USE_LIB -I$PREFIX/include $CXXFLAGS_SAVE"
export LDFLAGS="-L$PREFIX/lib $LDFLAGS_SAVE"

#install zziplib
FILENAME="zziplib-0.13.62.tar.bz2"
installpackage "http://sourceforge.net/projects/zziplib/files/zziplib13/0.13.62/$FILENAME/download" "$FILENAME"

#install freetype
FILENAME="freetype-2.4.4.tar.bz2"
installpackage "http://sourceforge.net/projects/freetype/files/freetype2/2.4.4/$FILENAME/download" "$FILENAME"

#install SDL
FILENAME="SDL-1.2.14.tar.gz"
installpackage "http://www.libsdl.org/release/$FILENAME" "$FILENAME"

#install libCURL
FILENAME="curl-7.21.6.tar.bz2"
installpackage "http://curl.haxx.se/download/$FILENAME" "$FILENAME"

#install pcre
FILENAME="pcre-8.12.tar.bz2"
#--enable-unicode-properties is needed for ember.
CONFIGURE_EXTRA_FLAGS_SAVE="$CONFIGURE_EXTRA_FLAGS"
export CONFIGURE_EXTRA_FLAGS="$CONFIGURE_EXTRA_FLAGS --enable-unicode-properties"
installpackage "http://sourceforge.net/projects/pcre/files/pcre/8.12/$FILENAME/download" "$FILENAME"
CONFIGURE_EXTRA_FLAGS="$CONFIGURE_EXTRA_FLAGS_SAVE"


#install sigc++
#hacks:
#	7za is not supporting PAX, need to use bsdtar
PKGNAME="libsigc++-2.2.9"
PKGLOGDIR="$LOGDIR/$PKGNAME"
PKGLOCKFILE="$LOCKDIR/${PKGNAME}_installed.lock"
if [ ! -f $PKGLOCKFILE ]; then
	printc "Installing $PKGNAME..."
	mkdir -p $PKGLOGDIR
	printc "    Downloading..."
	wget -q -c -P $DLDIR http://ftp.gnome.org/pub/GNOME/sources/libsigc++/2.2/$PKGNAME.tar.gz
	printc "    Extracting..."
	bsdtar -xf  $DLDIR/$PKGNAME.tar.gz
	mkdir -p $PKGNAME/mingw_build
	cd $PKGNAME/mingw_build
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
	wget -c -P $DLDIR http://sourceforge.net/projects/boost/files/boost/1.49.0/boost_1_49_0.tar.bz2/download
	extract $DLDIR/boost_1_49_0.tar.bz2
	cd boost_1_49_0
	./bootstrap.sh --with-toolset=mingw
	#solution found here: http://stackoverflow.com/questions/5012429/building-boost-under-msys-cant-find-mingw-jam
	sed -i "s/mingw/gcc/g" project-config.jam;
	./bjam --with-thread --with-date_time --with-chrono --prefix=$PREFIX --layout=system variant=release link=static toolset=gcc install

	cd ..
	touch $PKGLOCKFILE
fi

#install lua
PKGLOCKFILE="$LOCKDIR/lua_installed.lock"
if [ ! -f $PKGLOCKFILE ]; then
	wget -c -P $DLDIR http://www.lua.org/ftp/lua-5.1.4.tar.gz
	extract $DLDIR/lua-5.1.4.tar.gz
	cd lua-5.1.4
	make mingw $MAKEOPTS
	make install INSTALL_TOP=$PREFIX
	#install lua5.1.pc
	cp $SUPPORTDIR/lua5.1.pc ./lua5.1.pc
	export PREFIX_ESCAPED=$(echo $PREFIX | sed -e 's/\(\/\|\\\|&\)/\\&/g')
	sed -i "s/TPL_PREFIX/$PREFIX_ESCAPED/g" ./lua5.1.pc 
	mv ./lua5.1.pc $PREFIX/lib/pkgconfig/lua5.1.pc
	cd ..
	touch $PKGLOCKFILE
fi

#install tolua++
#hacks:
#	tolua uses scons, which needs python, which is big.
PKGLOCKFILE="$LOCKDIR/tolua++_installed.lock"
if [ ! -f $PKGLOCKFILE ]; then
	wget -c -P $DLDIR http://www.codenix.com/~tolua/tolua++-1.0.93.tar.bz2
	extract $DLDIR/tolua++-1.0.93.tar.bz2
	cd tolua++-1.0.93
	cp include/tolua++.h $PREFIX/include/tolua++.h
	cd src/lib
	gcc $CFLAGS -c -I$PREFIX/include -L$PREFIX/lib *.c
	ar cq libtolua++.a *.o
	cp libtolua++.a $PREFIX/lib/libtolua++.a
	cd ../bin
	gcc $CFLAGS $LDFLAGS -o tolua++ -I$PREFIX/include -L$PREFIX/lib -mwindows tolua.c toluabind.c -ltolua++ -llua
	cp tolua++.exe $PREFIX/bin/tolua++.exe
	cd ../../..
	touch $PKGLOCKFILE
fi

#install openal-soft
PKGLOCKFILE="$LOCKDIR/openal-soft_installed.lock"
if [ ! -f $PKGLOCKFILE ]; then
	wget -c -P $DLDIR http://kcat.strangesoft.net/openal-releases/openal-soft-1.13.tar.bz2
	extract $DLDIR/openal-soft-1.13.tar.bz2
	cd openal-soft-1.13
	cd build
	cmake -DCMAKE_INSTALL_PREFIX=$PREFIX -G"MSYS Makefiles" ..
	make all $MAKEOPTS
	make install
	cd ../..
	touch $PKGLOCKFILE
fi

#install freealut
FILENAME="freealut-1.1.0-src.zip"
installpackage "http://connect.creativelabs.com/openal/Downloads/ALUT/$FILENAME" "$FILENAME"

#install Cg
PKGLOCKFILE="$LOCKDIR/Cg_installed.lock"
if [ ! -f $PKGLOCKFILE ]; then
	cp -r "$CG_INC_PATH" $PREFIX
	cp "$CG_BIN_PATH/cg.dll" $PREFIX/bin/cg.dll
	pexports $PREFIX/bin/cg.dll | sed "s/^_//" > libCg.def
	dlltool --add-underscore -d libCg.def -l $PREFIX/lib/libCg.a
	rm libCg.def
	touch $PKGLOCKFILE
fi

#install Ogre3D
#hacks:
#	its not creating ogre.pc, we need to create them manually.
PKGLOCKFILE="$LOCKDIR/Ogre_installed.lock"
if [ ! -f $PKGLOCKFILE ]; then
	wget -c -P $DLDIR http://sourceforge.net/projects/ogre/files/ogre/1.8/1.8.1/ogre_src_v1-8-1.tar.bz2/download
	extract $DLDIR/ogre_src_v1-8-1.tar.bz2
	cd ogre_src_v1-8-1
	mkdir -p build
	cd build
	cmake -DCMAKE_INSTALL_PREFIX=$PREFIX -G"MSYS Makefiles" \
	-DOGRE_INSTALL_DEPENDENCIES=false -DOGRE_BUILD_SAMPLES=false -DOGRE_BUILD_PLUGIN_BSP=false \
	-DOGRE_BUILD_PLUGIN_OCTREE=false -DOGRE_BUILD_PLUGIN_PCZ=false -DOGRE_BUILD_RENDERSYSTEM_D3D9=false \
	-DOGRE_BUILD_COMPONENT_RTSHADERSYSTEM=false ..
	make all $MAKEOPTS
	make install
	#copy to get it available without configuration name.
	cp -r $PREFIX/bin/RelWithDebInfo/* $PREFIX/bin
	cp -r $PREFIX/lib/RelWithDebInfo/* $PREFIX/lib

	#get *.pc files.
	cp $SUPPORTDIR/OGRE*.pc .
	export PREFIX_ESCAPED=$(echo $PREFIX | sed -e 's/\(\/\|\\\|&\)/\\&/g')
	find . -maxdepth 1 -name "OGRE*.pc" -exec sed -i "s/TPL_PREFIX/$PREFIX_ESCAPED/g" '{}' \;
	mv ./OGRE*.pc $PREFIX/lib/pkgconfig
	cd ../..
	touch $PKGLOCKFILE
fi

#install CEGUI
PKGLOCKFILE="$LOCKDIR/CEGUI_installed.lock"
if [ ! -f $PKGLOCKFILE ]; then
	wget -c -P $DLDIR http://sourceforge.net/projects/crayzedsgui/files/CEGUI%20Mk-2/0.7.7/CEGUI-0.7.7.tar.gz/download
	extract $DLDIR/CEGUI-0.7.7.tar.gz
	cd CEGUI-0.7.7
	./configure --prefix=$PREFIX --disable-samples --disable-opengl-renderer --disable-irrlicht-renderer --disable-xerces-c \
	--disable-libxml --disable-expat --disable-directfb-renderer \
	--enable-freeimage --enable-ogre-renderer --enable-lua-module --enable-external-toluapp \
	FreeImage_CFLAGS="-DUSE_FREEIMAGE_LIBRARY -I$PREFIX/include" FreeImage_LIBS="-lFreeImage" \
	toluapp_CFLAGS="-I$PREFIX/include" toluapp_LIBS="-ltolua++" \
	MINGW32_BUILD=true CEGUI_BUILD_LUA_MODULE_UNSAFE=true CEGUI_BUILD_TOLUAPPLIB=true \
	$CONFIGURE_EXTRA_FLAGS
	make $MAKEOPTS
	make install
	cd ..
	touch $PKGLOCKFILE
fi
