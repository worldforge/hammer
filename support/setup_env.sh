#!/bin/bash

set -e

# Input environment variables for this script.
export INPUT_VARIABLES="DEBUG_BUILD MAKE_FLAGS CONFIGURE_FLAGS CMAKE_FLAGS COMPILE_FLAGS LINK_FLAGS FORCE_AUTOGEN FORCE_CONFIGURE TARGET_ARCH TARGET_OS HOST_ARCH HOST_OS HAMMERDIR WORKDIR SUPPORTDIR"

# Output environment variables for thi script.
export OUTPUT_VARIABLES="SOURCE BUILD BUILDDIR WORKDIR PREFIX DEPS_SOURCE DEPS_BUILD LOGDIR PKG_CONFIG_PATH PATH CPATH LIBRARY_PATH LD_LIBRARY_PATH CMAKE_FLAGS MAKE_FLAGS"
export OUTPUT_VARIABLES="$OUTPUT_VARIABLES CFLAGS CXXFLAGS CPPFLAGS LDFLAGS CONFIGURE_FLAGS CMAKE_PREFIX_PATH TOOLCHAIN HOSTTOOLS ACLOCAL_ARGS DEBUG_STR CMAKE_BUILD_DEBUG"
export OUTPUT_VARIABLES="$OUTPUT_VARIABLES ANDROID_SDK ANDROID_NDK NDK_TOOLCHAIN_VERSION ANDROID_STANDALONE_TOOLCHAIN CROSS_COMPILER SYSROOT CONFIGURE_CROSS_COMPILE CMAKE_CROSS_COMPILE PKG_CONFIG_LIBDIR CC CXX CPP"

function show_help()
{
    echo "Usage: eval \`setup_env.sh <command>\`"
    echo "Commands:"
    echo "  get_env  - Returns the current output variables as a script. Ignores input variables."
    echo "  set_env  - Sets an environment based on input variables. Can't be undone."
    echo "  unset_env- Unsets all output variables. Even the user's CFLAGS setting, etc."
    echo "  push_env - Pushes an environment based on input variables. Can be undone with pop_env."
    echo "  push_cur - Pushes the current environment to the stack. Can be undone with pop_env."
    echo "  pop_env  - Removes the last pushed environment and sets the environment back to parent."
}

function escapeString()
{
  # Escapes string in a form, which is acceptable by eval and sed.
  printf "%q" "$1" | sed -e 's/^[\\ ]*//' -e 's/[\\ ]*$//'
}

if [[ "$1" = "get_env" ]] ; then
  for envvar in PREV_ENV $OUTPUT_VARIABLES
  do
    id="${envvar}"
    val="${!envvar}"
    if [ -n "${!envvar+x}" ] ; then
      echo "export $id=$(escapeString "$val")"
    else
      echo "unset $id"
    fi
  done
  exit 0
elif [[ $1 = "pop_env" ]] ; then
  # embed eval into eval. :)
  echo 'eval "$PREV_ENV"'
  exit 0
elif [[ $1 = "push_env" ]] || [[ $1 = "push_cur" ]] ; then
  val="`$0 get_env`"
  echo "export PREV_ENV=$(escapeString "$val")"
  if [[ $1 = "push_cur" ]] ; then
    exit 0
  fi
elif [[ $1 = "unset_env" ]] ; then
  echo unset -v $OUTPUT_VARIABLES PREV_ENV
  exit 0
elif [[ $1 != "set_env" ]] ; then
  show_help
  exit 1
fi

# ++++++++++++++++++++++++++++++
# + push_env and set_env only! +
# + Other commands have exited +
# ++++++++++++++++++++++++++++++


