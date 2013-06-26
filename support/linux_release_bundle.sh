#!/bin/bash

#this script will copy everything from work/local to release
#it will recursively detect all ember dependencies, which are installed into the $WORK dir.
#also it will automatically resolve symlinks and copies the file only, because symlinks are not rpath compatible.
#it will also copy install.sh uninstall.sh and npWebEmber.so files for webember if availible

WORK="$PWD/work/local"
REL="$PWD/release"

export LD_LIBRARY_PATH="$WORK/lib"
if [ ! -d $WORK ] ; then
  echo "Error: $WORK directory does not exist!"
  exit 1
fi

mkdir -p $REL/bin
cp $WORK/bin/ember $REL/bin/ember
cp $WORK/bin/ember.bin $REL/bin/ember.bin

mkdir -p $REL/etc/ember
cp -r $WORK/etc/ember/* $REL/etc/ember

mkdir -p $REL/share/ember
cp -r $WORK/share/ember/* $REL/share/ember

#copy Ogre plugins and cg, which are not found automatically by the linker.
mkdir -p $REL/lib/OGRE
cp $WORK/lib/OGRE/*.so $REL/lib/OGRE
cp $WORK/lib/libCg.so $REL/lib

#remove temporary work file.
if [ -f tmp_ldd.txt ] ; then
  rm tmp_ldd.txt
fi
touch tmp_ldd.txt


function is_processed()
{
  cat tmp_ldd.txt | while read line2 ; do
    if [ "$line2" == "$1" ] ; then
      echo yes
      break;
    fi
  done
}
#lists all dependencies recursively which are installed in $WORK prefix
function list_deps()
{
  echo "`ldd \"$1\"`" | while read line ; do
    if [[ $line == *"${WORK}"* ]] ; then
      
      #cut text until > character
      line="`echo $line | cut -s -d '>' -f 2`"
      #cut text after ( character
      line="`echo $line | cut -s -d '(' -f 1`"
      #trim
      line="`echo $line`"

      if [ "$line" != "" ] && [ -f $line ] ; then
        #check in the tested list if it was already processed(endless loop protection)
        ret="`is_processed $line`"
        if [ "$ret" != "yes" ] ; then
          echo $line >> tmp_ldd.txt
          echo $line
          list_deps $line
        fi
      fi
    fi
  done
}

function copy_sharedlib()
{
  echo "copying $1"
  if [ -s "$1" ] ; then
    loc="`readlink -f $1`"
  else
    loc="$1"
  fi
  out="$REL/lib/`basename \"$1\"`"
  cp "$loc" "$out" 
  chmod 0755 "$out"
  chrpath -r "../lib:lib" "$out"
}
echo "gettings ember dependencies recursively"
list_deps "$REL/bin/ember.bin" | while read line; do copy_sharedlib "$line"; done

if [ -f ~/.mozilla/plugins/npWebEmber.so ] ; then
cp ~/.mozilla/plugins/npWebEmber.so $REL/npWebEmber.so
chmod 0755 ~/.mozilla/plugins/npWebEmber.so

cp $WORK/lib/libWebEmber-0.1.so $REL/lib/libWebEmber-0.1.so
chmod 0755 $REL/lib/libWebEmber-0.1.so

echo -e \
"# !/bin/bash\n  \
SCRIPTDIR=\"\$( cd -P \"\$( dirname \"\$0\" )\" && pwd )\"\n  \
mkdir -p ~/.mozilla/plugins/\n  \
cp \$SCRIPTDIR/npWebEmber.so ~/.mozilla/plugins/npWebEmber.so\n  \
mkdir -p ~/.ember\n  \
echo \$SCRIPTDIR > ~/.ember/webember.path\n" > $REL/install.sh
chmod 0755 $REL/install.sh

echo -e \
"# !/bin/bash\n  \
rm ~/.mozilla/plugins/npWebEmber.so\n  \
rm ~/.ember/webember.path\n" > $REL/uninstall.sh
chmod 0755 $REL/uninstall.sh

fi

#remove temporary work file.
if [ -f tmp_ldd.txt ] ; then
  rm tmp_ldd.txt
fi

