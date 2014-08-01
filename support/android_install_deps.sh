#!/bin/bash

set -e

if [[ x"$HAMMERDIR" = x"" ]] ; then
  echo "This script should be called through hammer.sh or with a configured environment with setup_env.sh"
fi

function updateAutotoolsToolchainDetection() {
  # If a source tarball was bootstrapped with older autotools,
  # it may show an error that the toolchain is broken/unsupported.
  # This function will update config.guess and config.sub
  # to support latest cross-compiler toolchains and architectures.
  # @param $1: path to search for outdated files.
  
  CONFIG_VER="config"
  CONFIG_SOURCEDIR=$DEPS_SOURCE/$CONFIG_VER
  CONFIG_INSTALLDIR=$1
  PWD_SAVE="$PWD"
  cd $DEPS_SOURCE
  if [ ! -d $CONFIG_SOURCEDIR ]; then
    git clone git://git.sv.gnu.org/config.git
    cd $CONFIG_SOURCEDIR
    git reset --hard 5049811e672
  fi
  cd $CONFIG_SOURCEDIR
  find $CONFIG_INSTALLDIR -type f -iname 'config.guess' -exec cp -T -f ./config.guess {} \;
  find $CONFIG_INSTALLDIR -type f -iname 'config.sub' -exec cp -T -f ./config.sub {} \;
  cd $PWD_SAVE
}

function getAndroidCMakeToolchain()
{
  ANDCMAKE_VER="android-cmake"
  ANDCMAKE_SOURCEDIR=$DEPS_SOURCE/$ANDCMAKE_VER
  ANDCMAKE_INSTALLDIR=$ANDCMAKE_SOURCEDIR/android.toolchain.cmake
  
  cd $DEPS_SOURCE
  if [ ! -d $ANDCMAKE_SOURCEDIR ]; then
    git clone https://github.com/taka-no-me/android-cmake.git
    cd $ANDCMAKE_SOURCEDIR
    git reset --hard 763b9f6ec43
  fi
  return $ANDCMAKE_INSTALLDIR;
}

function install_deps_toolchain()
{
  cd $DEPS_SOURCE

  # Android SDK
  if [ ! -d $ANDROID_SDK ]; then
    wget -c http://dl.google.com/android/android-sdk_r23.0.2-linux.tgz
    tar -xzf android-sdk_r23.0.2-linux.tgz
    
    # The user needs to accept a license, so we inject "y" as input. I'm not sure, whether this is legal.
    echo y | $ANDROID_SDK/tools/android update sdk -u -a --filter tools
    echo y | $ANDROID_SDK/tools/android update sdk -u -a --filter platform-tools
    echo y | $ANDROID_SDK/tools/android update sdk -u -a --filter build-tools-20.0.0
    echo y | $ANDROID_SDK/tools/android update sdk -u -a --filter android-15
    echo y | $ANDROID_SDK/tools/android update sdk -u -a --filter extra-android-support
  fi
  
  
  # Android NDK
  if [ ! -d $ANDROID_NDK ]; then
      wget -c http://dl.google.com/android/ndk/android-ndk32-r10-linux-$HOST_ARCH.tar.bz2
      tar -xjf android-ndk32-r10-linux-$HOST_ARCH.tar.bz2
      mv android-ndk-r10 android-ndk-r10-$HOST_ARCH
  fi
  if [ x"$TARGET_ARCH" = x"x86" ]; then
    TCNAME=x86
  else
    TCNAME=arm-linux-androideabi
  fi
  # Standalone posix toolchain
  $ANDROID_NDK/build/tools/make-standalone-toolchain.sh --ndk-dir=$ANDROID_NDK --platform=android-15 \
  --toolchain=$TCNAME-4.8 --system=linux-$HOST_ARCH --stl=gnustl --install-dir=$TOOLCHAIN
  
  # Create libpthread.a and libz.a dummy, because many libraries are hardcoding -lpthread or -lz, but on Android pthread works out of box.
  touch dummy.c
  $TOOLCHAIN/bin/$CROSS_COMPILER-gcc -o dummy.o -c dummy.c
  $TOOLCHAIN/bin/$CROSS_COMPILER-ar cru $SYSROOT/usr/lib/libpthread.a dummy.o
  $TOOLCHAIN/bin/$CROSS_COMPILER-ranlib $SYSROOT/usr/lib/libpthread.a
  $TOOLCHAIN/bin/$CROSS_COMPILER-ar cru $SYSROOT/usr/lib/libz.a dummy.o
  $TOOLCHAIN/bin/$CROSS_COMPILER-ranlib $SYSROOT/usr/lib/libz.a
  rm dummy.c
  rm dummy.o
  
  # Some dependencies use -lzlib to link zlib.
  cd $SYSROOT/usr/lib
  ln -s -f libz.a libzlib.a
  
  #Remove the headers for GLESv1 so that SDL will use GLESv2 only.
  rm -r $SYSROOT/usr/include/GLES
}


