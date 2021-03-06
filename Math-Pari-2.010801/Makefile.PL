# $Id: Makefile.PL,v 1.1 1995/01/23 04:46:12 ilya Exp $
use ExtUtils::MakeMaker;
use Config '%Config';

BEGIN {unshift @INC, 'utils'}
use Math::PariBuild;

# Uncomment and change this line if I fail to find it
# $paridir = "..";

unless (-t STDOUT) {		# Better reports if run with redirections
    my $odef = select STDERR;
    $| = 1;
    select STDOUT;
    $| = 1;
    select $odef;
}


grep {/^machine=(.*)$/i		 and $common::machine = $1}  @ARGV;
grep {/^configure$/i		 and $common::do_configure = 1}	     @ARGV;
grep {/^paridir=(.*?)[\/\\]?$/i	 and $paridir = $1}	     @ARGV;
grep {/^pari_tgz=(.*?)[\/\\]?$/i	 and $parisrc = $1}	     @ARGV;
grep {/^force_download$/i	 and $force_download = 1}    @ARGV;
grep {/^parilib=(.*)$/i		 and $common::parilib = $1}  @ARGV;

@ARGV = grep !/^((machine|paridir|pari_tgz|parilib)=.*|configure|force_download)$/i, @ARGV;

$paridir   = find_pari_dir() unless defined $paridir or $parisrc or $force_download;
($paridir) = download_and_patch_pari($parisrc, $force_download)
  if !$paridir or $force_download;

die <<EOD  unless $paridir;
Could not find GP/PARI build directory, please run Makefile.PL
with paridir=/directory option.
EOD

my $gcc_version
  = defined($Config{gccversion}) ? ", gccversion=$Config{gccversion}" : "";
print <<EOP;
Setting up Math::Pari with Perl $] on $^O version $Config{osvers};
   cc=$Config{cc}$gcc_version, ccflags='$Config{ccflags}',
   ld=$Config{ld}, ldflags='$Config{ldflags}', optimize='$Config{optimize}'.
EOP

if ($common::parilib) {
  $pari_version = '2001004';	# XXXX How to get a correct one?
  $define = '-DNO_HIGHLEVEL_PARI';
  print <<EOP;
Trying to use existing PARI library (at $common::parilib)
     (fake integer-formatted version $pari_version).
EOP
} else {
  $define = '';
  $pari_version = pari_formatted_version($paridir);
  print <<EOP;
Found GP/PARI build directory in $paridir
     (integer-formatted version $pari_version).
EOP
  print <<EOP if $pari_version =~ /^2003/;

  ### Math::Pari support of GP/PARI library version 2.3.* should be
  ###   considered cursory only.  One may need to downgrade to 2.1.7,
  ###   or run Makefile.PL with option machine=none if the tests fail.

  ### For example, the test t/55_intnum.t takes a very long time to complete,
  ###   and plotting functions are not supported.

EOP
  $common::pari_version = $pari_version;
  $common::main_paridir = $paridir;
  *MY::postamble = \&xMY::postamble;
}

$os = $Config{osname};

$define .= " -DPARI_VERSION_EXP=$pari_version -DDEBUG_PARI";
$define .= " -DUSE_SLOW_ARRAY_ACCESS -DUSE_SLOW_NARGS_ACCESS" if $] >= 5.009;
$libs = "-lm";
$libs .= " $common::parilib" if $common::parilib;
$noexp2 = '';			# Should be used for generation of paricfg.h

if ($os eq "solaris") {
  # Some older versions needed -lsunmath to import exp2().  This is
  # probably not needed anymore (though can speed things up).

  # Below -R specifies the path to search for this file when the
  # program will run, -L the path to search when the program is linked
#  @sc_dirs = '/opt/SUNWspro/lib' if -d '/opt/SUNWspro/lib';
#  @sc_dirs = </opt/SUNWspro/SC*/lib> unless @sc_dirs;
#  if (@sc_dirs) {
#    $libs .= " -R$sc_dirs[-1] -L$sc_dirs[-1] -lsunmath -lm";
#  } else {
#    #warn "Cannot find SUNWspro dirs, needed for -lsunmath, using NOEXP2.\n";
    $noexp2 = 1;
#  }
} elsif ($os eq "os2") {
  $noexp2 = 1;
  $define .= " -DMALLOC_PROCS";
} elsif ($os eq 'linux') {
  $noexp2 = 1;
}

my %opts;
unless ($common::parilib) {
  build_tests $paridir;		# Convert the test suite
  make_pod 'libPARI.pod', '-to_pod', $paridir; # Now the docs
  make_pod 'libPARI.dumb.pod', '-to_dumb_pod', $paridir;
  # ... and paricfg.h
  %opts = build_paricfg($paridir, $common::do_configure, $pari_version);

  if ($ENV{MATH_PARI_REPORT_CODES}) {
    # Check the correspondence between string interfaces and numeric interfaces
    my %codes;
    my %names;
    ep_in_version($pari_version);
    ep_codes_from_file("$paridir/src/language/init.c", %codes, %names);
    ep_codes_from_file("$paridir/src/gp/highlvl.c", %codes, %names);
    # EpValence reworked in 2.2.7; when exactly was it redone???  XXXX
    unless ($pari_version > 2002006 or ep_hash_report(%codes)) {
      print STDERR "Problems with numeric interface codes noted:\n";
      ep_hash_report(%codes, %names, \*STDERR);
    }
  }
}

