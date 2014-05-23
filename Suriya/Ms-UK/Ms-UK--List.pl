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
require "/opt/home/merit/Merit_Robots/DBILv2/DBIL.pm";
###########################################

#### Variable Initialization ##############
my $robotname = $0;
$robotname =~ s/\.pl//igs;
$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
my $retailer_name=$robotname;
$retailer_name =~ s/\-\-List\s*$//igs;
$retailer_name = lc($retailer_name);
my $Retailer_Random_String='Msu';
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

my $select_query = "select ObjectKey from Retailer where name=\'m&s-uk\'";
my $retailer_id = DBIL::Objectkey_Checking($select_query, $dbh, $robotname);
my %hash_id;
DBIL::RetailerUpdate($retailer_id,$excuetionid,$dbh,$robotname,'start');

my $retailer_name1='m&s-uk';
#################### For Dashboard #######################################
DBIL::Save_mc_instance_Data($retailer_name1,$retailer_id,$pid,$ip,'START',$robotname);
#################### For Dashboard #######################################


my $url='http://www.marksandspencer.com/';
my $content = lwp_get($url);

while($content=~m/<a[^>]*?data\-analyticsid\=\"[^>]*?\"\s*id\=\'[^>]*?\'\s*href\=\"([^>]*?)\">\s*<span>\s*($ARGV[0])\s*<\/span>/igs)
{
	my $menu_1_url=$1;
	my $menu_1=$2;
	my $menu_1_content=lwp_get($menu_1_url);
	my @menu2;
	if($menu_1_content=~m/<ul\s*class\=\"tabs\">\s*([\w\W]*?)\s*<\/ul>/is)
	{
		my $menu_1_block=$1;
		while($menu_1_block=~m/<a[^>]*?href\=\"\#\"\s*data\-analyticsid\=\"[^>]*?\">\s*([^>]*?)\s*<\/a>/igs)
		{
			my $menu_2=DBIL::Trim($1);
			push(@menu2,$menu_2);
		}
	}
	my $i=0;
	while($menu_1_content=~m/<div\s*class\=\"shop\-nav\">\s*([\w\W]*?)\s*<\/ul>\s*<\/div>/igs)
	{
		my $menu_3_block=$1;
		my $menu_2=$menu2[$i];		
		while($menu_3_block=~m/<a[^>]*?href\=\"([^>]*?)\"\s*data\-analyticsid\=\"[^>]*?\"[^>]*?>\s*([^>]*?)\s*<\/a>/igs)
		{
			my $menu_3_url=$1;
			my $menu_3=DBIL::Trim($2);
			my $menu_3_content=lwp_get($menu_3_url);			
			my $url_append;
			if($menu_3_content=~m/<form\s*class\=\"listing\-sort\"\s*id\=\"listing\-sort\-top\"\s*action\=\"([^>]*?)\"\s*data\-components\=[^>]*?>/is)
			{
				$url_append=$1;
				$url_append=~s/\&\#x3a\;/\:/igs;
				$url_append=~s/\&\#x2f\;/\//igs;
				$url_append=~s/\&\#x3f\;/\?/igs;
				$url_append=~s/\&\#x3d\;/\=/igs;
				$url_append=~s/\&amp\;/\&/igs;
			}
			NextPage4:
			while($menu_3_content=~m/itemprop\=\"url\"\s*href\=\"([^>]*?)\">\s*[^>]*?\s*<\/a>\s*<\/h3>/igs)
			{
				my $product_url=$1;
				$product_url=~s/\&\#x3a\;/\:/igs;
				$product_url=~s/\&\#x2f\;/\//igs;
				$product_url=~s/\&\#x3f\;/\?/igs;
				$product_url=~s/\&\#x3d\;/\=/igs;					
				$product_url=$1 if($product_url=~m/([^>]*?)\?/is);				
				
				print "$menu_1 :: $menu_2 :: $menu_3\n";
				my $product_object_key = DBIL::SaveProduct($product_url,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);				
				DBIL::SaveTag('Menu_1',$menu_1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
				DBIL::SaveTag('Menu_2',$menu_2,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
				DBIL::SaveTag('Menu_3',$menu_3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
				$dbh->commit();
			}
			if($menu_3_content=~m/<li>\s*<a\s*href\s*=\"\#link\"\s*class\=\"next\"\s*name\=\"page\"\s*data\-update\-hidden\=\"pageChoice\"\s*data\-auto\-post\=\"click\"\s*data\-value\=\"(\d+)\"\s*>\s*Next\s*<\/a>\s*<\/li>/is)
			{
				my $page_no=$1;
				my $next_page_url=$url_append.'&display=product&resultsPerPage=24&pageChoice='.$page_no;
				$menu_3_content=lwp_get($next_page_url);
				goto NextPage4;
			}
			while($menu_3_content=~m/<div\s*class\=\"head\">\s*<a\s*href\=\"\#\"\s*class\=\"heading\s*open\">\s*((?!Size|Price|Rating|Gender)[^>]*?)\s*<\/a>\s*([\w\W]*?)\s*<\/div>\s*<\/fieldset>/igs)
			{
				my $filter=DBIL::Trim($1);						
				my $filter_block=$2;					
				$filter=~s/\&\#x28\;/\(/igs;
				$filter=~s/\&\#x29\;/\)/igs;					
				while($filter_block=~m/<input\s*type\=\"checkbox\"\s*data\-components\=\'\[\"checkable\"\]\'\s*data\-auto\-post\=\"change\"\s*id\=\"generic\-\d+\"\s*name\=\"([^>]*?)\"\s*class\=\"checked\"\s*\/>\s*<label\s*class\=\"checkbox\-label\"\s*for\=\"generic\-\d+\">\s*<span\s*class\=\"filterOption\">\s*([^>]*?)\s*<\/span>/igs)
				{
					my $filter_pass=$1;
					my $filter_value=$2;
					my $filter_url=$url_append.'&'.$filter_pass.'=on'."&display=product&cachedFilters=".$filter_pass."+0+40+0+40+product+24";					
					my $filter_content=lwp_get($filter_url);
					NextPage1:
					while($filter_content=~m/itemprop\=\"url\"\s*href\=\"([^>]*?)\">\s*[^>]*?\s*<\/a>\s*<\/h3>/igs)
					{
						my $product_url=$1;
						$product_url=~s/\&\#x3a\;/\:/igs;
						$product_url=~s/\&\#x2f\;/\//igs;
						$product_url=~s/\&\#x3f\;/\?/igs;
						$product_url=~s/\&\#x3d\;/\=/igs;							
						$product_url=$1 if($product_url=~m/([^>]*?)\?/is);
						
						print "$menu_1 :: $menu_2 :: $menu_3 :: $filter($filter_value)\n";
						my $product_object_key = DBIL::SaveProduct($product_url,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);				
						DBIL::SaveTag('Menu_1',$menu_1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
						DBIL::SaveTag('Menu_2',$menu_2,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
						DBIL::SaveTag('Menu_3',$menu_3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
						DBIL::SaveTag($filter,$filter_value,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
						$dbh->commit();
					}
					if($filter_content=~m/<li>\s*<a\s*href\s*=\"\#link\"\s*class\=\"next\"\s*name\=\"page\"\s*data\-update\-hidden\=\"pageChoice\"\s*data\-auto\-post\=\"click\"\s*data\-value\=\"(\d+)\"\s*>\s*Next\s*<\/a>\s*<\/li>/is)
					{
						my $page_no=$1;
						my $next_page_url=$filter_url.'&display=product&resultsPerPage=24&pageChoice='.$page_no;
						$filter_content=lwp_get($next_page_url);
						goto NextPage1;
					}
				}
				while($filter_block=~m/<input\s*type\=\"checkbox\"\s*data\-components\=\'\[\"checkable\"\]\'\s*data\-auto\-post\=\"change\"\s*id\=\"[^>]*?\"\s*name\=\"([^>]*?)\"\s*\/>\s*<label\s*class\=\"color\-facet checkbox\-label\"\s*for\=\"[^>]*?\">\s*<span\s*class\=\"filterOption\s*hidden\">\s*\&nbsp\;\s*([^>]*?)\s*<\/span>/igs)
				{
					my $filter_pass=$1;
					my $filter_value=$2;
					# my $filter_url=$url_append.'&'.$filter_pass.'=on';					
					my $filter_url=$url_append.'&'.$filter_pass.'=on'."&display=product&cachedFilters=".$filter_pass."+0+40+0+40+product+24";
					my $filter_content=lwp_get($filter_url);
					NextPage2:
					while($filter_content=~m/itemprop\=\"url\"\s*href\=\"([^>]*?)\">\s*[^>]*?\s*<\/a>\s*<\/h3>/igs)
					{
						my $product_url=$1;
						$product_url=~s/\&\#x3a\;/\:/igs;
						$product_url=~s/\&\#x2f\;/\//igs;
						$product_url=~s/\&\#x3f\;/\?/igs;
						$product_url=~s/\&\#x3d\;/\=/igs;							
						$product_url=$1 if($product_url=~m/([^>]*?)\?/is);
						
						print "$menu_1 :: $menu_2 :: $menu_3 :: $filter($filter_value)\n";
						my $product_object_key = DBIL::SaveProduct($product_url,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);				
						DBIL::SaveTag('Menu_1',$menu_1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
						DBIL::SaveTag('Menu_2',$menu_2,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
						DBIL::SaveTag('Menu_3',$menu_3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);					
						DBIL::SaveTag($filter,$filter_value,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
						$dbh->commit();
					}
					if($filter_content=~m/<li>\s*<a\s*href\s*=\"\#link\"\s*class\=\"next\"\s*name\=\"page\"\s*data\-update\-hidden\=\"pageChoice\"\s*data\-auto\-post\=\"click\"\s*data\-value\=\"(\d+)\"\s*>\s*Next\s*<\/a>\s*<\/li>/is)
					{
						my $page_no=$1;
						my $next_page_url=$filter_url.'&display=product&resultsPerPage=24&pageChoice='.$page_no;
						$filter_content=lwp_get($next_page_url);
						goto NextPage2;
					}
				}
				while($filter_block=~m/<input\s*type\=\"radio\"\s*data\-components\=\'\[\"checkable\"\]\'\s*value\=\"([^>]*?)\"\s*data\-auto\-post\=\"change\"\s*id\=\"radioId\-\d+\"\s*name\=\"([^>]*?)\"\s*\/>\s*<label\s*class\=\"radio\-label\"\s*for\=\"radioId\-\d+\">\s*<span\s*class\=\"filterOption\">\s*([^>]*?)\s*<\/span>/igs)
				{
					my $filter_pass=$2.'='.$1;
					my $filter_value=$3;
					# my $filter_url=$url_append.'&'.$filter_pass;					
					my $filter_url=$url_append.'&'.$filter_pass.'=on'."&display=product&cachedFilters=".$filter_pass."+0+40+0+40+product+24";
					my $filter_content=lwp_get($filter_url);
					NextPage3:
					while($filter_content=~m/itemprop\=\"url\"\s*href\=\"([^>]*?)\">\s*[^>]*?\s*<\/a>\s*<\/h3>/igs)
					{
						my $product_url=$1;
						$product_url=~s/\&\#x3a\;/\:/igs;
						$product_url=~s/\&\#x2f\;/\//igs;
						$product_url=~s/\&\#x3f\;/\?/igs;
						$product_url=~s/\&\#x3d\;/\=/igs;							
						$product_url=$1 if($product_url=~m/([^>]*?)\?/is);
						
						print "$menu_1 :: $menu_2 :: $menu_3 :: $filter($filter_value)\n";
						my $product_object_key = DBIL::SaveProduct($product_url,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);				
						DBIL::SaveTag('Menu_1',$menu_1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
						DBIL::SaveTag('Menu_2',$menu_2,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
						DBIL::SaveTag('Menu_3',$menu_3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
						DBIL::SaveTag($filter,$filter_value,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
						$dbh->commit();
					}
					if($filter_content=~m/<li>\s*<a\s*href\s*=\"\#link\"\s*class\=\"next\"\s*name\=\"page\"\s*data\-update\-hidden\=\"pageChoice\"\s*data\-auto\-post\=\"click\"\s*data\-value\=\"(\d+)\"\s*>\s*Next\s*<\/a>\s*<\/li>/is)
					{
						my $page_no=$1;
						my $next_page_url=$filter_url.'&display=product&resultsPerPage=24&pageChoice='.$page_no;
						$filter_content=lwp_get($next_page_url);
						goto NextPage3;
					}
				}
			}
		}
		$i++;
	}
}
$dbh->commit();
#################### For Dashboard #######################################
DBIL::Save_mc_instance_Data($retailer_name1,$retailer_id,$pid,$ip,'STOP',$robotname);
#################### For Dashboard #######################################

#system(`/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl /opt/home/merit/Merit_Robots/Ms-UK--Detail.pl  &`);

sub lwp_get()
{
	my $url=$_[0];
	my $code_count=0;
    REPEAT: 
    my $req = HTTP::Request->new(GET=>$url); 
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
		if($code_count<3)
		{
			sleep 1;
			$code_count++;
			goto REPEAT;			
		}		
    }	
	return($res->content());
}
