#!/usr/bin/perl

require './geoserver-lib.pl';
require './tomcat-lib.pl';

if ($ENV{REQUEST_METHOD} eq "POST") {
	&ReadParseMime();
}else {
	&ReadParse();
	$no_upload = 1;
}


my $geo_ver = get_latest_geoserver_ver();
my $url = &urlize("http://sourceforge.net/projects/geoserver/files/GeoServer/$geo_ver/geoserver-$geo_ver-war.zip");

&redirect("./install_war.cgi?source=2&url=$url&return=%2E%2E%2Fgeohelm%2F&returndesc=Geohelm&caller=geohelm");

&ui_print_footer("", $text{'index_return'});
