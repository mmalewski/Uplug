#!/usr/bin/perl
#---------------------------------------------------------------------------
# USAGE
#
# OPTIONS
#
#   -o ........ overwrite existing data (deletes entire data directory!!)
#   -y ........ assumes yes (doesn't prompt before deleting data dir!)
#
#---------------------------------------------------------------------------
# Copyright (C) 2004 J�rg Tiedemann  <joerg@stp.ling.uu.se>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#---------------------------------------------------------------------------

use strict;

use FindBin qw($Bin);
use File::Copy;
use File::Basename;
use XML::Parser;

use vars qw($opt_d $opt_r $opt_t $opt_c $opt_v $opt_x $opt_o $opt_y $opt_f $opt_m);
use Getopt::Std;
getopts('d:r:t:c:x:voyf:m:');


# script arguments

my $CORPUS     = $opt_c || 'CORPUS';    # name of this corpus
my $ALIGNTYPE  = $opt_t || 'ces';       # alignment file extension
my $XMLDIR     = $opt_x || 'xml';       # directory with all xml files
my $CWBDATA    = $opt_d || 'data';      # location of CWB data files (indeces)
my $CWBREG     = $opt_r || 'reg';       # directory of CWB registry
my $OVERWRITE  = $opt_o || 0;           # overwrite old CWB data
my $ASSUME_YES = $opt_y || 0;           # assume yes to overwrite
my $VERBOSE    = $opt_v || 0;           # verbose output

my @LANG       = @ARGV;                 # languages to be processed (sub-dirs!)


# CWB encoding tools

my $ENCODE='cwb-encode';
my $CWBMAKEALL='cwb-makeall';
my $CWBALIGNENCODE='cwb-align-encode';

# some more global variables

my $TMPDIR = $opt_m || '/tmp/BITEXTINDEXER'.$$;
mkdir $TMPDIR,0755 unless (-d $TMPDIR);

my $SentTag='s';                 # default sentence tag
my $WordTag='w';                 # default word tag
my $AllAttributes = 1;           # use all attributes
my $StrucAttrPattern = undef;    # structural attribute pattern
my $WordAttrPattern = undef;     # token attribute pattern

# global variables used in XML parser

my @PATTR=();
my %SATTR=();
my %nrSATTR=();

my @AllPATTR=();
my %AllSATTR=();

my $pos=0;
my $SentStart=0;
my $SentDone=0;
my $WordStart=0;
my $WordDone=0;
my $XmlStr;
my %WordAttr=();


## non iso-latin1 language encodings ....
my %LANGCODES=(
	       # some three letter language codes (more to add ...)
	       'bul' => 'utf-8',
	       'chi' => 'utf-8',
	       'cze' => 'iso-8859-2',
	       'ell' => 'iso-8859-7',
	       'gre' => 'iso-8859-7',
	       'heb' => 'utf-8',
	       'hrv' => 'iso-8859-2',
	       'ice' => 'iso-8859-4',
	       'jap' => 'utf-8',
	       'jpn' => 'utf-8',
	       'lit' => 'iso-8859-4',
	       'rum' => 'iso-8859-2',
	       'rus' => 'utf-8',
	       'slv' => 'iso-8859-2',
	       'tur' => 'iso-8859-9',
	       # two letter codes (complete & correct ??)
	       'ar' => 'utf-8',
	       'az' => 'utf-8',
	       'be' => 'utf-8',
	       'bg' => 'utf-8',
	       'bs' => 'utf-8',
	       'cs' => 'iso-8859-2',
	       'el' => 'iso-8859-7',
#	       'el' => 'utf-8',
	       'eo' => 'iso-8859-3',
	       'et' => 'iso-8859-4',
	       'he' => 'utf-8',
	       'hr' => 'iso-8859-2',
	       'hu' => 'iso-8859-2',
	       'id' => 'utf-8',
	       'ja' => 'utf-8',
	       'jp' => 'utf-8',
	       'ko' => 'utf-8',
	       'ku' => 'utf-8',
	       'lt' => 'iso-8859-4',
	       'lv' => 'iso-8859-4',
	       'mi' => 'utf-8',
	       'mk' => 'utf-8',
	       'pl' => 'iso-8859-2',
	       'ro' => 'iso-8859-2',
	       'ru' => 'utf-8',
	       'sk' => 'iso-8859-2',
	       'sl' => 'iso-8859-2',
	       'sr' => 'iso-8859-2',
	       'ta' => 'utf-8',
	       'th' => 'utf-8',
	       'tr' => 'iso-8859-9',
	       'uk' => 'utf-8',
	       'vi' => 'utf-8',
	       'xh' => 'utf-8',
	       'zh_tw' => 'utf-8',
	       'zu' => 'utf-8'
		   );


