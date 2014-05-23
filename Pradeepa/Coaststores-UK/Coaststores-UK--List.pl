#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
###### Module Initialization ##############
use strict;
use LWP::UserAgent;
use HTML::Entities;
use URI::URL;
use HTTP::Cookies;
use DBI;
use DateTime;
#require "/opt/home/merit/Merit_Robots/DBIL.pm";
#require "/opt/home/merit/Merit_Robots/DBIL_Updated/DBIL.pm"; # USER DEFINED MODULE DBIL.PM
require "/opt/home/merit/Merit_Robots/DBILv2/DBIL.pm";
###########################################

#### Variable Initialization ##############
my $robotname = $0;
$robotname =~ s/\.pl//igs;
$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
my $retailer_name=$robotname;
$retailer_name =~ s/\-\-List\s*$//igs;
$retailer_name = lc($retailer_name);
my $Retailer_Random_String='Coa';
my $pid = $$;
my $ip = `/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`;
$ip = $1 if($ip =~ m/inet\s*addr\:([^>]*?)\s+/is);
my $excuetionid = $ip.'_'.$pid;
###########################################

############ Proxy Initialization #########
my $country = $1 if($robotname =~ m/\-([A-Z]{2})\-\-/is);
DBIL::ProxyConfig($country);
###########################################

##########User Agent######################
my $ua=LWP::UserAgent->new(show_progress=>1);
$ua->agent("Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.3 (.NET CLR 3.5.30729)");
$ua->timeout(30); 
$ua->cookie_jar({});
$ua->env_proxy;
###########################################

############Cookie File Creation###########
my ($cookie_file,$retailer_file) = DBIL::LogPath($robotname);
my $cookie = HTTP::Cookies->new(file=>$cookie_file,autosave=>1); 
$ua->cookie_jar($cookie);
###########################################

############Database Initialization########
my $dbh = DBIL::DbConnection();
###########################################

my $select_query = "select ObjectKey from Retailer where name=\'$retailer_name\'";
my $retailer_id = DBIL::Objectkey_Checking($select_query, $dbh, $robotname);

DBIL::RetailerUpdate($retailer_id,$excuetionid,$dbh,$robotname,'start');

#################### For Dashboard #######################################
DBIL::Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'START',$robotname);
#################### For Dashboard #######################################

############ URL Collection ##############
my $url = 'http://www.coast-stores.com/?lng=&ctry=GB';
my $content = get_content($url);
my %hash_id;

if($content=~m/<div[^<]*?id\=\"navigation\"[^>]*?>([\w\W]*?\s*<\/div>\s*<\/div>)/is)  ###Newin ,Clothing, Etc. all Block
{	
	my $part_content=$1;
	while($part_content=~m/level_1\s*\"\s*>([^<]*?)<([\w\W]*?)<\/ul>\s*<\/div>\s*<\/li>\s*(?:<li\s*class\s*\=\s*\"\s*level_1[^>]*?\"|<\/ul>)/igs) ####Newin ,Clothing, Etc. sep Block
	{
		my $menu_1=DBIL::Trim($1);
		my $part_content_url=$2;
		my $temp;
		
		while($part_content_url=~m/<li[^>]*?class\s*\=\s*\"\s*level_2[^>]*?\"[^>]*?>\s*<a[^>]*?href\s*\=\s*\"\s*([^>]*?)\s*\"[^>]*?>\s*([^>]*?)\s*</igs)
		{
			my $menu2_url=$1;
			my $menu2=DBIL::Trim($2);
			
			if($menu_1)
			{
				$temp=$menu_1;
			}
			else
			{
				$menu_1=$temp;
			}
			
			&collect_product($menu2_url,$menu_1,$menu2);
		}
	}
}

#################### For Dashboard #######################################
DBIL::Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);
#################### For Dashboard #######################################

sub collect_product()
{	
	my $List_Page_url=shift;
	my $menu_1=shift;
	my $menu_2=shift;
	
	my $List_Page_conetnt=get_content($List_Page_url);
	
next_page1:
	while($List_Page_conetnt=~m/<p[^<]*?class\=\"product_title\"[^>]*?>\s*<a[^<]*?href\=\"([^<]*?)\"[^>]*?>/igs)
	{
		my $prod_url=$1;
		$prod_url =~ s/amp\;//g;
		
		my $product_object_key;
		my $prod_id=$1 if($prod_url=~m/product\s*\/\s*(\d+)\s*$/is);
		if($hash_id{$prod_id} eq '')
		{
			$product_object_key = DBIL::SaveProduct($prod_url,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
			$hash_id{$prod_id}=$product_object_key;
		}
		$product_object_key=$hash_id{$prod_id};
		
		#Insert Product values
		DBIL::SaveTag('Menu_1',$menu_1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
		
		unless($menu_2=~m/^\s*$/is)
		{
			DBIL::SaveTag('Menu_2',$menu_2,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
		}
		$dbh->commit();
	}
	if($List_Page_conetnt=~m/<a[^<]*?href\=\"([^<]*?)\">\s*Next\s*page\s*<\/a>/is)
	{
		my $next_url=$1;
		$List_Page_conetnt = get_content($next_url);
		goto next_page1;
	}	
}
#TO get Product Page's Content
sub get_content()
{
	my $url=shift;
	my $err_count=0;
	$url=~s/amp\;//igs;
	home:
	my $req = HTTP::Request->new(GET=>"$url");
	$req->header("Accept"=>"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"); 
	$req->header("Content-Type"=>"application/x-www-form-urlencoded");
	my $res = $ua->request($req);	
    $cookie->extract_cookies($res); 
    $cookie->save; 
    $cookie->add_cookie_header($req); 
    my $code = $res->code(); 
    print $code,"\n"; 
    open LL,">>".$retailer_file;
    print LL "$url=>$code\n";
    close LL;
    if($code =~ m/50/is) 
    { 
        #sleep 500; 
        goto home; 
    } 
    if($code =~m/40/is)
	{	
		$err_count++;
		if($err_count<=3)
		{
			sleep(100);
			goto home;	
		}
	}
	elsif($code =~m/50/is)
	{
		$err_count++;
		if($err_count<=3)
		{
			#sleep(100);
			goto home;	
		}
	}
	elsif($code =~m/20/is)
	{
		$content = $res->content;
	}
	return($content);
}
