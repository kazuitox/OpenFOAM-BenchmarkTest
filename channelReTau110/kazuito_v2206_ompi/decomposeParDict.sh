#!/bin/bash
#
# Main
#
# 最適化スクリプトで生成されたパラメータ定義ファイルを評価
source $0.param
# ppn(process per node)とノード数から，領域分割数を算出
numberOfSubdomains=`expr $decomposeParDict_ppn \* $decomposeParDict_node`
# 元のケースディレクトリから必要なディレクトリをリンク
if [ ! -d include ]
then
    mkdir include
    (cd include
	ln -s  ../../include/* ./
    )
fi
for file in 0 constant system
do
    [ -L $file ] || ln -s ../$file .
done
# decomposeParDictを生成
rm -f include/decomposeParDict
cat > include/decomposeParDict <<EOF
numberOfSubdomains $numberOfSubdomains; // 領域分割数(並列数)
method $decomposeParDict_method; // 分割手法
preservePatches (sides_half0 sides_half1 inout_half0 inout_half1);
multiLevelCoeffs
{
  method  scotch;
  domains ($decomposeParDict_ppn $decomposeParDict_node);
}
EOF
cat > decomposePar.sh <<EOF
#!/bin/bash
source /usr/mpi/gcc/openmpi-4.0.3rc4/bin/mpivars.sh
source /share/app/OpenFOAM/OpenFOAM-v2206/etc/bashrc
decomposePar >& log.$0.\$$
echo \$$
EOF
chmod +x decomposePar.sh
JOBID=$(./decomposePar.sh)
echo $JOBID
exit 0
