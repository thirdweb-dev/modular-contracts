#!/bin/bash
DEST=lib/thirdweb-contracts-next/

rm -rf $DEST
mkdir -p $DEST

cp -a ../lib/ ../src/ ../foundry.toml ../remappings.txt $DEST

cd lib/creator-core-extensions-solidity && git apply ../../patch/manifold_creator_core_patch.diff
