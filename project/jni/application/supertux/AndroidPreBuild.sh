#!/bin/sh

mkdir -p AndroidData/assetpack
[ -e AndroidData/assetpack/data.zip ] && exit 0
cd supertux/data || exit 1
sed 's/@LOGO_FILE@/logo_final.sprite/g' levels/misc/menu.stl.in > levels/misc/menu.stl
if [ -e $HOME/.local/share/supertux2/tilecache ]; then
	mkdir -p tilecache
	cp -f $HOME/.local/share/supertux2/tilecache/* tilecache/
fi
zip -r -9 ../../AndroidData/assetpack/data.zip .
