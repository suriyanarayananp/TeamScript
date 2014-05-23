#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
###### Module Initialization ##############
use strict;
use LWP::UserAgent;
use HTML::Entities;
use URI::URL;
use HTTP::Cookies;
use DBI;
use DateTime;
#require "/opt/home/merit/Merit_Robots/DBIL/DBIL.pm";
require "/opt/home/merit/Merit_Robots/DBILv2/DBIL.pm";
###########################################

#### Variable Initialization ##############
my $robotname = $0;
$robotname =~ s/\.pl//igs;
$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
my $retailer_name=$robotname;
$retailer_name =~ s/\-\-List\s*$//igs;
$retailer_name = lc($retailer_name);
my $Retailer_Random_String='Zap';
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

my %totalHash;
my $menu1 = $ARGV[0];
my $menuurl1;
$menuurl1 = "http://www.zappos.com".$menuurl1 unless($menuurl1 =~ m/^http/is);
my $content = lwp_get($menuurl1); 
while($content =~ m/<li\s*class\=\"$menu1\">\s*<a\s*href\=\"([^>]*?)\"/igs)
{
	## Menu 1 => Clothing
	my $menuurl2 = $1;
	$menuurl2 = "http://www.zappos.com".$menuurl2 unless($menuurl2 =~ m/^http/is);
	# print"$";
	my $content2 = lwp_get($menuurl2); 
	while($content2 =~ m/<h4\s*>\s*<a\s*href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/a>/igs)
	{
		my $menuurl3 = $1;
		my $menu2 = &clean($2);   ## Menu2  => Women's Clothing
		next if($menu2 !~ m/$ARGV[1]/is);
		print"MENU2==>$menu2\n";
		$menuurl3 = "http://www.zappos.com".$menuurl3 unless($menuurl3 =~ m/^http/is);
		my $content3 = lwp_get($menuurl3);
		my $catStatus = 0;
		while($content3 =~ m/<h4\s*class\=\"stripeOuter\s*navOpen\">\s*<span>\s*<\/span>\s*([^>]*?)\s*<\/h4>([\w\W]*?)<\/div>/igs)
		{
			my $menu3 = &clean($1);  ## Category ==> Category value;
			my $subcont2 = $2;
			print"\n$menu3\n";
			if($menu3 =~ m/\bcategory\b/is)  ## If Category only
			{
				$catStatus = 1;
				while($subcont2 =~ m/href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*</igs)
				{
					my $menuurl4 = $1;
					my $menu4 = &clean($2);
					print"\n$menu4\n";
					$menuurl4 = "http://www.zappos.com".$menuurl4 unless($menuurl4 =~ m/^http/is);
					my $menucontent3 = lwp_get($menuurl4);
					while($menucontent3	 =~ m/<h4\s*class\=\"stripeOuter\s*navOpen\">\s*<span>\s*<\/span>\s*([^>]*?)\s*<\/h4>([\w\W]*?)<\/div>/igs)
					{
						my $menu5 = &clean($1);
						print"\n$menu5\n";
						my $subcont3 = $2;
						next if($menu5 =~ m/Brand|Size|Price|Rating|Width|Height/is);
						while($subcont3 =~ m/href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*</igs)
						{
							my $menuurl4 = $1;
							my $menu6 = &clean($2);
							print "$menu1->$menu2->$menu3->$menu4->$menu5->$menu6\n";
							$menuurl4 = "http://www.zappos.com".$menuurl4 unless($menuurl4 =~ m/^http/is);
							my $menucontent4 = lwp_get($menuurl4); 
							my $lastid = $2 if($menucontent4 =~ m/class\=\"last\">[^>]*?<a\s*href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/a>/is);
							my $lasturl = $1 if($menucontent4 =~ m/class\=\"last\">[^>]*?<a\s*href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/a>/is);
							my $i=2;
							NEXTPage:
							while($menucontent4 =~ m/href\=\"([^>]*?)\"\s*class\=\"product[^>]*?\"\s*data\-style\-id\=\"[^>]*?\"\s*data\-product\-id\=\"[^>]*?\"/igs) 
							{ 
								my $purl = &clean($1);
								$purl = "http://www.zappos.com".$purl unless($purl =~ m/^http/is);
								my $product_object_key;
								if($totalHash{$purl} ne '')
								{
									print "Data Exists! -> $totalHash{$purl}\n";
									$product_object_key = $totalHash{$purl};
								}
								else
								{
									print "New Data\n";
									$product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
									$totalHash{$purl}=$product_object_key;
								}
								DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) unless($menu1 eq '');
								DBIL::SaveTag('Menu_2',$menu2,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) unless($menu1 eq '');
								DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) unless($menu3 eq '');
								DBIL::SaveTag($menu5,$menu6,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) unless($menu5 eq '');
								$dbh->commit();
							} 
							while ($i<=$lastid)
							{
								my $pc = $i;
								$pc--;
								$lasturl = "http://www.zappos.com".$lasturl unless($lasturl =~ m/^http/is);
								print "NEXTPAGE => $lasturl\n";
								$lasturl =~ s/\-page\d+/\-page$i/is;
								$lasturl =~ s/p\=\d+/p\=$pc/is;
								print $lasturl,"\n"; #exit;
								$menucontent4 = lwp_get($lasturl);
								$i++;
								goto NEXTPage;
							}
						}
					}
				}
			}
			elsif($menu3=~m/\bProduct\s*Type\b/is)
			{
				$catStatus = 1;
				while($subcont2 =~ m/href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*</igs)
				{
					my $menuurl4 = $1;
					my $menu4 = &clean($2);
					#next if($menu4 ne 'Eyewear');
					$menuurl4 = "http://www.zappos.com".$menuurl4 unless($menuurl4 =~ m/^http/is);
					my $menucontent3 = lwp_get($menuurl4);
					while($menucontent3	 =~ m/<h4\s*class\=\"stripeOuter\s*navOpen\">\s*<span>\s*<\/span>\s*([^>]*?)\s*<\/h4>([\w\W]*?)<\/div>/igs)
					{
						my $menu5 = &clean($1);
						my $subcont3 = $2;
						next if($menu5 =~ m/Brand|Size|Price|Rating|Width|Height/is);
						while($subcont3 =~ m/href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*</igs)
						{
							my $menuurl4 = $1;
							my $menu6 = &clean($2);
							$menuurl4 = "http://www.zappos.com".$menuurl4 unless($menuurl4 =~ m/^http/is);
							my $menucontent4 = lwp_get($menuurl4);
							while($menucontent4	 =~ m/<h4\s*class\=\"stripeOuter\s*navOpen\">\s*<span>\s*<\/span>\s*([^>]*?)\s*<\/h4>([\w\W]*?)<\/div>/igs)
							{
								my $menu7 = &clean($1);
								my $subcont4 = $2;
								next if($menu7 =~ m/Brand|Size|Price|Rating|Width|Height/is);
								while($subcont4 =~ m/href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*</igs)
								{
									my $menuurl5 = $1;
									my $menu8 = &clean($2);
									print "$menu1->$menu2->$menu3->$menu4->$menu5->$menu6==>$menu7==>>$menu8\n";
									$menuurl5 = "http://www.zappos.com".$menuurl5 unless($menuurl5 =~ m/^http/is);
									my $menucontent5 = lwp_get($menuurl5);
									my $lastid = $2 if($menucontent5 =~ m/class\=\"last\">[^>]*?<a\s*href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/a>/is);
									my $lasturl = $1 if($menucontent5 =~ m/class\=\"last\">[^>]*?<a\s*href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/a>/is);
									my $i=2;
									NEXTPage3:
									while($menucontent5 =~ m/href\=\"([^>]*?)\"\s*class\=\"product[^>]*?\"\s*data\-style\-id\=\"[^>]*?\"\s*data\-product\-id\=\"[^>]*?\"/igs) 
									{ 
										my $purl = &clean($1);
										$purl = "http://www.zappos.com".$purl unless($purl =~ m/^http/is);
										my $product_object_key;
										if($totalHash{$purl} ne '')
										{
											print "Data Exists! -> $totalHash{$purl}\n";
											$product_object_key = $totalHash{$purl};
										}
										else
										{
											print "New Data\n";
											$product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
											$totalHash{$purl}=$product_object_key;
										}
										DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) unless($menu1 eq '');
										DBIL::SaveTag('Menu_2',$menu2,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) unless($menu1 eq '');
										DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) unless($menu3 eq '');
										DBIL::SaveTag($menu5,$menu6,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) unless($menu5 eq '');
										DBIL::SaveTag($menu7,$menu8,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) unless($menu5 eq '');
										$dbh->commit();
									} 
									while ($i<=$lastid)
									{
										my $pc = $i;
										$pc--;
										$lasturl = "http://www.zappos.com".$lasturl unless($lasturl =~ m/^http/is);
										print "NEXTPAGE => $lasturl\n";
										$lasturl =~ s/\-page\d+/\-page$i/is;
										$lasturl =~ s/p\=\d+/p\=$pc/is;
										print $lasturl,"\n"; #exit;
										$menucontent5 = lwp_get($lasturl);
										$i++;
										goto NEXTPage3;
									}
								}
							}
						}
					}
				}
				
			}
			elsif($catStatus == 0)
			{
				next if($menu3 =~ m/Brand|Size|Price|Rating|Width|Height/is);
				while($subcont2 =~ m/href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*</igs)
				{
					my $menuurl4 = $1;
					my $menu4 = &clean($2);
					# print"MENU4==>>$menu4\n";
					print "$menu1->$menu2->$menu3->$menu4\n";
					$menuurl4 = "http://www.zappos.com".$menuurl4 unless($menuurl4 =~ m/^http/is);
					my $menucontent4 = lwp_get($menuurl4); 
					my $lastid = $2 if($menucontent4 =~ m/class\=\"last\">[^>]*?<a\s*href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/a>/is);
					my $lasturl = $1 if($menucontent4 =~ m/class\=\"last\">[^>]*?<a\s*href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/a>/is);
					my $i=2;
					NEXTPage2:
					while($menucontent4 =~ m/href\=\"([^>]*?)\"\s*class\=\"product[^>]*?\"\s*data\-style\-id\=\"[^>]*?\"\s*data\-product\-id\=\"[^>]*?\"/igs) 
					{ 
						my $purl = &clean($1);
						$purl = "http://www.zappos.com".$purl unless($purl =~ m/^http/is);
						my $product_object_key;
						if($totalHash{$purl} ne '')
						{
							print "Data Exists! -> $totalHash{$purl}\n";
							$product_object_key = $totalHash{$purl};
						}
						else
						{
							print "New Data\n";
							$product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
							$totalHash{$purl}=$product_object_key;
						}
						DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) unless($menu1 eq '');
						DBIL::SaveTag('Menu_2',$menu2,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) unless($menu1 eq '');
						DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid) unless($menu3 eq '');
						$dbh->commit();
					} 
					while ($i<=$lastid)
					{
						my $pc = $i;
						$pc--;
						$lasturl = "http://www.zappos.com".$lasturl unless($lasturl =~ m/^http/is);
						print "NEXTPAGE => $lasturl\n";
						$lasturl =~ s/\-page\d+/\-page$i/is;
						$lasturl =~ s/p\=\d+/p\=$pc/is;
						print $lasturl,"\n"; #exit;
						$menucontent4 = lwp_get($lasturl);
						$i++;
						goto NEXTPage2;
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
$dbh->disconnect();
# system(`/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl /opt/home/merit/Merit_Robots/Zappos-US--Detail.pl &`);	
sub lwp_get() 
{ 
    my $url = shift;
    REPEAT: 
    my $req = HTTP::Request->new(GET=>$url); 
    $req->header("Accept"=>"text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"); 
    $req->header("Content-Type"=>"application/x-www-form-urlencoded"); 
    my $res = $ua->request($req); 
    $cookie->extract_cookies($res); 
    $cookie->save; 
    $cookie->add_cookie_header($req); 
    my $code = $res->code(); 
    open JJ,">>$retailer_file";
    print JJ "$url->$code\n";
    close JJ;
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