mkdir $CWBDATA,0755  if (not -d $CWBDATA);
mkdir $CWBREG,0755  if (not -d $CWBREG);
mkdir "$CWBDATA/$CORPUS",0755  if (not -d "$CWBDATA/$CORPUS");
mkdir "$CWBREG/$CORPUS",0755  if (not -d "$CWBREG/$CORPUS");

if ($opt_f){
    XML2CWB($opt_f,$opt_f.'.tok',$opt_f.'.pos','test');
    exit;
}

########################################################################
# make monolingual corpus indeces

if (not $opt_m){
foreach my $l (@LANG){
    print STDERR "find all xml files for '$l'\n" if $VERBOSE;
    my @doc = FindDocuments("$XMLDIR/$l",'xml');
    if (not @doc){next;}
    @doc = sort @doc;

    my $cwbtok = $TMPDIR.'/'.$l;
    my $cwbpos = $TMPDIR.'/'.$l.'.pos';

    @PATTR=();
    %SATTR=();
    %nrSATTR=();

    @AllPATTR=();
    %AllSATTR=();

    $pos=0;

    $SentStart=0;
    $SentDone=0;
    $WordStart=0;
    $WordDone=0;
    $XmlStr;
    %WordAttr=();

    foreach my $f (@doc){
	print STDERR "convert $f\n" if $VERBOSE;
	XML2CWB($f,$cwbtok,$cwbpos,$l);
    }

    my $attr = &AttrString;
    print STDERR "make CWB index for '$l'\n" if $VERBOSE;
    MakeCWBindex($l,$cwbtok,$attr);

    unlink $cwbtok;
    
}
}

########################################################################
# make alignment index for each language pair

foreach my $s (@LANG){
    ## read token position file for source language
    my $srcpos = $TMPDIR.'/'.$s.'.pos';
    my %SrcPos=();
    ReadPosFile($srcpos,\%SrcPos);

    foreach my $t (@LANG){

	my $dir = "$XMLDIR/$s-$t";
	$dir = "$XMLDIR/$s$t" if (-d "$XMLDIR/$s$t");
	next if (not -d $dir);

	## read token position file for target language
	my $trgpos = $TMPDIR.'/'.$t.'.pos';
	my %TrgPos=();
	ReadPosFile($trgpos,\%TrgPos);

	print STDERR "find all alignment files for '$s-$t'\n" if $VERBOSE;

#	my @doc = FindDocuments($dir,$ALIGNTYPE);    # (no genre-subcorpora):
	my @doc = FindDocuments($dir,$ALIGNTYPE,1);  # mindepth = 1!!!!
	if (not @doc){next;}
	@doc = sort @doc;

	my $srctrg = "$TMPDIR/$s$t.alg";
	my $trgsrc = "$TMPDIR/$t$s.alg";

	open ALG1,">$srctrg";
	open ALG2,">$trgsrc";

	print ALG1 "$s\ts\t$t\ts\n";
	print ALG2 "$t\ts\t$s\ts\n";

	foreach my $f (@doc){
	    Align2CWB($f,$srcpos,$trgpos,\%SrcPos,\%TrgPos);
	}

	close ALG1;
	close ALG2;

	print STDERR "make alignment index for '$s-$t'\n" if $VERBOSE;
	MakeCWBalg($srctrg,$trgsrc,$s,$t);

	unlink($srctrg);
	unlink($trgsrc);

    }
}