# We want to find the offset of the least significant byte
# of SV.flags inside an SV.
# It is enough to find the offset of the least significant byte inside a U32.
# (Needed for recognizing Perl code supplied to lisseq and lisexpr.)

$offset = index($Config{byteorder}, "1");
$offset = 3 if $offset > 3;	# SvFLAGS is actually I32
$define .= " -DLSB_in_U32=$offset";

my $longsize = length(eval { pack 'l!', 1 } or pack 'l', 1);
my $pari_int_size = $Config{'ivsize'} || $Config{'intsize'}
	or die "Can't deduce PARI int size";

$define .= ' -DLONG_SHORTER_THAN_IV' if $pari_int_size > $longsize;

$define .= ' -Derr=pari_err'; # On linux it can get a wrong dynamic loading
$define .= ' -DHAVE_LADD' if $opts{have_ladd};
$define .= ' -DGCC_INLINE' if $Config{gccversion} and not $Config{optimize} =~ /-g\b/;
$define .= ' -DHAVE_PARIPRIV' if -f "$paridir/src/headers/paripriv.h";
#$define .= ' -DNO_GRAPHICS_PARI' unless -f "$paridir/src/graph/plotgnuplot.c";

# XXXX otherwise segfaults trying to install highlevel functions???
$define .= ' -DNO_HIGHLEVEL_PARI' if $pari_version >= 2003000;

my $extra_inc = extra_includes($paridir);

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile being created.
&WriteMakefile(
	       LIBS	     =>  $libs,
	       INC	     => $extra_inc . ' -I$(PARI_DIR)/src/headers -I$(PARI_DIR)/src -I./libPARI',
	       NAME	     => 'Math::Pari',
	       ($common::parilib ? () :
		 (MYEXTLIB   =>  'libPARI/libPARI$(LIB_EXT)')),
	       VERSION_FROM  => 'Pari.pm',
	       DEFINE	     => $define,
	       dist	     => {COMPRESS=>'gzip -9f', SUFFIX=>'gz'},
	       clean	     => { FILES => 'pari.ps test_eng/ex.t- libPARI.dumb.pod libPARI.pod t/55_*.t' },
	       macro	     => {
				 PARI_DIR	  => $paridir,
				},
	      );


# Remake POD if the source changed.
# Go to a subdirectory to build the headers and the library.
# XXX With -j4 goes twice to a subdir in parallel, both times without -j4...
sub xMY::postamble {
  '
AUTOGEN_HEADERS = libPARI/pariinl.h

Pari$(OBJ_EXT) : $(AUTOGEN_HEADERS)

$(AUTOGEN_HEADERS): $(MYEXTLIB)

$(MYEXTLIB): libPARI/Makefile FORCE
	cd libPARI && $(MAKE) $(PASTHRU)

libPARI.pod: $(PARI_DIR)/doc/usersch3.tex libPARI/gphelp
	$(PERL) libPARI/gphelp -to_pod $(PARI_DIR)/doc/usersch3.tex > pod_tmp && mv pod_tmp $@

libPARI.dumb.pod: $(PARI_DIR)/doc/usersch3.tex libPARI/gphelp
	$(PERL) libPARI/gphelp -to_dumb_pod $(PARI_DIR)/doc/usersch3.tex > pod_tmp && mv pod_tmp $@

build_tests:
	-$(RM_F) test_eng/ex.t-
	$(FULLPERL) -Iutils -MMath::PariBuild -e "build_tests shift" $(PARI_DIR)

';
}

# Rewrite pic option to PIC in CCCDLFLAGS,
# Some voodoo with LD* with PERL_OBJECT (why not in makemaker?)
sub MY::const_config
{
 my $self = shift;
 my $flags = $self->{'CCCDLFLAGS'}; # Tmp var needed with Perl4 !
 $flags =~ s/(-[fK]?\s*)pic\b/${1}PIC/; 
 $flags =~ s/-KPIC/-K PIC/;	# Apparently (was?) needed on Solaris...
 $self->{'CCCDLFLAGS'} = $flags;
 if ($^O eq 'MSWin32' && $Config{'ccflags'} =~ /-DPERL_OBJECT/)
  {
   $self->{'LDFLAGS'} =~ s/-(debug|pdb:\w+)\s+//g;
   $self->{'LDDLFLAGS'} =~ s/-(debug|pdb:\w+)\s+//g;
  }
 return $self->MM::const_config;
}