function pexport()
{
  set -e
  # Same as export, but the command will be escaped and printed too.
  local id="${@%%=*}"
  local val="${@#*=}"
  # Debug check failed!
  local isOutput=0
  for envvar in $OUTPUT_VARIABLES
  do
    if [ x"$envvar" = x"$id" ] ; then
      isOutput=1
    fi
  done
  if [ x"$isOutput" = x"0" ] ; then
    # Debug check failed!
    echo "echo \"$id is not an output variable!\""
    exit 1
  fi
  OUT="export $id=`escapeString \"$val\"`"
  # Print it.
  echo $OUT
  # Run it.
  eval $OUT
}

for envvar in $INPUT_VARIABLES
do
  if [ -z "${!envvar+x}" ] ; then
    echo "Environment variable '$envvar' is not set, but required by the script!"
    exit 1
  fi
  # Print input state. The output is always equal for the same input. Deterministic system.
  #echo "INPUT $envvar=${!envvar}"
done

# ++++++++++++++++++++++++++++++++++
# + Environment setup starts here! +
# ++++++++++++++++++++++++++++++++++

# Worldforge source and build dir are equal in all builds. They are separated by BUILDDIR only.
pexport SOURCE=$WORKDIR/source/worldforge
pexport BUILD=$WORKDIR/build/worldforge
pexport PREFIX=$WORKDIR/local

if [ "$TARGET_OS" != "native" ] ; then
  if [ "$DEBUG_BUILD" = "1" ] ; then
    pexport DEBUG_STR="debug"
  else
    pexport DEBUG_STR="release"
  fi
  # Required for worldforge sources. Each platform builds different dependencies and different patches.
  pexport BUILDDIR="${TARGET_OS}-${TARGET_ARCH}-${DEBUG_STR}"
  
  # The rest of the paths will go into work/android/*.
  # TODO: We could merge the source directories for all android builds, except ndk, boost, toolchain.
  pexport WORKDIR="$WORKDIR/$BUILDDIR"
  
  # Ignore user specified compiler and linker flags, if cross-compiling.
  pexport CFLAGS=" "
  pexport CXXFLAGS=" "
  pexport CPPFLAGS=" "
  pexport LDFLAGS=" "
else
  pexport BUILDDIR="native-`getconf LONG_BIT`"
  # Needed to find tolua++ program if installed in prefix.
  pexport PATH="$PATH:$PREFIX/bin"
fi

pexport DEPS_SOURCE=$WORKDIR/source
pexport DEPS_BUILD=$WORKDIR/build
pexport LOGDIR=$WORKDIR/logs
pexport PKG_CONFIG_PATH="$PREFIX/lib64/pkgconfig:$PREFIX/lib/pkgconfig:/usr/local/lib/pkgconfig:/mingw/lib/pkgconfig:/lib/pkgconfig:$PKG_CONFIG_PATH"
pexport ACLOCAL_ARGS="$ACLOCAL_ARGS -I $PREFIX/share/aclocal"
# fixes libtool: link: warning: library * was moved.
#pexport DESTDIR="$PREFIX/lib"

pexport CPATH="$PREFIX/include:$CPATH"
pexport LIBRARY_PATH="$PREFIX/lib:$LIBRARY_PATH"
pexport LD_LIBRARY_PATH="$PREFIX/lib:$LD_LIBRARY_PATH"

if [ x"$COMPILE_FLAGS" != x"" ] ; then
  pexport CFLAGS="$COMPILE_FLAGS $CFLAGS"
else
  if [ "$DEBUG_BUILD" = "1" ] ; then
    pexport CMAKE_BUILD_DEBUG="-DCMAKE_BUILD_TYPE=Debug"
    pexport CFLAGS="-O0 -g -DDEBUG -D_DEBUG $CFLAGS"
  else
    pexport CMAKE_BUILD_DEBUG="-DCMAKE_BUILD_TYPE=RelWithDebInfo"
    pexport CFLAGS="-O2 -g -DNDEBUG $CFLAGS"
  fi
fi
pexport LDFLAGS="-L$PREFIX/lib $LDFLAGS $LINK_FLAGS"

pexport CONFIGURE_FLAGS="--prefix=$PREFIX $CONFIGURE_FLAGS"
# This is set so CEGUI can find its dependencies in the local prefix.
pexport CMAKE_PREFIX_PATH=$PREFIX