foreach my $s (@LANG){
    unlink($TMPDIR.'/'.$s.'.pos');
    foreach my $t (@LANG){
	unlink($TMPDIR.'/'.$t.'.pos');
    }
}
rmdir($TMPDIR);


# end of main ...
#############################################################








sub MakeCWBalg{
    my ($srctrg,$trgsrc,$srclang,$trglang)=@_;

    my $datdir = "$CWBDATA/$CORPUS";
    my $regdir = "$CWBREG/$CORPUS";

    #-----------------------------------------------
    # register alignments in CWB

    open F,"<$regdir/$trglang";
    my @reg=grep { /ALIGNED $srclang/ } <F>;
    close F;
    if (not @reg){
	open F,">>$regdir/$trglang";
	print F "ALIGNED $srclang\n";
	close F;
    }
    open F,"<$regdir/$srclang";
    my @reg=grep { /ALIGNED $trglang/ } <F>;
    close F;
    if (not @reg){
	open F,">>$regdir/$srclang";
	print F "ALIGNED $trglang\n";
	close F;
    }

    system "$CWBALIGNENCODE -r $regdir -D $srctrg";
    system "$CWBALIGNENCODE -r $regdir -D $trgsrc";

    copy "$srctrg","$datdir/$srclang$trglang.alg";
    copy "$trgsrc","$datdir/$trglang$srclang.alg";

    system "gzip -f $datdir/$trglang$srclang.alg";
    system "gzip -f $datdir/$srclang$trglang.alg";
}




sub Align2CWB{
    my ($file,$srcPosFile,$trgPosFile,$srcPos,$trgPos)=@_;

    my $lastsrc=-1;
    my $lasttrg=-1;

    if ($file=~/\.gz$/){open F,"gzip -cd <$file |";}
    else{open F,"<$file";}

    local $/='>';              # read blocks end at '>'
    my ($srcdoc,$trgdoc);
    my ($srcdocID,$trgdocID);

    while(<F>){
	if (/fromDoc\s*=\s*\"([^\"]+)\"/){
	    $srcdoc=$1;
	    $srcdoc=~s/\/\.\//\//g;
	    if (not exists $$srcPos{$srcdoc}){
		if (exists $$srcPos{$srcdoc.'.gz'}){
		    $srcdoc .= '.gz';
		}
	    }
	}
	if (/toDoc\s*=\s*\"([^\"]+)\"/){
	    $trgdoc=$1;
	    $trgdoc=~s/\/\.\//\//g;
	    if (not exists $$trgPos{$trgdoc}){
		if (exists $$trgPos{$trgdoc.'.gz'}){
		    $trgdoc .= '.gz';
		}
	    }
	}

	if (/(sentLink|link)\s.*xtargets=\"([^\"]+)\s*\;\s*([^\"]+)\"/){
	    my $src=$2;
	    my $trg=$3;
	    my @srcsent=split(/\s/,$src);
	    my @trgsent=split(/\s/,$trg);

	    if (not (@srcsent and @trgsent)){next;}
	    next if (not defined $$srcPos{$srcdoc});
	    next if (not defined $$srcPos{$srcdoc}{$srcsent[0]});
	    next if (not defined $$srcPos{$srcdoc}{$srcsent[-1]});

	    next if (not defined $$trgPos{$trgdoc});
	    next if (not defined $$trgPos{$trgdoc}{$trgsent[0]});
	    next if (not defined $$trgPos{$trgdoc}{$trgsent[-1]});

	    #------------------------------------------
	    # print alignment file (src --> trg)

	    if ($lastsrc<$$srcPos{$srcdoc}{$srcsent[0]}[0]){
		print ALG1 $$srcPos{$srcdoc}{$srcsent[0]}[0],"\t";
		print ALG1 $$srcPos{$srcdoc}{$srcsent[-1]}[1],"\t";
		print ALG1 $$trgPos{$trgdoc}{$trgsent[0]}[0],"\t";
		print ALG1 $$trgPos{$trgdoc}{$trgsent[-1]}[1],"\t";
		print ALG1 scalar @srcsent;
		print ALG1 ':';
		print ALG1 scalar @trgsent;
		print ALG1 "\n";
		$lastsrc=$$srcPos{$srcdoc}{$srcsent[-1]}[1];
	    }
	    
	    #------------------------------------------
	    # print alignment file (trg --> src)

	    if ($lasttrg<$$trgPos{$trgdoc}{$trgsent[0]}[0]){
		print ALG2 $$trgPos{$trgdoc}{$trgsent[0]}[0],"\t";
		print ALG2 $$trgPos{$trgdoc}{$trgsent[-1]}[1],"\t";
		print ALG2 $$srcPos{$srcdoc}{$srcsent[0]}[0],"\t";
		print ALG2 $$srcPos{$srcdoc}{$srcsent[-1]}[1],"\t";
		print ALG2 scalar @trgsent;
		print ALG2 ':';
		print ALG2 scalar @srcsent;
		print ALG2 "\n";
		$lasttrg=$$trgPos{$trgdoc}{$trgsent[-1]}[1];
	    }
	}
    }
    close F;
}





