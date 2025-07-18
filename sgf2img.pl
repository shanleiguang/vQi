#!/usr/bin/perl
#围棋SGF文件转中国古棋谱风格图片，SGF文件保存到games/01/game.sgf
#by shanleiguang, 2025.7
use strict;
use warnings;

use Image::Magick;
use Games::Go::SGF::Grove;
use Getopt::Std;
use Data::Dumper;
use Encode;
use utf8;

$| = 1; #autoflush

binmode(STDIN, 'encoding(utf8)');
binmode(STDOUT, 'encoding(utf8)');
binmode(STDERR, 'encoding(utf8)');

my %opts;

getopts('hDlcz:g:', \%opts);

if(defined $opts{'h'}) { print_help(); exit; }

print "错误：无棋谱ID，'-g'!\n" if(not $opts{'g'} or $opts{'g'} !~ m/^\d+$/);

my $game_id = $opts{'g'}; #棋谱ID

print "错误：棋谱ID目录不存在，'games/$opts{'g'}'\n" if(not -d "games/$game_id");
print "错误：棋谱SGF文件不存在，'games/$opts{'g'}/game.sgf'\n" if(not -f "games/$game_id/game.sgf");
print "错误：棋谱SGF转图片配置文件不存在，'games/$opts{'g'}/sgfimg.sgf'\n" if(not -f "games/$game_id/sgfimg.sgf");

my $type_id = $opts{'t'} ? $opts{'t'} : 1; # 默认为1: MultiGo
my $sgf_file = "games/$game_id/game.sgf"; #棋谱SGF文件
my $sgfimg_cfg = "games/$game_id/sgfimg.cfg"; #棋谱SGF转图片配置文件
my $ginfo_file = "games/$game_id/info.txt"; #棋谱基本信息文件
my $gcomment_file = "games/$game_id/comments.txt"; #棋谱备注文件
my $sgfimgs_dir = "games/$game_id/sgfimgs"; #棋谱转图片目录

`mkdir $sgfimgs_dir` if(not -d $sgfimgs_dir);

