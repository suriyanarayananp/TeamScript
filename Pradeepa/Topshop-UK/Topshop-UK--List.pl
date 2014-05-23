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
my $Retailer_Random_String='Top';
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
my $ua=LWP::UserAgent->new(show_progress=>1); #
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
##################### For Dashboard #######################################

my $url = 'http://www.topshop.com/';
my $content = get_content($url);
# open FH , ">home.html" or die "File not found\n";
# print FH $content;
# close FH;

my %totalHash;

############ URL Collection ##############
my @regex_array=('<li\s*class=\"[^<]*?\">\s*<a\s*[^<]*\s*title=\"(New\s*In)\">[\w\W]*?<\/a>\s*<div\s*[^<]*>([\w\W]*?)\s*<\/div>\s*<\/li>',
'<li\s*class=\"[^<]*?\">\s*<a\s*[^<]*\s*title=\"(Clothing)\">[\w\W]*?<\/a>\s*<div\s*[^<]*>([\w\W]*?)\s*<\/div>\s*<\/li>','<li\s*class=\"[^<]*?\">\s*<a\s*[^<]*\s*title=\"(Shoes)\">[\w\W]*?<\/a>\s*<div\s*[^<]*>([\w\W]*?)\s*<\/div>\s*<\/li>',
'<li\s*class=\"[^<]*?\">\s*<a\s*[^<]*\s*title=\"(Bags\s*&amp;\s*Accessories)\">[\w\W]*?<\/a>\s*<div\s*[^<]*>([\w\W]*?)\s*<\/div>\s*<\/li>',
'<li\s*class=\"[^<]*?\">\s*<a\s*[^<]*\s*title=\"(Make\s*Up)\">[\w\W]*?<\/a>\s*<div\s*[^<]*>([\w\W]*?)\s*<\/div>\s*<\/li>',
'<li\s*class=\"[^<]*?\">\s*<a\s*[^<]*\s*title=\"(Sale\s*&(?:amp;)?\s*Offers)\">[\w\W]*?<\/a>\s*<div\s*[^<]*>([\w\W]*?)\s*<\/div>\s*<\/li>');

my $robo_menu=$ARGV[0];