sub ReadPosFile{
    my $file=shift;
    my $pos=shift;
    open F,"<$file";
    my $f;
    while(<F>){
	chomp;
	if (/^\#\s+(\S+)\s*$/){
	    $f=$1;
	    next;
	}
	my ($id,$start,$end)=split(/\t/,$_);
	$$pos{$f}{$id}[0]=$start;
	$$pos{$f}{$id}[1]=$end;
    }
    close F;
}














sub MakeCWBindex{
    my ($lang,$cwbtok,$attr)=@_;

    #----------------------------------------------------------
    # cwb-encode arguments (PATTR and SATTR) are stored in $L.cmd
    # (take only one of them to encode the entire corpus)

    my $datdir = "$CWBDATA/$CORPUS";
    my $regdir = "$CWBREG/$CORPUS";

    if (-d "$datdir/$lang"){
	if ($OVERWRITE){
	    my $ok = $ASSUME_YES;
	    if (! $ASSUME_YES){
		print "$datdir/$lang exists! Overwrite [y|N]\n";
		my $answer = <STDIN>;
		if ($answer=~/^y/){
		    $ok = 1;
		}
	    }
	    if ($ok){
		system ("rm -fr $datdir/$lang");  # this looks scary!!!!!!!!!
	    }
	    else{
		unlink $lang;
		return 0;
	    }
	}
	else{
	    warn "$datdir/$lang exists! (do not overwrite!)\n";
	    unlink $lang;
	    return 0;
	}
    }

    ## save the ALIGNED lines!
    my @extra=();
    if (-e "$regdir/$lang"){
	@extra = `grep 'ALIGNED' $regdir/$lang`;
    }
    mkdir "$datdir/$lang",0755;
    system ("$ENCODE -R $regdir/$lang -d $datdir/$lang -f $cwbtok $attr");
    system ("$CWBMAKEALL -r $regdir -V $lang");

    ## ... and add them to the new registry file
    if (@extra){
	open REG,">>$regdir/$lang";
	foreach (@extra){
	    print REG $_;
	}
	close REG;
    }
}