function install_deps_boost()
{
  #This function will build bjam with host compiler
  BOOST_VER="boost-1_56_0_b1"
  #BOOST_DIR=boost-$BOOST_VER
  #BOOST_BUILDDIR=$DEPS_BUILD/$BOOST_DIR/$BUILDDIR
  #BOOST_ANDROID_SOURCEDIR=$DEPS_SOURCE/Boost-for-Android
  BOOST_SOURCEDIR="$DEPS_SOURCE/$BOOST_VER"
  BOOST_BUILDDIR="$DEPS_BUILD/$BOOST_VER/$BUILDDIR"
  if [ ! -d $BOOST_SOURCEDIR ]; then
    cd $DEPS_SOURCE

    wget -c http://downloads.sourceforge.net/sourceforge/boost/$BOOST_VER.tar.bz2
    tar -xjf $BOOST_VER.tar.bz2
  fi
  
  mkdir -p $BOOST_BUILDDIR
  
  # pop cross-compiler and push native compiler environment
  eval `$SUPPORTDIR/setup_env.sh pop_env`
  export TARGET_OS="native" && eval `$SUPPORTDIR/setup_env.sh push_env`
  
    #build bjam
    cd $BOOST_SOURCEDIR
    ./bootstrap.sh
  
  # pop native compiler and push back cross-compiler environment
  eval `$SUPPORTDIR/setup_env.sh pop_env`
  export TARGET_OS="android" && eval `$SUPPORTDIR/setup_env.sh push_env`

  mkdir -p $HOSTTOOLS/bin
  cp -f --dereference $BOOST_SOURCEDIR/bjam $HOSTTOOLS/bin/bjam
  
  #build boost
  cd $BOOST_SOURCEDIR
  cxxflags=""
  for flag in $CXXFLAGS; do cxxflags="$cxxflags cxxflags=$flag"; done
  $HOSTTOOLS/bin/bjam -q -a target-os=android $cxxflags runtime-link=static link=static threading=multi --layout=system \
         --with-thread --with-date_time --with-chrono --with-system --with-atomic \
         --prefix=$PREFIX --build-dir=$BOOST_BUILDDIR --stage-dir=$BOOST_BUILDDIR/stage install
  
}
function install_deps_ceguideps()
{
  CEGUIDEPS_VER=cegui-dependencies
  CEGUIDEPS_BUILDDIR=$DEPS_BUILD/$CEGUIDEPS_VER/$BUILDDIR/guest
  CEGUIDEPS_SOURCEDIR=$DEPS_SOURCE/$CEGUIDEPS_VER
  
  if [ ! -d $CEGUIDEPS_SOURCEDIR ]; then
    cd $DEPS_SOURCE
    hg clone https://bitbucket.org/cegui/cegui-dependencies -r 721921d
    cd $CEGUIDEPS_SOURCEDIR
    patch -N -p1 -r - < $SUPPORTDIR/android_fix-ceguideps.patch
  fi
  
  #-static will break the build
  LDFLAGS_SAVE="$LDFLAGS"
  #export LDFLAGS=$(echo $LDFLAGS | sed "s/ -static / /g")
  
  mkdir -p $CEGUIDEPS_BUILDDIR
  cd $CEGUIDEPS_BUILDDIR
  cmake $CMAKE_CROSS_COMPILE $CMAKE_FLAGS -DCEGUI_BUILD_FREEIMAGE=false -DCEGUI_BUILD_FREETYPE2=false \
    -DCEGUI_BUILD_GLEW=false -DCEGUI_BUILD_GLFW=false -DCEGUI_BUILD_GLM=false -DCEGUI_BUILD_SILLY=false \
    -DCEGUI_BUILD_TOLUAPP=true -DCEGUI_BUILD_LUA=true -DCEGUI_BUILD_PCRE=true -DCEGUI_BUILD_EXPAT=false \
    -DCEGUI_BUILD_TINYXML=true -DCMAKE_EXE_LINKER_FLAGS="-static" $CEGUIDEPS_SOURCEDIR

  #It seems that tolua++ and lua are built in parallel, but that will fail. So $MAKE_FLAGS will be ignored
  make
  #make install
  
  #It seems make install is not installing, so we will copy it manually.
  cp -r -f $CEGUIDEPS_BUILDDIR/dependencies/lib/static/* $PREFIX/lib
  cp -r -f $CEGUIDEPS_BUILDDIR/dependencies/include/* $PREFIX/include
  cp -r -f $SUPPORTDIR/lua5.1.pc $PREFIX/lib/pkgconfig
  PREFIX_ESCAPED=$(printf '%s\n' "$PREFIX" | sed 's/[\&/]/\\&/g')
  sed -i -e "s/TPL_PREFIX/$PREFIX_ESCAPED/g" $PREFIX/lib/pkgconfig/lua5.1.pc
  export LDFLAGS="$LDFLAGS_SAVE"
}

function install_deps_sigc++()
{
  SIGCPP_VER="libsigc++-2.2.11"
  SIGCPP_BUILDDIR=$DEPS_BUILD/$SIGCPP_VER/$BUILDDIR
  SIGCPP_SOURCEDIR=$DEPS_SOURCE/$SIGCPP_VER
  
  cd $DEPS_SOURCE
  wget -c http://ftp.gnome.org/pub/GNOME/sources/libsigc++/2.2/$SIGCPP_VER.tar.xz
  tar -xJf $SIGCPP_VER.tar.xz
  updateAutotoolsToolchainDetection $SIGCPP_SOURCEDIR
  mkdir -p $SIGCPP_BUILDDIR
  cd $SIGCPP_BUILDDIR
  $SIGCPP_SOURCEDIR/configure $CONFIGURE_FLAGS
  make $MAKE_FLAGS
  make install
}

function install_deps_sdl()
{
  #SDL_VER="SDL2-2.0.3"
  SDL_VER="SDL"
  SDL_BUILDDIR=$DEPS_BUILD/$SDL_VER/$BUILDDIR
  SDL_SOURCEDIR=$DEPS_SOURCE/$SDL_VER
  
  cd $DEPS_SOURCE
  
  # Android with standalone toolchain will be supported in SDL 2.0.4
  if [ ! -d $SDL_SOURCEDIR ]; then
    hg clone http://hg.libsdl.org/SDL -r ace0e63268f3
    updateAutotoolsToolchainDetection $SDL_SOURCEDIR
  fi
  #echo | cpp -Wp,-v
  #exit 0
  #updateAutotoolsToolchainDetection $SDL_SOURCEDIR
  #echo "CONFIGGGGG: $CONFIGURE_FLAGS"
  #env | grep CPP
  #wget -c http://www.libsdl.org/release/$SDL_VER.tar.gz
  #tar -xzf $SDL_VER.tar.gz
  cd $SDL_SOURCEDIR
  ./autogen.sh
  mkdir -p $SDL_BUILDDIR
  cd $SDL_BUILDDIR
  $SDL_SOURCEDIR/configure $CONFIGURE_FLAGS --disable-haptic --disable-audio
  #exit 0
  make $MAKE_FLAGS
  make install
}
function install_deps_ogredeps()
{
  OGREDEPS_VER="ogredeps"
  OGREDEPS_BUILDDIR=$DEPS_BUILD/$OGREDEPS_VER/$BUILDDIR
  OGREDEPS_SOURCEDIR=$DEPS_SOURCE/$OGREDEPS_VER
  
  cd $DEPS_SOURCE
  
  if [ ! -d $OGREDEPS_SOURCEDIR ]; then
    hg clone https://bitbucket.org/cabalistic/ogredeps -r 27b96a4
    cd $OGREDEPS_SOURCEDIR
    patch -N -p1 -r - < $SUPPORTDIR/android_fix-ogredeps.patch
  fi

  mkdir -p $OGREDEPS_BUILDDIR
  cd $OGREDEPS_BUILDDIR
  
  cmake $CMAKE_CROSS_COMPILE $CMAKE_FLAGS -DOGREDEPS_BUILD_ZLIB=false $OGREDEPS_SOURCEDIR
  make $MAKE_FLAGS
  make install
  
  # Some dependencies link it as zzip instead of zziplib
  cd $PREFIX/lib
  ln -s -f libzziplib.a libzzip.a
}
function install_deps_glsloptimizer()
{
  OGRE_VER="glsl-optimizer"
  OGRE_BUILDDIR=$DEPS_BUILD/$OGRE_VER/$BUILDDIR
  OGRE_SOURCEDIR=$DEPS_SOURCE/$OGRE_VER
  
  cd $DEPS_SOURCE
  
  if [ ! -d $OGRE_SOURCEDIR ]; then
    hg clone https://bitbucket.org/sinbad/ogre -r 77f3a5a
    cd $OGRE_SOURCEDIR
    patch -N -p1 -r - < $SUPPORTDIR/android_fix-ogre.patch
  fi

  mkdir -p $OGRE_BUILDDIR
  cd $OGRE_BUILDDIR
  
  #export LDFLAGS="$LDFLAGS -landroid -llog -lEGL "

  cmake $CMAKE_CROSS_COMPILE $CMAKE_FLAGS  $OGRE_SOURCEDIR
  make $MAKE_FLAGS
  make install
}
function install_deps_ogre()
{
  OGRE_VER="ogre"
  OGRE_BUILDDIR=$DEPS_BUILD/$OGRE_VER/$BUILDDIR
  OGRE_SOURCEDIR=$DEPS_SOURCE/$OGRE_VER
  
  cd $DEPS_SOURCE
  
  if [ ! -d $OGRE_SOURCEDIR ]; then
    hg clone https://bitbucket.org/sinbad/ogre -r 77f3a5a
    cd $OGRE_SOURCEDIR
    patch -N -p1 -r - < $SUPPORTDIR/android_fix-ogre.patch
  fi

  mkdir -p $OGRE_BUILDDIR
  cd $OGRE_BUILDDIR
  
  cp -u ${ANDROID_NDK}/sources/android/cpufeatures/*.c $OGRE_SOURCEDIR/OgreMain/src/Android
  cp -u ${ANDROID_NDK}/sources/android/cpufeatures/*.h $OGRE_SOURCEDIR/OgreMain/include
  
  cmake $CMAKE_CROSS_COMPILE $CMAKE_FLAGS -DEGL_INCLUDE_DIR="" -DOPENGLES2_INCLUDE_DIR="" -DOGRE_LIB_SUFFIX=""\
    -DOGRE_BUILD_SAMPLES=false -DOGRE_STATIC=true -DOGRE_BUILD_TOOLS=false -DOGRE_UNITY_BUILD=true -DZLIB_PREFIX_PATH="$SYSROOT/usr"\
    -DANDROID_ABI=armeabi -DOGRE_DEPENDENCIES_DIR=$PREFIX $OGRE_SOURCEDIR
 
  make $MAKE_FLAGS
  make install
  
  #When static linking, we need to add all OGRE/* include directories to CFLAGS.
  OGREINCDIR=$PREFIX/include/OGRE
  cd $OGREINCDIR
  OGREINC=-I\${includedir}/OGRE/$(ls -1 -d */  | tr "\\n" ":" | sed 's=\(.*\)/:=\1=' | sed "s=/:= -I\${includedir}/OGRE/=g")
  sed -i "s=Cflags:=Cflags: $OGREINC=g" $PREFIX/lib/pkgconfig/OGRE.pc
  
  OGREINCDIR=$PREFIX/include/OGRE/Plugins
  cd $OGREINCDIR
  OGREINC=-I\${includedir}/OGRE/Plugins/$(ls -1 -d */  | tr "\\n" ":" | sed 's=\(.*\)/:=\1=' | sed "s=/:= -I\${includedir}/OGRE/Plugins/=g")
  sed -i "s=Cflags:=Cflags: $OGREINC=g" $PREFIX/lib/pkgconfig/OGRE.pc
  
  OGREINCDIR=$PREFIX/include/OGRE/RenderSystems
  cd $OGREINCDIR
  OGREINC=-I\${includedir}/OGRE/RenderSystems/$(ls -1 -d */  | tr "\\n" ":" | sed 's=\(.*\)/:=\1=' | sed "s=/:= -I\${includedir}/OGRE/RenderSystems/=g")
  sed -i "s=Cflags:=Cflags: $OGREINC=g" $PREFIX/lib/pkgconfig/OGRE.pc
  
  #OGREPLUGINDIR=$PREFIX/lib/OGRE
  #cd $OGREPLUGINDIR
  #OGREPLUGIN=-I\${includedir}/OGRE/RenderSystems/$(ls -1 -d */  | tr "\\n" ":" | sed 's=\(.*\)/:=\1=' | sed "s=/:= -I\${includedir}/OGRE/RenderSystems/=g")
  #sed -i "s=Cflags:=Cflags: $OGREINC=g" $PREFIX/lib/pkgconfig/OGRE.pc
}
function install_deps_libiconv()
{
  LIBICONV_VER="libiconv-1.14"
  LIBICONV_BUILDDIR=$DEPS_BUILD/$LIBICONV_VER/$BUILDDIR
  LIBICONV_SOURCEDIR=$DEPS_SOURCE/$LIBICONV_VER
  
  cd $DEPS_SOURCE
  wget -c http://ftp.gnu.org/pub/gnu/libiconv/$LIBICONV_VER.tar.gz
  tar -xzf $LIBICONV_VER.tar.gz
  updateAutotoolsToolchainDetection $LIBICONV_SOURCEDIR
  
  mkdir -p $LIBICONV_BUILDDIR
  cd $LIBICONV_BUILDDIR 
  $LIBICONV_SOURCEDIR/configure $CONFIGURE_FLAGS
  make $MAKE_FLAGS
  make install
}

