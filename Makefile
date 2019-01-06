geonames/$(CNT).zip:
	mkdir -p `dirname $@`
	wget -q http://download.geonames.org/export/dump/$(CNT).zip -O $@
geonames/$(CNT).txt: geonames/$(CNT).zip
	unzip -f $< -d geonames
geonames/$(CNT).sqlite: geonames/$(CNT).txt
	spatialite $@ "CREATE TABLE $(CNT) (geonameid integer primary key, name varchar(200), asciiname varchar(200), alternatenames varchar(10000), latitude real, longitude real, featureclass char(1), featurecode varchar(10), countrycode char(2), cc2 varchar(200), admin1code varchar(20), admin2code varchar(80), admin3code varchar(20), admin4code varchar(20), population bigint, elevation integer, dem integer, timezone varchar(40), modificationdate char(10));"
	spatialite -separator '	' $@ ".import $< $(CNT)"
	spatialite $@ "DELETE FROM $(CNT) WHERE featurecode != 'PPL';"
	spatialite $@ "SELECT AddGeometryColumn('$(CNT)','geom',4326,'POLYGON',2);"
	spatialite $@ "UPDATE $(CNT) SET geom = Buffer(MakePoint(longitude, latitude, 4326),$(BUF))"
	spatialite $@ "DELETE FROM geometry_columns WHERE f_table_name = 'tiles';"
	spatialite $@ "DROP TABLE IF EXISTS tiles;"
	spatialite $@ "CREATE TABLE tiles (gid integer primary key AUTOINCREMENT,qkey varchar(64));"
	spatialite $@ "SELECT AddGeometryColumn('tiles', 'geom' ,4326, 'POLYGON', 'XY');"

ROI/$(CNT).ROI.txt: geonames/$(CNT).sqlite
	mkdir -p `dirname $@`
	ogrinfo $< $(CNT) -sql "select MbrMaxX(geom), MbrMaxY(geom), MbrMinX(geom), MbrMinY(geom) from $(CNT)" | grep -e "MbrMinX(geom) (Real)" -e "MbrMaxX(geom) (Real)" -e "MbrMinY(geom) (Real)" -e "MbrMaxY(geom) (Real)" | awk 'BEGIN{OFS="|"}/MaxX/{maxx=$$4}/MaxY/{maxy=$$4}/MinX/{minx=$$4}/MinY/{miny=$$4; print minx,maxx,miny,maxy}' > $@
