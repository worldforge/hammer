#!/bin/bash

# This script will create a portable App for Mac OS X.
# It should be run through hammer.sh or from the hammer directory. 


set -e

if [[ x"$HAMMERDIR" = x"" ]] ; then
  echo "This script should be called through hammer.sh or with a configured environment with setup_env.sh"
fi

if [ $TARGET_OS = "android" ] ; then

# I couldn't figure out how to extract dependencies using libtool, so I have written a script, which will do this for me.
function getLibToolDeps()
{  
  # get the dependencies of the *.la input file
  local CONTENT=`sed -n "s/dependency_libs='\\(.*\\)'/\\1/p" < $1`
  
  # list dependent la files
  local LA_FILES="`printf '%s\n' "$CONTENT" | grep -oh '[^[:blank:]]*\.la'`"
  
  # We want to replace each la file with its own dependencies recursively.
  # NOTE: The order is important! The content of the la file needs to be inserted at the la location.
  for LA_FILE in $LA_FILES
  do
    local LA_REAL_FILE="$LA_FILE"
    if [ ! -f $LA_REAL_FILE ] ; then
      local LA_REAL_FILE=${LA_REAL_FILE#"="}
    fi
    local LA_CONTENT="`getLibToolDeps $LA_REAL_FILE`"
    local LA_CONTENT_ESCAPED=$(printf '%s\n' "$LA_CONTENT" | sed 's/[\&/]/\\&/g')
    local LA_FILE_ESCAPED=$(printf '%s\n' "$LA_FILE" | sed 's/[[\.*^$(){}?+|/]/\\&/g')
    local CONTENT=`printf '%s\n' "$CONTENT" | sed -r "s/$LA_FILE_ESCAPED/$LA_CONTENT_ESCAPED/g"`
  done
  
  # get the static lib of the la. "$PREFIX/lib/EmberAndroid.la" ==> "-L$PREFIX/lib -lEmberAndroid"
  local SELF_A=`sed -n "s/old_library='lib\\(.*\\).a'/\\1/p" < $1`
  if [ x"$SELF_A" = x"" ] ; then
      echo "failed to determine libname for $1"
  fi
  local CONTENT="-L`dirname $1` -l${SELF_A} $CONTENT"
  printf '%s\n' "$CONTENT"
}
function removeDuplicateLinkFlags()
{
  # warning: This function may not work with --start-group or some other order dependent linker flags!
  CONTENT=" $1 "
  # Replace tabs with spaces to make other steps easier.
  CONTENT=$(printf "%s\n" "$CONTENT" | sed -e "s/[[:blank:]]/ /g" )
  #We want to keep first -L* instances and last -l* instances
  LIBDIRS="`printf '%s\n' "$CONTENT" | grep -oh '\-L[^ ]*'`"
  for LIBDIR in $LIBDIRS
  do
    LIBDIR_ESCAPED=$(printf '%s\n' "$LIBDIR" | sed 's/[[\.*^$(){}?+|/]/\\&/g')
    CONTENT=$(printf "%s\n" "$CONTENT" | sed -e "s/ $LIBDIR_ESCAPED / _$LIBDIR_ESCAPED /1" -e "s/ $LIBDIR_ESCAPED / /g" -e "s/ _\($LIBDIR_ESCAPED\) / \1 /" )
  done
  
  LIBS="`printf '%s\n' "$CONTENT" | grep -oh '\-l[^ ]*'`"

  for LIB in $LIBS
  do
    LIB_ESCAPED=$(printf '%s\n' "$LIB" | sed 's/[[\.*^$(){}?+|/]/\\&/g')
    CONTENT=$(printf "%s\n" "$CONTENT" | sed -e "s/\\(.*\\) $LIB_ESCAPED /\1 _$LIB_ESCAPED /g" -e "s/ $LIB_ESCAPED / /g" -e "s/ _\($LIB_ESCAPED\) / \1 /" )
  done
  # Replace multiple spaces, -lpthread and -lGLESv1_CM, which are hardcoded dependencies in some libs.
  CONTENT=$(printf "%s\n" "$CONTENT" | sed -e "s/ \\-lGLESv1_CM / /g" -e "s/ \\-lpthread / /g" -e "s/ \\-l / /g" -e "s/  */ /g" )
  echo "$CONTENT"
}

  LINKFLAGS="`getLibToolDeps $PREFIX/lib/libEmberAndroid.la`"
  LINKFLAGS="`removeDuplicateLinkFlags \"$LINKFLAGS\"`"
  
  if [ x"$TARGET_ARCH" = x"x86" ] ; then
    ABI="x86"
    STL_PATH=$ANDROID_NDK/sources/cxx-stl/gnu-libstdc++/4.8/libs/$ABI
  elif  [ x"$TARGET_ARCH" = x"ARMv7" ] ; then
    ABI="armeabi-v7a"
    STL_PATH=$ANDROID_NDK/sources/cxx-stl/gnu-libstdc++/4.8/libs/$ABI/thumb
  else
    echo "Undefined ABI for target architecture ${TARGET_ARCH}!"
    exit 1
  fi
  
  # The android-ndk will strip the c++ runtime to the sources that it owns. However it ignores the C++ needs of dependencies in LOCAL_LDLIBS. (bug in ndk)
  # It could be fixed by adding volatile std::sring and std::stringstream, etc to the EmberJNI.cpp, but that would be ugly.
  # To not mess with multiple C++ runtimes it will remove -lstdc++ from LOCAL_LDLIBS too.
  # So we will add the libgnustl_static.a with full path.
  LINKFLAGS="$LINKFLAGS -L$STL_PATH -lgnustl_static"
  
  # some missing ogre deps.
  echo $LINKFLAGS
  LINKFLAGS_ESCAPED=$(printf '%s\n' "$LINKFLAGS" | sed 's/[\&/]/\\&/g')
  SOURCE_ESCAPED=$(printf '%s\n' "$SOURCE" | sed 's/[\&/]/\\&/g')
  PREFIX_ESCAPED=$(printf '%s\n' "$PREFIX" | sed 's/[\&/]/\\&/g')
  
  EMBER_APP="$WORKDIR/ember.app"
  PROJECT_DIR="$BUILD/clients/ember_apk/$BUILDDIR"
  PROJECT_SOURCE_DIR="$SOURCE/clients/ember/src/extensions/android/project"
  KEYSTORE="$PROJECT_DIR/my-release-key.keystore"

  # From now on we only need the PATH from the environment (location of 'android' and 'ndk-build'). Change condition if you want to let NDK decide build flags.

  
  #if [ ! -d $PROJECT_DIR ]; then
    mkdir -p $PROJECT_DIR
    cp -r $PROJECT_SOURCE_DIR/* $PROJECT_DIR
    cp $PROJECT_DIR/jni/Android.mk.in $PROJECT_DIR/jni/Android.mk
    cp $PROJECT_DIR/jni/Application.mk.in $PROJECT_DIR/jni/Application.mk
    sed -i '1i# This is a generated file! Please edit Android.mk.in, then run AppBundler to regenerate.' $PROJECT_DIR/jni/Android.mk
    sed -i '1i# This is a generated file! Please edit Application.mk.in, then run AppBundler to regenerate.' $PROJECT_DIR/jni/Application.mk
    sed -i -e "s/%EXTRA_LIBS%/$LINKFLAGS_ESCAPED/g" -e "s/%SOURCE%/$SOURCE_ESCAPED/g" -e "s/%PREFIX%/$PREFIX_ESCAPED/g" -e "s/%SYSROOT%/$SYSROOT_ESCAPED/g" $PROJECT_DIR/jni/Android.mk
    sed -i -e "s/%ABI%/$ABI/g" $PROJECT_DIR/jni/Application.mk
  #fi
  export EMBER_APP="$WORKDIR/ember.apk"
  
  if [ "1" = "1" ] ; then
    export PATH_SAVE="$PATH"
    export DEBUG_BUILD_SAVE="$DEBUG_BUILD"
    eval `$SUPPORTDIR/setup_env.sh pop_env`
    export PATH="$PATH_SAVE"
    export DEBUG_BUILD="$DEBUG_BUILD_SAVE"
  fi
  
  android update project \
    --target "android-15" \
    --name "Ember" \
    --path "$PROJECT_DIR"
    
  if [ "$DEBUG_BUILD" = "0" ]; then
    echo Building release binaries!
    cd $PROJECT_DIR/jni
    ndk-build -B
    cd $PROJECT_DIR
    ant release
    if [ ! -f $KEYSTORE ]; then
      # You should change the password!
      keytool -genkey -v -keystore my-release-key.keystore -alias ember -keyalg RSA \
      -dname "CN=mqttserver.ibm.com, OU=ID, O=IBM, L=Hursley, S=Hants, C=GB" \
      -keysize 2048 -validity 10000 -storepass unofficialkeystore -keypass unofficialkey
    fi
    jarsigner -verbose -sigalg SHA1withRSA -digestalg SHA1 -keystore my-release-key.keystore \
    -storepass unofficialkeystore -keypass unofficialkey bin/Ember-release-unsigned.apk ember
    mv -f bin/Ember-release-unsigned.apk bin/Ember-release.apk
    #adb install bin/Ember-release.apk
  else
    echo Building debug binaries!
    cd $PROJECT_DIR/jni
    ndk-build NDK_DEBUG=1 -B
    cd $PROJECT_DIR
    ant debug
  fi

  exit 0
fi


export EMBER_APP="$WORKDIR/ember.app"
export WEBEMBER_PLUGIN="$WORKDIR/WebEmber.plugin"
export DYLIBBUNDLER="$PREFIX/bin/dylibbundler"
export OPENAL_FRAMEWORK="/opt/local/Library/Frameworks/OpenAl.framework"

BUNDLE=""

#install dylibbundler if its not installed
if [ ! -f $DYLIBBUNDLER ]; then
  #dylibbundler will automatically search every .dylib file used by a program,
  #then it will copy it to the given directory and set the absolute path to relative path.
  
  mkdir -p $DEPS_SOURCE
  cd $DEPS_SOURCE
  FILENAME="dylibbundler0.3.1.zip"
  curl -c - -OL http://switch.dl.sourceforge.net/project/macdylibbundler/macdylibbundler/0.3.1/$FILENAME
  unzip $FILENAME
  cd dylibbundler
  make
  cp dylibbundler $DYLIBBUNDLER
fi


if [ $# -eq 0 ] ; then
  echo "Usage: AppBundler.sh <target>"
  echo "Targets:"
  echo "  ember    - creates ember.app"
  echo "  webember - creates webember.plugin"
  exit 0
fi

if [ $1 = "ember" ] ; then
  BUNDLE="$EMBER_APP"
elif [ $1 = "webember" ] ; then
  BUNDLE="$WEBEMBER_PLUGIN"
fi

#files for ember and webember
if [ x"$BUNDLE" != x"" ] ; then
  
  #prepare directories
  mkdir -p $BUNDLE/Contents/MacOS
  mkdir -p $BUNDLE/Contents/Frameworks
  mkdir -p $BUNDLE/Contents/Plugins
  mkdir -p $BUNDLE/Contents/lib
  mkdir -p $BUNDLE/Contents/Resources
  
  #install media
  cp -r $PREFIX/etc $BUNDLE/Contents/Resources
  cp -r $PREFIX/share/ember/media $BUNDLE/Contents/Resources
  cp $PREFIX/share/icons/worldforge/ember.png $BUNDLE/Contents/Resources/ember.png
  
  #install Ogre plugins
  cp -r $PREFIX/lib/Plugin_* $BUNDLE/Contents/Plugins
  cp $PREFIX/lib/RenderSystem_GL.dylib $BUNDLE/Contents/Plugins/RenderSystem_GL.dylib
  
  #install frameworks
  cp -r $PREFIX/lib/Ogre.framework $BUNDLE/Contents/Frameworks
  cp -r $OPENAL_FRAMEWORK $BUNDLE/Contents/Frameworks
fi


#bundle ember
if [ $1 = "ember" ] ; then
  
  #install App configuration file
  echo -e \
"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n\
<!DOCTYPE plist PUBLIC \"-//Apple Computer//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n\
<plist version=\"1.0\">\n\
<dict>\n\
  <key>CFBundleGetInfoString</key>\n\
  <string>ember</string>\n\
  <key>CFBundleExecutable</key>\n\
  <string>ember.bin</string>\n\
  <key>CFBundleIdentifier</key>\n\
  <string>com.worldforge.ember</string>\n\
  <key>CFBundleName</key>\n\
  <string>ember</string>\n\
  <key>CFBundleIconFile</key>\n\
  <string>ember.png</string>\n\
  <key>CFBundleShortVersionString</key>\n\
  <string>0.6.1</string>\n\
  <key>CFBundleInfoDictionaryVersion</key>\n\
  <string>6.0</string>\n\
  <key>CFBundlePackageType</key>\n\
  <string>APPL</string>\n\
</dict>\n\
</plist>\n" > $EMBER_APP/Contents/Info.plist
 
  #install executable
  cp $PREFIX/bin/ember.bin $EMBER_APP/Contents/MacOS/ember.bin
  

  #install libraries
  $DYLIBBUNDLER -od -b -x $EMBER_APP/Contents/MacOS/ember.bin -d $EMBER_APP/Contents/libs
  

fi

if [ $1 = "webember" ] ; then
  #install webember
  cp $PREFIX/lib/libWebEmber-0.1.dylib $WEBEMBER_PLUGIN/Contents/lib/libWebEmber-0.1.dylib

  #install libraries
  $DYLIBBUNDLER -od -b -x $WEBEMBER_PLUGIN/Contents/lib/libWebEmber-0.1.dylib -d $WEBEMBER_PLUGIN/Contents/lib -p @loader_path/../lib

  
  #change framework linkage from @executable_path to @loader_path
  install_name_tool -change \
  "@executable_path/../Frameworks/Ogre.framework/Versions/1.7.3/Ogre" \
  "@loader_path/../Frameworks/Ogre.framework/Versions/1.7.3/Ogre" \
  "$WEBEMBER_PLUGIN/Contents/lib/libWebEmber-0.1.dylib"

  install_name_tool -change \
  "@executable_path/../Frameworks/Ogre.framework/Versions/1.7.3/Ogre" \
  "@loader_path/../Frameworks/Ogre.framework/Versions/1.7.3/Ogre" \
  "$WEBEMBER_PLUGIN/Contents/lib/libCEGUIOgreRenderer-0.7.5.dylib"
  
  install_name_tool -change \
  "@executable_path/../Frameworks/OpenAL.framework/Versions/A/OpenAL" \
  "@loader_path/../Frameworks/OpenAL.framework/Versions/A/OpenAL" \
  "$WEBEMBER_PLUGIN/Contents/lib/libWebEmber-0.1.dylib"
  
  for f in $WEBEMBER_PLUGIN/Contents/Plugins/*; do
    install_name_tool -change \
    "@executable_path/../Frameworks/Ogre.framework/Versions/1.7.3/Ogre" \
    "@loader_path/../Frameworks/Ogre.framework/Versions/1.7.3/Ogre" \
    "$f"
  done
  
fi