function install_deps_cegui()
{
  CEGUI_VER="cegui-0.8.4"
  CEGUI_BUILDDIR=$DEPS_BUILD/$CEGUI_VER/$BUILDDIR
  CEGUI_SOURCEDIR=$DEPS_SOURCE/$CEGUI_VER
  
  cd $DEPS_SOURCE
  
  if [ ! -d $CEGUI_SOURCEDIR ]; then
    #git clone https://github.com/ironsteel/cegui.git -b android-port
    #cd $CEGUI_SOURCEDIR
    #git reset --hard 577edcf46b
    
    wget -c http://downloads.sourceforge.net/sourceforge/crayzedsgui/$CEGUI_VER.tar.bz2
    tar -xjf $CEGUI_VER.tar.bz2
    #patch -N -p1 -r - < $SUPPORTDIR/android_fix-cegui.patch
  fi
  
  mkdir -p $CEGUI_BUILDDIR
  cd $CEGUI_BUILDDIR
  #export LIBS="-Wl,--start-group -lboost_date_time -lboost_system -lboost_thread -lboost_chrono -lzzip -lFreeImage -lfreetype -llua -liconv -Wl,--end-group -lz -landroid -lc -lm -ldl -llog"
  cmake $CMAKE_CROSS_COMPILE $CMAKE_FLAGS $CEGUI_SOURCEDIR -DOGRE_LIB=$PREFIX/lib/libOgreMainStatic.a \
  -DCEGUI_BUILD_XMLPARSER_TINYXML=false -DCEGUI_SAMPLES_ENABLED=false -DCEGUI_BUILD_PYTHON_MODULES=false \
  -DBoost_LIBRARY_DIRS=$PREFIX/lib -DCEGUI_BUILD_STATIC_CONFIGURATION=true -DCEGUI_BUILD_LUA_GENERATOR=false \
  -DOGRE_LIBRARIES="" -DCEGUI_BUILD_STATIC_FACTORY_MODULE=true -DCEGUI_BUILD_SHARED_LIBS_WITH_STATIC_DEPENDENCIES=true
  #cmake-gui .
  make $MAKE_FLAGS
  make install
  
  # Remove installed shared libraries, because the shared build can't be disabled.
  rm $PREFIX/lib/libCEGUI*so*
  rm -r $PREFIX/lib/cegui-0.8
}