#读取书籍配置文件
my %sgfimg;
open SCONFIG, "< $sgfimg_cfg";
print "读取棋谱转图片配置文件'$sgfimg_cfg'...\n";
while(<SCONFIG>) {
	chomp;
	next if(m/^\s{0,}$/);
	next if(m/^#/);
	s/#.*$// if(not m/=#/);
	s/\s//g;
	my ($k, $v) = split /=/, $_;
	$v = decode('utf-8', $v);
	$sgfimg{$k} = $v;
}
close(SCONFIG);

my ($decode_id, $app_id, $num_tid) = ($sgfimg{'decode_id'}, $sgfimg{'app_id'}, $sgfimg{'number_type_id'});
my ($num_fnt, $num_fbs) = ($sgfimg{'number_font'}, $sgfimg{'number_font_base_size'});
my ($num_zhb, $num_zhm, $num_zhs) = ($sgfimg{'number_zhfs_zoom_big'}, $sgfimg{'number_zhfs_zoom_mid'}, $sgfimg{'number_zhfs_zoom_sml'});
my ($lab_fnt, $lab_fs) = ('Helvetica', 30);
my ($pce_cr, $pce_lw) = ($sgfimg{'piece_circle_r'}, $sgfimg{'piece_circle_lw'});
my ($pce_or, $pce_olw) = ($sgfimg{'piece_circle_or'}, $sgfimg{'piece_circle_olw'});
my ($pce_olbc, $pce_olwc) = ($sgfimg{'piece_circle_olbc'}, $sgfimg{'piece_circle_olwc'});

my ($nzhp1x, $nzhp1y)   = ($sgfimg{'number_zhp1_x'}, $sgfimg{'number_zhp1_y'});
my ($nzhp21x, $nzhp21y) = ($sgfimg{'number_zhp21_x'}, $sgfimg{'number_zhp21_y'});
my ($nzhp22x, $nzhp22y) = ($sgfimg{'number_zhp22_x'}, $sgfimg{'number_zhp22_y'});
my ($nzhp31x, $nzhp31y) = ($sgfimg{'number_zhp31_x'}, $sgfimg{'number_zhp31_y'});
my ($nzhp32x, $nzhp32y) = ($sgfimg{'number_zhp32_x'}, $sgfimg{'number_zhp32_y'});
my ($nzhp33x, $nzhp33y) = ($sgfimg{'number_zhp33_x'}, $sgfimg{'number_zhp33_y'});
my ($nzhp41x, $nzhp41y) = ($sgfimg{'number_zhp41_x'}, $sgfimg{'number_zhp41_y'});
my ($nzhp42x, $nzhp42y) = ($sgfimg{'number_zhp42_x'}, $sgfimg{'number_zhp42_y'});
my ($nzhp43x, $nzhp43y) = ($sgfimg{'number_zhp43_x'}, $sgfimg{'number_zhp43_y'});
my ($nzhp44x, $nzhp44y) = ($sgfimg{'number_zhp44_x'}, $sgfimg{'number_zhp44_y'});

my $game = load_sgf $sgf_file;
my $gcontent = $game->[0];

if($opts{'D'}) { print Dumper($gcontent); exit; } #Dump棋谱文件数据结构

my $ginfo = shift @$gcontent; #第一个元素是棋局基本信息
my $round_num = int((scalar @$gcontent)/2+0.5); #剩下为回合落子信息，总回合数
my @ginfo_keys = ('AP', 'SZ', 'DT', 'PC', 'GN', 'EV', 'C', 'PB', 'BR', 'PW', 'WR', 'KM', 'RE');

foreach my $gkey (@ginfo_keys) {
	if(defined $ginfo->{$gkey}) {
		$ginfo->{$gkey} =~ s/\s|\t|\n//g;
		if(ref $ginfo->{$gkey} eq 'ARRAY') {
			$ginfo->{$gkey} = join ' ', @{$ginfo->{$gkey}};
		}
		$ginfo->{$gkey} = decode($decode_id, $ginfo->{$gkey});
		#print "$gkey -> $ginfo->{$gkey}\n";
	} else {
		$ginfo->{$gkey} = '';
	}
}

my $gap = $ginfo->{'AP'}; #打谱软件
my $gsz = $ginfo->{'SZ'}; #棋盘SIZE
my $gdate = $ginfo->{'DT'}; #时间
my $gpc = $ginfo->{'PC'}; #地点
my $gname = $ginfo->{'GN'};  #赛事名
my $gevent = $ginfo->{'EV'}; #赛事事件
my $gcomment = $ginfo->{'C'}; #备注
my $gpb = $ginfo->{'PB'}; #黑方选手
my $gbr = $ginfo->{'BR'}; #黑方段位
my $gpw = $ginfo->{'PW'}; #白方选手
my $gwr = $ginfo->{'WR'}; #白方段位
my $gkm = $ginfo->{'KM'}; #让子
my $gre = $ginfo->{'RE'}; #结果

print '-' x 80, "\n";
print "SGF棋谱信息\n";
print '-' x 80, "\n";
print "打谱软件（AP）：$gap\t棋盘大小（SZ）：$gsz\n";
print "赛事日期（DT）：$gdate\t赛事地点（PC）：$gpc\n";
print "赛事名称（GN）：$gname\n";
print "赛事事件（EV）：$gevent\n";
print "黑方选手（PB、BR）：$gpb $gbr\n";
print "白方选手（PW、WR）：$gpw $gwr\n";
print "让子信息（KM）：$gkm\n";
print "比赛结果（RE）：$gre\n";
print "总回合数：$round_num\n";
print '-' x 80, "\n";

exit if(defined $opts{'l'}); #打印显示棋谱基础信息

my $A1_x = 0; my $A1_y = 0;
my $tref = []; # [ [第一行【第一列x,y】], ]

foreach my $i (1..19) {
	my @lpoints; #左第一列
	foreach my $j (1..19) {
		my $x = $A1_x+$i*50;
		my $y = $A1_y+$j*50;
		push @lpoints, [$x, $y];
	}
	push @$tref, \@lpoints;
}

my $table_img = 'canvas/table_weiqi.jpg';
my $timg = Image::Magick->new();

$timg->ReadImage($table_img);

#座子
if($ginfo->{'AB'}) {
	foreach my $ab (@{$ginfo->{'AB'}}) {
		print_piece(0, 'B', $ab);
	}
}
if($ginfo->{'AW'}) {
	foreach my $aw (@{$ginfo->{'AW'}}) {
		print_piece(0, 'W', $aw);
	}
}

my $first_pc = $gcontent->[0]->{'B'} ? 'B' : 'W'; #判断黑先白先
my $color1 = ($first_pc eq 'B') ? 'B' : 'W';
my $color2 = ($first_pc eq 'B') ? 'W' : 'B';
my $color1_zh = ($color1 eq 'B') ? '黑' : '白';
my $color2_zh = ($color2 eq 'B') ? '黑' : '白';

open COMMENTS, "> $gcomment_file";
foreach my $rcnt (1..$round_num) {
	my $round1 = shift @$gcontent;
	my $round2 = shift @$gcontent;
	my $comment1 = $round1->{'C'} ? $round1->{'C'} : '@';
	my $comment2 = $round2->{'C'} ? $round2->{'C'} : '@';
	my $round_id = $rcnt;

	#输出备注
	$comment1 = decode($decode_id, $comment1);
	$comment2 = decode($decode_id, $comment2);
	print COMMENTS '@', "\n", '@', $color1_zh, $rcnt*2-1, "手\n";
	print COMMENTS "$comment1\n";
	print COMMENTS '@', $color2_zh, $rcnt*2, "手\n";
	print COMMENTS "$comment2\n";
	print COMMENTS '$', "\n";
	next if(defined $opts{'c'});

	#打印本轮落子
	print_piece(($rcnt-1)*2+1, $color1, $round1->{$color1});
	print_piece(($rcnt-1)*2+2, $color2, $round2->{$color2});
	$timg->Write("$sgfimgs_dir/last.jpg"); #保存本轮快照
	#打印本轮落子标识圈
	print_piece_oc(($rcnt-1)*2+1, $color1, $round1->{$color1});
	print_piece_oc(($rcnt-1)*2+2, $color2, $round2->{$color2});

	#打印Labels
	if($round1->{'LB'}) {
		foreach my $label (@{$round1->{'LB'}}) {
			print_label($label->[1], $label->[0]);
		}
	}
	if($round2->{'LB'}) {
		foreach my $label (@{$round2->{'LB'}}) {
			print_label($label->[1], $label->[0]);
		}
	}

	$round_id = '00'.$rcnt if($rcnt <= 9);
	$round_id = '0'.$rcnt if($rcnt >= 10 and $rcnt <=99);
	print "生成第[$rcnt/$round_num]回合图片...";
	$timg->Write("$sgfimgs_dir/$round_id.jpg");
	print "完成\n";
	if(defined $opts{'z'} and $rcnt == $opts{'z'}) {
		`rm $sgfimgs_dir/last.jpg` if($^O =~ m/darwin/i);
		`del $sgfimgs_dir/last.jpg` if($^O =~ m/win32/i);
		last;
	}
	if(not scalar @$gcontent) {
		`rm $sgfimgs_dir/last.jpg` if($^O =~ m/darwin/i);
		`del $sgfimgs_dir/last.jpg` if($^O =~ m/win32/i);
		last;
	}
	$timg = undef;
	$timg = Image::Magick->new();
	$timg->ReadImage("$sgfimgs_dir/last.jpg"); #读取快照图片，在快照基础上添加下一轮落子
}
close(COMMENTS);

sub print_help {
	print <<END
   ./$0，用于将围棋SGF棋谱文件转换为古棋谱风格的图片
	-h\t帮助信息
	-D\tDump SGF文件数据结构
	-l\t查看SGF文件赛事就出信息
	-c\t仅将每回合讲解备注文字输出到comments.txt文件
	-z\t测试模式，仅生成指定回合数量的图片
	-g\t棋谱ID，注意棋谱SGF文件需命名为'game.sgf'
		作者：兀雨书屋【小红书】，2025
END
}

sub get_zhnum {
	my $num = shift;
	my %num2zhs;
	open NUM, '< num2zh.txt';
	while(<NUM>) {
		chomp;
		$_ = decode('utf-8', $_);
		my ($n, $z) = split /\|/, $_;
		$num2zhs{$n} = $z;
	}
	close(NUM);
	return $num2zhs{$num};
}

sub get_zhnum_xy {
	my ($num, $cr, $pref) = @_;
	my $zhnum = get_zhnum($num);
	my ($cx, $cy) = @$pref;
	if(length($zhnum) == 1) {
		my $cs1 = $cr*$num_zhb;
		return ([$cx+$cs1*$nzhp1x, $cy+$cs1*$nzhp1y, $cs1]);
	}
	if(length($zhnum) == 2) {
		my ($cs1, $cs2) = ($cr*$num_zhm, $cr*$num_zhm);
		if($zhnum =~ m/^百/) {
			return (
				[$cx+$cs1*$nzhp31x, $cy+$cs1*$nzhp31y, $cs1],
				[$cx+$cs2*$nzhp32x, $cy+$cs1*$nzhp31y, $cs2]
			);
		} else {
			return (
				[$cx+$cs1*$nzhp21x, $cy+$cs1*$nzhp21y, $cs1],
				[$cx+$cs2*$nzhp22x, $cy+$cs2*$nzhp22y, $cs2]
			);
		}
	}
	if(length($zhnum) == 3) {
		my ($cs1, $cs2, $cs3) = ($cr*$num_zhm, $cr*$num_zhs, $cr*$num_zhs);
		if($zhnum =~ m/^[二|三]百/) {
			($cs1, $cs2, $cs3) = ($cr*$num_zhs, $cr*$num_zhs, $cr*$num_zhm);
			return (
				[$cx+$cs1*$nzhp41x, $cy+$cs1*$nzhp41y, $cs1],
				[$cx+$cs2*$nzhp42x, $cy+$cs2*$nzhp42y, $cs2],
				[$cx+$cs3*$nzhp32x, $cy+$cs1*$nzhp31y, $cs3]
			);
		} else {
			return (
				[$cx+$cs1*$nzhp31x, $cy+$cs1*$nzhp31y, $cs1],
				[$cx+$cs2*$nzhp32x, $cy+$cs2*$nzhp32y, $cs2],
				[$cx+$cs3*$nzhp33x, $cy+$cs3*$nzhp33y, $cs3]
			);
		}
	}
	if(length($zhnum) == 4) {
		my ($cs1, $cs2, $cs3, $cs4) = ($cr*$num_zhs, $cr*$num_zhs, $cr*$num_zhs, $cr*$num_zhs);
		return (
			[$cx+$cs1*$nzhp41x, $cy+$cs1*$nzhp41y, $cs1],
			[$cx+$cs2*$nzhp42x, $cy+$cs2*$nzhp42y, $cs2],
			[$cx+$cs3*$nzhp43x, $cy+$cs3*$nzhp43y, $cs3],
			[$cx+$cs4*$nzhp44x, $cy+$cs4*$nzhp44y, $cs4],
		);
	}
}

sub print_label {
	my ($label, $pref) = @_;
	my ($xid, $yid) = @$pref;
	my ($px, $py) = @{$tref->[$xid-1]->[$yid-1]};
	$timg->Annotate(text => $label, font => $lab_fnt, pointsize => $lab_fs, x => $px, y => $py,
		stroke => 'black', strokewidth => 1);
}

sub print_piece {
	my ($cnt, $pc, $pref) = @_;
	return if(not defined $pref);
	my $pcolor = ($pc eq 'B') ? 'black' : 'white';
	my $ncolor = ($pcolor eq 'black') ? 'white' : 'black';
	my ($xid, $yid) = @$pref;
	my ($px, $py);
	
	if($app_id == 1) {
		($px, $py) = @{$tref->[$xid]->[$yid]};
	}

	$timg->Draw(primitive => 'circle', points => "$px,$py @{[$px + $pce_cr]},$py",
		fill => $pcolor, stroke => 'black', strokewidth => $pce_lw);
	if($cnt > 0) {
		if($num_tid == 1) {
			my @nchars = split //, get_zhnum($cnt);
			my @nxys = get_zhnum_xy($cnt, $pce_cr, [$px, $py]);
			foreach my $i (0..$#nchars) {
				my $nc = $nchars[$i];
				my ($nx, $ny, $ns) = @{$nxys[$i]};
				$timg->Annotate(text => $nc, font => "fonts/$num_fnt", pointsize => $ns, x => $nx, y => $ny,
					fill => $ncolor, stroke => $ncolor, strokewidth => 0.5);
			}
		}
		if($num_tid == 0) {
			my ($ns, $nx, $ny);

			$ns = (length($cnt) == 3) ? $pce_cr*$num_zhs : $pce_cr*$num_zhm;
			$nx = (length($cnt) == 3) ? $px-length($cnt)*$ns/3.1 : (length($cnt) == 2) ? $px-length($cnt)*$ns/3.35 : $px-length($cnt)*$ns/3;
			$ny = $py+$ns/3;
			$timg->Annotate(text => $cnt, font => 'Helvetica', pointsize => $ns, x => $nx, y => $ny,
					fill => $ncolor, stroke => $ncolor, strokewidth => 0.5);
		}
	}
}

sub print_piece_oc {
	my ($cnt, $pc, $pref) = @_;
	return if(not defined $pref);
	my $pcolor = ($pc eq 'B') ? 'black' : 'white';
	my $ocolor = ($pcolor eq 'black') ? $pce_olbc : $pce_olwc;
	my ($xid, $yid) = @$pref;
	my ($px, $py);
	
	if($app_id == 1) {
		($px, $py) = @{$tref->[$xid]->[$yid]};
	}
	$timg->Draw(primitive => 'circle', points => "$px,$py @{[$px + $pce_or]},$py", fill => 'transparent',
		'stroke-dasharray' => [3,3,3], stroke => $ocolor, strokewidth => $pce_olw);
}