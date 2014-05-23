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
my $Retailer_Random_String='Abe';
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

my $content = lwp_get("http://www.abercrombie.com");

while($content =~ m/href\=\"([^>]*?)\">\s*<h2[^>]*?nav\-description\">\s*([^>]*?)\s*<\/h2>/igs)
{
	my $caturl = $1;
	my $menu1 = &clean($2);
	$caturl = "http://www.abercrombie.com".$caturl unless($caturl =~ m/^http/is);
	my $subcontent = &lwp_get($caturl); 
	if($subcontent =~ m/<ul\s*class\=\"primary\">([\w\W]*?)<\/ul>/is)
	{
		my $subcont = $1;
		while($subcont =~ m/href\=\"([^>]*?)\"\s*>\s*([^>]*?)\s*<\/a>/igs)
		{
			my $caturl2 = $1;
			my $menu2 = &clean($2);
			# next unless($menu2 =~ m/sale/is);
			$caturl2 = "http://www.abercrombie.com".$caturl2 unless($caturl2 =~ m/^http/is);
			my $subcontent2 = &lwp_get($caturl2);
			if($menu2 =~ m/Sale|Clearance/is)
			{
				print "Im here 1\n";
				if($subcontent2 =~ m/>\s*$menu2\s*<\/a>\s*<ul\s*class\=\"secondary\">([\w\W]*?)\s*(?:<\/ul>\s*<\/div>|<li\s*id\=\"cat\-anf_division)/is)
				{
					my $subcont2 = $1;
					print "Block0\n";
					while($subcont2 =~ m/End:\s*Filter\s*Ability to Block Sub Categories\s*\-\->\s*<li[^>]*?>\s*<a\s*href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>/igs)
					{
						my $caturl3 = $1;
						my $menu3 = &clean($2);
						$caturl3 = "http://www.abercrombie.com".$caturl3 unless($caturl3 =~ m/^http/is);
						my $menucontent3 = &lwp_get($caturl3); 
						if($menucontent3=~m/class\=\"current\s*selected[^>]*?>\s*<[^>]*?>\s*$menu3\s*<\/a>\s*<ul([\w\W]*?)<\/ul>\s*<\/li>/is)
						{
							my $block = $1;
							while($block =~ m/href\=\"([^>]*?)\">\s*([^>]*?)\s*</igs)
							{
								my $menuurl_1 = $1;
								my $menu4 = &clean($2);
								$menuurl_1 = "http://www.abercrombie.com".$menuurl_1 unless($menuurl_1 =~ m/^http/is);
								my $menucontent_1 = lwp_get($menuurl_1);
								while($menucontent_1 =~ m/<h2>\s*<a\s*href\=\"([^>]*?)\"/igs)
								{
									my $purl = $1;
									$purl = "http://www.abercrombie.com".$purl unless($purl =~ m/^http/is);
									my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
									print "Bread1 => $menu1->$menu2->$menu3->$menu4\n";
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
										DBIL::SaveTag('Category',$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									}
									$dbh->commit();
								}
							}
						}
						else
						{
							while($menucontent3 =~ m/<h2>\s*<a\s*href\=\"([^>]*?)\"/igs)
							{
								my $purl = $1;
								$purl = "http://www.abercrombie.com".$purl unless($purl =~ m/^http/is);
								my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
								print "Bread2 => $menu1->$menu2->$menu3\n";
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
								$dbh->commit();
							}
						}
					}
				}
			}
			elsif($subcontent2 =~ m/href\=\"([^>]*?)\"\s*class\=\"product\-link\"/is)
			{
				print "Block1\n";
				while($subcontent2 =~ m/href\=\"([^>]*?)\"\s*class\=\"product\-link\"/igs)
				{
					my $purl = $1;
					$purl = "http://www.abercrombie.com".$purl unless($purl =~ m/^http/is);
					my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
					print "Bread3 => $menu1->$menu2\n";
					unless($menu1=~m/^\s*$/is)
					{
						DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
					}
					unless($menu2=~m/^\s*$/is)
					{
						DBIL::SaveTag('Menu_2',$menu2,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
					}
					$dbh->commit();
				}
			}
			elsif($subcontent2 =~ m/<div\s*id\=\"category\-nav\-wrap\">([\w\W]*?)<div id="category-content"/is)
			{
				my $subcont3 = $1;
				print "Block2\n";
				if($subcont3 =~ m/<ul\s*class\=\"secondary\">([\w\W]*?)<\/ul>/is)
				{
					my $subcont2 = $1;
					while($subcont2 =~ m/href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>/igs)
					{
						my $caturl3 = $1;
						my $menu3 = &clean($2);
						$caturl3 = "http://www.abercrombie.com".$caturl3 unless($caturl3 =~ m/^http/is);
						my $subcontent3 = &lwp_get($caturl3); 
						while($subcontent3 =~ m/<h2>\s*<a\s*href\=\"([^>]*?)\"/igs)
						{
							my $purl = $1;
							$purl = "http://www.abercrombie.com".$purl unless($purl =~ m/^http/is);
							my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
							print "Bread4 => $menu1->$menu2->$menu3\n";
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
								DBIL::SaveTag('Category',$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
							}
							$dbh->commit();
						}
					}
				}
				else
				{
					print "$menu1->$menu2\n";
					while($subcontent2 =~ m/<h2>\s*<a\s*href\=\"([^>]*?)\"/igs)
					{
						my $purl = $1;
						$purl = "http://www.abercrombie.com".$purl unless($purl =~ m/^http/is);
						my $product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
						print "Bread5 => $menu1->$menu2\n";
						unless($menu1=~m/^\s*$/is)
						{
							DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
						}
						unless($menu2=~m/^\s*$/is)
						{
							DBIL::SaveTag('Menu_2',$menu2,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
						}
						$dbh->commit();
					}
				}
			}
		}
	}
}
#################### For Dashboard #######################################
DBIL::Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);
#################### For Dashboard #######################################
$dbh->commit();
# system(`/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl /opt/home/merit/Merit_Robots/Abercrombie-US--Detail.pl &`);
sub lwp_get() 
{ 
    my $url = shift;
	my $rerun_count=0;
	$url =~ s/^\s+|\s+$//g;
	$url =~ s/amp;//igs;
	Home:
	my $req = HTTP::Request->new(GET=>$url);
	$req->header("Accept"=>"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"); 
    $req->header("Content-Type"=>"application/x-www-form-urlencoded"); 
	my $res = $ua->request($req);
	$cookie->extract_cookies($res);
	$cookie->save;
	$cookie->add_cookie_header($req);
	my $code=$res->code;
	open JJ,">>$retailer_file";
	print JJ "$url->$code\n";
	close JJ;
	my $content;
	if($code =~m/20/is)
	{
		$content = $res->content;
	}
	else
	{
		if ( $rerun_count <= 3 )
		{
			$rerun_count++;
			sleep 5;
			goto Home;
		}
	}
	return $content;
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