function install_deps_openal()
{
  OPENAL_VER="openal-soft"
  OPENAL_BUILDDIR=$DEPS_BUILD/$OPENAL_VER/$BUILDDIR
  OPENAL_SOURCEDIR=$DEPS_SOURCE/$OPENAL_VER
  
  cd $DEPS_SOURCE
  
  if [ ! -d $OPENAL_SOURCEDIR ]; then
    # Android only supports OpenSL.
    # OpenAL-soft is not supporting android, so we need to use a fork.
    git clone https://github.com/apportable/openal-soft.git -b openal-soft-1.15.1-android
    cd $OPENAL_SOURCEDIR
    git reset --hard 4c015951be11d
    patch -N -p1 -r - < $SUPPORTDIR/android_fix-openal.patch
  fi
  
  mkdir -p $OPENAL_BUILDDIR
  cd $OPENAL_BUILDDIR
  cmake $CMAKE_CROSS_COMPILE $CMAKE_FLAGS $OPENAL_SOURCEDIR -DLIBTYPE=STATIC
  make $MAKE_FLAGS
  make install

}

function install_deps_freealut()
{
  FREEALUT_VER="freealut-1.1.0"
  FREEALUT_BUILDDIR=$DEPS_BUILD/$FREEALUT_VER/$BUILDDIR
  FREEALUT_SOURCEDIR=$DEPS_SOURCE/$FREEALUT_VER
  
  cd $DEPS_SOURCE
  # Creative's download page is down, so we need to use fedora mirror.
  wget -c http://pkgs.fedoraproject.org/repo/pkgs/freealut/$FREEALUT_VER.tar.gz/e089b28a0267faabdb6c079ee173664a/freealut-1.1.0.tar.gz
  tar -xzf freealut-1.1.0.tar.gz
  updateAutotoolsToolchainDetection $FREEALUT_SOURCEDIR

  mkdir -p $FREEALUT_BUILDDIR
  cd $FREEALUT_BUILDDIR

  eval `$SUPPORTDIR/setup_env.sh push_cur`
  export LIBS="$LIBS -lopenal -llog"
  
  
  $FREEALUT_SOURCEDIR/configure $CONFIGURE_FLAGS
  make $MAKE_FLAGS
  make install
  
  eval `$SUPPORTDIR/setup_env.sh pop_env`
}

