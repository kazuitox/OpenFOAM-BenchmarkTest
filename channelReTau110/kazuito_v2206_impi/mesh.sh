#!/bin/bash
#
# Main
#
# 最適化スクリプトで生成されたパラメータ定義ファイルを評価
source $0.param
# 元のケースディレクトリから必要なディレクトリをリンク
for dir in constant include
do
    if [ ! -d $dir ]
    then
	mkdir $dir
	(cd $dir
	    ln -s  ../../../$dir/* ./
	)
    fi
done
rm -f constant/polyMesh
for file in 0 system
do
    [ -L $file ] || ln -s ../../$file .
done
# Delta time and end time
case $mx in
    120)
	deltaT=0.004
	endTime=0.204
	;;
    240)
	deltaT=0.002
	endTime=0.102
	;;
    480)
	deltaT=0.001
	endTime=0.009
	;;
    762)
	deltaT=0.0006
	endTime=0.0018
	;;
esac
# controlDictを生成
rm -f include/controlDict
cat > include/controlDict <<EOF
application pimpleFoam;
startFrom startTime;
startTime 0;
stopAt endTime;
writeControl runTime;
deltaT $deltaT;
endTime $endTime;
writeInterval 1;
purgeWrite 0;
writeFormat binary;
writePrecision 6;
writeCompression off;
timeFormat general;
timePrecision 6;
runTimeModifiable false;
EOF
# blockMeshDictを生成
rm -f include/blockMeshDict
cat > include/blockMeshDict <<EOF
convertToMeters 1;
vertices
(
  (0 0 0 )
  (15.70796326794896619220 0 0 )
  (15.70796326794896619220 2 0 )
  (0 2 0 )
  (0 0 6.28318530717958647688)
  (15.70796326794896619220 0 6.28318530717958647688)
  (15.70796326794896619220 2 6.28318530717958647688)
  (0 2 6.28318530717958647688)
);
blocks
(
  hex (0 1 2 3 4 5 6 7)
  ($mx $my $mz)
  simpleGrading (1 1 1)
);
edges
(
);
boundary
(
  bottomWall
  {
    type wall;
     faces ((1 5 4 0));
  }
  topWall
  {
    type wall;
    faces ((2 6 7 3));
  }
  sides_half0
  {
    type cyclic;
    neighbourPatch sides_half1;
    faces ((0 3 2 1));
  }
  sides_half1
  {
    type cyclic;
    neighbourPatch sides_half0;
    faces ((4 7 6 5));
  }
  inout_half0
  {
    type cyclic;
    neighbourPatch inout_half1;
     faces ((0 4 7 3));
  }
  inout_half1
  {
    type cyclic;
    neighbourPatch inout_half0;
    faces ((1 5 6 2));
  }
);
mergePatchPairs
(
);
EOF
cat > blockMesh.sh <<EOF
#!/bin/bash
source /usr/mpi/gcc/openmpi-4.0.3rc4/bin/mpivars.sh
source /share/app/OpenFOAM/OpenFOAM-v2206/etc/bashrc
blockMesh >& log.$0.\$$
echo \$$
EOF
chmod +x blockMesh.sh
JOBID=$(./blockMesh.sh)
echo $JOBID
exit 0
