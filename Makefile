geonames/$(CNT).zip:
	wget -q http://download.geonames.org/export/dump/$(CNT).zip -O $@
geonames/$(CNT).txt: geonames/$(CNT).zip
	unzip $<