function install_deps_libcurl()
{
  LIBCURL_VER="curl"
  LIBCURL_BUILDDIR=$DEPS_BUILD/$LIBCURL_VER/$BUILDDIR
  LIBCURL_SOURCEDIR=$DEPS_SOURCE/$LIBCURL_VER
  
  cd $DEPS_SOURCE
  if [ ! -d $LIBCURL_SOURCEDIR ]; then
    git clone https://android.googlesource.com/platform/external/curl
  fi
  
  cd $LIBCURL_SOURCEDIR
  ./buildconf
  
  mkdir -p $LIBCURL_BUILDDIR
  cd $LIBCURL_BUILDDIR
  $LIBCURL_SOURCEDIR/configure $CONFIGURE_FLAGS
  make $MAKE_FLAGS
  make install

}

function install_deps_all()
{
  install_deps_toolchain
  install_deps_boost
  install_deps_sigc++
  install_deps_libcurl
  install_deps_libiconv
  install_deps_openal
  install_deps_freealut
  install_deps_sdl
  install_deps_ceguideps
  install_deps_ogredeps
  install_deps_ogre
  install_deps_cegui
}

#TODO: Set up logs, but for now it is easier to debug without logs.
if [ "$1" = "all" ] || [ "$1" = "toolchain" ] || [ "$1" = "sigc++" ] || [ "$1" = "openal" ] || [ "$1" = "freealut" ] || [ "$1" = "libcurl" ] || [ "$1" = "libiconv" ] || 
   [ "$1" = "boost" ] || [ "$1" = "sdl" ] || [ "$1" = "ogredeps" ] || [ "$1" = "ogre" ] || [ "$1" = "ceguideps" ] || [ "$1" = "cegui" ] ; then
  echo Compiling $1
  install_deps_$1
  echo Completed successfully!
else
  printf >&2 'Unknown target: %s\n' "$1"
  exit 1
fi
