BEGIN { push(@INC, ".."); };
use WebminCore;

require '../webmin/webmin-lib.pl';	#require
foreign_require('software', 'software-lib.pl');
foreign_require('postgresql', 'postgresql-lib.pl');

sub check_pg_repo_apt(){
	if( -f '/etc/apt/sources.list.d/pgdg.list'){
		return 1;
	}
	return 0;
}

sub check_pg_repo_yum{
	my $pg_ver = $_[0];
	my $distro = lc $_[1];
	my $pg_ver2;
	($pg_ver2 = $pg_ver) =~ s/\.//;

	if($distro eq 'fedora'){
		$distro = "fedora";
	}else{
		$distro = "redhat";	#centos, redhat, scientific
	}

	my @pinfo = software::package_info("pgdg-$distro-repo", undef, );
	if(@pinfo){
		return 1;
	}
	return 0;
}

sub save_repo_ver(){
	my $pg_ver=$_[0];

	open(my $fh, '>', $module_config_directory.'/repo_ver.txt') or die "open:$!";
	print $fh "repo_ver=$pg_ver\n";
	close $fh;
}

sub get_installed_pg_version(){
	my %pg_env;

	if(! -f $module_config_directory.'/repo_ver.txt'){
		return undef;	#no repo file
	}

	read_env_file($module_config_directory.'/repo_ver.txt', \%pg_env);
	return $pg_env{'repo_ver'};
}

sub have_pg_repo(){
	my $found = 0;	#1 if repo is found

	my $pg_ver = get_installed_pg_version();
	if (!$pg_ver){
		return 0;
	}

	my %osinfo = &detect_operating_system();
	if( $osinfo{'os_type'} =~ /redhat/i){	#other redhat

		my @temp = split /\s/, $osinfo{'real_os_type'};
		my $distro = $temp[0];
		if($distro eq "Scientific"){
			$distro = 'sl';
		}

		$found = check_pg_repo_yum($pg_ver, $distro);
	}elsif( $osinfo{'os_type'} =~ /debian/i){
		$found = check_pg_repo_apt();
	}

	return $found;
}

sub pg_list_databases{
	local $t = &postgresql::execute_sql_safe('template1', 'select datname from pg_database order by datname');
	return sort { lc($a) cmp lc($b) } map { $_->[0] } @{$t->{'data'}};
}

sub get_shp2pgsql_pkg_name{
	my $pg_ver = $_[0];

	my %osinfo = &detect_operating_system();
	if( $osinfo{'os_type'} =~ /debian/i){	#debian, ubuntu, etc
		return 'postgis';
	}elsif( $osinfo{'os_type'} =~ /arch/i){	#Arch
		return 'postgis';
	}elsif($osinfo{'os_type'} =~ /suse/i){	#Suse
		my $pg_ver2;
		($pg_ver2 = $pg_ver) =~ s/\.//;
		return "postgresql$pg_ver2-postgis postgresql$pg_ver2-postgis-utils";
	}elsif( $osinfo{'os_type'} =~ /redhat/i){	#other redhat

		my $pg_ver2;
		($pg_ver2 = $pg_ver) =~ s/\.//;

		my $cmd_out='';
		my $cmd_err='';
		my $out;
		if(has_command('dnf')){
			$out = &execute_command("dnf search postgis", undef, \$cmd_out, \$cmd_err, 0, 0);
		}else{
			$out = &execute_command("yum --disablerepo=* --enablerepo=pgdg$pg_ver2 search postgis", undef, \$cmd_out, \$cmd_err, 0, 0);
		}

		if($out != 0){
			&error("Error: yum: $cmd_err");
			return 1;
		}

		my @lines = split /\n/, $cmd_out;
		my $pkg = undef;
		foreach my $line (@lines){
			if($line =~ /^(postgis[0-9_]+-client)\.x86_64 :/i){
				$pkg = $1;
			}
		}
		return $pkg
	}

	return undef;
}
