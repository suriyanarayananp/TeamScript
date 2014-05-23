#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
###### Module Initialization ##############
use strict;
use LWP::UserAgent;
use HTML::Entities;
use URI::URL;
use HTTP::Cookies;
use DBI;
use DateTime;
require "/opt/home/merit/Merit_Robots/DBILv2/DBIL.pm";
###########################################

#### Variable Initialization ##############
my $robotname = $0;
$robotname =~ s/\.pl//igs;
$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
my $retailer_name=$robotname;
$retailer_name =~ s/\-\-List\s*$//igs;
$retailer_name = lc($retailer_name);
my $Retailer_Random_String='New';
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
my %totalHash; 
my $select_query = "select ObjectKey from Retailer where name=\'$retailer_name\'";
my $retailer_id = DBIL::Objectkey_Checking($select_query, $dbh, $robotname);
DBIL::RetailerUpdate($retailer_id,$excuetionid,$dbh,$robotname,'start');

#################### For Dashboard #######################################
DBIL::Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'START',$robotname);
##################### For Dashboard #######################################

my $content = lwp_get("http://www.newlook.com"); 
while($content =~ m/<li\s*id\=\"li\d+\"\s*><a\s*href\=\"([^>]*?)">\s*<h2[^>]*?>\s*([^>]*?)\s*<\/h2>/igs) 
{ 
    my $caturl = $1; 
	my $menu1 = &clean($2); 
	next unless($menu1 =~ m/$ARGV[0]/is);
	$caturl='http://www.newlook.com'.$caturl unless($caturl=~m/^\s*http\:/is);
	my $menucontent = lwp_get($caturl); 
    if(($menu1 =~ m/$ARGV[0]/is) and ($menu1 !~ m/maternity|Size|New\s*in/is))
    { 
		while($menucontent =~ m/h4>\s*([^>]*?)\s*<\/h4>([\w\W]*?)<\/ul>/igs) 
        { 
			 print "$menu1\n";
			my $menu2 = &clean($1);  #Womens New IN
			my $tempcont = $2;            
			#next if($menu2 =~ m/View\s*all/is);  #skip View All
			# next unless($menu2 =~ m/\s*Shop\s*Fit\s*/is);
			# print "$menu2\n";
            while($tempcont =~ m/href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>/igs)
			{
				my $caturl2 = $1;
				my $menu3 = &clean($2); #View All Clothing Footwear
				$caturl2 = 'http://www.newlook.com'.$caturl2 unless($caturl2 =~ m/^\s*http\:/is);
				#next if($menu3 =~ m/View\s*all/is);  #skip View All
				my $menucontent2 = lwp_get($caturl2); 
				while($menucontent2 =~ m/<h5>\s*([^>]*?)<\/h5>([\w\W]*?)<\/div>\s*<\/div>/igs)
				{
					my $menu4 = &clean($1); #Type
					my $tempcont2 = $2;
					if($menucontent2 =~ m/breadcrumbRemoveText/is)
					{
						next if($menu4 =~ m/Type|Height/is);
					}
					next if($menu4 =~ m/Size|Price|Rating/is);
					while($tempcont2 =~ m/class\=\"refine\"\s*href\=\"([^>]*?)\">\s*(?:<span[^>]*?>\s*<\/span>)?\s*([^>]*?)\s*<\/a>/igs)
					{
						my $caturl3 = $1;
						my $menu5 = &clean($2); #Tops
						$caturl3 = 'http://www.newlook.com'.$caturl3 unless($caturl3 =~ m/^\s*http\:/is);
						my $menucontent3 = lwp_get($caturl3); 
						NEXT:
						while($menucontent3 =~ m/class\=\"desc\">\s*<a\s*href\=\"([^>]*?)\"/igs)
						{
							my $product_url = $1;
							$product_url = 'http://www.newlook.com'.$product_url unless($product_url =~ m/^\s*http\:/is);
							my ($product_object_key, $pids);
							if($product_url =~ m/_([\d+]{7})/is)
							{
								$pids = $1;
							}
							if($totalHash{$pids} ne '')
							{
								print "Data Exists! -> $totalHash{$pids}\n";
								$product_object_key = $totalHash{$pids};
							}
							else
							{
								print "New Data\n";
								$product_object_key = DBIL::SaveProduct($product_url,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
								$totalHash{$pids}=$product_object_key;
							}
							print "LOOP 1 => $menu1->$menu2->$menu3->$menu4->$menu5\n";
							DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) unless($menu1 eq '');
							DBIL::SaveTag('Menu_2',$menu2,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) unless($menu2 eq '');
							DBIL::SaveTag('Menu_3',$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) unless($menu3 eq '');
							DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) unless($menu4 eq '');
							$dbh->commit();
							print "LOOP 1 => $product_object_key $menu1->$menu2->$menu3->$menu4->$menu5\n"
						}
						if($menucontent3 =~ m/href\=\"([^>]*?)\">\s*Next\s*<\/a>/is)
						{
							my $next = $1;
							$next = 'http://www.newlook.com'.$next unless($next =~ m/^\s*http\:/is);
							$menucontent3 = lwp_get($next); 
							goto NEXT;
						}
					}
				}
			}
        }
    }
	elsif(($menu1 =~ m/$ARGV[0]/is) and ($menu1 =~ m/maternity|New\s*In|Size/is))
	{
		# if(($menu1 =~ m/$ARGV[0]/is) and ($menu1 =~ m/maternity|Size/is))
		# {
		if($menucontent =~ m/<h2[^>]*?>\s*$menu1\s*<\/h2>([\w\W]*?)<\/div>\s*<\/div>/is)
		{
			my $subcont = $1;
			while($subcont =~ m/<div\s*class\=\"column\">\s*<ul\s*>\s*<li\s*>\s*([^>]*?)\s*<\/li>([\w\W]*?)(?:<\/ul>|<li\s*class\=\"seperator\")/igs)
			{
				my $menu2 = &clean($1);
				my $subcont2 = $2;
				#next if($menu2 =~ m/View\s*all/is);
				while($subcont2 =~ m/href\=\"([^>]*?)\">\s*([^>]*?)\s*<\/a>/igs)
				{
					my $caturl2 = $1; 
					my $menu3 = &clean($2); 
					#next if($menu3 =~ m/View\s*all/is);
					$caturl2='http://www.newlook.com'.$caturl2 unless($caturl2=~m/^\s*http\:/is);
					my $menucontent2 = lwp_get($caturl2); 
					while($menucontent2 =~ m/<h5>\s*([^>]*?)<\/h5>([\w\W]*?)<\/div>\s*<\/div>/igs)
					{
						my $menu4 = &clean($1); #Type
						my $tempcont2 = $2;
						next if($menu4 =~ m/Size|Price|Rating/is);
						while($tempcont2 =~ m/class\=\"refine\"\s*href\=\"([^>]*?)\">\s*(?:<span[^>]*?>\s*<\/span>)?\s*([^>]*?)\s*<\/a>/igs)
						{
							my $caturl3 = $1;
							my $menu5 = &clean($2); #Tops
							$caturl3 = 'http://www.newlook.com'.$caturl3 unless($caturl3 =~ m/^\s*http\:/is);
							my $menucontent3 = lwp_get($caturl3); 
							NEXT2:
							while($menucontent3 =~ m/class\=\"desc\">\s*<a\s*href\=\"([^>]*?)\"/igs)
							{
								my $product_url = $1;
								$product_url = 'http://www.newlook.com'.$product_url unless($product_url =~ m/^\s*http\:/is);
								my ($product_object_key, $pids);
								if($product_url =~ m/_([\d+]{7})/is)
								{
									$pids = $1;
								}
								if($totalHash{$pids} ne '')
								{
									print "Data Exists! -> $totalHash{$pids}\n";
									$product_object_key = $totalHash{$pids};
								}
								else
								{
									print "New Data\n";
									$product_object_key = DBIL::SaveProduct($product_url,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
									$totalHash{$pids}=$product_object_key;
								}
								print "Loop2 => $menu1->$menu2->$menu3->$menu4->$menu5\n";
								DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) unless($menu1 eq '');
								DBIL::SaveTag('Menu_2',$menu2,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) unless($menu2 eq '');
								DBIL::SaveTag('Menu_3',$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) unless($menu3 eq '');
								DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) unless($menu4 eq '');
								$dbh->commit();
							}
							if($menucontent3 =~ m/href\=\"([^>]*?)\">\s*Next\s*<\/a>/is)
							{
								my $next = $1;
								$next = 'http://www.newlook.com'.$next unless($next =~ m/^\s*http\:/is);
								$menucontent3 = lwp_get($next); 
								goto NEXT2;
							}
						}
					}
				}
			}
			while($subcont =~ m/\"seperator\"[^>]*?>(?:<span[^>]*?>)?\s*([^>]*?)\s*(?:<\/span>\s*)?<\/li>\s*([\w\W]*?)(?:<\/ul>|<li\s*class\=)/igs)## SAle
			{
				my $menu2 = &clean($1);
				my $subcont2 = $2;
				#next if($menu2 =~ m/View\s*all/is);
				while($subcont2 =~ m/href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/a>/igs)
				{
					my $caturl2 = $1; 
					my $menu3 = &clean($2); 
					#next if($menu3 =~ m/View\s*all/is);
					$caturl2='http://www.newlook.com'.$caturl2 unless($caturl2=~m/^\s*http\:/is);
					my $menucontent2 = lwp_get($caturl2); 
					while($menucontent2 =~ m/<h5>\s*([^>]*?)<\/h5>([\w\W]*?)<\/div>\s*<\/div>/igs)
					{
						my $menu4 = &clean($1); #Type
						my $tempcont2 = $2;
						next if($menu4 =~ m/Size|Price|Rating/is);
						while($tempcont2 =~ m/class\=\"refine\"\s*href\=\"([^>]*?)\">\s*(?:<span[^>]*?>\s*<\/span>)?\s*([^>]*?)\s*<\/a>/igs)
						{
							my $caturl3 = $1;
							my $menu5 = &clean($2); #Tops
							$caturl3 = 'http://www.newlook.com'.$caturl3 unless($caturl3 =~ m/^\s*http\:/is);
							my $menucontent3 = lwp_get($caturl3); 
							NEXT2:
							while($menucontent3 =~ m/class\=\"desc\">\s*<a\s*href\=\"([^>]*?)\"/igs)
							{
								my $product_url = $1;
								$product_url = 'http://www.newlook.com'.$product_url unless($product_url =~ m/^\s*http\:/is);
								my ($product_object_key, $pids);
								if($product_url =~ m/_([\d+]{7})/is)
								{
									$pids = $1;
								}
								if($totalHash{$pids} ne '')
								{
									print "Data Exists! -> $totalHash{$pids}\n";
									$product_object_key = $totalHash{$pids};
								}
								else
								{
									print "New Data\n";
									$product_object_key = DBIL::SaveProduct($product_url,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
									$totalHash{$pids}=$product_object_key;
								}
								print "Loop 3 => $menu1->$menu2->$menu3->$menu4->$menu5\n";
								DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) unless($menu1 eq '');
								DBIL::SaveTag('Menu_2',$menu2,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) unless($menu2 eq '');
								DBIL::SaveTag('Menu_3',$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) unless($menu3 eq '');
								DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) unless($menu4 eq '');
								$dbh->commit();
							}
							if($menucontent3 =~ m/href\=\"([^>]*?)\">\s*Next\s*<\/a>/is)
							{
								my $next = $1;
								$next = 'http://www.newlook.com'.$next unless($next =~ m/^\s*http\:/is);
								$menucontent3 = lwp_get($next); 
								goto NEXT2;
							}
						}
					}
				}
			}
		}
	}
}
# system(`/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl /opt/home/merit/Merit_Robots/Newlook-UK--Detail.pl &`);	

#################### For Dashboard #######################################
DBIL::Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);
##################### For Dashboard #######################################

sub lwp_get() 
{ 
	my $url=shift;
	my $rerun_count=0;
	$url =~ s/^\s+|\s+$|amp\;//g;
	home:
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
    if($code =~m/20/is)
	{
		return($res->content());
	}
	else
	{
		if ( $rerun_count <= 3 )
		{
			$rerun_count++;
			goto home;
		}
	}
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
