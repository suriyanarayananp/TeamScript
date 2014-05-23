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
my $Retailer_Random_String='Ame';
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
my $url="http://www.ae.com";
my $content0=&lwp_get($url);
while($content0 =~ m/href\=\"([^>]*?)\">\s*<span\s*class\=\"catLabel\">\s*([^>]*?)\s*<\/span>\s*<\/a>/igs)
{
	my $menu1url=DBIL::Trim($1);
	my $menu_1=DBIL::Trim($2);
	my $menu1 = $menu_1;
	if($menu1 =~ m/Men|Women/is) 
    { 
        my $menucontent = lwp_get($menu1url); 
        if($menucontent =~ m/class\=\"sideNav\s*catNav\">([\w\W]*?)<\/div>/is) 
        { 
            my $tempcont = $1; 
            if($tempcont =~ m/>\s*(Collections)\s*<\/span>([\w\W]*?)<span\s*class\=\"noLink\">/is) ##Collections LHM
			{
				my $menu2 = $1; #Collections
				my $subcont2 = $2;
				while($subcont2 =~ m/class\=\"navCat_cat\d+\s*emptyCat\">\s*<a\s*href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs) ## New Arrivials-> Menu2
				{
					my $menuurl2 = $1;
					my $menu3 = $2;
					my $subcont3 = &lwp_get($menuurl2);
					my $test=quotemeta($menu3);
					if($subcont3 =~ m/>\s*$test\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"subMenu\">([\w\W]*?)<\/ul>/is)
					{
						my $subcont4 = $1;
						while($subcont4 =~ m/class\=\"navCat_cat[^>]*?\"\s*>\s*<a\s*href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs) ## Tops-- Menu3 or category
						{
							my $menuurl3 = $1;
							my $menu4 = $2;
							print "$menu1->$menu2->$menu3->$menu4\n";
							my $subcont5 = &lwp_get($menuurl3);
							my $catid = $1 if($menuurl3 =~ m/catId\=([^>]*?)$/is);
							if($subcont5 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
							{
								my $catCollection = $1;
								while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
								{
									my $pid = &clean($1);
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									$dbh->commit();
									if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
									{
										my $pid = &clean($1);
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
										my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										$dbh->commit();
									}
								}
							}
							if($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
							{
								while($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
								{
									my $pid = &clean($1);
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									$dbh->commit();
									if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
									{
										my $pid = &clean($1);
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
										my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										$dbh->commit();
									}
								}
							}
						}
					}
					else
					{
						print "$menu1->$menu2->$menu3\n";
						my $catid = $1 if($menuurl2 =~ m/catId\=([^>]*?)$/is);
						if($subcont3 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
						{
							my $catCollection = $1;
							while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
							{
								my $pid = &clean($1);
								my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
								my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
								DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
								DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
								$dbh->commit();
								if($subcont3 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
								{
									my $pid = &clean($1);
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									$dbh->commit();
								}
							}
						}
						if($subcont3 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
						{
							while($subcont3 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
							{
								my $pid = &clean($1);
								my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
								my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
								DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
								DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
								$dbh->commit();
								if($subcont3 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
								{
									my $pid = &clean($1);
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									$dbh->commit();
								}
							}
						}
					}
				}
			}
			if($tempcont =~ m/>\s*(Categories)\s*<\/span>([\w\W]*?)<span\s*class\=\"noLink\">/is) ##Categories LHM
			{
				my $menu2 = $1; #Categories
				my $subcont2 = $2;
				while($subcont2 =~ m/class\=\"navCat_cat\d+\s*emptyCat\">\s*<a\s*href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs) ## Underwear->Access->colonge->shoes
				{
					my $menuurl2 = $1;
					my $menu3 = $2; ##Underwear
					my $subcont3 = &lwp_get($menuurl2);
					my $test=quotemeta($menu3);
					if($subcont3 =~ m/>\s*$test\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"subMenu\">([\w\W]*?)<\/ul>/is)
					{
						my $subcont4 = $1;
						while($subcont4 =~ m/class\=\"navCat_cat[^>]*?\"\s*>\s*<a\s*href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs) ## Trunks -- Menu3 or category
						{
							my $menuurl3 = $1;
							my $menu4 = $2;  ##Trunks
							my $subcont5 = &lwp_get($menuurl3);
							my $test=quotemeta($menu4);
							if($subcont5 =~ m/>\s*$test\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"subMenu\">([\w\W]*?)<\/ul>/is) ## Trunks Block
							{
								my $subcont6 = $1;
								while($subcont6 =~ m/href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs) ## Trunks -- Menu3 or category
								{
									my $menuurl4 = $1;
									my $menu5 = $2;   #Low Rise trunks
									print "$menu1->$menu2->$menu3->$menu4->$menu5\n";
									my $subcont6 = &lwp_get($menuurl4);
									my $catid = $1 if($menuurl4 =~ m/catId\=([^>]*?)$/is);
									if($subcont6 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
									{
										my $catCollection = $1;
										while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
										{
											my $pid = &clean($1);
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											$dbh->commit();
											if($subcont6 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
											{
												my $pid = &clean($1);
												my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
												my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												$dbh->commit();
											}
										}
									}
									if($subcont6 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
									{
										while($subcont6 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
										{
											my $pid = &clean($1);
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											$dbh->commit();
											if($subcont6 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
											{
												my $pid = &clean($1);
												my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
												my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												$dbh->commit();
											}
										}
									}
								}
							}
							else ## No Sub Menu from menu3 Eg: socks menu
							{
								print "$menu1->$menu2->$menu3->$menu4\n";
								my $catid = $1 if($menuurl3 =~ m/catId\=([^>]*?)$/is);
								if($subcont5 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
								{
									my $catCollection = $1;
									while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
									{
										my $pid = &clean($1);
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
										my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										$dbh->commit();
										if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
										{
											my $pid = &clean($1);
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											$dbh->commit();
										}
									}
								}
								if($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
								{
									while($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
									{
										my $pid = &clean($1);
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
										my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										$dbh->commit();
										if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
										{
											my $pid = &clean($1);
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											$dbh->commit();
										}
									}
								}
							}
						}
					}
				}
				if($subcont2 =~ m/<span>\s*([^>]*?)\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"[^>]*?\">([\w\W]*?)<\/ul>/is)
				{
					while($subcont2 =~ m/<span>\s*([^>]*?)\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"[^>]*?\">([\w\W]*?)<\/ul>/igs) ##categoreis->tops
					{
						my $menu3 = $1;
						my $menusubcont = $2;
						while($menusubcont =~ m/href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs) ## Trunks -- Menu3 or category
						{
							my $menuurl3 = $1;
							my $menu4 = $2;
							my $subcont3 = &lwp_get($menuurl3);
							my $test=quotemeta($menu4);
							if($subcont3 =~ m/>\s*$test\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"subMenu\">([\w\W]*?)<\/ul>/is) ## Trunks Block
							{
								my $subcont4 = $1;
								while($subcont4 =~ m/href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs) ## Trunks -- Menu3 or category
								{
									my $menuurl4 = $1;
									my $menu5 = $2;
									my $subcont5 = &lwp_get($menuurl4);
									my $catid = $1 if($menuurl4 =~ m/catId\=([^>]*?)$/is);
									print "$menu1->$menu2->$menu3->$menu4->$menu5\n";
									if($subcont5 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
									{
										my $catCollection = $1;
										while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
										{
											my $pid = &clean($1);
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											$dbh->commit();
											if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
											{
												my $pid = &clean($1);
												my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
												my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												$dbh->commit();
											}
										}
									}
									if($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
									{
										while($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
										{
											my $pid = &clean($1);
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											$dbh->commit();
											if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
											{
												my $pid = &clean($1);
												my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
												my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												$dbh->commit();
											}
										}
									}
								}
							}
							else ## No Sub Menu from menu3 Eg: socks menu
							{
								print "$menu1->$menu2->$menu3->$menu4\n";
								my $catid = $1 if($menuurl3 =~ m/catId\=([^>]*?)$/is);
								if($subcont3 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
								{
									my $catCollection = $1;
									while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
									{
										my $pid = &clean($1);
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
										my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										$dbh->commit();
										if($subcont3 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
										{
											my $pid = &clean($1);
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											$dbh->commit();
										}
									}
								}
								if($subcont3 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
								{
									while($subcont3 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
									{
										my $pid = &clean($1);
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
										my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										$dbh->commit();
										if($subcont3 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
										{
											my $pid = &clean($1);
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											$dbh->commit();
										}
									}
								}
							}
						}
					}
				}
			}
			if($tempcont =~ m/>\s*(Trends)\s*<\/span>([\w\W]*?)<\/ul>/is)
			{
				my $menu2 = $1; #Trends
				my $subcont2 = $2;
				while($subcont2 =~ m/href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
				{
					my $caturl = $1;
					my $menu3 = $2; #vday shop
					my $subcont3 = &lwp_get($caturl);
					print "$menu1->$menu2->$menu3\n";
					my $test=quotemeta($menu3);
					if($subcont3 =~ m/>\s*$test\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"subMenu\">([\w\W]*?)<\/ul>/is) ## Trunks Block
					{
						my $subcont4 = $1;
						while($subcont4 =~ m/href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs) ## Trunks -- Menu3 or category
						{
							my $menuurl4 = $1;
							my $menu4 = $2;
							my $subcont5 = &lwp_get($menuurl4);
							my $catid = $1 if($menuurl4 =~ m/catId\=([^>]*?)$/is);
							print "Link32=>$menu1->$menu2->$menu3->$menu4\n";
							if($subcont5 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
							{
								my $catCollection = $1;
								while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
								{
									my $pid = &clean($1);
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									$dbh->commit();
									if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
									{
										my $pid = &clean($1);
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
										my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										$dbh->commit();
									}
								}
							}
							if($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
							{
								while($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
								{
									my $pid = &clean($1);
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									$dbh->commit();
									if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
									{
										my $pid = &clean($1);
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
										my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										$dbh->commit();
									}
								}
							}
						}
					}
					else
					{
						my $catid = $1 if($caturl =~ m/catId\=([^>]*?)$/is);
						if($subcont3 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
						{
							print "Link32=>$menu1->$menu2->$menu3\n";
							my $catCollection = $1;
							while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
							{
								my $pid = &clean($1);
								my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
								my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
								DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
								DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
								$dbh->commit();
								if($subcont3 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
								{
									my $pid = &clean($1);
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									$dbh->commit();
								}
							}
						}
						if($subcont3 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
						{
							while($subcont3 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
							{
								my $pid = &clean($1);
								my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
								my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
								DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
								DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
								$dbh->commit();
								if($subcont3 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
								{
									my $pid = &clean($1);
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									$dbh->commit();
								}
							}
						}
					}
				}
			}
		} 
    }
	elsif($menu1 =~ m/Clearance/is) 
    { 
        my $menucontent = lwp_get($menu1url); 
        if($menucontent =~ m/class\=\"sideNav\s*catNav\">([\w\W]*?)<\/div>/is) 
        { 
            my $tempcont = $1; 
            while($tempcont =~ m/<span\s*class\=\"noLink\">\s*([^>]*?)\s*<\/span>\s*<ul\s*class\=\"menu\">(?:<[^>]*?>\s*)*([^>]*?)\s*<\/span>([\w\W]*?)<\/a>\s*<\/li>\s*<\/ul>\s*<\/li>\s*<\/ul>\s*<\/li>/igs)
			{
				my $menu2 = $1; #Mens clearance
				my $menu3 = $2;  #clearance
				my $subcont = $3; #subcont
				while($subcont =~ m/href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
				{
					my $cat_url = $1; 
					my $menu4 = $2; #$10 under deales or Tops
					my $subcont2 = &lwp_get($cat_url); 
					print "$menu1->$menu2->$menu3->$menu4\n";
					my $test=quotemeta($menu4);
					if($subcont =~ m/>\s*$test\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"subMenu\">([\w\W]*?)<\/ul>/is) #Sub Menu 
					{
						my $subcont5 = $1;
						while($subcont5 =~ m/href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs) ## Tops-- Menu3 or category
						{
							my $menuurl4 = $1;
							my $menu5 = $2;
							print "$menu1->$menu2->$menu3->$menu4->$menu5\n";
							my $subcont6 = &lwp_get($menuurl4);
							my $catid = $1 if($menuurl4 =~ m/catId\=([^>]*?)$/is);
							if($subcont6 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
							{
								my $catCollection = $1;
								while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
								{
									my $pid = &clean($1);
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									$dbh->commit();
									if($subcont6 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
									{
										my $pid = &clean($1);
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
										my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										$dbh->commit();
									}
								}
							}
							if($subcont6 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
							{
								while($subcont6 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
								{
									my $pid = &clean($1);
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									$dbh->commit();
									if($subcont6 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
									{
										my $pid = &clean($1);
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
										my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										$dbh->commit();
									}
								}
							}
						}
					}
					else #no sub menu
					{
						my $catid = $1 if($cat_url =~ m/catId\=([^>]*?)$/is);
						if($subcont2 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
						{
							my $catCollection = $1;
							while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
							{
								my $pid = &clean($1);
								my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
								my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
								DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
								DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
								DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
								$dbh->commit();
								if($subcont2 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
								{
									my $pid = &clean($1);
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									$dbh->commit();
								}
							}
						}
						if($subcont2 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
						{
							while($subcont2 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
							{
								my $pid = &clean($1);
								my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
								my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
								DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
								DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
								DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
								$dbh->commit();
								if($subcont2 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
								{
									my $pid = &clean($1);
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									$dbh->commit();
								}
							}
						}
					}
					
				}
			}
        } 
    } 
	elsif($menu_1=~ m/Aerie/is)
	{
		my $content=&lwp_get($menu1url);
		while($content=~ m/href\=\"([^>]*?)\">\s*<span\s*class\=\"catLabel\">\s*([^>]*?)\s*<\/span>\s*<\/a>/igs)
		{
			my $url2 =  &clean($1);
			my $menu2 =  &clean($2); # Bras|Undies|Swim|Clothing
			print "Menu2 => $menu2\n";
			my $subcont = &lwp_get($url2);
			if($subcont =~ m/class\=\"sideNav\s*catNav\">([\w\W]*?)<\/div>/is) 
			{ 
				my $tempcont = $1;
				while($tempcont =~ m/<span\s*class\=\"noLink\">\s*([^>]*?)\s*<\/span><ul\s*class\=\"menu\">([\w\W]*?<\/ul>)\s*<\/li>/igs)
				{
					my $menu3 = &clean($1); #Collections|Categories|Shop By Fit|Shop by Girl
					my $tempcont2 = $2;
					if($menu3 =~ m/Categories/is)
					{
						$tempcont2 = $2 if($subcont =~ m/>\s*(Categories)\s*<\/span>([\w\W]*?)<span\s*class\=\"noLink\">/is);
					}
					if($tempcont2 =~ m/<span>\s*([^>]*?)\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"subMenu\">([\w\W]*?)<\/ul>/is)
					{
						while($tempcont2 =~ m/<span>\s*([^>]*?)\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"subMenu\">([\w\W]*?)<\/ul>/igs)
						{
							
							my $menu4 = &clean($1);  #All Fit| View All
							my $tempcont3 = $2;
							while($tempcont3 =~ m/href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
							{
								my $url3 = $1;
								my $menu5 = &clean($2);  #Push up Bra
								my $subcont2 = &lwp_get($url3);
								my $test=quotemeta($menu5);
								if($subcont2 =~ m/>\s*$test\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"subMenu\">([\w\W]*?)<\/ul>/is)
								{
									my $subcont4 = $1;
									while($subcont4 =~ m/href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs) ## Tops-- Menu3 or category
									{
										my $menuurl3 = $1;
										my $menu6 = $2;
										print "Link1=>$menu1->$menu2->$menu3->$menu4->$menu5->$menu6\n";
										my $subcont5 = &lwp_get($menuurl3);
										my $catid = $1 if($menuurl3 =~ m/catId\=([^>]*?)$/is);
										if($subcont5 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
										{
											my $catCollection = $1;
											while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
											{
												my $pid = &clean($1);
												my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
												my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu5,$menu6,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												$dbh->commit();
												if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
												{
													my $pid = &clean($1);
													my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
													my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
													DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
													DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
													DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
													DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
													DBIL::SaveTag($menu5,$menu6,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
													$dbh->commit();
												}
											}
										}
										if($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
										{
											while($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
											{
												my $pid = &clean($1);
												my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
												my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu5,$menu6,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);  
												$dbh->commit();
												if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
												{
													my $pid = &clean($1);
													my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
													my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
													DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
													DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
													DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
													DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
													DBIL::SaveTag($menu5,$menu6,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
													$dbh->commit();
												}
											}
										}
									}
								}
								else
								{
									print "Link2=>$menu1->$menu2->$menu3->$menu4->$menu5\n";
									my $catid = $1 if($url3 =~ m/catId\=([^>]*?)$/is);
									if($subcont2 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
									{
										my $catCollection = $1;
										while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
										{
											my $pid = &clean($1);
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											$dbh->commit();
											if($subcont2 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
											{
												my $pid = &clean($1);
												my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
												my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												$dbh->commit();
											}
										}
									}
									if($subcont2 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
									{
										while($subcont2 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
										{
											my $pid = &clean($1);
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid); 
											$dbh->commit();											
											if($subcont2 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
											{
												my $pid = &clean($1);
												my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
												my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												$dbh->commit();
											}
										}
									}
								}
							}
						}
						if($menu3 =~ m/categories/is)
						{
							while($tempcont2 =~ m/class\=\"navCat_cat\d+\s+emptyCat\">\s*<a\s*href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
							{
							
								my $menuurl2 = $1;
								my $menu4 = $2;
								my $subcont3 = &lwp_get($menuurl2);
								my $test=quotemeta($menu4);
								if($subcont3 =~ m/>\s*$test\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"subMenu\">([\w\W]*?)<\/ul>/is)
								{
									my $subcont4 = $1;
									while($subcont4 =~ m/class\=\"navCat_cat[^>]*?\"\s*>\s*<a\s*href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs) ## Tops-- Menu3 or category
									{
										my $menuurl3 = $1;
										my $menu5 = $2;
										print "Link3=>$menu1->$menu2->$menu3->$menu4->$menu5\n";
										my $subcont5 = &lwp_get($menuurl3);
										my $catid = $1 if($menuurl3 =~ m/catId\=([^>]*?)$/is);
										if($subcont5 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
										{
											my $catCollection = $1;
											while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
											{
												my $pid = &clean($1);
												my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
												my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);  
												$dbh->commit();
												if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
												{
													my $pid = &clean($1);
													my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
													my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
													DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
													DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
													DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
													DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
													$dbh->commit();
												}
											}
										}
										if($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
										{
											while($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
											{
												my $pid = &clean($1);
												my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
												my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);  
												$dbh->commit();
												if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
												{
													my $pid = &clean($1);
													my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
													my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
													DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
													DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
													DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
													DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
													$dbh->commit();
												}
											}
										}
									}
								}
								else
								{
									print "Link4=>$menu1->$menu2->$menu3->$menu4\n";
									my $catid = $1 if($menuurl2 =~ m/catId\=([^>]*?)$/is);
									if($subcont3 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
									{
										my $catCollection = $1;
										while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
										{
											my $pid = &clean($1);
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											$dbh->commit();
											if($subcont3 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
											{
												my $pid = &clean($1);
												my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
												my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												$dbh->commit();
											}
										}
									}
									if($subcont3 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
									{
										while($subcont3 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
										{
											my $pid = &clean($1);
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											$dbh->commit();
											if($subcont3 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
											{
												my $pid = &clean($1);
												my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
												my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												$dbh->commit();
											}
										}
									}
								}
							}
						}
					}
					elsif($tempcont2 =~ m/href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/is)
					{
						while($tempcont2 =~ m/href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
						{
							my $menuurl2 = $1;
							my $menu4 = $2;
							my $subcont3 = &lwp_get($menuurl2);
							my $test=quotemeta($menu4);
							if($subcont3 =~ m/>\s*$test\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"subMenu\">([\w\W]*?)<\/ul>/is)
							{
								my $subcont4 = $1;
								while($subcont4 =~ m/class\=\"navCat_cat[^>]*?\"\s*>\s*<a\s*href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs) ## Tops-- Menu3 or category
								{
									my $menuurl3 = $1;
									my $menu5 = $2;
									print "Link3=>$menu1->$menu2->$menu3->$menu4->$menu5\n";
									my $subcont5 = &lwp_get($menuurl3);
									my $catid = $1 if($menuurl3 =~ m/catId\=([^>]*?)$/is);
									if($subcont5 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
									{
										my $catCollection = $1;
										while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
										{
											my $pid = &clean($1);
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid); 
											$dbh->commit();
											if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
											{
												my $pid = &clean($1);
												my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
												my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid); 
												$dbh->commit();
											}
										}
									}
									if($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
									{
										while($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
										{
											my $pid = &clean($1);
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);   
											$dbh->commit();
											if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
											{
												my $pid = &clean($1);
												my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
												my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid); 
												$dbh->commit();
											}
										}
									}
								}
							}
							else
							{
								print "Link4=>$menu1->$menu2->$menu3->$menu4\n";
								my $catid = $1 if($menuurl2 =~ m/catId\=([^>]*?)$/is);
								if($subcont3 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
								{
									my $catCollection = $1;
									while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
									{
										my $pid = &clean($1);
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
										my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										$dbh->commit();
										if($subcont3 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
										{
											my $pid = &clean($1);
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											$dbh->commit();
										}
									}
								}
								if($subcont3 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
								{
									while($subcont3 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
									{
										my $pid = &clean($1);
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
										my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										$dbh->commit();
										if($subcont3 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
										{
											my $pid = &clean($1);
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											$dbh->commit();
										}
									}
								}
							}
						}
					}
				}
				while($tempcont =~ m/<li\s*class\=\"navHeader\s*navCat_cat\d+\s*navCat_[^>]*?emptyCat\">\s*<a\s*href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
				{
					my $menuurl2 = $1;
					my $menu3 = $2;
					my $subcont3 = &lwp_get($menuurl2);
					my $test=quotemeta($menu3);
					if($subcont3 =~ m/>\s*$test\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"subMenu\">([\w\W]*?)<\/ul>/is)
					{
						my $subcont4 = $1;
						while($subcont4 =~ m/class\=\"navCat_cat[^>]*?\"\s*>\s*<a\s*href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs) ## Tops-- Menu3 or category
						{
							my $menuurl3 = $1;
							my $menu4 = $2;
							print "Link5=>$menu1->$menu2->$menu3->$menu4\n";
							my $subcont5 = &lwp_get($menuurl3);
							my $catid = $1 if($menuurl3 =~ m/catId\=([^>]*?)$/is);
							if($subcont5 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
							{
								my $catCollection = $1;
								while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
								{
									my $pid = &clean($1);
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									$dbh->commit();
									if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
									{
										my $pid = &clean($1);
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
										my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										$dbh->commit();
									}
								}
							}
							if($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
							{
								while($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
								{
									my $pid = &clean($1);
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid); 
									$dbh->commit();
									if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
									{
										my $pid = &clean($1);
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
										my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										$dbh->commit();
									}
								}
							}
						}
					}
					else
					{
						print "Link6=>$menu1->$menu2->$menu3\n";
						my $catid = $1 if($menuurl2 =~ m/catId\=([^>]*?)$/is);
						if($subcont3 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
						{
							my $catCollection = $1;
							while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
							{
								my $pid = &clean($1);
								my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
								my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
								DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
								DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
								$dbh->commit();
								if($subcont3 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
								{
									my $pid = &clean($1);
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									$dbh->commit();
								}
							}
						}
						if($subcont3 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/is)
						{
							while($subcont3 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
							{
								my $pid = &clean($1);
								my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
								my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
								DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
								DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);   
								$dbh->commit();
								if($subcont3 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
								{
									my $pid = &clean($1);
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									$dbh->commit();
								}
							}
						}
					}
				}
				if(($tempcont =~ m/<span>\s*([^>]*?)\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"Menu\">([\w\W]*?)<\/ul>/is))
				{
					my $menu3 = &clean($1);
					my $subcont5 = $2;
					while($subcont5 =~ m/href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
					{
						my $clearurl = $1;
						my $menu4 = &clean($2);
						my $subcont6 = &lwp_get($clearurl);
						my $test=quotemeta($menu4);
						if($subcont6 =~ m/>\s*$test\s*<\/span>\s*<\/a>\s*<ul\s*class\=\"subMenu\">([\w\W]*?)<\/ul>/is)
						{
							my $subcont7 = $1;
							while($subcont7 =~ m/class\=\"navCat_cat[^>]*?\"\s*>\s*<a\s*href\=\"([^>]*?)\">\s*<span>\s*([^>]*?)\s*<\/span>/igs) ## Tops-- Menu3 or category
							{
								my $menuurl7 = $1;
								my $menu5 = $2;
								print "Clear=>$menu1->$menu2->$menu3->$menu4->$menu5\n";
								my $subcont5 = &lwp_get($menuurl7);
								my $catid = $1 if($menuurl7 =~ m/catId\=([^>]*?)$/is);
								if($subcont5 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
								{
									my $catCollection = $1;
									while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
									{
										my $pid = &clean($1);
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
										my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid); 
										$dbh->commit();
										if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
										{
											my $pid = &clean($1);
											my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
											my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid); 
											$dbh->commit();
										}
									}
								}
								while($subcont5 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
								{
									my $pid = &clean($1);
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);  
									$dbh->commit();
									if($subcont5 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
									{
										my $pid = &clean($1);
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
										my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid); 
										$dbh->commit();
									}
								}
							}
						}
						else
						{
							print "Link4=>$menu1->$menu2->$menu3->$menu4\n";
							my $catid = $1 if($clearurl =~ m/catId\=([^>]*?)$/is);
							if($subcont6 =~ m/\{\"$catid\"\:\{\"availablePrdIds\"\:\[([\w\W]*?)\]/is)
							{
								my $catCollection = $1;
								while($catCollection =~ m/\"prdId\"\:\"([^>]*?)\"\,\"faceoutId\"\:\"([^>]*?)\"/igs)
								{
									my $pid = &clean($1);
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									$dbh->commit();
									if($subcont6 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
									{
										my $pid = &clean($1);
										my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
										my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										$dbh->commit();
									}
								}
							}
							while($subcont6 =~ m/\{\"availablePrdIds\"\:\[\{\"prdId\"\:\"([^>]*?)\"/igs)
							{
								my $pid = &clean($1);
								my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
								my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
								DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
								DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
								DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);   
								$dbh->commit();
								if($subcont6 =~ m/\"prdId\"\:\"$pid\"\,\"faceoutId\"\:\"\d+\"\,\"addlBundlePrdId\"\:\{\"prdId\"\:\"([^>]*?)\"/is)
								{
									my $pid = &clean($1);
									my $purl = "http://www.ae.com/web/browse/product.jsp?productId=".$pid; 
									my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									$dbh->commit();
								}								
							}
						}
					}
				}
			}
		}
	}
	
}

#################### For Dashboard #######################################
DBIL::Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);
#################### For Dashboard #######################################

# system(`/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl /opt/home/merit/Merit_Robots/Americaneagle-US--Detail.pl &`);	
sub lwp_get() 
{ 
    REPEAT: 
    my $url = $_[0];
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