sub FindDocuments{
    my $dir=shift;
    my $ext=shift;
    my $mindepth=shift;
    my $depth=shift;
    my @docs=();
    if (opendir(DIR, $dir)){
	my @files = grep { /^[^\.]/ } readdir(DIR);
	closedir DIR;
	foreach my $f (@files){
	    if (-f "$dir/$f" && $f=~/\.$ext(.gz)?$/){
		if ((not defined($mindepth)) ||
		    ($depth>=$mindepth)){
		    push (@docs,"$dir/$f");
		}
	    }
	    if (-d "$dir/$f"){
		$depth++;
		push (@docs,FindDocuments("$dir/$f",$ext,$mindepth,$depth));
	    }
	}
    }
    return @docs;
}





#----------------------------------------------------------------------
#----------------------------------------------------------------------
# XML2CWB
#
# convert XML files to CWB index files
#----------------------------------------------------------------------
#----------------------------------------------------------------------

sub GetLangEncoding{
    my $lang = shift;
    return $LANGCODES{$lang} if (exists $LANGCODES{$lang});
    return 'iso-8859-1';
}



sub XML2CWB{

    my ($file,$cwbtok,$cwbpos,$lang)=@_;
    $lang=~tr/A-Z/a-z/;

    #----------------------------------------------------------
    # convert corpus files to CWB input format!

    my $allattr=1;
    my $spattern=undef;
    my $ppattern=undef;

    open OUT,">>$cwbtok";
    open POS,">>$cwbpos";

    my $encoding = GetLangEncoding($lang);
    eval { binmode (OUT,':encoding('.$encoding.')'); };

    print POS "# $file\n";

    if (not -e $file){return;}

    eval { print OUT "<file name=\"$file\">\n"; 
	   $SATTR{file} = { name => $file };
	   if ($CORPUS eq 'subtitles'){
	       $file=~/(\A|\/)([0-9]+)\_([0-9]+)\_([0-9]+)\_(.*)\.xml/;
	       print OUT "<sub id=\"$3\" movie=\"$5\" movieID=\"$2\">\n";
	       $SATTR{sub} = { id => $3,
			       movie => $5,
			       movieID => $2 };
	   }
       };

    my $zipped = 0;
    if ($file=~/\.gz$/){
	$zipped=1;
	#--------------------
	# dirty hack to get one of the german OO-files to work:
	# /replace &nbsp; with ' ' to make the xml-parser happy
	# another hack: use recode to make sure that perl and XML::Parser
	# can parse the encoding (otherwise I sometimes get 
        #    'panic: sv_setpvn called with negative strlen. ...'
	#--------------------
	system ("gzip -cd $file | sed 's/\&nbsp/ /g;' | recode -f utf8..$encoding | recode -f $encoding..utf8 > $TMPDIR/xml2cwb");
	$file="$TMPDIR/xml2cwb";
    }

    if ($AllAttributes){
	my $parser1=
	    new XML::Parser(Handlers => {Start => \&XmlAttrStart});
	
	eval { $parser1->parsefile($file); };
	if ($@){warn "$@";}
	@PATTR=sort keys %WordAttr;
    }

    my $parser2=
	new XML::Parser(Handlers => {Start => \&XmlStart,
				     End => \&XmlEnd,
				     Default => \&XmlChar,
				 },);

    eval { $parser2->parsefile($file); };
    if ($@){warn "$@";}

    unlink $file if $zipped;

    foreach my $s (keys %SATTR){              # save structural attributes
	%{$AllSATTR{$s}}=%{$SATTR{$s}};       # in global attribute hash
    }
    if (@PATTR>@AllPATTR){                    # save positional attributes
	@AllPATTR=@PATTR;                     # in global attribute array
    }
    close POS;
    eval { print OUT '</sub>'."\n" if ($CORPUS eq 'subtitles'); };
    eval { print OUT '</file>'."\n"; };
    eval { close OUT; };
}













#-------------------------------------------------------------------
# print cwb-encode arguments for structural & positional attributes

