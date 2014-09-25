#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
########## MODULE INITIALIZATION ###########

use strict;
use POSIX;
use HTTP::Cookies;
use LWP::UserAgent;
use HTML::Entities;
use WWW::Mechanize;
use URI::Escape;
use LWP::Simple;
use Encode qw(encode);
use DateTime;
require "/opt/home/merit/Merit_Robots/DBILv2/DBIL.pm"; # USER DEFINED MODULE DBIL.PM

###########################################

######### VARIABLE INITIALIZATION ##########

my $robotname=$0;
$robotname=~s/\.pl//igs;
$robotname =$1 if($robotname=~m/[^>]*?\/*([^\/]+?)\s*$/is);
my $retailer_name=$robotname;
$retailer_name=~s/\-\-List\s*$//igs;
$retailer_name=lc($retailer_name);
my $Retailer_Random_String='Msu';
my $pid=$$;
my $ip=`/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`;
$ip=$1 if($ip=~m/inet\s*addr\:([^>]*?)\s+/is);
my $excuetionid=$ip.'_'.$pid;

#############################################

######### PROXY INITIALIZATION ##############
my $country=$1 if($robotname=~m/\-([A-Z]{2})\-\-/is);
&DBIL::ProxyConfig($country);
#############################################

######### USER AGENT #######################

my $ua=LWP::UserAgent->new(show_progress=>1);
$ua->agent("Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.3 (.NET CLR 3.5.30729)");
$ua->timeout(30); 
$ua->cookie_jar({});
$ua->env_proxy;

############################################

######### COOKIE FILE CREATION ############
my ($cookie_file,$retailer_file)=&DBIL::LogPath($robotname);
my $cookie=HTTP::Cookies->new(file=>$cookie_file,autosave=>1); 
$ua->cookie_jar($cookie);
############################################

######### ESTABLISHING DB CONNECTION #######
my $dbh=&DBIL::DbConnection();
############################################
 
my $select_query="select ObjectKey from Retailer where name=\'m&s-uk\'";
my $retailer_id=&DBIL::Objectkey_Checking($select_query, $dbh, $robotname);

#ROBOT START PROCESS TIME STORED INTO RETAILER TABLE FOR RUNTIME MANIPULATION
&DBIL::RetailerUpdate($retailer_id,$excuetionid,$dbh,$robotname,'start');

my $retailer_name1='m&s-uk';
#################### For Dashboard #######################################
DBIL::Save_mc_instance_Data($retailer_name1,$retailer_id,$pid,$ip,'START',$robotname);
#################### For Dashboard #######################################
my %validate;

my $url = "http://www.marksandspencer.com/";
my $content = &lwp_get($url);
###### <-- LIST ROBOT - BEGIN --> ########

while($content =~ m/class\=\"mega\-trigger\"\s*>\s*<a[^>]*?href\=\"([^>]*?)\">\s*<span>\s*($ARGV[0])\s*<\/span>/igs) ## Main Menu Regex
{
	my $listurl = $1;
	my $menu1 = &clean($2);  ##Women
	# next unless($menu1 =~ m/Women/is);
	my $menu_1_content = &lwp_get($listurl);
	
	my @menu2;
	if($menu_1_content=~m/<div\s*class\=\"controls\s*g12\">\s*([\w\W]*?)\s*<\/div>\s*<\/div>/is)
	{
		my $menu_1_block=$1;
		while($menu_1_block=~m/<a[^>]*?href\=\"\#\"\s*data\-analyticsid\=\"[^>]*?\">\s*([^>]*?)\s*<\/a>/igs)
		{
			my $menu_2=&clean($1);
			# next if($menu_2!~m/SUITS/is);
			push(@menu2,$menu_2);   ###Clothing., Shoes & Accessories,,, Bra soon...
		}
	}
	my $i = 0;
	while($menu_1_content =~ m/<li\s*class\=\"[^>]*?\s*panel\"\s*role\=\"tabpanel\">\s*([\w\W]*?\s*<\/div>)\s*<\/li>/igs)
	{
		my $menu1block = $1;
		while($menu1block =~ m/<h2>\s*([\w\W]*?)\s*<\/h2>([\w\W]*?)<\/ul>\s*<\/div>\s*<\/div>/igs)
		{
			my $menu3 = &clean($1);    ##### Categories, Explore our brand
			my $menu1block2 = $2;
			# next unless($menu3 =~ m/Bags/is);
			while($menu1block2 =~ m/href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/a>/igs)
			{
				my $listurl2 = $1;
				my $menu4 = &clean($2);  ## New IN, Blazers, Cashmers....
				# print "$menu1->$menu2[$i]->$menu3->$menu4\n";
				# next unless($menu2[$i] =~ m/Accessories/is && $menu3 =~ m/Accessories/is && $menu4 =~ m/Jewellery/is);
				# next unless($menu4 =~ m/petite/is);
				my $menu2content = &lwp_get($listurl2);
				&URL_Collection($menu2content, $menu1, $menu2[$i], $menu3, $menu4, '', '');
=cut
				# if($menu2content =~ m/<div\s*class\=\"inner\-box\">([\w\W]*?<\/ul>\s*)<\/div>\s*<\/div>\s*<\/div>\s*<\/div>\s*<div\s*class\=\"control\-bar\-wrapper\">/is)
				if($menu2content !~ m/<li\s*class\=\"active\">\s*<a>\s*$menu4\s*<\/a>/is)
				{
					if($menu2content =~ m/<div\s*class\=\"inner\-box\">([\w\W]*?)<div\s*class\=\"control\-bar\-wrapper\">/is)
					{
						my $menu2subcat = $1;
						my $ck2 = 0;
						while($menu2subcat =~ m/href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/a>/igs)
						{
							my $listurl3 = $1;
							my $menu5 = &clean($2);  ## Shoes & Sandals, Clothing, Bags & Accessories.
							my $tmenu5 = quotemeta($menu5);
							# print "Menu5 :: $menu5\n\n\n"; #exit;
							next if($menu5 =~ m/Guide/is);
							# next unless($menu5 =~ m/Total\s*Support/is);
							my $menu3content = &lwp_get($listurl3);
							if($menu3content !~ m/<li\s*class\=\"active\">\s*<a>\s*$tmenu5\s*<\/a>/is)
							{
								# print "I'm here\n";
								my $ck = 0;
								if($menu3content =~ m/<div\s*class\=\"inner\-box\">([\w\W]*?)<\/div>\s*<\/div>/is)
								{
									my $menu3subcat = $1;
									while($menu3subcat =~ m/href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/a>/igs)
									{
										my $listurl4 = $1;
										my $menu6 = &clean($2);  ## Shoes.
										my $menu4content = &lwp_get($listurl4);
										$ck++;
										$ck2++;
										&URL_Collection($menu4content, $menu1, $menu2[$i], $menu3, $menu4, $menu5, $menu6);
									}
									if($ck == 0)
									{
										print "New Format\n\n $menu1, $menu2[$i], $menu3, $menu4, $menu5 \n\n";
										$ck2++;
										&URL_Collection($menu3content, $menu1, $menu2[$i], $menu3, $menu4, $menu5, '');
									}
								}
								else
								{
									$ck2++;
									&URL_Collection($menu3content, $menu1, $menu2[$i], $menu3, $menu4, $menu5, '');
								}
							}
							else
							{
								$ck2++;
								&URL_Collection($menu3content, $menu1, $menu2[$i], $menu3, $menu4, $menu5, '');
							}
						}
						if($ck2 == 0)
						{
							&URL_Collection($menu2content, $menu1, $menu2[$i], $menu3, $menu4, '', '');
						}
					}
					else
					{
						&URL_Collection($menu2content, $menu1, $menu2[$i], $menu3, $menu4, '', '');
					}
				}
				# else
				# {
					# print "Else Part \n\n"; exit;
					# &URL_Collection($menu2content, $menu1, $menu2[$i], $menu3, $menu4, '', '');
				# }
=cut				
			}
		}
		$i++;
	}
}
sub URL_Collection()
{
	my ($menu_3_content, $menu_1, $menu_2, $menu_3, $menu_4, $menu_5, $menu_6) = @_;
	my $url_append;
	if($menu_3_content=~m/<form\s*class\=\"listing\-sort\"\s*id\=\"listing\-sort\-top\"\s*action\=\"([^>]*?)\"\s*data\-components\=/is)
	{
		$url_append = decode_entities($1);
	}
	if($menu_3_content =~ m/div\s*class\=\"head\">\s*<a\s*href\=\"\#\"\s*class\=\"heading\s*open\">\s*((?!Size|Price|Rating|Gender)[^>]*?)\s*<\/a>\s*([\w\W]*?)\s*<\/div>\s*<\/fieldset>/is)
	{
		while($menu_3_content=~m/<div\s*class\=\"head\">\s*<a\s*href\=\"\#\"\s*class\=\"heading\s*open\">\s*((?!Size|Price|Rating|Gender)[^>]*?)\s*<\/a>\s*([\w\W]*?)\s*<\/div>\s*<\/fieldset>/igs)
		{
			# print "Block1\n";
			my $filter=&clean($1);						
			my $filter_block=$2;					
			$filter=~s/\&\#x28\;/\(/igs;
			$filter=~s/\&\#x29\;/\)/igs;
			next if($filter =~ m/Rating/is);
			while($filter_block=~m/<input\s*type\=\"checkbox\"[^>]*?name\=\"([^>]*?)\"\s*class\=\"checked\"\s*\/>\s*<label\s*class\=\"checkbox[^>]*?>\s*<span\s*class\=\"filterOption\">\s*([^>]*?)\s*<\/span>/igs)
			{
				my $filter_pass=$1;
				my $filter_value=$2;
				my $filter_url=$url_append.'&'.$filter_pass.'=on'."&display=product&cachedFilters=".$filter_pass."+0+40+0+40+product+24";
				# print "Block1\n\n";
				$filter_url =~ s/\s+//igs;
				my $filter_content = &lwp_get($filter_url);
				NextPage1:
				while($filter_content=~m/itemprop\=\"url\"\s*href\=\"([^>]*?)\">\s*[^>]*?\s*<\/a>\s*<\/h3>/igs)
				{
					my $product_url=decode_entities($1);
					$product_url=$1 if($product_url=~m/([^>]*?)\?/is);
					
					&db_insert($product_url,$menu_1,$menu_2,$menu_3,$menu_4,$menu_5,$menu_6,$filter,$filter_value);
				}
				if($filter_content=~m/<li>\s*<a\s*href\s*=\"\#link\"\s*class\=\"next\"\s*name\=\"page\"\s*data\-update\-hidden\=\"pageChoice\"\s*data\-auto\-post\=\"click\"\s*data\-value\=\"(\d+)\"\s*>\s*Next\s*<\/a>\s*<\/li>/is)
				{
					my $page_no=$1;
					my $next_page_url=$filter_url.'&display=product&resultsPerPage=24&pageChoice='.$page_no;
					$filter_content=lwp_get($next_page_url);
					goto NextPage1;
				}
			}
			## Only Color
			while($filter_block=~m/<input\s*type\=\"checkbox\"\s*[^>]*?name\=\"([^>]*?)\"\s*\/>\s*<label\s*style[^>]*?>\s*<span\s*class\=\"filterOption\s*hidden\">\s*\&nbsp\;\s*([^>]*?)\s*<\/span>/igs)
			{
				my $filter_pass=$1;
				my $filter_value=$2;
				my $filter_url=$url_append.'&'.$filter_pass.'=on'."&display=product&cachedFilters=".$filter_pass."+0+40+0+40+product+24";
				$filter_url =~ s/\s+//igs;
				my $filter_content=lwp_get($filter_url);
				NextPage4:
				while($filter_content=~m/itemprop\=\"url\"\s*href\=\"([^>]*?)\">\s*[^>]*?\s*<\/a>\s*<\/h3>/igs)
				{
					my $product_url=decode_entities($1);
					$product_url=$1 if($product_url=~m/([^>]*?)\?/is);
					
					&db_insert($product_url,$menu_1,$menu_2,$menu_3,$menu_4,$menu_5,$menu_6,$filter,$filter_value);
				}
				if($filter_content=~m/<li>\s*<a\s*href\s*=\"\#link\"\s*class\=\"next\"\s*name\=\"page\"\s*data\-update\-hidden\=\"pageChoice\"\s*data\-auto\-post\=\"click\"\s*data\-value\=\"(\d+)\"\s*>\s*Next\s*<\/a>\s*<\/li>/is)
				{
					my $page_no=$1;
					my $next_page_url=$filter_url.'&display=product&resultsPerPage=24&pageChoice='.$page_no;
					$filter_content=lwp_get($next_page_url);
					goto NextPage4;
				}
			}
			while($filter_block=~m/<input\s*type\=\"radio\"[^>]*?value\=\"([^>]*?)\"[^>]*?name\=\"([^>]*?)\"\s*\/>\s*<label\s*class\=\"radio\-label\"\s*for\=\"radioId\-\d+\">\s*<span\s*class\=\"filterOption\">\s*([^>]*?)\s*<\/span>/igs)
			{
				my $filter_pass=$2.'='.$1;
				my $filter_value=$3;
				# my $filter_url=$url_append.'&'.$filter_pass.'=on'."&display=product&cachedFilters=".$filter_pass."+0+40+0+40+product+24";
				my $filter_url=$url_append.'&'.$filter_pass."&display=product&cachedFilters=".$filter_pass."+0+40+0+40+product+24";
				$filter_url =~ s/\s+//igs;
				my $filter_content=lwp_get($filter_url);
				NextPage3:
				while($filter_content=~m/itemprop\=\"url\"\s*href\=\"([^>]*?)\">\s*[^>]*?\s*<\/a>\s*<\/h3>/igs)
				{
					my $product_url=decode_entities($1);
					$product_url=$1 if($product_url=~m/([^>]*?)\?/is);
					
					&db_insert($product_url,$menu_1,$menu_2,$menu_3,$menu_4,$menu_5,$menu_6,$filter,$filter_value);
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
	else
	{
		NextPageAV:
		while($menu_3_content =~ m/itemprop\=\"url\"\s*href\=\"([^>]*?)\">\s*[^>]*?\s*<\/a>\s*<\/h3>/igs)
		{
			my $product_url=decode_entities($1);
			$product_url=$1 if($product_url=~m/([^>]*?)\?/is);
			&db_insert($product_url,$menu_1,$menu_2,$menu_3,$menu_4,$menu_5,$menu_6,'','');
		}
		if($menu_3_content =~ m/<li>\s*<a\s*href\s*=\"\#link\"\s*class\=\"next\"\s*name\=\"page\"\s*data\-update\-hidden\=\"pageChoice\"\s*data\-auto\-post\=\"click\"\s*data\-value\=\"(\d+)\"\s*>\s*Next\s*<\/a>\s*<\/li>/is)
		{
			my $nexturl = $1;
			$nexturl = $url_append.'&pageChoice='.$nexturl;
			$menu_3_content=lwp_get($nexturl);
			goto NextPageAV;
		}
	}
}

sub db_insert()
{
	my ($product_url, $menu1, $menu2, $menu3, $menu4, $menu5, $menu6, $filter, $filtervalue) = @_;
	print "$menu1, $menu2, $menu3, $menu4, $menu5, $menu6, $filter, $filtervalue\n";
	my $product_object_key;
	
	if($validate{$product_url} eq '')
	{ # CHECKING WHETHER PRODUCT URL ALREADY AVAILABLE IN THE HASH TABLE
		$product_object_key=&DBIL::SaveProduct($product_url,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid); # GENERATING UNIQUE PRODUCT ID
		$validate{$product_url}=$product_object_key; # STORING PRODUCT_ID INTO HASH TABLE
	}
	$product_object_key=$validate{$product_url}; # USING EXISTING PRODUCT_ID IF THE HASH TABLE CONTAINS THIS URL
	
	unless($menu1=~m/^\s*$/is)
	{
		DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
	}
	unless($menu2=~m/^\s*$/is)
	{
		DBIL::SaveTag('Menu_2',$menu2,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
	}
	unless($menu3=~m/^\s*$/is)
	{
		DBIL::SaveTag('Menu_3',$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
	}
	unless($menu4=~m/^\s*$/is)
	{
		DBIL::SaveTag('Menu_4',$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
	}
	unless($menu5=~m/^\s*$/is)
	{
		DBIL::SaveTag('Menu_5',$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
	}
	unless($menu6=~m/^\s*$/is)
	{
		DBIL::SaveTag('Menu_6',$menu6,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
	}
	unless($filtervalue=~m/^\s*$/is)
	{
		DBIL::SaveTag($filter,$filtervalue,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
	}
	$dbh->commit();	
	
	if($product_url=~m/\/p\/ds/is)
	{
		&db_insert_multi_item($product_url, $menu1, $menu2, $menu3, $menu4, $menu5, $menu6, $filter, $filtervalue);
	}
}

sub db_insert_multi_item()
{
	my ($product_url, $menu1, $menu2, $menu3, $menu4, $menu5, $menu6, $filter, $filtervalue)=@_;
	
	my $product_url_content=lwp_get($product_url); 
	my $product_object_key;
	
	while($product_url_content=~m/<a[^>]*?href\s*\=\s*\"([^>]*?)\"[^>]*?>[^>]*?<\/a>\s*<\/div>\s*<input[^>]*?>\s*<div[^>]*? class\s*\=\s*\"product\"[^>]*?>/igs)
	{
		my $product_url1=$1;
		$product_url1=&clean($product_url1);
		
		if($validate{$product_url1} eq '')
		{ # CHECKING WHETHER PRODUCT URL ALREADY AVAILABLE IN THE HASH TABLE
			$product_object_key=&DBIL::SaveProduct($product_url1,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid); # GENERATING UNIQUE PRODUCT ID
			$validate{$product_url1}=$product_object_key; # STORING PRODUCT_ID INTO HASH TABLE
		}
		$product_object_key=$validate{$product_url1}; # USING EXISTING PRODUCT_ID IF THE HASH TABLE CONTAINS THIS URL
		
		unless($menu1=~m/^\s*$/is)
		{
			DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
		}
		unless($menu2=~m/^\s*$/is)
		{
			DBIL::SaveTag('Menu_2',$menu2,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
		}
		unless($menu3=~m/^\s*$/is)
		{
			DBIL::SaveTag('Menu_3',$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
		}
		unless($menu4=~m/^\s*$/is)
		{
			DBIL::SaveTag('Menu_4',$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
		}
		unless($menu5=~m/^\s*$/is)
		{
			DBIL::SaveTag('Menu_5',$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
		}
		unless($menu6=~m/^\s*$/is)
		{
			DBIL::SaveTag('Menu_6',$menu6,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
		}
		unless($filtervalue=~m/^\s*$/is)
		{
			DBIL::SaveTag($filter,$filtervalue,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
		}
		$dbh->commit();
	}
}

################### For Dashboard #######################################
DBIL::Save_mc_instance_Data($retailer_name1,$retailer_id,$pid,$ip,'STOP',$robotname);
################### For Dashboard #######################################

sub lwp_get(){ # FETCH SOURCE PAGE CONTENT FOR THE GIVEN URL
	my $url=shift;
	my $rerun_count=0;
	$url=~s/^\s+|\s+$//g;
	Repeat:
	my $request=HTTP::Request->new(GET=>$url);
	$request->header("Accept"=>"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"); 
    $request->header("Content-Type"=>"application/x-www-form-urlencoded");
	my $response=$ua->request($request);
	$cookie->extract_cookies($response);
	$cookie->save;
	$cookie->add_cookie_header($request);
	my $code=$response->code;
	
	######## WRITING LOG INTO /var/tmp/Retailer/$retailer_file #######
	
	open JJ,">>$retailer_file";
	print JJ "$url->$code\n";
	close JJ;
	
	##################################################################
	
	my $content;
	if($code=~m/20/is){
		$content=$response->content;
		return $content;
	}
	elsif($code=~m/30/is){
		my $loc=$response->header('location');                
        $loc=decode_entities($loc);    
        my $loc_url=url($loc,$url)->abs;        
        $url=$loc_url;
        goto Repeat;
	}
	elsif($code=~m/40/is){
		if($rerun_count <= 3){
			$rerun_count++;			
			goto Repeat;
		}
		return 1;
	}
	else{
		if($rerun_count <= 3){
			$rerun_count++;			
			goto Repeat;
		}
		return 1;
	}
}

sub clean()
{
	my $var=shift;
	$var=~s/<[^>]*?>/ /igs;	
	$var=~s/\&nbsp\;|amp\;/ /igs;
	$var=~s/\\n\s*$//igs;
	$var=decode_entities($var);
	$var=~s/\s+/ /igs;
	return ($var);
}
