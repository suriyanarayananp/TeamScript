#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
###### Module Initialization ##############
use strict;
use LWP::UserAgent;
use HTML::Entities;
use URI::URL;
use HTTP::Cookies;
use DBI;
use DateTime;
#require "/opt/home/merit/Merit_Robots/DBIL/DBIL.pm"; # USER DEFINED MODULE DBIL.PM
require "/opt/home/merit/Merit_Robots/DBILv2/DBIL.pm";
#require "/opt/home/merit/Merit_Robots/DBIL_Updated/DBIL.pm"; 
###########################################

#### Variable Initialization ##############
my $robotname = $0;
$robotname =~ s/\.pl//igs;
$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
my $retailer_name=$robotname;
$retailer_name =~ s/\-\-List\s*$//igs;
$retailer_name = lc($retailer_name);
my $Retailer_Random_String='Hmu';
my $pid = $$;
my $ip = `/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`;
$ip = $1 if($ip =~ m/inet\s*addr\:([^>]*?)\s+/is);
my $excuetionid = $ip.'_'.$pid;
my %totalHash;
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

my $select_query = "select ObjectKey from Retailer where name=\'h&m-uk\'";
my $retailer_id = DBIL::Objectkey_Checking($select_query, $dbh, $robotname);
DBIL::RetailerUpdate($retailer_id,$excuetionid,$dbh,$robotname,'start');

my $retailer_name1='h&m-uk';
################### For Dashboard #######################################
DBIL::Save_mc_instance_Data($retailer_name1,$retailer_id,$pid,$ip,'START',$robotname);
################### For Dashboard #######################################

############ URL Collection ##############
#Home Page 
my $content = lwp_get("http://www.hm.com/gb/"); 

my @regex_array=('<a[^>]*?href\=\"([^>]*?)\"[^>]*?>\s*(sale)\s*<','<a[^>]*?href\=\"([^>]*?)\"[^>]*?>\s*(LADIES)\s*<','<a[^>]*?href\=\"([^>]*?)\"[^>]*?>\s*(MEN)\s*<','<a[^>]*?href\=\"([^>]*?)\"[^>]*?>\s*(KIDS)\s*<','<a[^>]*?href\=\"([^>]*?)\"[^>]*?>\s*(Home)\s*<'); 

my $robo_menu=$ARGV[0];