sub AttrString{
    my $attr="-xsB";
    foreach my $s (keys %AllSATTR){
	$attr.=" -S $s:0";
	my $a=join "+",keys %{$AllSATTR{$s}};
	if ($a){$attr.='+'.$a;}
    }
    foreach (@AllPATTR){
	$attr.=" -P $_";
    }
    return $attr;
}




#-------------------------------------------------------------------
# XML parser handles (parser 2)


sub XmlStart{
    my $p=shift;
    my $e=shift;

    if ($e eq $SentTag){
	if ($SentStart){             # there is already an open sentence!
	    printXmlEndTag($e,@_);   # --> close the old one first!!
	    print POS $pos-1,"\n";
	}
	$SentStart=1;
	printXmlStartTag($e,@_);
	my %attr=@_;
	print POS "$attr{id}\t$pos\t";
    }
    elsif ($e eq $WordTag){
	$WordStart=1;
	$XmlStr='';
	%WordAttr=@_;
    }
    elsif ($CORPUS eq 'subtitles' && $e eq 'time'){
	if ($p->{OPENTIME}){
	    printXmlEndTag($e,@_);
	    $p->{OPENTIME} = 0;
	}
	else{
	    printXmlStartTag($e,@_);
	    $p->{OPENTIME} = 1;
	}
    }
    elsif (defined $SATTR{$e}){
	$nrSATTR{$e}++;                             # don't allow recursive
	if ($nrSATTR{$e}==1){printXmlStartTag($e,@_);}  # structures!!!!!!
    }
}

sub XmlEnd{
    my $p=shift;
    my $e=shift;
    if ($e eq $SentTag){
	if ($SentStart){
	    $SentStart=0;
	    printXmlEndTag($e,@_);
	    print POS $pos-1,"\n";
	}
    }
    elsif ($e eq $WordTag){
	$WordStart=0;
	printWord($XmlStr,\%WordAttr);
	$pos++;
    }
    elsif ($CORPUS eq 'subtitles' && $e eq 'time'){
	return 1;
    }
    elsif (defined $SATTR{$e}){
	if ($nrSATTR{$e}==1){printXmlEndTag($e,@_);}
	$nrSATTR{$e}--;
    }
}

sub XmlChar{
    my $p=shift;
    my $e=shift;
    if ($WordStart){
	$XmlStr.=$p->recognized_string;
    }
}

#-------------------------------------------------------------------
# XML parser handles (parser 1)

sub XmlAttrStart{
    my $p=shift;
    my $e=shift;
    if ($e eq $WordTag){
	if (defined $WordAttrPattern){
	    if ($e!~/^$WordAttrPattern$/){return;}
	}
	$WordStart=1;
	while (@_){$WordAttr{$_[0]}=$_[1];shift;shift;}
    }
    else{
	if (defined $StrucAttrPattern){
	    if ($e!~/^$StrucAttrPattern$/){return;}
	    }
	while (@_){$SATTR{$e}{$_[0]}=$_[1];shift;shift;}
    }
}





sub printWord{
    my $word=shift;
    my $attr=shift;
    $word=~tr/\n/ /;
    $word=~s/^\s+(\S)/$1/s;
    $word=~s/(\S)\s+$/$1/s;
    eval { print OUT $word; };
    foreach (@PATTR){
	if (defined $attr->{$_}){
	    eval { print OUT "\t$attr->{$_}"; };
	}
	else{
	    eval { print OUT "\tunknown"; };
	}
    }
    eval { print OUT "\n"; };
}

sub printXmlStartTag{
    my $tag=shift;
    my %attr=@_;
    eval { print OUT "<$tag"; };
    foreach (keys %attr){
	if (defined $SATTR{$tag}{$_}){
	    eval { print OUT " $_=\"$attr{$_}\""; };
	}
    }
    eval { print OUT ">\n"; };
}

sub printXmlEndTag{
    my $tag=shift;
    my %attr=@_;
    eval { print OUT "</$tag>\n"; };
}

#---------------------------------------------------------------------
#---------------------------------------------------------------------
