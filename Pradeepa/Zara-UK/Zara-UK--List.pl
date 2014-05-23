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
my $Retailer_Random_String='Zar';
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

my $content = get_content("http://www.zara.com/uk/");
# open FH , ">home.html" or die "File not found\n";
# print FH $content;
# close FH;

############ URL Collection ##############
my @regex_array=(
'<li\s*id=\"menuItemData_[^<]*\">\s*<a\s*href=\"([^<]*?)\"\s*>\s*(NEW\s*THIS\s*WEEK)\s*<\/a>','<li\s*id=\"menuItemData_[^<]*\">\s*<a\s*href=\"([^<]*?)\"\s*>\s*(WOMAN)\s*<\/a>',
'<li\s*id=\"menuItemData_[^<]*\">\s*<a\s*href=\"([^<]*?)\"\s*>\s*(MAN)\s*<\/a>',
'<li\s*id=\"menuItemData_[^<]*\">\s*<a\s*href=\"([^<]*?)\"\s*>\s*(KIDS)\s*<\/a>',
'<li\s*id=\"menuItemData_[^<]*\">\s*<a\s*href=\"([^<]*?)\"\s*>\s*(TRF)\s*<\/a>',
'<li\s*id=\"menuItemData_[^<]*\">\s*<a\s*href=\"([^<]*?)\"\s*>\s*(SALE)\s*<\/a>','<li\s*id=\"menuItemData_[^<]*\">\s*<a\s*href=\"([^<]*?)\"\s*>\s*(MINI)\s*<\/a>','<li\s*id=\"menuItemData_[^<]*\">\s*<a\s*href=\"([^<]*?)\"\s*>\s*(NEW COLLECTION)\s*<\/a>');  #Top Menu Collection

my $robo_menu=$ARGV[0];