foreach my $regex(@regex_array)
{
	if ( $content =~ m/$regex/is )
	{
		my $url2 = $1;
		my $menu1 = &clean($2);  #Ladies
		
		next unless($menu1 eq $robo_menu);
		
		my $subcont = lwp_get($url2); 
		if($menu1 !~ m/Sale/is)
		{	
			if($subcont =~ m/<ul\s*class\=\"filters\">([\w\W]*?)<\/ul>/is)  #New Arrivals Only
			{
				my $subcont2 = $1;
				while($subcont2 =~ m/<a\s*href\=\"([^>]*?)\"\s*class\=\"[^>]*?\"\s*rel\=\"nofollow\">\s*<span>\s*([^>]*?)\s*<\/span>/igs)
				{
					my $url3 = $1;
					my $menu2 = &clean($2); #NEW aRRIVALS
					my $subcont3 = lwp_get($url3); 
					while($subcont3 =~ m/<div\s*class\=\"dimension[^>]*?data\-metricsName\=\"[^>]*?\">\s*<strong>\s*([^>]*?)\s*<\/strong>([\w\W]*?)<\/div>/igs)
					{
						my $menu3 = &clean($1); #Filters like Colour /Size / Concepts
						my $subcont4 = $2;
						next if($menu3 =~ m/Size|Price|Ratings/is);
						while($subcont4 =~ m/<a\s*href\=\"([^>]*?)\"\s*class\=\"[^>]*?\"\s*rel\=\"nofollow\">\s*([^>]*?)\s*<\/a>/igs)
						{
							my $url4 = $1;
							my $menu4 = &clean($2); ### White/ Red ...
							$url4 = $url4.'&xhr=true';
							my $subcont5 = lwp_get($url4); 
							NEXTPage:
							while($subcont5 =~ m/<li[^>]*?>\s*<div>\s*<a[^>]*?href=(?:\"|\')\s*([^>]*?)\s*(?:\"|\')[^>]*?>\s*<span\s*class\s*\=\s*(?:\"|\')\s*details\s*(?:\"|\')\s*>/igs)
							{
								my $purl = $1;
								next if($purl=~m/SIMILAR_TO_SD$/is);
								$purl =~ s/\?[^>]*?$//igs;
								my $product_object_key;
								if($totalHash{$purl} ne '')
								{
									$product_object_key = $totalHash{$purl};
								}
								else
								{
									$product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
									$totalHash{$purl}=$product_object_key;
								}
								###Insert Product values
								unless($menu1=~m/^\s*$/is)
								{
									DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
								}
								unless($menu2=~m/^\s*$/is)
								{
									DBIL::SaveTag('Menu_2',$menu2,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
								}
								unless($menu4=~m/^\s*$/is)
								{
									DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
								}
								$dbh->commit();
							}
							if($subcont5 =~ m/href\=\"([^>]*?)\">\s*Next\s*</is)
							{
								my $next = $1;
								my $turl = $url4;
								$turl =~ s/\?([^>]*?)$//igs;
								$next = $turl.$next unless($next =~ m/^http/is);
								next if($next =~ m/\#/is);
								$subcont5 = lwp_get($next); 
								goto NEXTPage;
							}
						}
					}
					
				}
			}
			if($subcont =~ m/<ul\s*class\=\"products\s*single\">([\w\W]*?)<\/ul>/is)  ###Single Products
			{
				my $subcont2 = $1;
				while($subcont2 =~ m/<a\s*href\=\"([^>]*?)\"\s*class\=\"[^>]*?\"\s*rel\=\"nofollow\">\s*([^>]*?)\s*<\/a>/igs)
				{
					my $url3 = $1;
					my $menu2 = &clean($2); #Tops
					my $subcont3 = lwp_get($url3); 
					if($subcont3 =~ m/<li\s*class\=\"unfolded\">\s*<a\s*href\=\"[^>]*?\"\s*class\=\"\s*act\"[^>]*?>\s*([^>]*?)\s*<\/a>\s*([\w\W]*?)<\/ul>/is)
					{
						my $subcont4 = $2;
						while($subcont4 =~ m/<a\s*href\=\"([^>]*?)\"\s*class\=\"[^>]*?\"\s*rel\=\"nofollow\">\s*([^>]*?)\s*<\/a>/igs)
						{
							my $url4 = $1;
							my $menu3 = &clean($2); #Vest
							next if($menu3 =~ m/View\s*All/is);
							my $subcont5 = lwp_get($url4); 
							if($subcont5 =~ m/<ul\s*class\=\"subsubtype\">([\w\W]*?)<\/ul>/is)
							{
								my $subcont6 = $1;
								while($subcont6 =~ m/<a\s*href\=\"([^>]*?)\"\s*class\=\"[^>]*?\"\s*rel\=\"nofollow\">\s*([^>]*?)\s*<\/a>/igs)
								{
									my $url5 = $1;
									my $menu4 = &clean($2);
									next if($menu4 =~ m/View\s*All/is);
									my $subcont7 = lwp_get($url5); 
									if($subcont7 =~ m/<div\s*class\=\"dimension[^>]*?data\-metricsName\=\"[^>]*?\">\s*<strong>\s*([^>]*?)\s*<\/strong>([\w\W]*?)<\/div>/is)
									{
										while($subcont7 =~ m/<div\s*class\=\"dimension[^>]*?data\-metricsName\=\"[^>]*?\">\s*<strong>\s*([^>]*?)\s*<\/strong>([\w\W]*?)<\/div>/igs)
										{
											my $menu5 = &clean($1); #Filters like Colour /Size / Concepts
											my $subcont8 = $2;
											next if($menu5 =~ m/Size|Price|Ratings/is);
											while($subcont8 =~ m/<a\s*href\=\"([^>]*?)\"\s*class\=\"[^>]*?\"\s*rel\=\"nofollow\">\s*([^>]*?)\s*<\/a>/igs)
											{
												my $url6 = $1;
												my $menu6 = &clean($2); ### White/ Red ...
												$url6 = $url6.'&xhr=true';
												my $subcont9 = lwp_get($url6); 
												NEXTPage2:
												while($subcont9 =~ m/<li[^>]*?>\s*<div>\s*<a[^>]*?href=(?:\"|\')\s*([^>]*?)\s*(?:\"|\')[^>]*?>\s*<span\s*class\s*\=\s*(?:\"|\')\s*details\s*(?:\"|\')\s*>/igs)
												{
													my $purl = $1;
													next if($purl=~m/SIMILAR_TO_SD$/is);
													$purl =~ s/\?[^>]*?$//igs;
													my $product_object_key;
													if($totalHash{$purl} ne '')
													{
														$product_object_key = $totalHash{$purl};
													}
													else
													{
														$product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
														$totalHash{$purl}=$product_object_key;
													}
													###Insert Product values
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
														DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
													}
													unless($menu4=~m/^\s*$/is)
													{
														DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
													}
													unless($menu6=~m/^\s*$/is)
													{
														DBIL::SaveTag($menu5,$menu6,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
													}
													$dbh->commit();
												}
												if($subcont9 =~ m/href\=\"([^>]*?)\">\s*Next\s*</is)
												{
													my $next = $1;
													my $turl = $url6;
													$turl =~ s/\?([^>]*?)$//igs;
													$next = $turl.$next unless($next =~ m/^http/is);
													next if($next =~ m/\#/is);
													$subcont9 = lwp_get($next); 
													goto NEXTPage2;
												}
											}
										}
									}
									else
									{
										#No filters...
										NEXTPage2_2:
										while($subcont7 =~ m/<li[^>]*?>\s*<div>\s*<a[^>]*?href=(?:\"|\')\s*([^>]*?)\s*(?:\"|\')[^>]*?>\s*<span\s*class\s*\=\s*(?:\"|\')\s*details\s*(?:\"|\')\s*>/igs)
										{
											my $purl = $1;
											next if($purl=~m/SIMILAR_TO_SD$/is);
											$purl =~ s/\?[^>]*?$//igs;
											my $product_object_key;
											if($totalHash{$purl} ne '')
											{
												$product_object_key = $totalHash{$purl};
											}
											else
											{
												$product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
												$totalHash{$purl}=$product_object_key;
											}
											###Insert Product values
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
												DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											}
											unless($menu4=~m/^\s*$/is)
											{
												DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											}
											$dbh->commit();
										}
										if($subcont7 =~ m/href\=\"([^>]*?)\">\s*Next\s*</is)
										{
											my $next = $1;
											my $turl = $url5;
											$turl =~ s/\?([^>]*?)$//igs;
											$next = $turl.$next unless($next =~ m/^http/is);
											next if($next =~ m/\#/is);
											$subcont7 = lwp_get($next); 
											goto NEXTPage2_2;
										}
									}
									
								}
							}
							else
							{
								if($subcont5 =~ m/<div\s*class\=\"dimension[^>]*?data\-metricsName\=\"[^>]*?\">\s*<strong>\s*([^>]*?)\s*<\/strong>([\w\W]*?)<\/div>/is)
								{
									while($subcont5 =~ m/<div\s*class\=\"dimension[^>]*?data\-metricsName\=\"[^>]*?\">\s*<strong>\s*([^>]*?)\s*<\/strong>([\w\W]*?)<\/div>/igs)
									{
										my $menu4 = &clean($1); #Filters like Colour /Size / Concepts
										my $subcont6 = $2;
										next if($menu4 =~ m/Size|Price|Ratings/is);
										while($subcont6 =~ m/<a\s*href\=\"([^>]*?)\"\s*class\=\"[^>]*?\"\s*rel\=\"nofollow\">\s*([^>]*?)\s*<\/a>/igs)
										{
											my $url5 = $1;
											my $menu5 = &clean($2); ### White/ Red ...
											$url5 = $url5.'&xhr=true';
											my $subcont7 = lwp_get($url5); 
											NEXTPage21:
											while($subcont7 =~ m/<li[^>]*?>\s*<div>\s*<a[^>]*?href=(?:\"|\')\s*([^>]*?)\s*(?:\"|\')[^>]*?>\s*<span\s*class\s*\=\s*(?:\"|\')\s*details\s*(?:\"|\')\s*>/igs)
											{
												my $purl = $1;
												next if($purl=~m/SIMILAR_TO_SD$/is);
												$purl =~ s/\?[^>]*?$//igs;
												my $product_object_key;
												if($totalHash{$purl} ne '')
												{
													$product_object_key = $totalHash{$purl};
												}
												else
												{
													$product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
													$totalHash{$purl}=$product_object_key;
												}
												###Insert Product values
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
													DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												}
												unless($menu5=~m/^\s*$/is)
												{
													DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												}
												$dbh->commit();
											}
											if($subcont7 =~ m/href\=\"([^>]*?)\">\s*Next\s*</is)
											{
												my $next = $1;
												my $turl = $url5;
												$turl =~ s/\?([^>]*?)$//igs;
												$next = $turl.$next unless($next =~ m/^http/is);
												next if($next =~ m/\#/is);
												$subcont7 = lwp_get($next); 
												goto NEXTPage21;
											}
										}
									}
								}
								else
								{
									NEXTPage22:
									while($subcont5 =~ m/<li[^>]*?>\s*<div>\s*<a[^>]*?href=(?:\"|\')\s*([^>]*?)\s*(?:\"|\')[^>]*?>\s*<span\s*class\s*\=\s*(?:\"|\')\s*details\s*(?:\"|\')\s*>/igs)
									{
										my $purl = $1;
										next if($purl=~m/SIMILAR_TO_SD$/is);
										$purl =~ s/\?[^>]*?$//igs;
										my $product_object_key;
										if($totalHash{$purl} ne '')
										{
											$product_object_key = $totalHash{$purl};
										}
										else
										{
											$product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
											$totalHash{$purl}=$product_object_key;
										}
										###Insert Product values
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
											DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										}
										$dbh->commit();
									}
									if($subcont5 =~ m/href\=\"([^>]*?)\">\s*Next\s*</is)
									{
										my $next = $1;
										my $turl = $url4;
										$turl =~ s/\?([^>]*?)$//igs;
										$next = $turl.$next unless($next =~ m/^http/is);
										next if($next =~ m/\#/is);
										$subcont5 = lwp_get($next); 
										goto NEXTPage22;
									}
								}
							}
							
						}
					}
					elsif($subcont3 =~ m/<li\s*class\=\"unfolded\">\s*<a\s*href\=\"([^>]*?)\"\s*class\=\"\s*Single\s*act\"[^>]*?>/is)
					{
						if($subcont3 =~ m/<div\s*class\=\"dimension[^>]*?data\-metricsName\=\"[^>]*?\">\s*<strong>\s*([^>]*?)\s*<\/strong>([\w\W]*?)<\/div>/is)
						{
							while($subcont3 =~ m/<div\s*class\=\"dimension[^>]*?data\-metricsName\=\"[^>]*?\">\s*<strong>\s*([^>]*?)\s*<\/strong>([\w\W]*?)<\/div>/igs)
							{
								my $menu3 = &clean($1); #Filters like Colour /Size / Concepts
								my $subcont4 = $2;
								next if($menu3 =~ m/Size|Price|Ratings/is);
								while($subcont4 =~ m/<a\s*href\=\"([^>]*?)\"\s*class\=\"[^>]*?\"\s*rel\=\"nofollow\">\s*([^>]*?)\s*<\/a>/igs)
								{
									my $url4 = $1;
									my $menu4 = &clean($2); ### White/ Red ...
									$url4 = $url4.'&xhr=true';
									my $subcont5 = lwp_get($url4); 
									NEXTPage33:
									while($subcont5 =~ m/<li[^>]*?>\s*<div>\s*<a[^>]*?href=(?:\"|\')\s*([^>]*?)\s*(?:\"|\')[^>]*?>\s*<span\s*class\s*\=\s*(?:\"|\')\s*details\s*(?:\"|\')\s*>/igs)
									{
										my $purl = $1;
										next if($purl=~m/SIMILAR_TO_SD$/is);
										$purl =~ s/\?[^>]*?$//igs;
										my $product_object_key;
										if($totalHash{$purl} ne '')
										{
											$product_object_key = $totalHash{$purl};
										}
										else
										{
											$product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
											$totalHash{$purl}=$product_object_key;
										}
										###Insert Product values
										unless($menu1=~m/^\s*$/is)
										{
											DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										}
										unless($menu2=~m/^\s*$/is)
										{
											DBIL::SaveTag('Menu_2',$menu2,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										}
										unless($menu4=~m/^\s*$/is)
										{
											DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										}
										$dbh->commit();
									}
									if($subcont5 =~ m/href\=\"([^>]*?)\">\s*Next\s*</is)
									{
										my $next = $1;
										my $turl = $url4;
										$turl =~ s/\?([^>]*?)$//igs;
										$next = $turl.$next unless($next =~ m/^http/is);
										next if($next =~ m/\#/is);
										$subcont5 = lwp_get($next); 
										goto NEXTPage33;
									}
								}
							}
						}
						else
						{
							NEXTPage34:
							while($subcont3 =~ m/<li[^>]*?>\s*<div>\s*<a[^>]*?href=(?:\"|\')\s*([^>]*?)\s*(?:\"|\')[^>]*?>\s*<span\s*class\s*\=\s*(?:\"|\')\s*details\s*(?:\"|\')\s*>/igs)
							{
								my $purl = $1;
								next if($purl=~m/SIMILAR_TO_SD$/is);
								$purl =~ s/\?[^>]*?$//igs;
								my $product_object_key;
								if($totalHash{$purl} ne '')
								{
									$product_object_key = $totalHash{$purl};
								}
								else
								{
									$product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
									$totalHash{$purl}=$product_object_key;
								}
								###Insert Product values
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
							if($subcont3 =~ m/href\=\"([^>]*?)\">\s*Next\s*</is)
							{
								my $next = $1;
								my $turl = $url3;
								$turl =~ s/\?([^>]*?)$//igs;
								$next = $turl.$next unless($next =~ m/^http/is);
								next if($next =~ m/\#/is);
								$subcont3 = lwp_get($next); 
								goto NEXTPage34;
							}
						}
					}
				}
			}
			if($subcont =~ m/<li\s*class\=\"unfolded\"[^>]*?>\s*<a[^>]*?>\s*([^>]*?)\s*<\/a>([\w\W]*?)<\/ul>/is)  ## This Week Products
			{
				my $menu2 = &clean($1);
				my $subcont2 = $2;
				while($subcont2 =~ m/<a\s*href\=\"([^>]*?)\"\s*class\=\"[^>]*?\"\s*rel\=\"nofollow\">\s*([^>]*?)\s*<\/a>/igs)
				{
					my $url3 = $1;
					my $menu3 = &clean($2); #Tops
					my $subcont3 = lwp_get($url3); 
					if($subcont3 =~ m/<div\s*class\=\"dimension[^>]*?data\-metricsName\=\"[^>]*?\">\s*<strong>\s*([^>]*?)\s*<\/strong>([\w\W]*?)<\/div>/is)
					{
						while($subcont3 =~ m/<div\s*class\=\"dimension[^>]*?data\-metricsName\=\"[^>]*?\">\s*<strong>\s*([^>]*?)\s*<\/strong>([\w\W]*?)<\/div>/igs)
						{
							my $menu4 = &clean($1); #Filters like Colour /Size / Concepts
							my $subcont4 = $2;
							next if($menu4 =~ m/Size|Price|Ratings/is);
							while($subcont4 =~ m/<a\s*href\=\"([^>]*?)\"\s*class\=\"[^>]*?\"\s*rel\=\"nofollow\">\s*([^>]*?)\s*<\/a>/igs)
							{
								my $url4 = $1;
								my $menu5 = &clean($2); ### White/ Red ...
								$url4 = $url4.'&xhr=true';
								my $subcont5 = lwp_get($url4); 
								NEXTPage46:
								while($subcont5 =~ m/<li[^>]*?>\s*<div>\s*<a[^>]*?href=(?:\"|\')\s*([^>]*?)\s*(?:\"|\')[^>]*?>\s*<span\s*class\s*\=\s*(?:\"|\')\s*details\s*(?:\"|\')\s*>/igs)
								{
									my $purl = $1;
									next if($purl=~m/SIMILAR_TO_SD$/is);
									$purl =~ s/\?[^>]*?$//igs;
									my $product_object_key;
									if($totalHash{$purl} ne '')
									{
										$product_object_key = $totalHash{$purl};
									}
									else
									{
										$product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
										$totalHash{$purl}=$product_object_key;
									}
									###Insert Product values
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
										DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									}
									unless($menu5=~m/^\s*$/is)
									{
										DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									}
									$dbh->commit();
								}
								if($subcont5 =~ m/href\=\"([^>]*?)\">\s*Next\s*</is)
								{
									my $next = $1;
									my $turl = $url4;
									$turl =~ s/\?([^>]*?)$//igs;
									$next = $turl.$next unless($next =~ m/^http/is);
									next if($next =~ m/\#/is);
									$subcont5 = lwp_get($next); 
									goto NEXTPage46;
								}
							}
						}
					}
					else
					{
						NEXTPage45:
						while($subcont3 =~ m/<li[^>]*?>\s*<div>\s*<a[^>]*?href=(?:\"|\')\s*([^>]*?)\s*(?:\"|\')[^>]*?>\s*<span\s*class\s*\=\s*(?:\"|\')\s*details\s*(?:\"|\')\s*>/igs)
						{
							my $purl = $1;
							next if($purl=~m/SIMILAR_TO_SD$/is);
							$purl =~ s/\?[^>]*?$//igs;
							my $product_object_key;
							if($totalHash{$purl} ne '')
							{
								$product_object_key = $totalHash{$purl};
							}
							else
							{
								$product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
								$totalHash{$purl}=$product_object_key;
							}
							###Insert Product values
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
								DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
							}
							$dbh->commit();
						}
						if($subcont3 =~ m/href\=\"([^>]*?)\">\s*Next\s*</is)
						{
							my $next = $1;
							my $turl = $url3;
							$turl =~ s/\?([^>]*?)$//igs;
							$next = $turl.$next unless($next =~ m/^http/is);
							next if($next =~ m/\#/is);
							$subcont3 = lwp_get($next); 
							goto NEXTPage45;
						}
					}
				}
			}
			
		}
		elsif($menu1 =~ m/Sale/is)
		{
			while($subcont =~ m/<li\s*class\=\"folded\"\s*id\=\"filter[^>]*?>\s*<a\s*href\=\"[^>]*?\">\s*([^>]*?)\s*<\/a>([\w\W]*?)<\/ul>/igs)
			{
				my $menu2 = &clean($1);
				my $subcont2 = $2;
				while($subcont2 =~ m/<a\s*href\=\"([^>]*?)\"\s*class\=\"[^>]*?\"\s*rel\=\"nofollow\">\s*([^>]*?)\s*<\/a>/igs)
				{
					my $url3 = $1;
					my $menu3 = &clean($2); #Tops
					next if($menu3 =~ m/View\s*All/is);
					my $subcont3 = lwp_get($url3); 
					if($subcont3 =~ m/<li\s*class\=\"unfolded\">\s*<a\s*href\=\"[^>]*?\"\s*class\=\"\s*act\"[^>]*?>\s*([^>]*?)\s*<\/a>\s*([\w\W]*?)<\/ul>/is)
					{
						my $subcont4 = $2;
						while($subcont4 =~ m/<a\s*href\=\"([^>]*?)\"\s*class\=\"[^>]*?\"\s*rel\=\"nofollow\">\s*([^>]*?)\s*<\/a>/igs)
						{
							my $url4 = $1;
							my $menu4 = &clean($2);  #skinny Jeans
							next if($menu4 =~ m/View\s*All/is);
							my $subcont5 = lwp_get($url4); 
							if($subcont5 =~ m/<ul\s*class\=\"subsubtype\">([\w\W]*?)<\/ul>/is)
							{
								my $subcont6 = $1;
								while($subcont6 =~ m/<a\s*href\=\"([^>]*?)\"\s*class\=\"[^>]*?\"\s*rel\=\"nofollow\">\s*([^>]*?)\s*<\/a>/igs)
								{
									my $url5 = $1;
									my $menu5 = &clean($2);
									next if($menu5 =~ m/View\s*All/is);
									my $subcont7 = lwp_get($url5); 
									if($subcont7 =~ m/<div\s*class\=\"dimension[^>]*?data\-metricsName\=\"[^>]*?\">\s*<strong>\s*([^>]*?)\s*<\/strong>([\w\W]*?)<\/div>/is)
									{
										while($subcont7 =~ m/<div\s*class\=\"dimension[^>]*?data\-metricsName\=\"[^>]*?\">\s*<strong>\s*([^>]*?)\s*<\/strong>([\w\W]*?)<\/div>/igs)
										{
											my $menu6 = &clean($1); #Filters like Colour /Size / Concepts
											my $subcont8 = $2;
											next if($menu6 =~ m/Size|Price|Ratings/is);
											while($subcont8 =~ m/<a\s*href\=\"([^>]*?)\"\s*class\=\"[^>]*?\"\s*rel\=\"nofollow\">\s*([^>]*?)\s*<\/a>/igs)
											{
												my $url6 = $1;
												my $menu7 = &clean($2); ### White/ Red ...
												my $subcont9 = lwp_get($url6); 
												NEXTPages2:
												while($subcont9 =~ m/<li[^>]*?>\s*<div>\s*<a[^>]*?href=(?:\"|\')\s*([^>]*?)\s*(?:\"|\')[^>]*?>\s*<span\s*class\s*\=\s*(?:\"|\')\s*details\s*(?:\"|\')\s*>/igs)
												{
													my $purl = $1;
													next if($purl=~m/SIMILAR_TO_SD$/is);
													$purl =~ s/\?[^>]*?$//igs;
													my $product_object_key;
													if($totalHash{$purl} ne '')
													{
														$product_object_key = $totalHash{$purl};
													}
													else
													{
														$product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
														$totalHash{$purl}=$product_object_key;
													}
													###Insert Product values
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
														DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
													}
													unless($menu5=~m/^\s*$/is)
													{
														DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
													}
													unless($menu7=~m/^\s*$/is)
													{
														DBIL::SaveTag($menu6,$menu7,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
													}
													$dbh->commit();
												}
												if($subcont9 =~ m/href\=\"([^>]*?)\">\s*Next\s*</is)
												{
													my $next = $1;
													my $turl = $url6;
													$turl =~ s/\?([^>]*?)$//igs;
													$next = $turl.$next unless($next =~ m/^http/is);
													next if($next =~ m/\#/is);
													$subcont9 = lwp_get($next); 
													goto NEXTPages2;
												}
											}
										}
									}
									else
									{
										#No filters...
										NEXTPages2_2:
										while($subcont7 =~ m/<li[^>]*?>\s*<div>\s*<a[^>]*?href=(?:\"|\')\s*([^>]*?)\s*(?:\"|\')[^>]*?>\s*<span\s*class\s*\=\s*(?:\"|\')\s*details\s*(?:\"|\')\s*>/igs)
										{
											my $purl = $1;
											next if($purl=~m/SIMILAR_TO_SD$/is);
											$purl =~ s/\?[^>]*?$//igs;
											my $product_object_key;
											if($totalHash{$purl} ne '')
											{
												$product_object_key = $totalHash{$purl};
											}
											else
											{
												$product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
												$totalHash{$purl}=$product_object_key;
											}
											###Insert Product values
											unless($menu1=~m/^\s*$/is)
											{
												DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											}
											unless($menu2=~m/^\s*$/is)
											{
												DBIL::SaveTag('Menu_2',$menu2,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											}
											unless($menu4=~m/^\s*$/is)
											{
												DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
											}
											$dbh->commit();
										}
										if($subcont7 =~ m/href\=\"([^>]*?)\">\s*Next\s*</is)
										{
											my $next = $1;
											my $turl = $url5;
											$turl =~ s/\?([^>]*?)$//igs;
											$next = $turl.$next unless($next =~ m/^http/is);
											next if($next =~ m/\#/is);
											$subcont7 = lwp_get($next); 
											goto NEXTPages2_2;
										}
									}
									
								}
							}
							else
							{
								if($subcont5 =~ m/<div\s*class\=\"dimension[^>]*?data\-metricsName\=\"[^>]*?\">\s*<strong>\s*([^>]*?)\s*<\/strong>([\w\W]*?)<\/div>/is)
								{

									while($subcont5 =~ m/<div\s*class\=\"dimension[^>]*?data\-metricsName\=\"[^>]*?\">\s*<strong>\s*([^>]*?)\s*<\/strong>([\w\W]*?)<\/div>/igs)
									{
										my $menu5 = &clean($1); #Filters like Colour /Size / Concepts
										my $subcont6 = $2;
										next if($menu5 =~ m/Size|Price|Ratings/is);
										while($subcont6 =~ m/<a\s*href\=\"([^>]*?)\"\s*class\=\"[^>]*?\"\s*rel\=\"nofollow\">\s*([^>]*?)\s*<\/a>/igs)
										{
											my $url5 = $1;
											my $menu6 = &clean($2); ### White/ Red ...
											my $subcont7 = lwp_get($url5); 
											NEXTPages5_74:
											while($subcont7 =~ m/<li[^>]*?>\s*<div>\s*<a[^>]*?href=(?:\"|\')\s*([^>]*?)\s*(?:\"|\')[^>]*?>\s*<span\s*class\s*\=\s*(?:\"|\')\s*details\s*(?:\"|\')\s*>/igs)
											{
												my $purl = $1;
												next if($purl=~m/SIMILAR_TO_SD$/is);
												$purl =~ s/\?[^>]*?$//igs;
												my $product_object_key;
												if($totalHash{$purl} ne '')
												{
													$product_object_key = $totalHash{$purl};
												}
												else
												{
													$product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
													$totalHash{$purl}=$product_object_key;
												}
												###Insert Product values
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
													DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												}
												unless($menu6=~m/^\s*$/is)
												{
													DBIL::SaveTag($menu5,$menu6,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
												}
												$dbh->commit();
											}
											if($subcont7 =~ m/href\=\"([^>]*?)\">\s*Next\s*</is)
											{
												my $next = $1;
												my $turl = $url5;
												$turl =~ s/\?([^>]*?)$//igs;
												$next = $turl.$next unless($next =~ m/^http/is);
												next if($next =~ m/\#/is);
												$subcont7 = lwp_get($next); 
												goto NEXTPages5_74;
											}
										}
									}			
								}
								else
								{
								NEXTPages5_75:
								while($subcont5 =~ m/<li[^>]*?>\s*<div>\s*<a[^>]*?href=(?:\"|\')\s*([^>]*?)\s*(?:\"|\')[^>]*?>\s*<span\s*class\s*\=\s*(?:\"|\')\s*details\s*(?:\"|\')\s*>/igs)
								{
									my $purl = $1;
									next if($purl=~m/SIMILAR_TO_SD$/is);
									$purl =~ s/\?[^>]*?$//igs;
									my $product_object_key;
									if($totalHash{$purl} ne '')
									{
										$product_object_key = $totalHash{$purl};
									}
									else
									{
										$product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
										$totalHash{$purl}=$product_object_key;
									}
									###Insert Product values
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
										DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									}
									$dbh->commit();
								}
								if($subcont5 =~ m/href\=\"([^>]*?)\">\s*Next\s*</is)
								{
									my $next = $1;
									my $turl = $url4;
									$turl =~ s/\?([^>]*?)$//igs;
									$next = $turl.$next unless($next =~ m/^http/is);
									next if($next =~ m/\#/is);
									$subcont5 = lwp_get($next); 
									goto NEXTPages5_75;
								}
								}
								
							}
						}
					}
					elsif($subcont3 =~ m/<li\s*class\=\"unfolded\">\s*<a\s*href\=\"([^>]*?)\"\s*class\=\"\s*Single\s*act\"[^>]*?>/is)
					{
						# print "test2\n";
						if($subcont3 =~ m/<div\s*class\=\"dimension[^>]*?data\-metricsName\=\"[^>]*?\">\s*<strong>\s*([^>]*?)\s*<\/strong>([\w\W]*?)<\/div>/is)
						{
							while($subcont3 =~ m/<div\s*class\=\"dimension[^>]*?data\-metricsName\=\"[^>]*?\">\s*<strong>\s*([^>]*?)\s*<\/strong>([\w\W]*?)<\/div>/igs)
							{
								my $menu4 = &clean($1); #Filters like Colour /Size / Concepts
								my $subcont8 = $2;
								next if($menu4 =~ m/Size|Price|Ratings/is);
								while($subcont8 =~ m/<a\s*href\=\"([^>]*?)\"\s*class\=\"[^>]*?\"\s*rel\=\"nofollow\">\s*([^>]*?)\s*<\/a>/igs)
								{
									my $url6 = $1;
									my $menu5 = &clean($2); ### White/ Red ...
									$url6 = $url6.'&xhr=true';
									my $subcont9 = lwp_get($url6); 
									NEXTPages98:
									while($subcont9 =~ m/<li[^>]*?>\s*<div>\s*<a[^>]*?href=(?:\"|\')\s*([^>]*?)\s*(?:\"|\')[^>]*?>\s*<span\s*class\s*\=\s*(?:\"|\')\s*details\s*(?:\"|\')\s*>/igs)
									{
										my $purl = $1;
										next if($purl=~m/SIMILAR_TO_SD$/is);
										$purl =~ s/\?[^>]*?$//igs;
										my $product_object_key;
										if($totalHash{$purl} ne '')
										{
											$product_object_key = $totalHash{$purl};
										}
										else
										{
											$product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
											$totalHash{$purl}=$product_object_key;
										}
										###Insert Product values
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
											DBIL::SaveTag($menu3,$menu4,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										}
										unless($menu5=~m/^\s*$/is)
										{
											DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										}
										$dbh->commit();
									}
									if($subcont9 =~ m/href\=\"([^>]*?)\">\s*Next\s*</is)
									{
										my $next = $1;
										my $turl = $url6;
										$turl =~ s/\?([^>]*?)$//igs;
										$next = $turl.$next unless($next =~ m/^http/is);
										next if($next =~ m/\#/is);
										$subcont9 = lwp_get($next); 
										goto NEXTPages98;
									}
								}
							}
						}
						else
						{
							#No filters...
							NEXTPages299:
							while($subcont3 =~ m/<li[^>]*?>\s*<div>\s*<a[^>]*?href=(?:\"|\')\s*([^>]*?)\s*(?:\"|\')[^>]*?>\s*<span\s*class\s*\=\s*(?:\"|\')\s*details\s*(?:\"|\')\s*>/igs)
							{
								my $purl = $1;
								next if($purl=~m/SIMILAR_TO_SD$/is);
								$purl =~ s/\?[^>]*?$//igs;
								my $product_object_key;
								if($totalHash{$purl} ne '')
								{
									$product_object_key = $totalHash{$purl};
								}
								else
								{
									$product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
									$totalHash{$purl}=$product_object_key;
								}
								###Insert Product values
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
							if($subcont3 =~ m/href\=\"([^>]*?)\">\s*Next\s*</is)
							{
								my $next = $1;
								my $turl = $url3;
								$turl =~ s/\?([^>]*?)$//igs;
								$next = $turl.$next unless($next =~ m/^http/is);
								next if($next =~ m/\#/is);
								$subcont3 = lwp_get($next); 
								goto NEXTPages299;
							}
						}
					}
				}
			}
			if($subcont =~ m/<li\s*class\=\"unfolded\"[^>]*?>\s*<a[^>]*?>\s*([^>]*?)\s*<\/a>([\w\W]*?)<\/ul>/is)  ## This Week Products
			{
				my $menu2 = &clean($1);
				my $subcont2 = $2;
				while($subcont2 =~ m/<a\s*href\=\"([^>]*?)\"\s*class\=\"[^>]*?\"\s*rel\=\"nofollow\">\s*([^>]*?)\s*<\/a>/igs)
				{
					my $url3 = $1;
					my $menu3 = &clean($2); #Tops
					my $subcont3 = lwp_get($url3); 
					if($subcont3 =~ m/<div\s*class\=\"dimension[^>]*?data\-metricsName\=\"[^>]*?\">\s*<strong>\s*([^>]*?)\s*<\/strong>([\w\W]*?)<\/div>/is)
					{
						while($subcont3 =~ m/<div\s*class\=\"dimension[^>]*?data\-metricsName\=\"[^>]*?\">\s*<strong>\s*([^>]*?)\s*<\/strong>([\w\W]*?)<\/div>/igs)
						{
							my $menu4 = &clean($1); #Filters like Colour /Size / Concepts
							my $subcont4 = $2;
							next if($menu4 =~ m/Size|Price|Ratings/is);
							while($subcont4 =~ m/<a\s*href\=\"([^>]*?)\"\s*class\=\"[^>]*?\"\s*rel\=\"nofollow\">\s*([^>]*?)\s*<\/a>/igs)
							{
								my $url4 = $1;
								my $menu5 = &clean($2); ### White/ Red ...
								my $subcont5 = lwp_get($url4); 
								NEXTPages10:
								while($subcont5 =~ m/<li[^>]*?>\s*<div>\s*<a[^>]*?href=(?:\"|\')\s*([^>]*?)\s*(?:\"|\')[^>]*?>\s*<span\s*class\s*\=\s*(?:\"|\')\s*details\s*(?:\"|\')\s*>/igs)
								{
									my $purl = $1;
									next if($purl=~m/SIMILAR_TO_SD$/is);
									$purl =~ s/\?[^>]*?$//igs;
									my $product_object_key;
									if($totalHash{$purl} ne '')
									{
										$product_object_key = $totalHash{$purl};
									}
									else
									{
										$product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
										$totalHash{$purl}=$product_object_key;
									}
									###Insert Product values
									unless($menu1=~m/^\s*$/is)
									{
										DBIL::SaveTag('Menu_1',$menu1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									}
									unless($menu2=~m/^\s*$/is)
									{
										DBIL::SaveTag($menu2,$menu3,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									}
									unless($menu4=~m/^\s*$/is)
									{
										DBIL::SaveTag($menu4,$menu5,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
									}
									$dbh->commit();
								}
								if($subcont5 =~ m/href\=\"([^>]*?)\">\s*Next\s*</is)
								{
									my $next = $1;
									my $turl = $url4;
									$turl =~ s/\?([^>]*?)$//igs;
									$next = $turl.$next unless($next =~ m/^http/is);
									next if($next =~ m/\#/is);
									$subcont5 = lwp_get($next); 
									goto NEXTPages10;
								}
							}
						}
					}
					else
					{
						NEXTPages10_1:
						while($subcont3 =~ m/<li[^>]*?>\s*<div>\s*<a[^>]*?href=(?:\"|\')\s*([^>]*?)\s*(?:\"|\')[^>]*?>\s*<span\s*class\s*\=\s*(?:\"|\')\s*details\s*(?:\"|\')\s*>/igs)
						{
							my $purl = $1;
							next if($purl=~m/SIMILAR_TO_SD$/is);
							$purl =~ s/\?[^>]*?$//igs;
							my $product_object_key;
							if($totalHash{$purl} ne '')
							{
								$product_object_key = $totalHash{$purl};
							}
							else
							{
								$product_object_key = DBIL::SaveProduct($purl,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
								$totalHash{$purl}=$product_object_key;
							}
							###Insert Product values
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
						if($subcont3 =~ m/href\=\"([^>]*?)\">\s*Next\s*</is)
						{
							my $next = $1;
							my $turl = $url3;
							$turl =~ s/\?([^>]*?)$//igs;
							$next = $turl.$next unless($next =~ m/^http/is);
							next if($next =~ m/\#/is);
							$subcont3 = lwp_get($next); 
							goto NEXTPages10_1;
						}
					}
				}
			}
		}
	}
}

################### For Dashboard #######################################
DBIL::Save_mc_instance_Data($retailer_name1,$retailer_id,$pid,$ip,'STOP',$robotname);
################### For Dashboard #######################################

#Function to get Page's Content
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
#Function to remove Special Characters and and to replace decode_entities
sub clean() 
{ 
    my $var=shift; 
    $var=~s/<[^>]*?>//igs; 
    $var=~s/&nbsp\;|amp\;/ /igs; 
    $var=decode_entities($var); 
    $var=~s/\s+/ /igs; 
    return ($var); 
}
