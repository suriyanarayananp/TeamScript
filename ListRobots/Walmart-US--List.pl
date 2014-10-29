#!/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl
# Module Initialization.
use strict;
use LWP::UserAgent;
use Log::Syslog::Fast ':all';
use Net::Domain qw(hostname);
use Config::Tiny;

# Package Initialization.
require "/opt/home/merit/Merit_Robots/anorak-worker/AnorakDB.pm";
require "/opt/home/merit/Merit_Robots/anorak-worker/AnorakUtility.pm";

# Location of the config file with all settings.
my $ini_file = '/opt/home/merit/Merit_Robots/anorak-worker/anorak-worker.ini';

# Variable Initialization.
my $robotname = $0;
$robotname =~ s/\.pl//igs;
$robotname =$1 if($robotname =~ m/[^>]*?\/*([^\/]+?)\s*$/is);
my $retailer_name=$robotname;
$retailer_name =~ s/\-\-List\s*$//igs;
$retailer_name = lc($retailer_name);
my $Retailer_Random_String='Wal';
my $pid = $$;
my $ip = `/sbin/ifconfig eth0 | grep "inet addr" | awk -F: '{print $2}' | awk '{print $1}'`;
$ip = $1 if($ip =~ m/inet\s*addr\:([^>]*?)\s+/is);
my $executionid = $ip.'_'.$pid;
my %hash_id;
# Setting the UserAgent.
my $ua = LWP::UserAgent->new(show_progress=>1);
$ua->agent("Mozilla/5.0 (Windows; U; Windows NT 5.1; en-US; rv:1.9.2.3) Gecko/20100401 Firefox/3.6.3 (.NET CLR 3.5.30729)");
$ua->timeout(30);
$ua->cookie_jar({});

# Read the settings from the config file.
my $ini = Config::Tiny->new;
$ini = Config::Tiny->read($ini_file);
if (!defined $ini) 
{
	# Die if reading the settings failed.
	die "FATAL: ", Config::Tiny->errstr;
}

# Setup logging to syslog.
my $logger = Log::Syslog::Fast->new(LOG_UDP, $ini->{logs}->{server}, $ini->{logs}->{port}, LOG_LOCAL3, LOG_INFO, $ip,'aw-'. $pid . '@' . $ip );

# Connect to AnorakDB Package.
my $dbobject = AnorakDB->new($logger,$executionid);
$dbobject->connect($ini->{mysql}->{host}, $ini->{mysql}->{port}, $ini->{mysql}->{name}, $ini->{mysql}->{user}, $ini->{mysql}->{pass});

# Connect to Utility package.
my $utilityobject = AnorakUtility->new($logger,$ua);

# Getting Retailer_id and Proxystring.
my ($retailer_id,$ProxySetting) = $dbobject->GetRetailerProxy($retailer_name);
$dbobject->RetailerUpdate($retailer_id,$robotname,'start');

# Setting the Environment Variables.
$utilityobject->SetEnv($ProxySetting);

# To indicate script has started in dashboard. 
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'START',$robotname);

# Once script has started send a msg to logger.
$logger->send("$robotname :: Instance Started :: $pid\n");

# Getting home page content.
my $url = 'http://www.walmart.com/';
my $content = $utilityobject->Lwp_Get($url);
my $menu1 = $ARGV[0];
############ URL Collection ##############
# Pattern match to take Top menu & it's block.
#if($content=~m/class\=nav\-flyout-heading>(\s*<a\s*href\=[^>]*?>\s*$ARGV[1]\s*[\w\W]*?)<\/a>\s*<\/div>\s*<\/div>/is)
if($content=~m/class\=nav\-flyout-heading>(\s*<a[^>]*?href\=[^>]*?>\s*$ARGV[1]\s*[\w\W]*?)<\/a>\s*<\/div>\s*<\/div>/is)
{
	print "I am here\n";
	my $block1 = $1;
	while($block1 =~ m/href\=\"\s*[^>]*?\s*\">\s*([^>]*?)\s*<i>([\w\W]*?)<\/li>\s*<\/ul>/igs)
	{
		my $menu2 = $1;
		my $block2 = $2;
		# next if($menu2 =~ m/clothing/is);
		while($block2 =~ m/href\=\"\s*([^>]*?)\s*\">\s*([^>]*?)\s*<\/a>/igs)
		{
			my $pgurl1 = $1;
			my $menu3 = $utilityobject->Decode($2);
			# next unless($menu3 =~ m/Tall/is);
			$pgurl1 = $url.$pgurl1 unless($pgurl1 =~ m/^http/is);
			my $cont2 = $utilityobject->Lwp_Get($pgurl1);
			print "menu 3 URL:; $pgurl1\n";
			print "$menu1 -> $menu2 -> $menu3\n";
			##next unless($menu3 =~ m/Ear\s*Piercing|Wedding\s*\&\s*Engagement/is);		### Remove after the testing	
			# open ss,">walmart2.html";
			# print ss $cont2;
			# close ss;
			# exit;
			my $abspath = $1 if($cont2 =~ m/rel\=canonical\s*href\=\"([^>]*?)\"/is);
			$abspath = "http://www.walmart.com".$abspath if($abspath !~ m/^http/is);
			# while($cont2 =~ m/class\=expander\-toggle\s*href\=\"#\">\s*([^>]*?)\s*<\/a>([\w\W]*?)<\/div>\s*<\/div>/igs)  ## LH Filter Block
			if($cont2 =~ m/class\=expander\-toggle[^>]*?>\s*([^>]*?)\s*<\/a>([\w\W]*?)<\/div>\s*<\/div>/is)
			{
				while($cont2 =~ m/class\=expander\-toggle[^>]*?>\s*([^>]*?)\s*<\/a>([\w\W]*?)<\/div>\s*<\/div>/igs)  ## LH Filter Block
				{
					my $filterheader = $utilityobject->Decode($1);
					my $filterblock = $2;
					
					# next unless($filterheader =~ m/popular\s*in\s*BOYS/is);
					next if($filterheader =~ m/Department|rating|size|brand|price|save/is);  #Skip few filters
					
					if($filterblock =~ m/href\=\"([^>]*?)\">\s*(?:<[^>]*?>\s*)\s*([^>]*?)\s*<\/span>|href\=\"([^>]*?)\">\s*(?:<[^>]*?>\s*)[\w\W]*?>([^>]*?)\s*<\/div>|href\=\"\s*([^>]*?)\s*\">\s*([^>]*?)\s*<\/a>/is)
					{
						#while($filterblock =~ m/href\=\"([^>]*?)\">\s*(?:<[^>]*?>\s*)\s*([^>]*?)\s*<\/span>|href\=\"([^>]*?)\">\s*(?:<[^>]*?>\s*)[\w\W]*?>([^>]*?)\s*<\/div>|href\=\"\s*([^>]*?)\s*\">\s*([^>]*?)\s*<\/a>/igs)
						while($filterblock =~ m/href\=\"([^>]*?)\">\s*(?:<[^>]*?>\s*)\s*([^>]*?)\s*<\/span>|href\=\"([^>]*?)\">\s*(?:<[^>]*?>\s*)[\w\W]*?>([^>]*?)\s*<\/div>|href\=\"\s*([^>]*?)\s*\">\s*([^>]*?)\s*<\/a>/igs)
						{
							my $filterurl = $utilityobject->Decode($1.$3.$5);
							my $filtervalue = $utilityobject->Decode($2.$4.$6);
							# my $filterurl2 = $1.$filterurl.'&ajax=true' if($pgurl1 =~ m/([^>]*?)\?/is);
							# $filterurl2 = $filterurl if($filterurl2 eq '');
							# next unless($filtervalue =~ m/skin\s*care/is);
							# print "FilterURL1 => $filterurl\n";
							if($filterheader =~ m/\bRetailer\b/is)
							{
								next unless($filtervalue=~ m/walmart/is);
							}
							my %nextpage;
							NextPage:
							$filterurl =~ s/\s+//igs;
							if($filterurl =~ m/browse/is || $filterurl !~ m/^\?/is)
							{
								$filterurl= "http://www.walmart.com".$filterurl unless($filterurl =~ m/^http/is);
							}
							else
							{
								$filterurl= "http://www.walmart.com/browse/".$filterurl unless($filterurl =~ m/^http/is);
							}
							# $filterurl= $abspath.$filterurl unless($filterurl =~ m/^http/is); # Accept: Accessories,
							#$filterurl= "$abspath".$filterurl unless($filterurl =~ m/^http/is);
							# my $abspath = $1 if($filterurl =~ m/([^>]*?)(?:\?|$)/is);
							# $filterurl2= "http://www.walmart.com".$filterurl2 unless($filterurl2 =~ m/^http/is);
							print "FilterURL2 => $filterurl\n";
							# print "FilterURL2 => $filterurl2\n";
							# my $filtercont = $utilityobject->Lwp_Get($filterurl2);
							my $filtercont = $utilityobject->Lwp_Get($filterurl);

							# open ss,">walmart3.html";
							# print ss $filtercont;
							# close ss;
							
							print "$menu1 -> $menu2 -> $menu3 -> $filterheader -> $filtervalue\n";
							while($filtercont =~ m/data\-item\-id\=\\\"([^>]*?)\\\"[^>]*?>|data\-item\-id\=([^>]*?)\s*data-seller[^>]*?>/igs)
							{
								
								my $pid = $utilityobject->Trim($1.$2);
								my $purl = "http://www.walmart.com/ip/$pid";
								$purl = $url.$purl unless($purl =~ m/^http/is);
								
								print "$pid\n";
								my $product_object_key;
								
								if($hash_id{$pid} eq '')
								{
									$product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
									$hash_id{$pid}=$product_object_key;
								}
								else
								{
									$product_object_key=$hash_id{$pid};
								}
								
								# Insert Tag values.
								$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
								$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
								$dbobject->SaveTag('Menu_3',$menu3,$product_object_key,$robotname,$Retailer_Random_String) if($menu3 ne '');
								unless($filterheader=~m/^\s*$/is)
								{
									$dbobject->SaveTag($filterheader,$filtervalue,$product_object_key,$robotname,$Retailer_Random_String) if($filtervalue ne '');
								}
								
								# Committing the transaction.
								$dbobject->commit();
							}
							if($filtercont =~ m/btn\-next\\\"\s*href\=\\\"([^>]*?)\\\">|btn\-next\"\s*href\=\"([^>]*?)\">/is)
							{
								$filterurl = $utilityobject->Decode($1.$2);
								# $filterurl = $abspath.$filterurl unless($filterurl =~ m/^http/is);
								# $filterurl = $1.$filterurl if($filtercont =~ m/rel\=canonical\s*href\=\"([^>]*?)\"/is);
								# $filterurl = "http://www.walmart.com".$filterurl if($filterurl !~ m/^http/is);
								# print "AbsPath ::: $abspath\n";
								if($filterurl =~ m/browse/is || $filterurl !~ m/^\?/is)
								{
									$filterurl= "http://www.walmart.com".$filterurl unless($filterurl =~ m/^http/is);
								}
								else
								{
									$filterurl= "http://www.walmart.com/browse/".$filterurl unless($filterurl =~ m/^http/is);
								}
								print "Page URL:: $filterurl\n";
								my $pageid;
								if($filterurl=~ m/page\=\s*(\d+)(?:[^>]*?$|[^>]*?\/)/is)
								{
									$pageid = $1;
									$nextpage{$pageid}++;
									print "Page ID $pageid :: $nextpage{$pageid} \n";
								}
								#<STDIN>;
								goto NONextPage if($nextpage{$pageid}>1);
								print "NextPage:::: $filterurl\n";
								goto NextPage;
							}
							NONextPage:
								print "NO nEXT pAGE\n";
						}
					}
					else
					{
						goto WEDDING;
					}
				}
			}
			elsif($cont2=~ m/<li\s*class\=\"header\">([^>]*?)<\/li>([\w\W]*?)<\/ul>/is) # Exxlusion of normal flow
			{
				my $menu4_header=$1;
				my $menu4_block=$2;
				while($menu4_block=~m/<li>\s*<a\s*href\=\"([^>]*?)\"[^>]*?>\s*([^>]*?)\s*<\/a>/igs)
				{
					my $menu4_URL=$1;
					my $menu4=$2;
					my $cont2 = $utilityobject->Lwp_Get($menu4_URL);
					
					while($cont2 =~ m/class\=expander\-toggle[^>]*?>\s*([^>]*?)\s*<\/a>([\w\W]*?)<\/div>\s*<\/div>/igs)  ## LH Filter Block
					{
						my $filterheader = $utilityobject->Decode($1);
						my $filterblock = $2;
						
						# next unless($filterheader =~ m/popular\s*in\s*BOYS/is);
						next if($filterheader =~ m/Department|rating|size|brand|price|save/is);  #Skip few filters
						
						while($filterblock =~ m/href\=\"([^>]*?)\">\s*(?:<[^>]*?>\s*)\s*([^>]*?)\s*<\/span>|href\=\"([^>]*?)\">\s*(?:<[^>]*?>\s*)[\w\W]*?>([^>]*?)\s*<\/div>|href\=\"\s*([^>]*?)\s*\">\s*([^>]*?)\s*<\/a>/igs)
						{
							my $filterurl = $utilityobject->Decode($1.$3.$5);
							my $filtervalue = $utilityobject->Decode($2.$4.$6);
							# my $filterurl2 = $1.$filterurl.'&ajax=true' if($pgurl1 =~ m/([^>]*?)\?/is);
							# $filterurl2 = $filterurl if($filterurl2 eq '');
							# next unless($filtervalue =~ m/skin\s*care/is);
							# print "FilterURL1 => $filterurl\n";
							if($filterheader =~ m/\bRetailer\b/is)
							{
								next unless($filtervalue=~ m/walmart/is);
							}
							my %nextpage;
							NextPage1:
							$filterurl =~ s/\s+//igs;
							if($filterurl =~ m/browse/is || $filterurl !~ m/^\?/is)
							{
								$filterurl= "http://www.walmart.com".$filterurl unless($filterurl =~ m/^http/is);
							}
							else
							{
								$filterurl= "http://www.walmart.com/browse/".$filterurl unless($filterurl =~ m/^http/is);
							}
							# $filterurl= $abspath.$filterurl unless($filterurl =~ m/^http/is); # Accept: Accessories,
							#$filterurl= "$abspath".$filterurl unless($filterurl =~ m/^http/is);
							# my $abspath = $1 if($filterurl =~ m/([^>]*?)(?:\?|$)/is);
							# $filterurl2= "http://www.walmart.com".$filterurl2 unless($filterurl2 =~ m/^http/is);
							print "FilterURL2 => $filterurl\n";
							# print "FilterURL2 => $filterurl2\n";
							# my $filtercont = $utilityobject->Lwp_Get($filterurl2);
							my $filtercont = $utilityobject->Lwp_Get($filterurl);

							# open ss,">walmart3.html";
							# print ss $filtercont;
							# close ss;
							
							print "$menu1 -> $menu2 -> $menu3 -> $filterheader -> $filtervalue\n";
							while($filtercont =~ m/data\-item\-id\=\\\"([^>]*?)\\\"[^>]*?>|data\-item\-id\=([^>]*?)\s*data-seller[^>]*?>/igs)
							{
								
								my $pid = $utilityobject->Trim($1.$2);
								my $purl = "http://www.walmart.com/ip/$pid";
								$purl = $url.$purl unless($purl =~ m/^http/is);
								
								print "$pid\n";
								my $product_object_key;
								
								if($hash_id{$pid} eq '')
								{
									$product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
									$hash_id{$pid}=$product_object_key;
								}
								else
								{
									$product_object_key=$hash_id{$pid};
								}
								
								# Insert Tag values.
								$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
								$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
								$dbobject->SaveTag('Menu_3',$menu3,$product_object_key,$robotname,$Retailer_Random_String) if($menu3 ne '');
								$dbobject->SaveTag($menu4_header,$menu4,$product_object_key,$robotname,$Retailer_Random_String) if($menu4 ne '');
								unless($filterheader=~m/^\s*$/is)
								{
									$dbobject->SaveTag($filterheader,$filtervalue,$product_object_key,$robotname,$Retailer_Random_String) if($filtervalue ne '');
								}
								
								# Committing the transaction.
								$dbobject->commit();
							}
							if($filtercont =~ m/btn\-next\\\"\s*href\=\\\"([^>]*?)\\\">|btn\-next\"\s*href\=\"([^>]*?)\">/is)
							{
								$filterurl = $utilityobject->Decode($1.$2);
								# $filterurl = $abspath.$filterurl unless($filterurl =~ m/^http/is);
								# $filterurl = $1.$filterurl if($filtercont =~ m/rel\=canonical\s*href\=\"([^>]*?)\"/is);
								# $filterurl = "http://www.walmart.com".$filterurl if($filterurl !~ m/^http/is);
								# print "AbsPath ::: $abspath\n";
								if($filterurl =~ m/browse/is || $filterurl !~ m/^\?/is)
								{
									$filterurl= "http://www.walmart.com".$filterurl unless($filterurl =~ m/^http/is);
								}
								else
								{
									$filterurl= "http://www.walmart.com/browse/".$filterurl unless($filterurl =~ m/^http/is);
								}
								print "Page URL:: $filterurl\n";
								my $pageid;
								##if($filterurl=~ m/page\=\s*(\d+)(?:[^>]*?$|[^>]*?\/)/is)
								##if($filterurl=~ m/\/page\/(\d+)(?:$|\/)/is)###
								if($filterurl=~ m/page\=\s*(\d+)(?:[^>]*?$|[^>]*?\/)/is)
								{
									$pageid = $1;
									$nextpage{$pageid}++;
									print "Page ID $pageid :: $nextpage{$pageid} \n";
								}
								#<STDIN>;
								goto NONextPage1 if($nextpage{$pageid}>1);
								print "NextPage:::: $filterurl\n";
								goto NextPage1;
							}
							NONextPage1:
								print "NO nEXT pAGE\n";
						}
					}
				}
			}
			else
			{
				WEDDING:
				while($cont2 =~ m/class\=expander\-toggle[^>]*?>\s*([^>]*?)\s*<\/a>([\w\W]*?)<\/div>\s*<\/div>/igs)  ## LH Filter Block
				{
					my $menu4_header = $utilityobject->Decode($1);
					my $menu4_block = $2;
					next if($menu4_header =~ m/Department|rating|size|brand|price|save|Jewelry\s*Education/is);  #Skip few filters
					
					while($menu4_block=~m/href\=\"([^>]*?)\"[^>]*?>\s*<span>\s*([^>]*?)<\/span>/igs)
					{
						my $menu4_URL='http://www.walmart.com'.$1;
						my $menu4=$2;
						
						my $cont2 = $utilityobject->Lwp_Get($menu4_URL);
						
						while($cont2 =~ m/class\=expander\-toggle[^>]*?>\s*([^>]*?)\s*<\/a>([\w\W]*?)<\/div>\s*<\/div>/igs)  ## LH Filter Block
						{
							my $filterheader = $utilityobject->Decode($1);
							my $filterblock = $2;
							
							# next unless($filterheader =~ m/popular\s*in\s*BOYS/is);
							next if($filterheader =~ m/Department|rating|size|brand|price|save/is);  #Skip few filters
							
							while($filterblock =~ m/href\=\"([^>]*?)\">\s*(?:<[^>]*?>\s*)\s*([^>]*?)\s*<\/span>|href\=\"([^>]*?)\">\s*(?:<[^>]*?>\s*)[\w\W]*?>([^>]*?)\s*<\/div>|href\=\"\s*([^>]*?)\s*\">\s*([^>]*?)\s*<\/a>/igs)
							{
								my $filterurl = $utilityobject->Decode($1.$3.$5);
								my $filtervalue = $utilityobject->Decode($2.$4.$6);
								# my $filterurl2 = $1.$filterurl.'&ajax=true' if($pgurl1 =~ m/([^>]*?)\?/is);
								# $filterurl2 = $filterurl if($filterurl2 eq '');
								# next unless($filtervalue =~ m/skin\s*care/is);
								# print "FilterURL1 => $filterurl\n";
								if($filterheader =~ m/\bRetailer\b/is)
								{
									next unless($filtervalue=~ m/walmart/is);
								}
								my %nextpage;
								NextPage2:
								$filterurl =~ s/\s+//igs;
								if($filterurl =~ m/browse/is || $filterurl !~ m/^\?/is)
								{
									$filterurl= "http://www.walmart.com".$filterurl unless($filterurl =~ m/^http/is);
								}
								else
								{
									$filterurl= "http://www.walmart.com/browse/".$filterurl unless($filterurl =~ m/^http/is);
								}
								# $filterurl= $abspath.$filterurl unless($filterurl =~ m/^http/is); # Accept: Accessories,
								#$filterurl= "$abspath".$filterurl unless($filterurl =~ m/^http/is);
								# my $abspath = $1 if($filterurl =~ m/([^>]*?)(?:\?|$)/is);
								# $filterurl2= "http://www.walmart.com".$filterurl2 unless($filterurl2 =~ m/^http/is);
								print "FilterURL2 => $filterurl\n";
								# print "FilterURL2 => $filterurl2\n";
								# my $filtercont = $utilityobject->Lwp_Get($filterurl2);
								my $filtercont = $utilityobject->Lwp_Get($filterurl);

								# open ss,">walmart3.html";
								# print ss $filtercont;
								# close ss;
								
								print "$menu1 -> $menu2 -> $menu3 -> $filterheader -> $filtervalue\n";
								while($filtercont =~ m/data\-item\-id\=\\\"([^>]*?)\\\"[^>]*?>|data\-item\-id\=([^>]*?)\s*data-seller[^>]*?>/igs)
								{									
									my $pid = $utilityobject->Trim($1.$2);
									my $purl = "http://www.walmart.com/ip/$pid";
									$purl = $url.$purl unless($purl =~ m/^http/is);
									
									print "$pid\n";
									my $product_object_key;
									
									if($hash_id{$pid} eq '')
									{
										$product_object_key = $dbobject->SaveProduct($purl,$robotname,$retailer_id,$Retailer_Random_String);
										$hash_id{$pid}=$product_object_key;
									}
									else
									{
										$product_object_key=$hash_id{$pid};
									}
									
									# Insert Tag values.
									$dbobject->SaveTag('Menu_1',$menu1,$product_object_key,$robotname,$Retailer_Random_String) if($menu1 ne '');
									$dbobject->SaveTag('Menu_2',$menu2,$product_object_key,$robotname,$Retailer_Random_String) if($menu2 ne '');
									$dbobject->SaveTag('Menu_3',$menu3,$product_object_key,$robotname,$Retailer_Random_String) if($menu3 ne '');
									$dbobject->SaveTag($menu4_header,$menu4,$product_object_key,$robotname,$Retailer_Random_String) if($menu4 ne '');
									unless($filterheader=~m/^\s*$/is)
									{
										$dbobject->SaveTag($filterheader,$filtervalue,$product_object_key,$robotname,$Retailer_Random_String) if($filtervalue ne '');
									}
									
									# Committing the transaction.
									$dbobject->commit();
								}
								if($filtercont =~ m/btn\-next\\\"\s*href\=\\\"([^>]*?)\\\">|btn\-next\"\s*href\=\"([^>]*?)\">/is)
								{
									$filterurl = $utilityobject->Decode($1.$2);
									# $filterurl = $abspath.$filterurl unless($filterurl =~ m/^http/is);
									# $filterurl = $1.$filterurl if($filtercont =~ m/rel\=canonical\s*href\=\"([^>]*?)\"/is);
									# $filterurl = "http://www.walmart.com".$filterurl if($filterurl !~ m/^http/is);
									# print "AbsPath ::: $abspath\n";
									if($filterurl =~ m/browse/is || $filterurl !~ m/^\?/is)
									{
										$filterurl= "http://www.walmart.com".$filterurl unless($filterurl =~ m/^http/is);
									}
									else
									{
										$filterurl= "http://www.walmart.com/browse/".$filterurl unless($filterurl =~ m/^http/is);
									}
									my $pageid;
									print "Page URL:: $filterurl\n";
									if($filterurl=~ m/page\=\s*(\d+)(?:[^>]*?$|[^>]*?\/)/is)
									{
										$pageid = $1;
										$nextpage{$pageid}++;
										print "Page ID $pageid :: $nextpage{$pageid} \n";
									}
									#<STDIN>;
									goto NONextPage2 if($nextpage{$pageid}>1);
									print "NextPage:::: $filterurl\n";									
									goto NextPage2;
								}
								NONextPage2:
									print "NO nEXT pAGE\n";
							}
						}
					}					
				}	
			}
		}
	}
}
$logger->send("$robotname :: Instance Completed  :: $pid\n");
################### For Dashboard #######################################
$dbobject->Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);
################### For Dashboard #######################################
$dbobject->commit();

$dbobject->Destroy();
