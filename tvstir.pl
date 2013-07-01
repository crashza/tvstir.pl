#!/usr/bin/perl

#
# tvstir.pl simple script to move TV Shows
# into formatted directories as below
# ----TV Show->Season X
# Burn.Notice.S07E04.HDTV.x264-KILLERS.mp4
#

use warnings;
use strict;
use Getopt::Long;    # Used for CLI args
use Cwd;
use Data::Dumper;    # debugging only
use LWP::Simple;
use XML::Simple;
use Text::Table;

GetOptions(
    'help|?!'     => \my $help,
    'version'     => \my $showversion,
    'lucky'       => \my $lucky,
    'write'       => \my $write,
    'directory=s' => \my $directory,
    'output=s'    => \my $output
);

my $version = 'v0.1';

if ($help) {
    print "TV Series Organizer $version\n";
    print "Release 28 June 2013\n";
    print "tvstir.pl  - Move TV Shows into formatted directories\n";
    print "\n";
    print "Usage: tvstir.pl [OPTIONS]\n";
    print "\n";
    print "Input options:\n";
    print "  --help 	| -h		Print this help menu\n";
    print
"  --write	| -w		Actually move files (Default is to print changes only)\n";
    print
      "  --directory	| -w		Directory to check for TV shows (Default is pwd)\n";
    print "  --output	| -o		Directory to write changes default is pwd\n";
    print "  --version			Print the current version\n";
    print "  --lucky			Use first hit on the TVDB\n\n";
    exit;
}

if ($showversion) {
    print "tvstir.pl $version\n";
    exit;
}

#Lets set the directory that we need to work on

if ( !$directory ) { $directory = getcwd }

#Slurp up the files in the directory

my @files;

opendir( DIR, $directory ) or die $!;

while ( my $file = readdir(DIR) ) {

    if ( $file !~ /^\./ ) {
        next unless ( -f "$directory/$file" );
        push( @files, $file )

    }
}

my $season;
my $tvshow;
my %matched;
my %unmatched;
my %tvseason;
foreach (@files) {
    $season = getseason($_);
    $tvshow = getseries($_);
    if ( $tvshow eq 'No Matching TV Show' ) {
        $unmatched{$_} = 'No Matching TV Show';
    }
    else {
        $matched{$_}  = $tvshow;
        $tvseason{$_} = $season;

        #print "$_ has been detected as TV Show:\t\t$tvshow\n"
    }
}

# Lets Print the Results
print "\n";
my $matchtb =
  Text::Table->new( "File\n----", "TV Show\n-- ----", "Season\n------" );
my $unmatchtb = Text::Table->new( "File\n----", "Reason\n------", );

foreach my $key ( keys %matched ) {
    $matchtb->load(
        [ "$key    ", "$matched{$key}    ", "$tvseason{$key}    " ] );
}

foreach my $key ( keys %unmatched ) {
    $unmatchtb->load( [ "$key    ", "$unmatched{$key}" ] );
}
print "=" x 60, "\n";
print "Matched Shows:\n";
print "=" x 60, "\n";
print $matchtb;
print "\n";
print "=" x 60, "\n";
print "Unmatched Shows:\n";
print "=" x 60, "\n";
print $unmatchtb;
print "\n";

# Set output dir

if ( !$output ) { $output = getcwd }

if ($write) {
    foreach my $key ( keys %matched ) {
        if ( !-d "$output/$matched{$key}" ) {
            mkdir "$output/$matched{$key}", 0777;
        }
        if ( !-d "$output/$matched{$key}/Season $tvseason{$key}" ) {
            mkdir "$output/$matched{$key}//Season $tvseason{$key}", 0777;
        }
        rename "$directory/$key",
          "$output/$matched{$key}/Season $tvseason{$key}/$key";
    }
}
else {
    print "Use --write to write changes\n\n";
}

sub getseries {
    my $name = $_[0];
    if ( $name =~ m/^.*[Ss]\d*[Ee]\d.*$/ ) {    #File Format $name.S02E12.mkv
        $name =~ s/\.[Ss]\d*[Ee]\d.*$//;
        $name =~ s/\./ /g;
    }
    elsif ( $name =~ m/^.*\d\d.*$/ ) {
        $name =~ s/\.\d\d\d.*$//;    #We can assume Dubios naming $name.212.mkv
        $name =~ s/\./ /g;
    }
    else {
        $name = 'Error';
    }
    if ( $name ne 'Dubios' and $name ne 'Error' ) {
        my $xml = XML::Simple->new( ForceArray => 1, KeepRoot => 1 );
        my $content =
          get("http://thetvdb.com/api/GetSeries.php?seriesname=$name");
        die "Couldn't get it!" unless defined $content;
        my $inxml = $xml->XMLin($content);
        my $show  = $inxml->{Data}->[0]->{Series};
        if ( !$show ) {
            $name = 'No Matching TV Show';
        }
        else {
            my $elements = scalar @{$show};

            if ( $elements gt '1' and !$lucky ) {

                print "\nMore than one TV show found for $_[0]\n\n";
                my $count = 0;
                foreach ( @{$show} ) {
                    print "$count: \t$_->{SeriesName}->[0]\n";
                    $count = $count + 1;
                }
                print "\n";
                print "Enter selection:";
                my $id = <>;
                chomp($id);
                my $options     = $elements - 1;
                my $validselect = 0;
                if ( $id le $options and $id ge 0 ) { $validselect = 1 }

                while ( $validselect != 1 ) {
                    print "Incorrect selection please re-enter:";
                    $id = <>;
                    chomp($id);
                    if ( $id le $options and $id ge 0 ) { $validselect = 1 }
                }
                print "\n";
                $name = $show->[$id]->{SeriesName}->[0];
            }
            else {
                $name = $show->[0]->{SeriesName}->[0];
            }
        }
    }
    else { $name = 'No Matching TV Show' }
    return $name;
}

sub getseason {
    my $season = $_[0];
    if ( $season =~ m/^.*[Ss]\d*[Ee]\d.*$/ ) {
        $season =~ m/([Ss]\d*[Ee]\d*)/;
        $season = $1;
        $season =~ s/[Ss]//;
        $season =~ s/[Ee]\d*//;
        $season =~ s/^0//;
    }
    elsif ( $season =~ m/^.*\.\d\d\d*\..*m..$/ ) {
        $season =~ m/(\d\d*)/;
        $season = $1;
        $season =~ s/\d\d$//;
    }
    else { $season = 'ERROR'; }

    return $season;
}

#fin