if [[ "$TARGET_OS" = "android" ]] ; then
  if [[ x"$HOST_OS" != x"GNU/Linux" ]] ; then
    echo >&2 "Host OS $HOST_OS is unsupported! Only GNU/Linux is supported!"
    exit 1
  fi
  if [[ x"$HOST_ARCH" != x"x86_64" ]] && [[ x"$HOST_ARCH" != x"i686" ]] ; then
    echo >&2 "Host architecture $HOST_ARCH is unsupported! Only i686 and x86_64 is supported!"
    exit 1
  fi
  
  # Set up hammer directory structure
  pexport TOOLCHAIN=$WORKDIR/toolchain
  pexport HOSTTOOLS=$WORKDIR/host_tools

  # Setup directories
  mkdir -p $PREFIX
  mkdir -p $DEPS_SOURCE
  mkdir -p $DEPS_BUILD
  mkdir -p $LOGDIR
  mkdir -p $HOSTTOOLS/bin

  # These are used by cmake to identify android kits
  pexport ANDROID_SDK=$DEPS_SOURCE/android-sdk-linux
  pexport ANDROID_NDK=$DEPS_SOURCE/android-ndk-r10-$HOST_ARCH
  pexport ANDROID_STANDALONE_TOOLCHAIN=$TOOLCHAIN
  pexport NDK_TOOLCHAIN_VERSION=4.8
  
  # These are used by autoconfig for cross-compiling
  if [[ $TARGET_ARCH = ARM* ]] ; then
    pexport CROSS_COMPILER=arm-linux-androideabi
  else
    pexport CROSS_COMPILER=i686-linux-android
  fi
  pexport SYSROOT=$TOOLCHAIN/sysroot
  
  # Set android toolchain to the beginning of PATH, so that any call to "gcc" or "g++" will end up into android toolchain.
  pexport PATH=$TOOLCHAIN/bin:$TOOLCHAIN/$CROSS_COMPILER/bin:$ANDROID_SDK/platform-tools:$ANDROID_SDK/tools:$ANDROID_NDK:$HOSTTOOLS/bin:$PATH

  # Set up prefix path properly
  pexport PKG_CONFIG_LIBDIR=$PREFIX/lib/pkgconfig
  pexport CC=$CROSS_COMPILER-gcc
  pexport CXX=$CROSS_COMPILER-g++
  pexport CPP=$CROSS_COMPILER-cpp
  # This helps to ignore system dependencies.
  pexport CFLAGS="$CFLAGS -mandroid --sysroot=$SYSROOT"
  
  # Macros that should be set to detect android.
  pexport CFLAGS="$CFLAGS -D__ANDROID__ -DANDROID"
  
  # Required for threading.
  pexport CFLAGS="$CFLAGS -D_GLIBCXX__PTHREADS -D_REENTRANT"
  
  # Required for boost
  pexport CFLAGS="$CFLAGS -D__GLIBC__"
  
  # Required for OpenAL
  pexport CFLAGS="$CFLAGS -DAL_LIBTYPE_STATIC"
  
  #Disable warning spam from boost
  pexport CFLAGS="$CFLAGS -Wno-unused-local-typedefs -Wno-unused-variable"
  
  pexport CFLAGS="$CFLAGS -funwind-tables"
  
  # We don't need late binding (used for recursive dependencies), so we want all symbols defined.
  pexport LDFLAGS="$LDFLAGS -Wl,--no-undefined"
 
  # Android uses sysv hashes, but we will keep gnu hashes too, because it is insignificant in size. TODO: Maybe sysv would be enough?
  pexport LDFLAGS="$LDFLAGS -Wl,--hash-style=both"
  
  THUMB_DIR=""
  if [[ $TARGET_ARCH = ARM* ]] ; then
    THUMB_DIR="/armv7-a/thumb"
    # Select ARM instruction set and min VFP version. softfp ABI means that it will not use 
    # VFP registers through ABI calls (softfp and hardfp has incompatible ABI and can't be linked together).
    pexport CFLAGS="$CFLAGS -march=armv7-a -mfpu=vfpv3-d16 -mfloat-abi=softfp -mthumb"
    # The aliasing and pic is required, while inline-limit reduces build size.
    pexport CFLAGS="$CFLAGS -fno-strict-aliasing -fpic -finline-limit=64"
    # Macros that should be set to detect android/arm.
    pexport CFLAGS="$CFLAGS -D__arm__"
    
    #Set architecture and support some buggy CPUs.
    pexport LDFLAGS="$LDFLAGS -march=armv7-a -Wl,--fix-cortex-a8"
    
    if [ "$DEBUG_BUILD" = "1" ] ; then
      # Debug flags.
      pexport CFLAGS="$CFLAGS -fno-omit-frame-pointer"
    else
      # Release flags.
      pexport CFLAGS="$CFLAGS -fomit-frame-pointer -funswitch-loops"
      
      # Reference count function calls. This will be used by the linker to trim unused functions.
      pexport CFLAGS="$CFLAGS -ffunction-sections -fdata-sections"
  
      # Don't export any symbols except JNI symbols.
      pexport CFLAGS="$CFLAGS -fvisibility=hidden"
      
      # Merge equal function bodies into one function. This may disable inlining and degrade performance.
      pexport LDFLAGS="$LDFLAGS -Wl,--icf=safe"
  
      # Remove unused functions.
      pexport LDFLAGS="$LDFLAGS -Wl,--gc-sections"
  
      # Apply -fvisibility=hidden on all symbols from linked *.a files.
      pexport LDFLAGS="$LDFLAGS -Wl,--exclude-libs,ALL"
    fi
  else
    # Set architecture. This is required for openal.
    pexport CFLAGS="$CFLAGS -msse2"
    # android x86
    if [ "$DEBUG_BUILD" = "1" ] ; then
      # Debug flags.
      pexport CFLAGS="$CFLAGS -fno-omit-frame-pointer -fno-strict-aliasing"
    else
      # Release flags.
      pexport CFLAGS="$CFLAGS -fomit-frame-pointer -fno-strict-aliasing"
    fi
  fi
  
  
  # Set up compiler/linker
  pexport CPATH="$TOOLCHAIN/include/c++/$NDK_TOOLCHAIN_VERSION/${CROSS_COMPILER}${THUMB_DIR}"
  pexport CPATH="$CPATH:$TOOLCHAIN/lib/gcc/${CROSS_COMPILER}/$NDK_TOOLCHAIN_VERSION/include"
  pexport CPATH="$CPATH:$TOOLCHAIN/include/c++/$NDK_TOOLCHAIN_VERSION"
  pexport CPATH="$CPATH:$SYSROOT/usr/include"
  pexport CPATH="$CPATH:$PREFIX/include"

  # Transform CPATH into -I... compiler flags
  INCFLAGS=-I$(echo $CPATH | sed "s/:/ -I/g")
  pexport CFLAGS="$CFLAGS $INCFLAGS"

  pexport CPPFLAGS="$CFLAGS"
  
  # Add required features. Unfortunatelly, these increase the binary size a lot. Maybe we should remove it from some depepndencies.
  pexport CXXFLAGS="$CFLAGS -frtti -fexceptions"
  
  pexport LIBRARY_PATH="$TOOLCHAIN/$CROSS_COMPILER/lib${THUMB_DIR}:$TOOLCHAIN/lib/gcc/$CROSS_COMPILER/${NDK_TOOLCHAIN_VERSION}${THUMB_DIR}:$SYSROOT/usr/lib:$PREFIX/lib"
  pexport LD_LIBRARY_PATH="$LIBRARY_PATH"

  # Transform LIBRARY_PATH into -L... linker flags
  LIBFLAGS=-L$(echo $LIBRARY_PATH | sed "s/:/ -L/g")
  pexport LDFLAGS="$LDFLAGS $LIBFLAGS"

  # Get common ancestor prefix, so that system paths like /usr/lib will be ignored by cmake
  export CMAKE_ROOT_PATH=`printf "%s\n%s\n" "$PREFIX" "$TOOLCHAIN" | sed -e 'N;s/^\(.*\).*\n\1.*$/\1/'`

  # Set up cmake flags required for cross-compiling
  pexport CMAKE_CROSS_COMPILE="-DCMAKE_SYSTEM_NAME=Linux -DCMAKE_C_COMPILER=$TOOLCHAIN/$CROSS_COMPILER/bin/gcc -DCMAKE_MAKE_PROGRAM=make -DANDROID=true"
  pexport CMAKE_CROSS_COMPILE="$CMAKE_CROSS_COMPILE -DCMAKE_FIND_ROOT_PATH=$CMAKE_ROOT_PATH -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=ONLY -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY"
  pexport CMAKE_CROSS_COMPILE="$CMAKE_CROSS_COMPILE -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY -DCMAKE_INSTALL_PREFIX=$PREFIX"
  pexport CMAKE_CROSS_COMPILE="$CMAKE_CROSS_COMPILE -DPKG_CONFIG_EXECUTABLE=`which pkg-config`"
  
  #pexport CMAKE_CROSS_COMPILE="-DCMAKE_TOOLCHAIN_FILE=$(getAndroidCMakeToolchain) -DCMAKE_FIND_ROOT_PATH=$CMAKE_ROOT_PATH -DCMAKE_INSTALL_PREFIX=$PREFIX"
  
  pexport CONFIGURE_CROSS_COMPILE="--host=$CROSS_COMPILER --prefix=$PREFIX --with-sysroot=$SYSROOT"
  pexport CONFIGURE_FLAGS="$CONFIGURE_CROSS_COMPILE --enable-static --disable-shared --disable-rpath"
  #pexport LIBS="-lboost_thread -lboost_system -lboost_atomic"

