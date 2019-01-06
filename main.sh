# /bin/bash

export CNT=KE
export BUF=0.025 # approx 3 km
export DB=geonames/$CNT.sqlite

make $DB ROI/$CNT.ROI.txt

export ZLEVEL=17 # Tile size is 307 x 307 m
export PREREQ="var tilebelt = require('@mapbox/tilebelt');"

IFS='
'
mkdir -p SQL
export SQL=SQL/$CNT.insert.sql
rm -f $SQL
touch $SQL

function sql_insert() {
    XTILE=$1
    YTILE=$2
    QKey=`nodejs -e "$PREREQ process.stdout.write(String(tilebelt.tileToQuadkey([$XTILE,$YTILE,$ZLEVEL])))"`
    grep $QKey $SQL > /dev/null
    if [ $? -eq 1 ]; then
	BB=($(nodejs -e "$PREREQ console.log(tilebelt.tileToBBOX([$XTILE,$YTILE,$ZLEVEL]));" | tr -d ',[]'))
	TILELONMIN=${BB[0]}
	TILELATMIN=${BB[1]}
	TILELONMAX=${BB[2]}
	TILELATMAX=${BB[3]}
	echo "INSERT INTO tiles (qkey, geom, x, y) VALUES ('$QKey',ST_GeomFromText('POLYGON (($TILELONMIN $TILELATMIN, $TILELONMIN $TILELATMAX, $TILELONMAX $TILELATMAX, $TILELONMAX $TILELATMIN, $TILELONMIN $TILELATMIN))', 4326), $XTILE, $YTILE);" >> $SQL
    fi
}
export -f sql_insert

for ROI in `cat ROI/$CNT.ROI.txt`; do

    LONMIN=`echo $ROI | cut -f 1 -d '|'`
    LONMAX=`echo $ROI | cut -f 2 -d '|'`
    LATMIN=`echo $ROI | cut -f 3 -d '|'`
    LATMAX=`echo $ROI | cut -f 4 -d '|'`
    TILE_LONLATMIN="$(nodejs -e "$PREREQ console.log(tilebelt.pointToTile($LONMIN, $LATMIN, $ZLEVEL));" | tr -d ',[]' | sed 's/^ //; s/ $//')"
    XTILEMIN=$(echo $TILE_LONLATMIN | cut -d " " -f 1)
    YTILEMAX=$(echo $TILE_LONLATMIN | cut -d " " -f 2)
    
    TILE_LONLATMAX="$(nodejs -e "$PREREQ console.log(tilebelt.pointToTile($LONMAX, $LATMAX, $ZLEVEL));" | tr -d ',[]' | sed 's/^ //; s/ $//')"
    XTILEMAX=$(echo $TILE_LONLATMAX | cut -d " " -f 1)
    YTILEMIN=$(echo $TILE_LONLATMAX | cut -d " " -f 2)

    parallel --nice 10 --progress sql_insert {} {} ::: `seq $XTILEMIN $XTILEMAX` ::: `seq $YTILEMIN $YTILEMAX`
#    parallel --nice 10 --progress sql_insert {} {} ::: `seq ${TILE_LONLATMIN[0]} ${TILE_LONLATMAX[0]}` ::: `seq ${TILE_LONLATMAX[1]} ${TILE_LONLATMIN[1]}`
done

spatialite $DB < $SQL
