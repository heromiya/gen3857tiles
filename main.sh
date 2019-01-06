# /bin/bash

# Panghan
#LONMAX=100.08
#LONMAX=99.70
#LONMIN=99.69
#LATMAX=9.70
#LATMIN=9.67

#Savannakhet Extent: (104.732625, 15.876399) - (106.798488, 17.113576)
#LONMAX=106.798488
#LONMIN=104.732625
#LATMAX=17.113576
#LATMIN=15.876399

COUNTY=KE
BUF=0.025 # approx 3 km


ZLEVEL=15 # Tile size is 1223 x 1223 m
PREREQ="var tilebelt = require('tilebelt');"
DB=assignmentTiles.sqlite

rm -f $DB
spatialite $DB <<EOF
DELETE FROM geometry_columns WHERE f_table_name = 'tiles';
DROP TABLE IF EXISTS tiles;
CREATE TABLE tiles (
        gid integer primary key AUTOINCREMENT,
        qkey varchar(64)
);
SELECT AddGeometryColumn('tiles', 'the_geom' ,4326, 'POLYGON', 'XY');
EOF

ogrinfo PPL-5km.gpkg -al | grep -e minx -e maxx -e miny -e maxy | grep = | awk 'BEGIN{OFS="|"}/minx/{minx=$4}/maxx/{maxx=$4}/miny/{miny=$4}/maxy/{maxy=$4; print minx,maxx,miny,maxy}' > ROI.txt

IFS='
'

for ROI in `cat ROI.txt`; do

    LONMIN=`echo $ROI | cut -f 1 -d '|'`
    LONMAX=`echo $ROI | cut -f 2 -d '|'`
    LATMIN=`echo $ROI | cut -f 3 -d '|'`
    LATMAX=`echo $ROI | cut -f 4 -d '|'`

    XTILEMIN=`nodejs -e "$PREREQ Tile=tilebelt.pointToTile($LONMIN, $LATMIN, $ZLEVEL); process.stdout.write(String(Tile[0]))"`
    YTILEMAX=`nodejs -e "$PREREQ Tile=tilebelt.pointToTile($LONMIN, $LATMIN, $ZLEVEL); process.stdout.write(String(Tile[1]))"`
    XTILEMAX=`nodejs -e "$PREREQ Tile=tilebelt.pointToTile($LONMAX, $LATMAX, $ZLEVEL); process.stdout.write(String(Tile[0]))"`
    YTILEMIN=`nodejs -e "$PREREQ Tile=tilebelt.pointToTile($LONMAX, $LATMAX, $ZLEVEL); process.stdout.write(String(Tile[1]))"`

    for XTILE in `seq $XTILEMIN $XTILEMAX`; do
	for YTILE in `seq $YTILEMIN $YTILEMAX`; do
	    QKey=`nodejs -e "$PREREQ process.stdout.write(String(tilebelt.tileToQuadkey([$XTILE,$YTILE,$ZLEVEL])))"`
	    TILELONMIN=`nodejs -e "$PREREQ BB=tilebelt.tileToBBOX([$XTILE,$YTILE,$ZLEVEL]); process.stdout.write(String(BB[0]))"`
	    TILELATMIN=`nodejs -e "$PREREQ BB=tilebelt.tileToBBOX([$XTILE,$YTILE,$ZLEVEL]); process.stdout.write(String(BB[1]))"`
	    TILELONMAX=`nodejs -e "$PREREQ BB=tilebelt.tileToBBOX([$XTILE,$YTILE,$ZLEVEL]); process.stdout.write(String(BB[2]))"`
	    TILELATMAX=`nodejs -e "$PREREQ BB=tilebelt.tileToBBOX([$XTILE,$YTILE,$ZLEVEL]); process.stdout.write(String(BB[3]))"`
	    echo "INSERT INTO tiles (qkey, the_geom) VALUES ('$QKey',ST_GeomFromText('POLYGON (($TILELONMIN $TILELATMIN, $TILELONMIN $TILELATMAX, $TILELONMAX $TILELATMAX, $TILELONMAX $TILELATMIN, $TILELONMIN $TILELATMIN))', 4326));" | spatialite $DB
	done
    done

done
