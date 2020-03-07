#! /bin/bash

DB="tilePolygon.JPN.Z19.2020-03-04_10_41_52.sqlite"
ogr2ogr -overwrite -f SQLite $DB osm_natural.gpkg osm_natural_vec #SELECT geom, natural FROM osm_natural WHERE  -where "natural = 'wood'"
ogr2ogr -overwrite -f SQLite $DB exclude.gpkg exclude
spatialite "$DB" <<EOF

SELECT CreateSpatialIndex('tilepolygon','geom');
SELECT CreateSpatialIndex('osm_natural_vec','GEOMETRY');


DROP TABLE IF EXISTS tilepolygon_5percent;
CREATE TABLE tilepolygon_5percent AS

SELECT geom,x,y,z,gadm0,qkey,dn 
FROM  tilepolygon ,osm_natural_vec
WHERE ST_Intersects(ST_Centroid(tilepolygon.geom), osm_natural_vec.GEOMETRY)

ORDER BY RANDOM() 
LIMIT 540

;


INSERT INTO tilepolygon_5percent 

SELECT  geom,x,y,z,gadm0,qkey,dn
 FROM tilepolygon , osm_natural_vec
WHERE NOT ST_Intersects(ST_Centroid(tilepolygon.geom), osm_natural_vec.GEOMETRY)

ORDER BY RANDOM() 
LIMIT 540;

--INSERT INTO geometry_columns VALUES ('tilepolygon_5percent','geom',6,2,4326,0);
EOF
