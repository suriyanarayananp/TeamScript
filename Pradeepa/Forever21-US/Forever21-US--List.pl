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
my $Retailer_Random_String='For';
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

my $url ='http://www.forever21.com/Product/Main.aspx?br=f21';
my $content =&getcont($url,"GET","","");
#open FH , ">home.html" or die "File not found\n";
#print FH $content;
#close FH;
# my %totalHash;
my %hash_id;
############ URL Collection ##############
#sale is inside men and girl
my @regex_array=('<a\s*href\=\"([^\"]*)\"\s*[^>]*?>\s*(NEW\s*ARRIVALS)\s*<\/a>\s*<div','<div\s*class\s*\=\s*\"\s*women\s*dropdown\s*\"\s*>\s*<a\s*href\s*\=\s*\"\s*([^>]*?)\s*\"\s*class\s*\=\s*\"\s*dropdown\-toggle\s*\"\s*>\s*(Women)\s*<','<a\s*href\=\"([^\"]*)\"\s*[^>]*?>\s*(CLOTHING)\s*<\/a>\s*<div','<a\s*href\=\"([^\"]*)\"\s*[^>]*?>\s*(ACCESSORIES)\s*<\/a>\s*<div','<a\s*href\=\"([^\"]*)\"\s*[^>]*?>\s*(SHOES)\s*<\/a>\s*<div','<a\s*href\=\"([^\"]*)\"\s*[^>]*?>\s*(LOVE\s*21)\s*<\/a>\s*<div','<a\s*href\=\"([^\"]*)\"\s*[^>]*?>\s*(PLUS\s*SIZES)\s*<\/a>\s*<div','<a\s*href\=\"([^\"]*)\"\s*[^>]*?>\s*(MEN)\s*<\/a>\s*<div','<a\s*href\=\"([^\"]*)\"\s*[^>]*?>\s*(GIRLS)\s*<\/a>\s*<div','<a\s*href\=\"([^\"]*)\"\s*[^>]*?>\s*(SALE\s*(?:\&\s*DEALS)?)\s*<\/a>\s*<div'); #Getting Top Menu urls

my $robo_menu=$ARGV[0];

my ($temp,$temp1,$temp2,$temp3);

