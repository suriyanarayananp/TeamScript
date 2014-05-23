#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
###### Module Initialization ##############
# use strict;
use LWP::UserAgent;
use HTML::Entities;
use URI::URL;
use HTTP::Cookies;
use DBI;
use DateTime;
# require "/opt/home/merit/Merit_Robots/DBIL.pm"; # USER DEFINED MODULE DBIL.PM
require "/opt/home/merit/Merit_Robots/DBILv2/DBIL.pm"; # USER DEFINED MODULE DBIL.PM
###########################################

#### Variable Initialization ##############
my $robotname = $0;
$robotname =~ s/\.pl//igs;
$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
my $retailer_name=$robotname;
$retailer_name =~ s/\-\-List\s*$//igs;
$retailer_name = lc($retailer_name);
my $Retailer_Random_String='Zal';
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

# ############Database Initialization########
my $dbh = DBIL::DbConnection();
# my $mqh = DBIL::MqConnection();
# ###########################################
 
my $select_query = "select ObjectKey from Retailer where name=\'$retailer_name\'";
my $retailer_id = DBIL::Objectkey_Checking($select_query,$dbh,$robotname);

#################### For Dashboard #######################################
DBIL::Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'START',$robotname);
#################### For Dashboard #######################################

############ URL Collection ##############   
my $content = &lwp_get("http://www.zalando.co.uk/"); 
   $content = &lwp_get($ARGV[0]); 
