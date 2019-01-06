# /bin/bash

export CNT=KE
export BUF=0.025 # approx 3 km
export DB=geonames/$CNT.sqlite

make $DB ROI/$CNT.ROI.txt

export ZLEVEL=17 # Tile size is 307 x 307 m
PREREQ="var tilebelt = require('@mapbox/tilebelt');"

IFS='
'
mkdir -p SQL
SQL=SQL/$CNT.insert.sql
rm -f $SQL
touch $SQL

function sql_insert() {
    XTILE=$1
    YTILE=$2
    QKey=`nodejs -e "$PREREQ process.stdout.write(String(tilebelt.tileToQuadkey([$XTILE,$YTILE,$ZLEVEL])))"`
    grep $QKey $SQL
    if [ $? -eq 1 ]; then
	TILELONMIN=`nodejs -e "$PREREQ BB=tilebelt.tileToBBOX([$XTILE,$YTILE,$ZLEVEL]); process.stdout.write(String(BB[0]))"`
	TILELATMIN=`nodejs -e "$PREREQ BB=tilebelt.tileToBBOX([$XTILE,$YTILE,$ZLEVEL]); process.stdout.write(String(BB[1]))"`
	TILELONMAX=`nodejs -e "$PREREQ BB=tilebelt.tileToBBOX([$XTILE,$YTILE,$ZLEVEL]); process.stdout.write(String(BB[2]))"`
	TILELATMAX=`nodejs -e "$PREREQ BB=tilebelt.tileToBBOX([$XTILE,$YTILE,$ZLEVEL]); process.stdout.write(String(BB[3]))"`
	echo "INSERT INTO tiles (qkey, the_geom) VALUES ('$QKey',ST_GeomFromText('POLYGON (($TILELONMIN $TILELATMIN, $TILELONMIN $TILELATMAX, $TILELONMAX $TILELATMAX, $TILELONMAX $TILELATMIN, $TILELONMIN $TILELATMIN))', 4326));" >> $SQL
    fi
}
export -f sql_insert

for ROI in `cat ROI/$CNT.ROI.txt`; do

    LONMIN=`echo $ROI | cut -f 1 -d '|'`
    LONMAX=`echo $ROI | cut -f 2 -d '|'`
    LATMIN=`echo $ROI | cut -f 3 -d '|'`
    LATMAX=`echo $ROI | cut -f 4 -d '|'`

    XTILEMIN=`nodejs -e "$PREREQ Tile=tilebelt.pointToTile($LONMIN, $LATMIN, $ZLEVEL); process.stdout.write(String(Tile[0]))"`
    YTILEMAX=`nodejs -e "$PREREQ Tile=tilebelt.pointToTile($LONMIN, $LATMIN, $ZLEVEL); process.stdout.write(String(Tile[1]))"`
    XTILEMAX=`nodejs -e "$PREREQ Tile=tilebelt.pointToTile($LONMAX, $LATMAX, $ZLEVEL); process.stdout.write(String(Tile[0]))"`
    YTILEMIN=`nodejs -e "$PREREQ Tile=tilebelt.pointToTile($LONMAX, $LATMAX, $ZLEVEL); process.stdout.write(String(Tile[1]))"`

    parallel --nice 10 --progress sql_insert {} {} ::: `seq $XTILEMIN $XTILEMAX` ::: `seq $YTILEMIN $YTILEMAX`
done

spatialite $DB < insert.sql
