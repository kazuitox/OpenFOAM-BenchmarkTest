#!/bin/sh

# Json filenames
jsonFilenames="\
#tuneOpenFOAM-mesh_0.37M.json \
#tuneOpenFOAM-mesh_3M.json \
#tuneOpenFOAM-mesh_24M.json \
tuneOpenFOAM-mesh_96M.json \
"

for jsonFilename in $jsonFilenames
do
# SQLite3データベース名
studyname=${jsonFilename%.json}
jsonFilename=$studyname.json # パラメータ空間の設定ファイル
dbfile=$studyname.db # SQLite3データベースファイル名
storage=sqlite:///$dbfile

# SQLite3データベースが存在しない場合，作成する
res=""
[ -f $dbfile ] && res=`sqlite3 $dbfile "select * from studies where study_name = '$studyname'"`
[ -z $res ] && optuna create-study --study $studyname --storage $storage

# ソルバ解析時間最適化
# --studyName <スタディ名>
# --jsonFilename <JSON形式設定ファイル名>
# --storage <SQLite3データベース名>
../../bin/tuneOpenFOAM.py \
    --studyName $studyname \
    --jsonFilename $jsonFilename \
    --storage $storage \
    --gridSearch \
>& log.$studyname
done
