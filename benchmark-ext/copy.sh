DEST=lib/thirdweb-contracts-next/

rm -rf $DEST
mkdir -p $DEST

cp -a ../lib/ ../src/ ../foundry.toml ../remappings.txt $DEST