foreach my $regex(@regex_array)
{
# while($content=~m/<li[^>]*?>\s*<a[^>]*?href\s*\=\s*\"\s*([^>]*?)\s*\"[^>]*?>([^>]*?)<[^>]*?>\s*<div[^>]*?class\s*\=\s*\"\s*mdrop/igs)
# {
	if ( $content =~m/$regex/is )
	{
		my $urlcontent =$1;
		my $menu_1=DBIL::Trim($2);  ##Main or Top Menu(Menu1)::NEW ARRIVALS,WOMEN, MEN
		
		if(($menu_1 eq "Women")&($urlcontent eq "#")) #TopMenu Women do not have Corresponing url hence assigning main url
		{
			$urlcontent=$url;
		}
		
		my $content1 = &getcont($urlcontent,"GET","","");
		
		$content1=~s/<font\s*class\=\"SubCategBold\">\s*/<End><start>/igs;
		
		if(($menu_1=~m/$robo_menu/is)&&($robo_menu=~m/NEW\s*ARRIVALS/is))
		{
			while($content1=~m/(?:<start>\s*([^<]*?)\s*<[\w\W]*?)?<dt[^>]*?>\s*<a\s*href\=\"([^\"]*?)\"\s*[^>]*?>\s*<font\s*class\=\"SubCateg[^>]*?\"\s*>\s*([\w\W]*?)<\/font>\s*<\/a>\s*<\/\s*dt>/igs)
			{
				my $menu_2_cat_new=$1;  ##LHM Main Heding2=>Eg:Features (All menu1 have)
				my $url_2_new=$2;
				my $menu_2_new=$3;  ##Menu2=>Style Deals,Not So Basic in New Arrivals
				
				if($menu_2_cat_new)
				{
					$temp=$menu_2_cat_new;
				}
				else
				{
					$menu_2_cat_new=$temp;
				}
			
				&GetProduct($url_2_new,'',$menu_1,$menu_2_cat_new,$menu_2_new,'','','','','');
				
				my $content2_new = &getcont($url_2_new,"GET","","");
					
				$content2_new=~s/<font\s*class\=\"SubCategBold\">\s*/<End><start>/igs;
				
				if($menu_2_new=~m/Premium\s*Beauty/is)  #(Menu2=> Scenario 1)New Arrivals,Premium Beauty
				{
					while($content2_new=~m/(?:<start>\s*([^<]*?)\s*<[\w\W]*?)?<dt[^>]*?>\s*<a\s*href\=\"([^\"]*?)\"\s*[^>]*?>\s*<font\s*class\=\"SubCateg\">\s*([\w\W]*?)<\/font>\s*<\/a>\s*<\/\s*dt>/igs)
					{
						my $menu_3_cat_new=$1;  #LHM Main Heding3=>Features (All menu1 have)
						my $url_3_new=$2;
						my $menu_3_new=$3;  #Menu3=>Style Deals,Not So Basic in New Arrivals
						
						if($menu_3_cat_new)
						{
							$temp1=$menu_3_cat_new;
						}
						else
						{
							$menu_3_cat_new=$temp1;
						}
						
						&GetProduct($url_3_new,'',$menu_1,$menu_2_cat_new,$menu_2_new,$menu_3_cat_new,$menu_3_new,'','','');
						
						my $content3_new = &getcont($url_3_new,"GET","","");
						
						if($menu_3_new=~m/Style\s*Deals/is)
						{
							while($content3_new=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)##under$5 in Style Deals
							{
								my $url_4_NewStyle=$1;
								my $menu_4_Style=$2;
						
								&GetProduct($url_4_NewStyle,'',$menu_1,$menu_2_cat_new,$menu_2_new,$menu_3_cat_new,$menu_3_new,$menu_4_Style,'','');  
							}
						}
						elsif($content3_new=~m/<font[^>]*?class\s*\=\s*\"\s*SubCateg\s*\"[^>]*?>\s*$menu_3_new\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*0px\s*\;\s*\"[^>]*?>/is)	##SubCategory1
						{
							my $blk1=$1;
					
							while($blk1=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)##under$5 in Style Deals,Denim-Basics
							{
								my $url_4_new=$1;
								my $menu_4_new=$2;
								
								&GetProduct($url_4_new,'',$menu_1,$menu_2_cat_new,$menu_2_new,$menu_3_cat_new,$menu_3_new,$menu_4_new,'','');
							
								my $content4_new = &getcont($url_4_new,"GET","","");
									
								if($content4_new=~m/<dt[^>]*?10px\;\s*\"\s*>\s*<a[^>]*?>\s*<font[^>]*?class\s*\=\s*\"\s*SubCateg\s*\"[^>]*?>\s*$menu_4_new\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*10px\s*\;\s*\"[^>]*?>/is)	 ###SubCategory2
								{
									my $blk2=$1;
									
									while($blk2=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)
									{
										my $url_5_new=$1;
										my $menu_5_new=$2;
										
										&GetProduct($url_5_new,'',$menu_1,$menu_2_cat_new,$menu_2_new,$menu_3_cat_new,$menu_3_new,$menu_4_new,$menu_5_new,'');
									
										my $content5_new = &getcont($url_5_new,"GET","","");
									
										if($content5_new=~m/<dt[^>]*?20px\;\s*\"\s*>\s*<a[^>]*?>\s*<font[^>]*?class\s*\=\s*\"\s*SubCateg\s*\"[^>]*?>\s*$menu_5_new\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*20px\s*\;\s*\"[^>]*?>/is)  ##SubCategory3	
										{
											my $blk3=$1;
											
											while($blk3=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)
											{
												my $url_6_new=$1;
												my $menu_6_new=$2;
										
												&GetProduct($url_6_new,'',$menu_1,$menu_2_cat_new,$menu_2_new,$menu_3_cat_new,$menu_3_new,$menu_4_new,$menu_5_new,$menu_6_new);
											}
										}
									}
								}
							}
						}
						
						if($menu_3_new=~m/Capsule\s*2\.1/is)
						{
						   $content2_new='';
						}
					}
				}
				else   #(Menu2=> Scenario 2)If not Premium Beauty
				{
					if($menu_2_new=~m/Style\s*Deals/is)
					{
						while($content2_new=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)##under$5 in Style Deals
						{
							my $url_3_Style1=$1;
							my $menu_3_style1=$2;
					
							&GetProduct($url_3_Style1,'',$menu_1,$menu_2_cat_new,$menu_2_new,'',$menu_3_style1,'','','');
						}
					}
					elsif($content2_new=~m/<font[^>]*?class\s*\=\s*\"\s*SubCateg\s*\"[^>]*?>\s*$menu_2_new\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*0px\s*\;\s*\"[^>]*?>/is)	##SubCategory1
					{
						my $blk1=$1;
				
						while($blk1=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)
						{
							my $url_3_new=$1;
							my $menu_3_new=$2;
							
							&GetProduct($url_3_new,'',$menu_1,$menu_2_cat_new,$menu_2_new,'',$menu_3_new,'','','');
						
							my $content3_new = &getcont($url_3_new,"GET","","");
								
							if($content3_new=~m/<font[^>]*?class\s*\=\s*\"\s*SubCateg\s*\"[^>]*?>\s*$menu_3_new\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*10px\s*\;\s*\"[^>]*?>/is)	##SubCategory2
							{
								my $blk2=$1;
								
								while($blk2=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)
								{
									my $url_4_new=$1;
									my $menu_4_new=$2;
									
									&GetProduct($url_4_new,'',$menu_1,$menu_2_cat_new,$menu_2_new,'',$menu_3_new,$menu_4_new,'','');
								
									my $content4_new = &getcont($url_4_new,"GET","","");
								
									if($content4_new=~m/<dt[^>]*?10px\;\s*\"\s*>\s*<a[^>]*?>\s*<font[^>]*?class\s*\=\s*\"\s*SubCateg\s*\"[^>]*?>\s*$menu_4_new\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*10px\s*\;\s*\"[^>]*?>/is)	###SubCategory3
									{
										my $blk3=$1;
										
										while($blk3=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)
										{
											my $url_5_new=$1;
											my $menu_5_new=$2;
									
											&GetProduct($url_5_new,'',$menu_1,$menu_2_cat_new,$menu_2_new,'',$menu_3_new,$menu_4_new,$menu_5_new,'');
											
											my $content5_new = &getcont($url_5_new,"GET","","");
									
											if($content5_new=~m/<dt[^>]*?20px\;\s*\"\s*>\s*<a[^>]*?>\s*<font[^>]*?class\s*\=\s*\"\s*SubCateg\s*\"[^>]*?>\s*$menu_5_new\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*20px\s*\;\s*\"[^>]*?>/is)	
											{
												my $blk3=$1;
												
												while($blk3=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)
												{
													my $url_6_new=$1;
													my $menu_6_new=$2;
											
													&GetProduct($url_6_new,'',$menu_1,$menu_2_cat_new,$menu_2_new,'',$menu_3_new,$menu_4_new,$menu_5_new,$menu_6_new);
												}
											}
										}
									}
								}
							}
						}
					}
				}
			}
		}
		elsif(($menu_1=~m/$robo_menu/is)&&($menu_1 eq "Women"))  ##Menu1=>Women (TopMenu do not have separate url hence taking Blocks from Top Menu)
		{
			# print "Women\n";		
			if($content1=~m/<a[^>]*?href\s*\=\s*\"[^>]*?\"[^>]*?class\s*\=\s*\"\s*dropdown\s*\-\s*toggle\s*\"[^>]*?>\s*(Women)\s*<([\w\W]*?)<\/div>\s*<\/div>\s*<\/div>/is)
			{
				my $blk_Women=$&; #Main Block 1
				
				if($blk_Women=~m/<a[^>]*?class\s*\=\s*\"\s*direct\s*\"\s*href\s*\=\s*\"([^>]*?)\s*\"\s*>([^<]*?)</is) #Scenario 1
				{
					while($blk_Women=~m/<a[^>]*?class\s*\=\s*\"\s*direct\s*\"\s*href\s*\=\s*\"([^>]*?)\s*\"\s*>([^<]*?)</igs)  ##Women>Clothing,Love 21,Accessories
					{
						my $url_2_women=$1;
						my $menu_2_women=DBIL::Trim($2);	###Menu2=> Clothing under Women
						
						my $content2_Women = &getcont($url_2_women,"GET","","");
						
						if($menu_2_women=~m/(?:CLOTHING|LOVE21|ACCESSORIES)/is) #If Main Heading under women  is  CLOTHING or LOVE21 or ACCESSORIES (Scenario 1=>Scenario 1)
						{
							$content2_Women=~s/<font\s*class\=\"SubCategBold\">\s*/<End><start>/igs;
							
							while($content2_Women=~m/(?:<start>\s*([^<]*?)\s*<[\w\W]*?)?<dt[^>]*?>\s*<a\s*href\=\"([^\"]*?)\"\s*[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg[^>]*?\"\s*>\s*([\w\W]*?)<\/font>\s*<\/a>\s*<\/\s*dt>/igs)
							{
								my $menu_3_cat_wom=$1;  ##LHM Main Heding3 =>Features (All menu1 have)
								my $url_3_wom=$2;
								my $menu_3_wom=$3;  ##Menu3=>Style Deals,Not So Basic in New Arrivals
								
								if($menu_3_cat_wom)
								{
									$temp3=$menu_3_cat_wom;
								}
								else
								{
									$menu_3_cat_wom=$temp3;
								}
								
								&GetProduct($url_3_wom,'',$menu_1,'',$menu_2_women,$menu_3_cat_wom,$menu_3_wom,'','','');
								
								my $content3_wom = &getcont($url_3_wom,"GET","","");
								
								if(($menu_3_wom=~m/Style\s*Deals/is)&&($menu_3_wom!~m/Capsule/is))
								{
									while($content3_wom=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg[^>]*?\"\s*>([^>]*?)</igs)##under$5 in Style Deals
									{
										my $url_4_womStyle=$1;
										my $menu_4_womStyle=$2;
								
										&GetProduct($url_4_womStyle,'',$menu_1,'',$menu_2_women,$menu_3_cat_wom,$menu_3_wom,$menu_4_womStyle,'','');
									}
								}
								elsif($content3_wom=~m/<font[^>]*?class\s*\=\s*\"\s*SubCateg\s*\"[^>]*?>\s*$menu_3_wom\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*0px\s*\;\s*\"[^>]*?>/is)	###SubCategory1
								{
									my $blk1=$1;
									
									while($blk1=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg[^>]*?\"\s*>([^>]*?)</igs)##Denim-Basics
									{
										my $url_4_wom=$1;
										my $menu_4_wom=$2;
										
										&GetProduct($url_4_wom,'',$menu_1,'',$menu_2_women,$menu_3_cat_wom,$menu_3_wom,$menu_4_wom,'','');
										
										my $content4_wom = &getcont($url_4_wom,"GET","","");
											
										if($content4_wom=~m/<dt[^>]*?10px\;\s*\"\s*>\s*<a[^>]*?>\s*<font[^>]*?class\s*\=\s*\"\s*SubCateg[^>]*?\"[^>]*?>\s*$menu_4_wom\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*10px\s*\;\s*\"[^>]*?>/is)	###SubCategory2
										{
											my $blk2=$1;
											
											while($blk2=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg[^>]*?\"\s*>([^>]*?)</igs)
											{
												my $url_5_wom=$1;
												my $menu_5_wom=$2;
												
												&GetProduct($url_5_wom,'',$menu_1,'',$menu_2_women,$menu_3_cat_wom,$menu_3_wom,$menu_4_wom,$menu_5_wom,'');
												
												my $content5_wom = &getcont($url_5_wom,"GET","","");
												
												if($content5_wom=~m/<dt[^>]*?20px\;\s*\"\s*>\s*<a[^>]*?>\s*<font[^>]*?class\s*\=\s*\"\s*SubCateg[^>]*?\"[^>]*?>\s*$menu_5_wom\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*20px\s*\;\s*\"[^>]*?>/is)	###SubCategory3
												{
													my $blk3=$1;
													
													while($blk3=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg[^>]*?\"\s*>([^>]*?)</igs)
													{
														my $url_6_wom=$1;
														my $menu_6_wom=$2;
														
														&GetProduct($url_6_wom,'',$menu_1,'',$menu_2_women,$menu_3_cat_wom,$menu_3_wom,$menu_4_wom,$menu_5_wom,$menu_6_wom);
													}
												}
											}
										}
									}
								}
							}
						}
						else    ##If Main Heading under women is not CLOTHING or LOVE21 or ACCESSORIES (Scenario 2)
						{	
							
							if($content2_Women=~m/<font[^>]*?class\s*\=\s*\"\s*SubCateg\s*\"[^>]*?>\s*$menu_2_women\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*0px\s*\;\s*\"[^>]*?>/is)	###SubCategory1
							{
								my $blk1=$1;
						
								while($blk1=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg[^>]*?\"\s*>([^>]*?)</igs)##Denim-Basics
								{
									my $url_3_wom=$1;
									my $menu_3_wom=$2;
									
									&GetProduct($url_3_wom,'',$menu_1,'',$menu_2_women,'',$menu_3_wom,'','','');
								
									my $content4_wom = &getcont($url_3_wom,"GET","","");
										
									if($content4_wom=~m/<dt[^>]*?10px\;\s*\"\s*>\s*<a[^>]*?>\s*<font[^>]*?class\s*\=\s*\"\s*SubCateg[^>]*?\"\s*>\s*$menu_3_wom\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*10px\s*\;\s*\"[^>]*?>/is)	###SubCategory2
									{
										my $blk2=$1;
										
										while($blk2=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg[^>]*?\"\s*>([^>]*?)</igs)
										{
											my $url_4_wom=$1;
											my $menu_4_wom=$2;
											
											&GetProduct($url_4_wom,'',$menu_1,'',$menu_2_women,'',$menu_3_wom,$menu_4_wom,'','');
											
											my $content5_wom = &getcont($url_4_wom,"GET","","");
												
											if($content5_wom=~m/<dt[^>]*?20px\;\s*\"\s*>\s*<a[^>]*?>\s*<font[^>]*?class\s*\=\s*\"\s*SubCateg[^>]*?\"[^>]*?>\s*$menu_4_wom\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*20px\s*\;\s*\"[^>]*?>/is)	###SubCategory3
											{
												my $blk3=$1;
												
												while($blk3=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg[^>]*?\"\s*>([^>]*?)</igs)
												{
													my $url_5_wom=$1;
													my $menu_5_wom=$2;
													
													&GetProduct($url_5_wom,'',$menu_1,'',$menu_2_women,'',$menu_3_wom,$menu_4_wom,$menu_5_wom,'');
												}
											}
										}
									}
								}
							}
							else #Page's do not have Subcategory's
							{
								&GetProduct($url_2_women,'',$menu_1,'',$menu_2_women,'','','','','');
							}
						}
					}
				}
				if($blk_Women=~m/<div[^>]*?>\s*(Features)\s*<([\w\W]*?)<\/div>\s*<\/div>\s*<\/div>/is) ###Scenario 2=>Features
				{
					my $menu_2_womenFeat=$1;
					my $FeatureBlock=$2;
					
					while($FeatureBlock=~m/<a[^>]*?href\s*\=\s*\"\s*([^>]*?)\s*\"[^>]*?>([^>]*?)</igs)
					{
						my $url_2_womenFeat=$1;
						my $menu_3_womenFeat=DBIL::Trim($2); ##Shop By Style
						
						my $content4_womFeat = &getcont($url_2_womenFeat,"GET","","");
					
						if($menu_2_womenFeat=~m/Style\s*Deals/is)
						{
							while($content4_womFeat=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)##Denim-Basics
							{
								my $url_3_womfeatStyle=$1;
								my $menu_3_womfeatStyle=$2;
						
								&GetProduct($url_3_womfeatStyle,'',$menu_1,'',$menu_2_womenFeat,'',$menu_3_womenFeat,$menu_3_womfeatStyle,'','');
							}
						}
						else
						{
							&GetProduct($url_2_womenFeat,'',$menu_1,'',$menu_2_womenFeat,'',$menu_3_womenFeat,'','','');
						}
					}
				}
			}
		}
		elsif(($menu_1=~m/$robo_menu/is)&&($robo_menu=~m/SALE\s*(?:&(?:amp\;)?\s*DEALS)?/is))   ##Menu1=> SALE&DEALS
		{
			while($content1=~m/(?:<start>\s*([^<]*?)\s*<[\w\W]*?)?<dt[^>]*?>\s*<a\s*href\=\"([^\"]*?)\"\s*[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg[^>]*?\"\s*>\s*([\w\W]*?)<\/font>\s*<\/a>\s*<\/\s*dt>/igs)
			{
				my $menu_2_cat_sal=$1;  ##LHM Main Heading2 =>Shop All Sale
				my $url_2_sal=$2;
				my $menu_2_sal=$3;  ##Menu2=>Women,Style DEals
				
				if($menu_2_cat_sal)
				{
					$temp2=$menu_2_cat_sal;
				}
				else
				{
					$menu_2_cat_sal=$temp2;
				}
			
				my $content2_sal = &getcont($url_2_sal,"GET","","");
				
				$content2_sal=~s/<font\s*class\=\"SubCategBold\">\s*/<End><start>/igs;
				
				if($menu_2_cat_sal=~m/Shop\s*All\s*Sale/is)  #New Arrivals,Premium Beauty
				{
					if($menu_2_sal=~m/Women/is)
					{
						while($content2_sal=~m/(?:<start>\s*([^<]*?)\s*<[\w\W]*?)?<dt[^>]*?>\s*<a\s*href\=\"([^\"]*?)\"\s*[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg[^>]*?\"\s*>\s*([\w\W]*?)<\/font>\s*<\/a>\s*<\/\s*dt>/igs)
						{
							my $menu_3_cat_sal=$1;  ##LHM Main Heading3=>Women>>Shop By Category
							my $url_3_sal=$2;
							my $menu_3_sal=$3;  ##Menu3=>Dresses
							
							if($menu_3_cat_sal)
							{
								$temp1=$menu_3_cat_sal;
							}
							else
							{
								$menu_3_cat_sal=$temp1;
							}
							
							if($menu_3_cat_sal!~m/(?:\s*Shop\s*By\s*Category\s*|Features)/is)
							{
								next;
							}
							
							&GetProduct($url_3_sal,'',$menu_1,$menu_2_cat_sal,$menu_2_sal,$menu_3_cat_sal,$menu_3_sal,'','','');
							
							my $content3_sal = &getcont($url_3_sal,"GET","","");
							
							if($content3_sal=~m/class\s*\=\s*\"\s*items_name\s*\"\s*>/is) ###If subcat with ItemName	
							{
								while($content3_sal=~m/class\s*\=\s*\"\s*items_name\s*\"\s*>\s*([^<]*?)\s*<([\w\W]*?)<hr[^>]*?>\s*<\/td>\s*<\/tr>\s*<\/table>/igs)
								{
									my $menusubsal_4=$1;
									my $subblksal4=$2;
									
									&GetProduct('',$subblksal4,$menu_1,$menu_2_cat_sal,$menu_2_sal,$menu_3_cat_sal,$menu_3_sal,$menusubsal_4,'','');
								}
							}
							elsif($content3_sal=~m/<font[^>]*?class\s*\=\s*\"\s*SubCateg[^>]*?\"[^>]*?>\s*$menu_3_sal\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*0px\s*\;\s*\"[^>]*?>/is)	##Subcategory1
							{
								my $blk1=$1;
						
								while($blk1=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs) 
								{
									my $url_4_sal=$1;
									my $menu_4_Sal=$2;
									
									&GetProduct($url_4_sal,'',$menu_1,$menu_2_cat_sal,$menu_2_sal,$menu_3_cat_sal,$menu_3_sal,$menu_4_Sal,'','');
								
									my $content4_sal = &getcont($url_4_sal,"GET","","");
										
									if($content4_sal=~m/<dt[^>]*?10px\;\s*\"\s*>\s*<a[^>]*?>\s*<font[^>]*?class\s*\=\s*\"\s*SubCateg[^>]*?\"[^>]*?>\s*$menu_4_Sal\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*10px\s*\;\s*\"[^>]*?>/is)	###Subcategory2
									{
										my $blk2=$1;
										
										while($blk2=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)
										{
											my $url_5_Sal=$1;
											my $menu_5_sal=$2;
											
											&GetProduct($url_5_Sal,'',$menu_1,$menu_2_cat_sal,$menu_2_sal,$menu_3_cat_sal,$menu_3_sal,$menu_4_Sal,$menu_5_sal,'');
										
											my $content5_new = &getcont($url_5_Sal,"GET","","");
										
											if($content5_new=~m/<dt[^>]*?20px\;\s*\"\s*>\s*<a[^>]*?>\s*<font[^>]*?class\s*\=\s*\"\s*SubCateg[^>]*?\"[^>]*?>\s*$menu_5_sal\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*20px\s*\;\s*\"[^>]*?>/is)	####Subcategory3
											{
												my $blk3=$1;
												
												while($blk3=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)##Denim-Basics
												{
													my $url_6_sal=$1;
													my $menu_6_sal=$2;
											
													&GetProduct($url_6_sal,'',$menu_1,$menu_2_cat_sal,$menu_2_sal,$menu_3_cat_sal,$menu_3_sal,$menu_4_Sal,$menu_5_sal,$menu_6_sal);
												}
											}
										}
									}
								}
							}
							elsif($menu_3_sal=~m/Style\s*Deals/is) #Style Deals
							{
								while($content3_sal=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)##under$5 in Style Deals
								{
									my $url_4_NewStyle=$1;
									my $menu_4_Style=$2;
							
									&GetProduct($url_4_NewStyle,'',$menu_1,$menu_2_cat_sal,$menu_2_sal,$menu_3_cat_sal,$menu_3_sal,$menu_4_Style,'','');  
								}
							}
						}
					}
					else   ##Men, Girls in Sale
					{
						if($content2_sal=~m/0px\;\s*(?:\"|\')\s*>\s*<a[^>]*?href\s*\=\s*(?:\"|\')\s*([^>]*?)\s*(?:\"|\')[^>]*?>\s*<font[^>]*?>\s*(Sale)\s*<([\w\W]*?)(?:<dt\s*style=[^>]*?left\s*\:\s*0px\s*\;\s*\"[^>]*?>|<\/dl>)/is)
						{
							my $url_3_sal=$1;
							my $menu_3_sal=$2;
							my $menu_3_sal_blk=$3;
							
							&GetProduct($url_3_sal,'',$menu_1,$menu_2_cat_sal,$menu_2_sal,'',$menu_3_sal,'','','');
							
							while($menu_3_sal_blk=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)
							{
								my $url_4_sal=$1;
								my $menu_4_Sal=$2;
								
								&GetProduct($url_4_sal,'',$menu_1,$menu_2_cat_sal,$menu_2_sal,'',$menu_3_sal,$menu_4_Sal,'','');
							}
						}
						else
						{
							&GetProduct($url_2_sal,'',$menu_1,$menu_2_cat_sal,$menu_2_sal,'','','','','');
						}
					}
				}
				else
				{
					if($menu_2_sal=~m/Style\s*Deals/is)   ###Style Deals
					{
						while($content2_sal=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)##under$5 in Style Deals,Denim-Basics
						{
							my $url_4_SalStyle1=$1;
							my $menu_4_SalStyle1=$2;
					
							&GetProduct($url_4_SalStyle1,'',$menu_1,$menu_2_cat_sal,$menu_2_sal,'',$menu_4_SalStyle1,'','','');  
						}
					}
					else
					{
						&GetProduct($url_2_sal,'',$menu_1,$menu_2_cat_sal,$menu_2_sal,'','','','','');
					}
				}
			}
		}
		elsif($menu_1=~m/$robo_menu/is)  ## Menu1=>"Other Than Women, Sale"
		{
			while($content1=~m/(?:<start>\s*([^<]*?)\s*<[\w\W]*?)?<dt[^>]*?>\s*<a\s*href\=\"([^\"]*?)\"\s*[^>]*?>\s*<font\s*class\=\"SubCateg([^>]*?)\">\s*([\w\W]*?)<\/font>\s*<\/a>\s*<\/\s*dt>/igs)
			{
				my $menu_2_cat=$1;  ##LHM Main Heading 2=>Features (All menu1 have)
				my $url_2=$2;
				my $subcatflag=$3;
				my $menu_2=$4;  ##Menu2=>Style Deals,Not So Basic
				
				if($menu_2_cat)
				{
					$temp2=$menu_2_cat;
				}
				else
				{
					$menu_2_cat=$temp2;
				}
				
				&GetProduct($url_2,'',$menu_1,$menu_2_cat,$menu_2,'','','','','');
				
				my $content2 = &getcont($url_2,"GET","","");
				
				if(($content2=~m/class\s*\=\s*\"\s*items_name\s*\"\s*>/is)&&(($menu_2!~m/Style Deals/is))) ###If subcat with ItemName	
				{
					while($content2=~m/class\s*\=\s*\"\s*items_name\s*\"\s*>\s*([^<]*?)\s*<([\w\W]*?)<hr[^>]*?>\s*<\/td>\s*<\/tr>\s*<\/table>/igs)
					{
						my $menusub_3=$1;
						my $subblk3=$2;
						
						&GetProduct('',$subblk3,$menu_1,$menu_2_cat,$menu_2,'',$menusub_3,'','','');
					}
				}
				elsif($content2=~m/<font[^>]*?class\s*\=\s*\"\s*SubCateg\s*\"[^>]*?>\s*$menu_2\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*0px\s*\;\s*\"[^>]*?>/is)	##Subcategory1
				{
					my $blk1=$1;
					
					while($blk1=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg[^>]*?\"\s*>([^>]*?)</igs)
					{
						my $url_3=$1;
						my $menu_3=$2;
						
						&GetProduct($url_3,'',$menu_1,$menu_2_cat,$menu_2,'',$menu_3,'','','');
						
						my $content3 = &getcont($url_3,"GET","","");
						
						if($content3=~m/<dt[^>]*?10px\;\s*\"\s*>\s*<a[^>]*?>\s*<font[^>]*?class\s*\=\s*\"\s*SubCateg\s*\"[^>]*?>\s*$menu_3\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*10px\s*\;\s*\"[^>]*?>/is)	###Subcategory 2
						{
							my $blk2=$1;
							
							while($blk2=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)##Denim-Basics
							{
								my $url_4=$1;
								my $menu_4=$2;
								
								&GetProduct($url_4,'',$menu_1,$menu_2_cat,$menu_2,'',$menu_3,$menu_4,'','');
							
								my $content4 = &getcont($url_4,"GET","","");
							
								if($content4=~m/<dt[^>]*?20px\;\s*\"\s*>\s*<a[^>]*?>\s*<font[^>]*?class\s*\=\s*\"\s*SubCateg[^>]*?\"[^>]*?>\s*$menu_4\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*20px\s*\;\s*\"[^>]*?>/is)	####Subcategory3
								{	
									my $blk4=$1;
									
									while($blk4=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)
									{
										my $url_5=$1;
										my $menu_5=$2;
								
										&GetProduct($url_5,'',$menu_1,$menu_2_cat,$menu_2,'',$menu_3,$menu_4,$menu_5,'');
										
										my $content5 = &getcont($url_5,"GET","","");
										
										if($content5=~m/<dt[^>]*?30px\;\s*\"\s*>\s*<a[^>]*?>\s*<font[^>]*?class\s*\=\s*\"\s*SubCateg[^>]*?\"[^>]*?>\s*$menu_5\s*<([\w\W]*?)<dt\s*style=[^>]*?left\s*\:\s*30px\s*\;\s*\"[^>]*?>/is)	####Subcategory4
										{
											my $blk5=$1;											
											
											while($blk5=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg[^>]*?\"\s*>([^>]*?)</igs)
											{
												my $url_6=$1;
												my $menu_6=$2;
												
												&GetProduct($url_6,'',$menu_1,$menu_2_cat,$menu_2,'',$menu_3,$menu_4,$menu_5,$menu_6);
											}
										}
									}
								}
							}
						}								
					}
				}
				elsif(($menu_2=~m/Style\s*Deals/is)&&(!$subcatflag)) ##Style Deals 
				{
					while($content2=~m/<dt[^>]*?>\s*<a[^>]*?href\s*\=\s*(?:\"|\')([^\"\']*)\s*(?:\"|\')[^>]*?>\s*<font\s*class\s*\=\s*\"\s*SubCateg\s*\"\s*>([^>]*?)</igs)##under$5 in Style Deals
					{
						my $url_3_Sty=$1;  
						my $menu_3_Sty=$2;
				
						&GetProduct($url_3_Sty,'',$menu_1,$menu_2_cat,$menu_2,'',$menu_3_Sty,'','','');
					}
				}
			}
		}
		else
		{
			next;
		}
	}	
}
			
sub GetProduct() #Function to collect Products
{
	my $main_url=shift;  
	my $subblock=shift;
	my $menu_11=shift;
	my $menu_2_cat2=shift;
	my $menu_22=shift;
	my $menu_3_cat3=shift;
	my $menu_33=shift;
	my $menu_44=shift;
	my $menu_55=shift;
	my $menu_66=shift;
	
	if($subblock ne '')
	{
		# print "\nSuBLK>>>menu_11:$menu_11,$menu_2_cat2:$menu_22,$menu_3_cat3:$menu_33,menu_44:$menu_44,menu_55:$menu_55,menu_66:$menu_66\n";
		while($subblock=~m/<div\s*class\=\'ItemImage\'[^>]*?>\s*<a\s*href\=\'([^\']*)\'>/igs)
		{
			my $product_url=$1;
			my ($product_id,$product_object_key);
			
			if($product_url=~m/ProductID\s*\=\s*([^\&\$]*?)\s*(?:\&|$)/is)
			{
				$product_id=$1;
			}
			$product_url=~s/\&VariantID=[\w\W]*//is;
			
			###Insert Product values
			if($hash_id{$product_id} eq  '')
			{
				$product_object_key = DBIL::SaveProduct($product_url,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
				$hash_id{$product_id}=$product_object_key;
			}
			else
			{
				$product_object_key=$hash_id{$product_id};
			}
			
			##Insert Tag values
			DBIL::SaveTag('Menu_1',$menu_11,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			if($menu_2_cat2)
			{
				DBIL::SaveTag($menu_2_cat2,$menu_22,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
			else
			{
				DBIL::SaveTag('Menu_2',$menu_22,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
			
			unless($menu_33 eq '')
			{
				if($menu_3_cat3)
				{
					DBIL::SaveTag($menu_3_cat3,$menu_33,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
				}
				else
				{
					DBIL::SaveTag($menu_22,$menu_33,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
				}
			}
			unless($menu_44 eq '')
			{
				DBIL::SaveTag($menu_33,$menu_44,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
			unless($menu_55 eq '')
			{
				DBIL::SaveTag($menu_44,$menu_55,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
			unless($menu_66 eq '')
			{
				DBIL::SaveTag($menu_55,$menu_66,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
			}
			$dbh->commit();
		}
	}
	else
	{
		
		my $main_url1="$main_url"."&pagesize=100";
		
		my $main_url_content;
		
		my $staus=get_content_status($main_url1);
		if($staus=~m/200/is)
		{
			$main_url_content=&getcont($main_url1,"GET","","");
		}
		else
		{
			$main_url_content=getcont($main_url);
		}

	next_page:

		##Insert Product values		
		if($main_url_content=~m/<div\s*class\=\'ItemImage\'[^>]*?>\s*<a\s*href\=\'([^\']*)\'>/is)
		{
			# print "NOT IN SuBLK>>>menu_11:$menu_11,$menu_2_cat2:$menu_22,$menu_3_cat3:$menu_33,menu_44:$menu_44,menu_55:$menu_55,menu_66:$menu_66\n";
			while($main_url_content=~m/<div\s*class\=\'ItemImage\'[^>]*?>\s*<a\s*href\=\'([^\']*)\'>/igs)
			{
				my $product_url=$1;
				my ($product_id,$product_object_key);
				
				if($product_url=~m/ProductID\s*\=\s*([^\&\$]*?)\s*(?:\&|$)/is)
				{
					$product_id=$1;
				}
				$product_url=~s/\&VariantID=[\w\W]*//is;
				
				###Insert Product values
				if($hash_id{$product_id} eq  '')
				{
					$product_object_key = DBIL::SaveProduct($product_url,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
					$hash_id{$product_id}=$product_object_key;
				}
				else
				{
					$product_object_key=$hash_id{$product_id};
				}
				
			   ##Insert Tag values
				DBIL::SaveTag('Menu_1',$menu_11,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
				if($menu_2_cat2)
				{
					DBIL::SaveTag($menu_2_cat2,$menu_22,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
				}
				else
				{
					DBIL::SaveTag('Menu_2',$menu_22,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
				}
				
				unless($menu_33 eq '')
				{
					if($menu_3_cat3)
					{
						DBIL::SaveTag($menu_3_cat3,$menu_33,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
					}
					else
					{
						DBIL::SaveTag($menu_22,$menu_33,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
					}
				}
				unless($menu_44 eq '')
				{
					DBIL::SaveTag($menu_33,$menu_44,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
				}
				unless($menu_55 eq '')
				{
					DBIL::SaveTag($menu_44,$menu_55,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
				}
				unless($menu_66 eq '')
				{
					DBIL::SaveTag($menu_55,$menu_66,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
				}
				$dbh->commit();
			}
		}
		elsif($main_url_content=~m/<iframe\s*src\=\s*(?:\"|\')([^<]*?)(?:\"|\')[^<]*?>/is) ###If Product Page having Images (Eg: "http://www.forever21.com/looks/F21_main.aspx?br=21men")
		{
			# print "NOT IN SuBLK11111>>>menu_11:$menu_11,$menu_2_cat2:$menu_22,$menu_3_cat3:$menu_33,menu_44:$menu_44,menu_55:$menu_55,menu_66:$menu_66\n";   # "Inside Frame"
			my $main_url_content_url1=$1;
			
			my $main_url_content_url1="http://www.forever21.com".$main_url_content_url1 unless($main_url_content_url1=~m/^http/is);
			
			my $main_url1_content=&getcont($main_url_content_url1,"GET","","");
			
			while($main_url1_content=~m/<a[^>]*?href\s*\=\s*(?:\"|\')\s*javascript[^\(]*?\((?:\'|\")([^>]*?)(?:\'|\")[^>]*?\)\s*[^>]*?>/igs)
			{
				my $product_url=$1;
				$product_url=~s/amp;//igs;					
				my $product_url="http://www.forever21.com".$product_url unless($product_url=~m/^http/is);
				
				my ($product_id,$product_object_key);
				
				if($product_url=~m/ProductID\s*\=\s*([^\&\$]*?)\s*(?:\&|$)/is)
				{
					$product_id=$1;
				}
				$product_url=~s/\&VariantID=[\w\W]*//is;
				
				###Insert Product values
				if($hash_id{$product_id} eq  '')
				{
					$product_object_key = DBIL::SaveProduct($product_url,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
					$hash_id{$product_id}=$product_object_key;
				}
				else
				{
					$product_object_key=$hash_id{$product_id};
				}
				
				######Insert Tag values
				DBIL::SaveTag('Menu_1',$menu_11,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
				if($menu_2_cat2)
				{
					DBIL::SaveTag($menu_2_cat2,$menu_22,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
				}
				else
				{
					DBIL::SaveTag('Menu_2',$menu_22,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
				}
				
				unless($menu_33 eq '')
				{
					if($menu_3_cat3)
					{
						DBIL::SaveTag($menu_3_cat3,$menu_33,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
					}
					else
					{
						DBIL::SaveTag($menu_22,$menu_33,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
					}
				}
				unless($menu_44 eq '')
				{
					DBIL::SaveTag($menu_33,$menu_44,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
				}
				unless($menu_55 eq '')
				{
					DBIL::SaveTag($menu_44,$menu_55,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
				}
				unless($menu_66 eq '')
				{
					DBIL::SaveTag($menu_55,$menu_66,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
				}
				$dbh->commit();
			}
		}
		#next page
		if($main_url_content=~m/<a[^>]*?href\s*\=\s*(?:\"|\')([^>]*?)(?:\"|\')\s*title\s*\=\s*(?:\"|\')\s*NextPage[^>]*?(?:\"|\')[^>]*?>/is)
		{
			$main_url=$1;
			
			$main_url='http://www.forever21.com/Product/Category.aspx'.$main_url unless($main_url=~m/^\s*http\:/is);
			
			$main_url_content = &getcont($main_url,"GET","","");
			goto next_page;
		}
	}
}

#################### For Dashboard #######################################
DBIL::Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);
#################### For Dashboard #######################################

#Function to get Product Page's Content
sub getcont()
{
    my($url,$method,$cont,$ref,$extra)=@_;
	my $iterr=0;
	Home:
	my $request=HTTP::Request->new("$method"=>$url);
	if($ref ne '')
    {
        $request->header("Referer"=>"$ref");
    }
    if(lc $method eq 'post')
    {
        $request->content($cont);
    }
	$request->header("Content-Type"=>"application/x-www-form-urlencoded; charset=UTF-8");
	if($extra ne '')
	{
		$request->header("X-Requested-With"=>"$extra");
	}
	my $res=$ua->request($request);
	$cookie->extract_cookies($res);
    $cookie->save;
    $cookie->add_cookie_header($request);
    my $code=$res->code;
	if($code==200)
    {
		my $content=$res->content();
		return $content;
	}
    elsif($code=~m/50/is)
    {
		if($iterr==3)
		{
			return;
		}
        #sleep(30);
		$iterr++;
        goto Home;
	}
    elsif($code=~m/30/is)
    {
		my $loc=$res->header("Location");
        $url=url($loc,$url)->abs();
		my $content=getcont($url,"GET","","");
		return $content;
	}
    elsif($code=~m/40/is)
    {
        #print "\n URL Not found";
    }
}
#Function to get Product Page's Code
sub get_content_status
{
	my $url = shift;
	my $rerun_count=0;
	Home:
	$url =~ s/^\s+|\s+$//g;
	$url =~ s/amp\;//g;
	my $req = HTTP::Request->new(GET=>"$url");
	$req->header("Content-Type"=> "text/plain");
	my $res = $ua->request($req);
	$cookie->extract_cookies($res);
	$cookie->save;
	$cookie->add_cookie_header($req);
	my $code=$res->code;
	if($code =~m/20/is)
	{
	 return $code;
	}
	else
	{
		if ( $rerun_count <= 1 )
		{
				$rerun_count++;
				goto Home;
		}
	}
}