foreach my $regex (@regex_array)
{
	if ( $content =~ m/$regex/is )
	{
		my $urlcontent = $2;
		my $menu_1=&clean($1); ###Clothing
		my ($menu_2,$category_url);
		
		next unless($menu_1 eq $robo_menu);
		
		while ( $urlcontent =~ m/<a[^<]*?href\=\"([\w\W]*?)\"\s*title\=\"[\w\W]*?\">\s*(\w[^<]+?)\s*</igs )
		{
			my $main_list_url = $1;
			my $menu_2=&clean($2);####Dresses
			# again:
			# next if($menu_2!~m/Suits\s*and\s*Co/is);
			
			if($menu_2=~m/^\s*A\-Z\s*$|^\s*View\s*All\s*$|^\s*We\s*Love\s*$/is)
			{
				next;
			}
			unless($main_list_url=~m/^\s*http\:/is)
			{
				$main_list_url=$url.$main_list_url;
			}
			my $main_list_content = get_content($main_list_url);
			
			if ( $main_list_content =~ m/<span\s*class=\"filter_label[^<]*\">((?![^<]*\s*Brand)(?!BRAND)?(?!SIZE)(?!price)(?![^>]*?Rating)(?![^>]*?Price)(?![^>]*?Accessories)(?![^<]*\sSize)(?!Size)[^<]*?)<\/span>(?:[^>]*?|<a[^<]*>[^<]*<\/a>)\s*<\/div>\s*<div\s*class=\"cf\">([\w\W]*?)<\/ul>\s*<\/div>\s*<\/div>/is) 
			{
				my $part_name = &clean($1);  ##Party Dresses
				my $list_part_content = &clean($2);
				
				if($part_name=~m/\s*Categor(?:y|ies)\s*/is)  ##If Category
				{
					print "In Category Block >>$menu_1 $menu_2  $part_name\n";
					my $count1=1;
					
					while($list_part_content=~m/<a[^<]*?href\=\"([^<]*?)\"[^>]*?>\s*([\w\W]*?)\s*<\/a>/igs) ## #(?!View\s*All)
					{
						my $category_url = $1;
						my $category_name = &clean($2);
						$category_name =~s/(\([\w]*\))//;  
						print "Category Block category_name>>$category_name\t\t\t$count1\n";
						
						my $count=1;
						
						if(($count1==1)&&($category_name=~m/^\s*View\s*All\s*/is))
						{
							goto Color;
						}
						elsif($category_name=~m/^\s*View\s*All\s*/is)
						{
							next;
						}
						$count1++;
						
						next_page:
						unless($category_url=~m/^\s*http\:/is)
						{
							$category_url=$url.$category_url;
						}
						my $product_list_content=get_content($category_url);
						while($product_list_content=~m/<a\s*[^<]*?href=\"([^<]*?)\"\s*data\-productId=\"[\d]*?\">[\w\W]*?<\/a>/igs)  ##Product Collection
						{
							my $product_url=$1;
							
							# if($category_name=~m/Suits\s*and\s*Co/is)
							# {
								# print "product_url>>$product_url\n";
							# }
							 
							unless($product_url=~m/^\s*http\:/is)
							{
								$product_url=$url.$product_url;
							}
							$product_url =~ s/amp;//g;
							
							if($product_url=~m/^[^>]*\/([^>]*?)\?[^>]*?$/is) #### Making Unique Product URL
							{
								$product_url='http://www.topshop.com/en/tsuk/product/'.$1;
							}
							elsif($product_url=~m/^[^>]*\/([^>]*?)$/is)
							{
								$product_url='http://www.topshop.com/en/tsuk/product/'.$1;
							}
							
							###Insert Product values
							my $product_object_key;
							if($totalHash{$product_url} ne '')
							{
								# print "Data Exists! -> $totalHash{$product_url}\n";
								$product_object_key = $totalHash{$product_url};
							}
						   else
						   {
								# print "New Data\n";
								$product_object_key = DBIL::SaveProduct($product_url,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
								$totalHash{$product_url}=$product_object_key;
						   }
							
							###Insert Tag values
							DBIL::SaveTag('Menu_1',$menu_1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
							DBIL::SaveTag('Menu_2',$menu_2,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
							DBIL::SaveTag('Category',$category_name,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
							$dbh->commit();	
						}
Color:						
						my $main_list_content_color=get_content($category_url);
						
						if($count==1)
						{
							if ( $main_list_content_color =~ m/<span\s*class=\"filter_label[^<]*\">([^<]*Colour)<\/span>(?:[^>]*?|<a[^<]*>[^<]*<\/a>)\s*<\/div>\s*<div\s*class=\"cf\">([\w\W]*?)<\/ul>\s*<\/div>\s*<\/div>/is)								
							{
								my $part_name1 = &clean($1);
								my $list_part_content1 = $2;
								
								print "Getting Color\n";
								
								while($list_part_content1=~m/<a[^<]*?href\=\"([^<]*?)\"[^>]*?>\s*(?!View\s*All)([\w\W]*?)\s*<\/a>/igs)##if list page have do not have category except "BRAND,COLOR,SIZE,price"
								{
									my $category_url_clr = &clean($1);
									my $category_name_clr = &clean($2);
									
									$category_name_clr=&ProperCase($category_name_clr);
									$category_name_clr=~s/\-(\w)/-\u\L$1/is;
									sub ProperCase
									{
									 join(' ',map{ucfirst(lc("$_"))}split(/\s/,$_[0]));
									}
									
									next_page11:
									unless($category_url_clr=~m/^\s*http\:/is)
									{
										$category_url_clr=$url.$category_url_clr;
									}
									my $product_list_content1=get_content($category_url_clr);
									while($product_list_content1=~m/<a\s*[^<]*?href=\"([^<]*?)\"\s*data\-productId=\"[\d]*?\">[\w\W]*?<\/a>/igs) ##Product Collection
									{
										my $product_url=$1;
										unless($product_url=~m/^\s*http\:/is)
										{
											$product_url=$url.$product_url;
										}
										$product_url =~ s/amp;//g;
										
										if($product_url=~m/^[^>]*\/([^>]*?)\?[^>]*?$/is) #### Making Unique Product URL
										{
											$product_url='http://www.topshop.com/en/tsuk/product/'.$1;
										}
										elsif($product_url=~m/^[^>]*\/([^>]*?)$/is)
										{
											$product_url='http://www.topshop.com/en/tsuk/product/'.$1;
										}
										
										###Insert Product values
										my $product_object_key;
										if($totalHash{$product_url} ne '')
										{
											# print "Data Exists! -> $totalHash{$product_url}\n";
											$product_object_key = $totalHash{$product_url};
										}
									   else
									   {
											# print "New Data\n";
											$product_object_key = DBIL::SaveProduct($product_url,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
											$totalHash{$product_url}=$product_object_key;
									   }
										
										$category_name_clr =~s/(\([\w]*\))//;  
										###Insert Tag values										
										DBIL::SaveTag('Menu_1',$menu_1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag('Menu_2',$menu_2,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										DBIL::SaveTag($part_name1,$category_name_clr,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
										$dbh->commit();
									}
									if ( $product_list_content1 =~ m/<li\s*class=\"show_next\">\s*<a\s*href=\"([^<]*?)\"[^>]*?>/is )
									{
										$category_url_clr = $1;
										$category_url_clr =~ s/amp;//g;
										goto next_page11;
									}
								}										
							}
							$count++;
						}
						if ( $product_list_content =~ m/<li\s*class=\"show_next\">\s*<a\s*href=\"([^<]*?)\"[^>]*?>/is ) 
						{
							$category_url = $1;
							$category_url =~ s/amp;//g;
							goto next_page;
						}
					}
				}
				else  ###Products taken by color
				{
					
					my $part_name = &clean($1);
					my $list_part_content = $2;
					# print "No category Only Color Block:::$menu_1 $menu_2 $part_name\n";
					
					while($list_part_content=~m/<a[^<]*?href\=\"([^<]*?)\"[^>]*?>\s*(?!View\s*All)([\w\W]*?)\s*<\/a>/igs)##if list page have do not have category except "BRAND,COLOR,SIZE,price"
					{
						my $category_url = $1;
						my $category_name = &clean($2);
						
						next_page2:
						unless($category_url=~m/^\s*http\:/is)
						{
							$category_url=$url.$category_url;
						}
						my $product_list_content=get_content($category_url);
						while($product_list_content=~m/<a\s*[^<]*?href=\"([^<]*?)\"\s*data\-productId=\"[\d]*?\">[\w\W]*?<\/a>/igs) ##Product Collection
						{
							my $product_url=$1;
							# print "product_url>>$product_url\n";
							unless($product_url=~m/^\s*http\:/is)
							{
								$product_url=$url.$product_url;
							}
							$product_url =~ s/amp;//g;
							
							if($product_url=~m/^[^>]*\/([^>]*?)\?[^>]*?$/is) #### Making Unique Product URL
							{
								$product_url='http://www.topshop.com/en/tsuk/product/'.$1;
							}
							elsif($product_url=~m/^[^>]*\/([^>]*?)$/is)
							{
								$product_url='http://www.topshop.com/en/tsuk/product/'.$1;
							}
							
							###Insert Product values
							my $product_object_key;
							if($totalHash{$product_url} ne '')
							{
								$product_object_key = $totalHash{$product_url};
							}
						   else
						   {
								$product_object_key = DBIL::SaveProduct($product_url,$dbh,$robotname,$retailer_id,$Retailer_Random_String,$excuetionid);
								$totalHash{$product_url}=$product_object_key;
						   }
							
							$category_name =~s/(\([\w]*\))//;  
							###Insert Tag values										
							DBIL::SaveTag('Menu_1',$menu_1,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
							DBIL::SaveTag('Menu_2',$menu_2,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
							DBIL::SaveTag($part_name,$category_name,$product_object_key,$dbh,$robotname,$Retailer_Random_String,$excuetionid);
							$dbh->commit();
						}
						if ( $product_list_content =~ m/<li\s*class=\"\s*show_next\s*\">\s*<a\s*href=\"([^<]*?)\"[^>]*?>/is ) 
						{
							$category_url = $1;
							$category_url =~ s/amp;//g;
							goto next_page2;
						}
					}										
				}
			}
			else
			{
				# print "Block Not Matching\n";
			}
		}
	}
}
sub clean()
{
	my $text=shift;
	
	$text=~ s/amp;//g;
	$text=~s/Â//igs;
	
	return $text;
}

#################### For Dashboard #######################################
DBIL::Save_mc_instance_Data($retailer_name,$retailer_id,$pid,$ip,'STOP',$robotname);
#################### For Dashboard #######################################

# system(`/opt/home/merit/perl5/perlbrew/perls/perl-5.14.4/bin/perl /opt/home/merit/Merit_Robots/Topshop-UK--Detail.pl  &`);

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
	elsif($code =~m/50/is)
	{
		if ( $rerun_count <= 3 )
		{
			$rerun_count++;
			goto Home;
		}
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

