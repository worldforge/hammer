#!/bin/bash

#This script will create a portable App for Mac OS X.


set -e

export HAMMERDIR=$PWD
export WORKDIR=$HAMMERDIR/work
export PREFIX=$WORKDIR/local
export DEPS_SOURCE=$WORKDIR/build/deps
export MAKEOPTS="-j3"
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
  wget -c http://switch.dl.sourceforge.net/project/macdylibbundler/macdylibbundler/0.3.1/$FILENAME
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


