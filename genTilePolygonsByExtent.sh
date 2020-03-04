#! /bin/bash

export GADM_GID=$1
export ZLEVEL=$2
export WORKDIR=$(mktemp -d)
export SQL=$WORKDIR/tilePolygon.insert.$GADM_GID.$ZLEVEL.sql
DB=tilePolygon.$GADM_GID.Z$ZLEVEL.$(date +%F_%T).sqlite

#EXTENT=($(psql -h guam -d suvannaket -F " " -qAtc "SELECT ST_XMin(wkb_geometry), ST_XMax(wkb_geometry), ST_YMin(wkb_geometry), ST_YMax(wkb_geometry) FROM gadm36_level1 WHERE gid_1 = '$GADM_GID';"))
export LONMIN=$3
export LATMIN=$4
export LONMAX=$5
export LATMAX=$6

XYMIN=($(echo "var tilebelt = require('@mapbox/tilebelt'); console.log(tilebelt.pointToTile(${LONMIN}, ${LATMIN}, $ZLEVEL));" | nodejs | tr -d '[],'))
XYMAX=($(echo "var tilebelt = require('@mapbox/tilebelt'); console.log(tilebelt.pointToTile(${LONMAX}, ${LATMAX}, $ZLEVEL));" | nodejs | tr -d '[],'))

echo "CREATE TABLE tilepolygon (x interger, y integer, z integer, gadm0 varchar(3), qkey varchar(256)); SELECT AddGeometryColumn('tilepolygon','geom',4326,'MULTIPOLYGON','XY');" > $SQL

function tilePolygon() {
    X=$1
    Y=$2
    if [ ! -e  $WORKDIR/$X.$Y.sql ]; then
	BBOX=($(echo "var tilebelt = require('@mapbox/tilebelt'); console.log(tilebelt.tileToBBOX(["$X", "$Y", "$ZLEVEL"]));" | nodejs | tr -d ",[]"))
	QKEY=$(echo "var tilebelt = require('@mapbox/tilebelt'); console.log(tilebelt.tileToQuadkey(["$X", "$Y", "$ZLEVEL"]));" | nodejs)
	#CENTER=($(echo "var tilebelt = require('tilebelt'); bbox = tilebelt.tileToBBOX(["$X", "$Y", "$ZLEVEL"]); console.log((bbox[0]+bbox[2])/2, (bbox[1]+bbox[3])/2)" | nodejs))
	echo "INSERT INTO tilepolygon (x,y,z,gadm0,qkey,geom) VALUES ("$X","$Y","$ZLEVEL",'"$GADM_GID"','"$QKEY"',GeomFromText('MULTIPOLYGON((("${BBOX[0]}" "${BBOX[1]}", "${BBOX[0]}" "${BBOX[3]}", "${BBOX[2]}" "${BBOX[3]}", "${BBOX[2]}" "${BBOX[1]}", "${BBOX[0]}" "${BBOX[1]}")))', 4326));" > $WORKDIR/insert.$X.$Y.sql	
	#echo "INSERT INTO tilepoint (x, y, geom) VALUES ("$X","$Y",MakePoint("${CENTER[0]}","${CENTER[1]}",4326));" > $WORKDIR/$X.$Y.sql
    fi
}
export -f tilePolygon

parallel --nice 10 --progress tilePolygon {1} {2} ::: $(seq ${XYMIN[0]} ${XYMAX[0]}) ::: $(seq ${XYMAX[1]} ${XYMIN[1]})
find $WORKDIR -type f | grep "\/insert.*\.sql$" | xargs cat >> $SQL

rm -f $DB
spatialite $DB < $SQL

exit 0