elif [ "$TARGET_OS" = "native" ] && [[ $OSTYPE == *darwin* ]] ; then
  #the default architecture is universal build: i864;x86_64
  #To save space and time, we will only build x86_64
  pexport CMAKE_FLAGS="$CMAKE_FLAGS -GXcode -DCMAKE_OSX_ARCHITECTURES=x86_64"

  #on mac libtool is called glibtool.
  #Automake should set this, but it has messed up the order of variable definitions.
  pexport MAKE_FLAGS="$MAKE_FLAGS LIBTOOL=glibtool"

  pexport CXXFLAGS="-O2 -g -DTOLUA_EXPORT -DCEGUI_STATIC -I$PREFIX/include -I/opt/local/include $CXXFLAGS"
  pexport CFLAGS="-O2 -g -DTOLUA_EXPORT -DCEGUI_STATIC -I$PREFIX/include -I/opt/local/include $CFLAGS"
  pexport LDFLAGS="$LDFLAGS -L$PREFIX/lib -L/opt/local/lib"

  #without CPATH cegui is not finding freeimage.
  pexport CPATH="/opt/local/include:$CPATH"
elif [ "$TARGET_OS" = "native" ] && [[ x$MSYSTEM = x"MINGW32" && $1 != "install-deps" ]] ; then
  pexport CONFIGURE_FLAGS="$CONFIGURE_FLAGS --enable-shared --disable-static"
  pexport CXXFLAGS="-O2 -msse2 -mthreads -DBOOST_THREAD_USE_LIB -DCEGUILUA_EXPORTS $CXXFLAGS"
  pexport PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:/usr/local/lib/pkgconfig:/mingw/lib/pkgconfig:/lib/pkgconfig:$PKG_CONFIG_PATH"
  #for msys/mingw we need to specify the include directory
  pexport CXXFLAGS="-I$PREFIX/include $CXXFLAGS"
#else
  # TODO: Show error and quit if target is unsupported
fi