foreach my $regex(@regex_array)
{
	if ( $content =~ m/$regex/is )
	{
		my $menu1_url = $1;
		my $menu_1=DBIL::Trim($2);
		
		next unless($menu_1 eq $robo_menu);
		
		my ($menu_2,$product_url);
		my $urlcontent = get_content($menu1_url);
		
		if($urlcontent =~ m/<ul\s*class=\"current\">\s*<li([\w\W]*)\s*<\/a>\s*<\/li>\s*<\/ul>\s*<\/li>/is)  ##SubMenu1 Block
		{
			my $menu2_content=$&;
			
			while($menu2_content =~ m/<\s*a\s*href=\"([^<]*?)"\s*>\s*([^<]*?)\s*<\s*\/a\s*>/igs)  ##SubMenu1 (Eg.Coats)
			{
				$menu_2=DBIL::Trim($2);
				my $menu2_url=$1;
				
				my $list_content = get_content($menu2_url);
				
				if($list_content=~m/<ul\s*class\s*\=\s*\"\s*current\s*\"\s*>[\w\W]*?<ul\s*class\s*\=\s*\"\s*current\s*\"\s*>([\w\W]*?)<\/ul>/is) ##SubMenu2 (Eg.Coats under Woman)
				{
					my ($cat_id1,$prod_id11);
					print "menu_2 : $menu_2\n";
				
					if($menu2_url=~m/\-?\s*c\s*(\d+)\s*\.\s*html/is)
					{
						$cat_id1=$1;
					}

					my $Char1='http://www.zara.com/webapp/wcs/stores/servlet/CategoryFilterJSON?categoryId='.$cat_id1.'&langId=-1&storeId=10706&filterCode=STATIC&ajaxCall=true';
					##Getting Characteristic url for the Produts under Respective Category(In Filter)
					my $Color1='http://www.zara.com/webapp/wcs/stores/servlet/CategoryFilterJSON?categoryId='.$cat_id1.'&langId=-1&storeId=10706&filterCode=DYNAMIC&ajaxCall=true';
					##Getting Color url for the Produts under Respective Category(In Filter)
					
					my $Char_Cont1 = get_content($Char1);
					# print "Char_Cont1::$Char_Cont1\n";
					
					my $Color_Cont1 = get_content($Color1);
					# print "Color_Cont1::$Color_Cont1\n";
					
					while($list_content=~ m/<a\s*href='([^<]*?)'\s*[^<]*\s*class='item\s*gaProductDetailsLink'/igs)   ##Collecting Products 
					{
						$product_url = $1;
						
						###Insert Product values
						my $product_object_key = DBIL::SaveProduct($product_url,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
						###Insert Tag values
						DBIL::SaveTag('Menu_1',$menu_1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
						DBIL::SaveTag('Menu_2',$menu_2,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
						$dbh->commit();
						if($product_url=~m/p\s*(\d+)\s*\.\s*html/is)
						{
							$prod_id11=$1;
						}
						
						##Taking Characteristics and Color Tag 
						&charactertag1($Char_Cont1,$prod_id11,$product_object_key);##Getting Characteristics Ids for the Corresponding Category using Function
						&charactertag1($Color_Cont1,$prod_id11,$product_object_key);##Getting Color Ids for the Corresponding Category using Function 
					}
					while($list_content =~ m/<ul\s*class\s*\=\s*\"\s*current\s*\"\s*>[\w\W]*?<ul\s*class\s*\=\s*\"\s*current\s*\"\s*>([\w\W]*?)<\/ul>/igs)##SubMenu2 Block
					{
						my $list_subcontent=$1;
						
						while($list_subcontent =~ m/<\s*a\s*href=\"([^<]*?)"\s*>\s*(?!\s*View\s*All)([^<]*?)\s*<\s*\/a\s*>/igs) ##SubMenu2
						{
							my $category_name=$2;  #DBIL::Trim($2);
							my $category_url =$1;
							
							my $main_list_content = get_content($category_url);
							
							##Taking Characteristics and Color Tag 
							my ($cat_id,$prod_id);
							
							if($category_url=~m/\-?\s*c\s*(\d+)\s*\.\s*html/is)
							{
								$cat_id=$1;
							}

							my $Char='http://www.zara.com/webapp/wcs/stores/servlet/CategoryFilterJSON?categoryId='.$cat_id.'&langId=-1&storeId=10706&filterCode=STATIC&ajaxCall=true';
							##Getting Characteristic url for the Produts under Respective Category(In Filter) 
							my $Color='http://www.zara.com/webapp/wcs/stores/servlet/CategoryFilterJSON?categoryId='.$cat_id.'&langId=-1&storeId=10706&filterCode=DYNAMIC&ajaxCall=true';
							##Getting Color url for the Produts under Respective Category(In Filter)
							
							my $Char_Cont = get_content($Char);
							my $Color_Cont = get_content($Color);
								
							while($main_list_content=~ m/<a\s*href='([^<]*?)'\s*[^<]*\s*class='item\s*gaProductDetailsLink'/igs)  ##Collecting Products
							{
								$product_url = $1;
								
								###Insert Product values
								my $product_object_key = DBIL::SaveProduct($product_url,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
								###Insert Tag values
								DBIL::SaveTag('Menu_1',$menu_1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
								DBIL::SaveTag('Menu_2',$menu_2,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
								DBIL::SaveTag('Menu_3',$category_name,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
								$dbh->commit();
								
								if($product_url=~m/p\s*(\d+)\s*\.\s*html/is)
								{
									$prod_id=$1;
								}
								
								&charactertag1($Char_Cont,$prod_id,$product_object_key);##Getting Characteristics Ids for the Corresponding Category using Function
								&charactertag1($Color_Cont,$prod_id,$product_object_key);##Getting Color Ids for the Corresponding Category using Function 
							}
						}
					}
				}
				else
				{
					my ($cat_id1,$prod_id11);
					print "menu_2 : $menu_2\n";
					
					if($menu2_url=~m/\-?\s*c\s*(\d+)\s*\.\s*html/is)
					{
						$cat_id1=$1;
					}
					
					my $Char1='http://www.zara.com/webapp/wcs/stores/servlet/CategoryFilterJSON?categoryId='.$cat_id1.'&langId=-1&storeId=10706&filterCode=STATIC&ajaxCall=true';
					##Getting Characteristic url for the Produts under Respective Category(In Filter)
					my $Color1='http://www.zara.com/webapp/wcs/stores/servlet/CategoryFilterJSON?categoryId='.$cat_id1.'&langId=-1&storeId=10706&filterCode=DYNAMIC&ajaxCall=true';
					##Getting Color url for the Products under Respective Category(In Filter)
					
					my $Char_Cont1 = get_content($Char1);##Getting Characteristics Ids for the Corresponding Category using Function
					my $Color_Cont1 = get_content($Color1);##Getting Color Ids for the Corresponding Category using Function
					
					while($list_content=~ m/<a\s*href='([^<]*?)'\s*[^<]*\s*class='item\s*gaProductDetailsLink'/igs)   ##Collecting Products
					{
						$product_url = $1;
						
						###Insert Product values
						my $product_object_key = DBIL::SaveProduct($product_url,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
						###Insert Tag values
						DBIL::SaveTag('Menu_1',$menu_1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
						DBIL::SaveTag('Menu_2',$menu_2,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
						$dbh->commit();
						
						if($product_url=~m/p\s*(\d+)\s*\.\s*html/is)
						{
							$prod_id11=$1;
						}
						
						##Taking Characteristics and Color Tag 
						&charactertag1($Char_Cont1,$prod_id11,$product_object_key); ##Getting Characteristics Ids for the Corresponding Category using Function
						&charactertag1($Color_Cont1,$prod_id11,$product_object_key);##Getting Color Ids for the Corresponding Category using Function
					}
				}
			}
		}
	}
}

sub charactertag1()
{
	my $Jcont1=shift;
	my $prod_id1=shift;
	my $product_object_key1=shift;
	
	while($Jcont1=~m/{\s*\"\s*values\s*\"([\w\W]*?)\"\s*type\s*\"\s*\:\s*\"\s*([^>]*?)\s*\"\s*}/igs)  ####Char,Color, Quality Blk (In Filter)
	{
		my $Type1_blk=$1;
		my $Type1=$2;
		
		if($Type1=~m/(?:size|Price)/is) ##Skip if size ,price
		{
			next;
		}
		
		while($Type1_blk=~m/{\s*\"[\w\W]*?\"\s*\}/igs)
		{
			my $Type_blk11=$&;
			my $name1;
			
			if($Type_blk11=~m/\s*\"\s*name\s*\"\s*\:\s*\"([^\'\"]*?)\s*\"/is) ##Getting name Eg. Characteristics or color
			{
				$name1=$1;
			}
			
			if($Type_blk11=~m/\"\s*skus\s*\"\s*\:([\w\W]*?\"\])/is)   ######Product urls to match with blk
			{
				my $Skus_id_blk1=$1;
				
				while($Skus_id_blk1=~m/(?:\"|\')\s*([^\'\"]*?)\s*(?:\"|\')/igs)  ######Product urls to match Char ids
				{
					my $Skuid1=$1;
					
					if(($Skuid1 eq $prod_id1)||($Skuid1=~m/$prod_id1/))
					{
						$Type1=~s/features/characteristics/igs;
						$Type1=~s/quality/qualities/igs;
						
						DBIL::SaveTag($Type1,$name1,$product_object_key1,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
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

##Function to Obtain Page's Content
sub get_content()
{
    my $url=shift;
    my $rerun_count=0;
    Home:
    my $req = HTTP::Request->new(GET=>"$url");
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
			goto Home;
		}
	}
}
