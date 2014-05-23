#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
###### Module Initialization ##############
use strict;
use DBI;
#require "/opt/home/merit/Merit_Robots/DBIL.pm";
require "/opt/home/merit/Merit_Robots/DBILv3/DBIL.pm";
require "/opt/home/merit/Merit_Robots/Ms_UK.pm";
###########################################

####Variable Initialization##############
my $robotname = $0;
$robotname =~ s/\.pl//igs;
$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
my $retailer_name=$robotname;
my $robotname_detail=$robotname;
my $robotname_list=$robotname;
$robotname_list =~ s/\-\-Detail/--List/igs;
$retailer_name =~ s/\-\-Detail\s*$//igs;
$retailer_name = lc($retailer_name);
my $Retailer_Random_String='Mar';
my $pid = $$;
my $ip = `/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`;
$ip = $1 if($ip =~ m/inet\s*addr\:([^>]*?)\s+/is);
my $excuetionid = $ip.'_'.$pid;
###########################################

############Database Initialization########
# Establishing db connection
my $dbh = DBIL::DbConnection();
###########################################
$retailer_name='m&s-uk';
my $select_query = "select ObjectKey from Retailer where name=\'$retailer_name\'";
my $retailer_id = DBIL::Objectkey_Checking($select_query, $dbh, $robotname);
my ($product_object_key,$product_url);
my $hashref = DBIL::Objectkey_Url($robotname_list, $dbh, $robotname,$retailer_id);
my %hashUrl = %$hashref;
foreach (keys %hashUrl)
{
	$product_object_key = $_;
	$product_url = $hashUrl{$_};
	print "$product_object_key -> $product_url\n";
	&Ms_UK::Ms_UK_DetailProcess($product_object_key,$product_url,$dbh,$robotname,$retailer_id);
}
DBIL::RetailerUpdate($retailer_id,$excuetionid,$dbh,$robotname,'end');
$dbh->commit();
$dbh->disconnect();