my $menu1 = $ARGV[1];
my $menu2 = $ARGV[2];
my $menu3 = $ARGV[3];
if($content =~ m/class\=\"parentCat\">\s*<span\s*class\=\"isActive\s*iconSprite\">\s*([^>]*?)\s*<([\w\W]*?)<\/li>\s*<\/ul>\s*<\/li>/is)
{
	my $menu3  = &clean($1);
	my $cont2_sub = $2;
	while($cont2_sub =~ m/href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*</igs)
	{
		my $catlink3 = $1;
		my $menu4 = &clean($2); #Menu3 -> Bra
		# print "Menu4 ==> $menu4\n";
		# next if($menu4 !~ m/Coats/is);
		$catlink3 = "http://www.zalando.co.uk/".$catlink3 unless($catlink3 =~ m/^http/is);
		print "$menu3->$menu4\n";
		my $subcontent = lwp_get($catlink3); 
		if($subcontent =~ m/class\=\"parentCat\">\s*<span\s*class\=\"isActive\s*iconSprite\">\s*([^>]*?)\s*<([\w\W]*?)<\/li>\s*<\/ul>\s*<\/li>/is)
		{
			my $menu4  = &clean($1);
			my $cont3_sub = $2;
			while($cont3_sub =~ m/href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*</igs)
			{
				my $catlink4 = $1;
				my $menu5 = &clean($2); #Menu5 -> Balcontee Bar
				# print "Menu5 => $menu5\n";
				# next if($menu5 !~ m/Down\s*Coats/is);
				$catlink4 = "http://www.zalando.co.uk/".$catlink4 unless($catlink4 =~ m/^http/is);
				my $cont4 = lwp_get($catlink4); 
				while($cont4 =~ m/<div\s*class\=\"filter\">\s*<div\s*class\=\"title\">\s*<label>\s*([^>]*?)\s*<\/label>\s*<\/div>([\w\W]*?)<\/div>/igs)
				{
					my $menu6 = &clean($1);
					# print "Menu6 ==> $menu6\n";
					my $cont5 = $2;
					next if($menu6 =~ m/Category|More\s*categories|Size|Price|You\s*might\s*also\s*like\s*|Free\s*Delivery|Brand|Colour/is);
					while($cont5 =~ m/href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<|value\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*</igs)
					{
						my $catlink5 = $1.$3;
						my $menu7 = &clean($2.$4);
						$catlink5 = "http://www.zalando.co.uk/".$catlink5 unless($catlink5 =~ m/^http/is);
						my $cont6 = &lwp_get($catlink5); 
						&collect_product($menu1,$menu2,$menu3,$menu4,$menu5,$menu6,$menu7,$cont6);
					}
				}
				if($cont4 =~ m/<span\s*class\=\"left\">\s*((?!Brand|Size|Price)[^>]*?)\s*<([\w\W]*?)<\/div>\s*<\/div>/is)
				{
					my $menu6 = &clean($1);
					my $cont5 = $2;
					# open ss,">zalando_Test.html";
					# print ss $cont5;
					# close ss;
					# print "Menu6=> $menu6\n";
					while($cont5 =~ m/<a\s*class\=\"([^>]*?)\"[^>]*?href\=\"\/([^>]*?)\"[^>]*?>/igs)
					{
						my $menu7 = &clean($1);
						my $catlink5 = $2;		
						# next if($menu7 !~ m/Gray/is);						
						$catlink5 = "http://www.zalando.co.uk/".$catlink5 unless($catlink5 =~ m/^http/is);
						my $cont6 = &lwp_get($catlink5); 
						# open ss,">zalando_Test2.html";
						# print ss $cont6;
						# close ss;
						&collect_product($menu1,$menu2,$menu3,$menu4,$menu5,$menu6,$menu7,$cont6);
					}
					while($cont5 =~ m/<a[^>]*?href\=\"\/([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/a>/igs)
					{
						my $catlink5 = $1;
						my $menu7 = &clean($2);
						# next if($menu7 !~ m/Gray/is);
						$catlink5 = "http://www.zalando.co.uk/".$catlink5 unless($catlink5 =~ m/^http/is);
						my $cont6 = &lwp_get($catlink5); 
						# open ss,">zalando_Test2.html";
						# print ss $cont6;
						# close ss;
						&collect_product($menu1,$menu2,$menu3,$menu4,$menu5,$menu6,$menu7,$cont6);
					}
				}
			}
		}
		else
		{
			while($subcontent =~ m/<div\s*class\=\"filter\">\s*<div\s*class\=\"title\">\s*<label>\s*([^>]*?)\s*<\/label>\s*<\/div>([\w\W]*?)<\/div>/igs)
			{
				my $menu6 = &clean($1);
				my $cont5 = $2;
				next if($menu6 =~ m/Category|More\s*categories|Size|Price|You\s*might\s*also\s*like\s*|Free\s*Delivery|Brand|Colour/is);
				while($cont5 =~ m/href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<|value\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*</igs)
				{
					my $catlink5 = $1.$3;
					my $menu7 = &clean($2.$4);
					$catlink5 = "http://www.zalando.co.uk/".$catlink5 unless($catlink5 =~ m/^http/is);
					my $cont6 = &lwp_get($catlink5); 
					&collect_product($menu1,$menu2,$menu3,$menu4,'',$menu6,$menu7,$cont6);
				}
			}
			if($subcontent =~ m/<span\s*class\=\"left\">\s*((?!Brand|Size|Price)[^>]*?)\s*<([\w\W]*?)<\/div>\s*<\/div>/is)
			{
				my $menu6 = &clean($1);
				my $cont5 = $2;				
				while($cont5 =~ m/<a\s*class\=\"([^>]*?)\"[^>]*?href\=\"\/([^>]*?)\"[^>]*?>/igs)
				{					
					my $menu7 = &clean($1);
					my $catlink5 = $2;
					$catlink5 = "http://www.zalando.co.uk/".$catlink5 unless($catlink5 =~ m/^http/is);
					my $cont6 = &lwp_get($catlink5); 
					&collect_product($menu1,$menu2,$menu3,$menu4,'',$menu6,$menu7,$cont6);
				}
				while($cont5 =~ m/<a[^>]*?href\=\"\/([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/a>/igs)
				{
					my $catlink5 = $1;
					my $menu7 = &clean($2);
					$catlink5 = "http://www.zalando.co.uk/".$catlink5 unless($catlink5 =~ m/^http/is);
					my $cont6 = &lwp_get($catlink5); 
					&collect_product($menu1,$menu2,$menu3,$menu4,'',$menu6,$menu7,$cont6);
				}
			}
		}
	}
}
else
{
	while($content =~ m/<div\s*class\=\"filter\">\s*<div\s*class\=\"title\">\s*<label>\s*([^>]*?)\s*<\/label>\s*<\/div>([\w\W]*?)<\/div>/igs)
	{
		my $menu6 = &clean($1);
		my $cont5 = $2;
		next if($menu6 =~ m/Category|More\s*categories|Size|Price|You\s*might\s*also\s*like\s*|Free\s*Delivery|Brand|Colour/is);
		while($cont5 =~ m/href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<|value\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*</igs)
		{
			my $catlink5 = $1.$3;
			my $menu7 = &clean($2.$4);
			$catlink5 = "http://www.zalando.co.uk/".$catlink5 unless($catlink5 =~ m/^http/is);
			my $cont6 = &lwp_get($catlink5); 
			&collect_product($menu1,$menu2,$menu3,'','',$menu6,$menu7,$cont6);
		}
	}
	if($content =~ m/<span\s*class\=\"left\">\s*((?!Brand|Size|Price)[^>]*?)\s*<([\w\W]*?)<\/div>\s*<\/div>/is)
	{
		my $menu6 = &clean($1);
		my $cont5 = $2;
		while($cont5 =~ m/<a\s*class\=\"([^>]*?)\"[^>]*?href\=\"\/([^>]*?)\"[^>]*?>/igs)
		{					
			my $menu7 = &clean($1);
			my $catlink5 = $2;
			$catlink5 = "http://www.zalando.co.uk/".$catlink5 unless($catlink5 =~ m/^http/is);
			my $cont6 = &lwp_get($catlink5); 
			&collect_product($menu1,$menu2,$menu3,'','',$menu6,$menu7,$cont6);
		}
		while($cont5 =~ m/<a[^>]*?href\=\"\/([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/a>/igs)
		{
			my $catlink5 = $1;
			my $menu7 = &clean($2);
			$catlink5 = "http://www.zalando.co.uk/".$catlink5 unless($catlink5 =~ m/^http/is);
			my $cont6 = &lwp_get($catlink5); 
			&collect_product($menu1,$menu2,$menu3,'','',$menu6,$menu7,$cont6);
		}		
	}
}


#################### For Dashboard #######################################
DBIL::Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);
#################### For Dashboard #######################################

sub collect_product()
{
	my ($menu_1, $menu_2, $menu_3, $menu_4, $menu_5, $menu_6, $menu_7, $category_content) = @_;
	print "$menu_1->$menu_2->$menu_3->$menu_4->$menu_5->$menu_6->$menu_7\n";
	nextpage:
	if($category_content=~m/<div\s*class\=\"pager\s*\">([\w\W]*?)<div\s*class\=\"pager\s*pBottom\s*cleaner\">/is)
	{
		my $block=$1;
		# while($block=~m/class\=\"productBox\"\s*href\=\"([^>]*?)\">\s*<span\s*class\=\"imageBox\">/igs)##while
		while($block=~m/class\=\"productBox\"\s*href\=\"([^>]*?)\"/igs)##while
		{
			my $purl="http://www.zalando.co.uk$1";
			my $pids;
			if($purl =~ m/\-([a-z0-9]{9})\-[a-z0-9]{3}\./is)
			{
				$pids = $1;
			}
			my $product_object_key;
			if($totalHash{$pids} ne '')
			{
				print "Data Exists! -> $totalHash{$pids}\n";
				$product_object_key = $totalHash{$pids};
			}
			else
			{
				print "New Data\n";
				$product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid,$mqh);
				$totalHash{$pids}=$product_object_key;
			}
			unless($menu_1=~m/^\s*$/is)
			{
				DBIL::SaveTag('Menu_1',$menu_1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
			unless($menu_2=~m/^\s*$/is)
			{
				DBIL::SaveTag('Menu_2',$menu_2,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
			unless($menu_3=~m/^\s*$/is)
			{
				DBIL::SaveTag('Menu_3',$menu_3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
			unless($menu_4=~m/^\s*$/is)
			{
				DBIL::SaveTag('Menu_4',$menu_4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
			unless($menu_5=~m/^\s*$/is)
			{
				DBIL::SaveTag('Menu_5',$menu_5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
			unless($menu_7=~m/^\s*$/is)
			{
				DBIL::SaveTag($menu_6,$menu_7,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
			$dbh->commit();
		}
	}
	elsif($category_content=~m/Sort\s*by\:([\w\W]*?)<div\s*class\=\"pager\s*pBottom\s*cleaner\">/is)
	{
		my $block=$1;
		# while($block=~m/class\=\"productBox\"\s*href\=\"([^>]*?)\">\s*<span\s*class\=\"imageBox\">/igs)##while
		while($block=~m/class\=\"productBox\"\s*href\=\"([^>]*?)\"/igs)##while
		{
			my $purl="http://www.zalando.co.uk$1";
			my $pids;
			if($purl =~ m/\-([a-z0-9]{9})\-[a-z0-9]{3}\./is)
			{
				$pids = $1;
			}
			my $product_object_key;
			if($totalHash{$pids} ne '')
			{
				print "Data Exists! -> $totalHash{$pids}\n";
				$product_object_key = $totalHash{$pids};
			}
			else
			{
				print "New Data\n";
				$product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid,$mqh);
				$totalHash{$pids}=$product_object_key;
			}
			unless($menu_1=~m/^\s*$/is)
			{
				DBIL::SaveTag('Menu_1',$menu_1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
			unless($menu_2=~m/^\s*$/is)
			{
				DBIL::SaveTag('Menu_2',$menu_2,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
			unless($menu_3=~m/^\s*$/is)
			{
				DBIL::SaveTag('Menu_3',$menu_3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
			unless($menu_4=~m/^\s*$/is)
			{
				DBIL::SaveTag('Menu_4',$menu_4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
			unless($menu_5=~m/^\s*$/is)
			{
				DBIL::SaveTag('Menu_5',$menu_5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
			unless($menu_7=~m/^\s*$/is)
			{
				DBIL::SaveTag($menu_6,$menu_7,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
			$dbh->commit();
		}
	}
	elsif($category_content =~ m/class\=\"productBox\"\s*href\=\"([^>]*?)\"/is)
	{
		while($category_content=~m/class\=\"productBox\"\s*href\=\"([^>]*?)\"/igs)##while
		{
			my $purl="http://www.zalando.co.uk$1";
			my $pids;
			if($purl =~ m/\-([a-z0-9]{9})\-[a-z0-9]{3}\./is)
			{
				$pids = $1;
			}
			my $product_object_key;
			if($totalHash{$pids} ne '')
			{
				print "Data Exists! -> $totalHash{$pids}\n";
				$product_object_key = $totalHash{$pids};
			}
			else
			{
				print "New Data\n";
				$product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid,$mqh);
				$totalHash{$pids}=$product_object_key;
			}
			unless($menu_1=~m/^\s*$/is)
			{
				DBIL::SaveTag('Menu_1',$menu_1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
			unless($menu_2=~m/^\s*$/is)
			{
				DBIL::SaveTag('Menu_2',$menu_2,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
			unless($menu_3=~m/^\s*$/is)
			{
				DBIL::SaveTag('Menu_3',$menu_3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
			unless($menu_4=~m/^\s*$/is)
			{
				DBIL::SaveTag('Menu_4',$menu_4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
			unless($menu_5=~m/^\s*$/is)
			{
				DBIL::SaveTag('Menu_5',$menu_5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
			unless($menu_7=~m/^\s*$/is)
			{
				DBIL::SaveTag($menu_6,$menu_7,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
			$dbh->commit();
		}
	}
	if($category_content=~m/<link\s*rel="next"\s*href\=\"([^>]*?)\"\s*\/>/is)
	{
		my $next_page_url=$1;	
		$category_content = lwp_get($next_page_url);
		goto nextpage;
		
	}
    elsif($category_content=~m/<span\s*class\=\"current\">[\d]+<\/span>\s*<\/li><li>\s*<a\s*href\=\"([^>]*?)\">/is)
	{
		my $next_page_url="http://www.zalando.co.uk/$1";	
		$category_content = lwp_get($next_page_url);
		goto nextpage;
	}
}
sub lwp_get() 
{ 
    REPEAT: 
	my $url = $_[0];
	$url =~ s/amp;//igs;
    my $req = HTTP::Request->new(GET=>$url); 
    $req->header("Accept"=>"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"); 
    $req->header("Content-Type"=>"application/x-www-form-urlencoded"); 
    my $res = $ua->request($req); 
    $cookie->extract_cookies($res); 
    $cookie->save; 
    $cookie->add_cookie_header($req); 
    my $code = $res->code(); 
    print $code,"\n"; 
    if($code =~ m/50/is) 
    { 
        sleep 500; 
        goto REPEAT; 
    } 
    return($res->content()); 
} 
sub clean() 
{ 
    my $var=shift; 
    $var=~s/<[^>]*?>//igs; 
    $var=~s/&nbsp\;|amp\;/ /igs; 
    $var=decode_entities($var); 
    $var=~s/\s+/ /igs; 
    return ($var); 
}
