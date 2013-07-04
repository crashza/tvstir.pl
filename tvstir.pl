#!/usr/bin/perl

#
# tvstir.pl simple script to move TV Shows
# into formatted directories as below
# ----TV Show->Season X
#
# Copyright 2013 Trevor Steyn
# This program is distributed under the terms of the GNU General Public License
#

use warnings;
use strict;

use Cwd;
use File::Copy;         # Used to copy files
use LWP::Simple;        # Used for TVDB http get
use XML::Simple;        # Used to parse XML reply from TVDB
use Text::Table;        # Used to format output
use Data::Dumper;       # Debugging only
use Getopt::Long;       # Used for CLI args
use Config::Simple;     # Used for reading config file
use Term::ANSIColor;    # Fancy colours

GetOptions(
    'help|?!'        => \my $help,
    'version'        => \my $showversion,
    'lucky'          => \my $lucky,
    'write'          => \my $write,
    'copy|c'         => \my $copy,
    'noseason|n'     => \my $noseason,
    'directory=s'    => \my $directory,
    'output=s'       => \my $output,
    'preference|p=s' => \my $preference,
);

# Set Version

my $version = 'v0.11';

# Help Menu

if ($help) {
    print "TV Series Organizer $version\n";
    print "Release 28 June 2013\n";
    print "tvstir.pl  - Move TV Shows into formatted directories\n";
    print "\n";
    print "Usage: tvstir.pl [OPTIONS]\n";
    print "\n";
    print "Options:\n";
    print "  --help 		| -h		Print this help menu\n";
    print "  --version		| -v		Print the current version\n";
    print "  --lucky		| -l		Use first hit on the TVDB\n";
    print
"  --write		| -w		Actually move files (Default is to print changes only)\n";
    print "  --copy		| -c		Dont Move files rather copy files needs --write\n";
    print
"  --directory <path>	| -d		Directory to check for TV shows (Default is pwd)\n\n";
    print "Output options:\n";
    print "  --output <path>	| -o		Directory to write changes default is pwd\n";
    print "  --noseason 		| -n		Dont create a season folder\n\n";
    print "Other options:\n";
    print "  --preference <file>	| -p		Preference file\n\n";
    exit;
}

# if copy is specified make sure --write is aswell

if ( $copy and !$write ) {
    print "Please specify --write when using --copy\n";
    exit;
}

# Show Version and exit

if ($showversion) {
    print "tvstir.pl $version\n";
    exit;
}

# Lets set the directory that we need to work on

if ( !$directory ) { $directory = getcwd }

# Lets Read Config file if specified

my $config;
if ($preference) {
    $config = new Config::Simple($preference);
}

# Slurp up the files in the directory

my @files;

opendir( DIR, $directory ) or die $!;

while ( my $file = readdir(DIR) ) {

    if ( $file !~ /^\./ ) {
        next unless ( -f "$directory/$file" );
        push( @files, $file )

    }
}

# Try find matching TV show and season

my $season;
my $tvshow;
my %matched;
my %unmatched;
my %tvseason;
foreach my $filename (@files) {
    $season = getseason($filename);
    $tvshow = getseries($filename);
    if ( $tvshow eq 'No Matching TV Show' ) {
        $unmatched{$filename} = 'No Matching TV Show';
    }
    else {
        $matched{$filename}  = $tvshow;
        $tvseason{$filename} = $season;

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
print "=" x 78, "\n";
print "Matched Shows:\n";
print "=" x 78, "\n";
print $matchtb;
print "\n";
print "=" x 78, "\n";
print "Unmatched Shows:\n";
print "=" x 78, "\n";
print $unmatchtb;
print "\n";

# Set output dir

if ( !$output ) { $output = getcwd }

# If --write is passed create the directory structure and move files

if ($write) {
    foreach my $key ( keys %matched ) {
        if ( !-d "$output/$matched{$key}" ) {
            mkdir "$output/$matched{$key}", 0777;
        }
        if ( !$noseason ) {
            if ( !-d "$output/$matched{$key}/Season $tvseason{$key}" ) {
                mkdir "$output/$matched{$key}//Season $tvseason{$key}", 0777;
            }
            if ($copy) {
                my $outputfile =
                  "$output/$matched{$key}/Season $tvseason{$key}/$key";
                my $inputfile = "$directory/$key";
                print color("yellow"),
                  "File $key copy in progress standby....\n", color("reset");
                copy( $inputfile, $outputfile ) or die "File cannot be copied.";
            }
            else {
                rename "$directory/$key",
                  "$output/$matched{$key}/Season $tvseason{$key}/$key";
            }
        }
        else {
            if ($copy) {
                my $outputfile =
                  "$output/$matched{$key}/Season $tvseason{$key}/$key";
                my $inputfile = "$directory/$key";
                print color("yellow"),
                  "File $key copy in progress standby....\n", color("reset");
                copy( "$directory/$key", "$output/$matched{$key}/$key" )
                  or die "File cannot be
                copied.";

            }
            else {
                rename "$directory/$key", "$output/$matched{$key}/$key";
            }
        }
    }
}
else {
    print color("red"), "Use --write to write changes\n\n", color("reset");
}

# Subroutines

sub getseries {
    my $name = $_[0];

    # Check if conf file exists
    my $showfound;

    if ($config) {
        my %tvshows_config = %{ $config->{_DATA} };
        foreach my $tvshows_preference ( keys %tvshows_config ) {
            my @regexp_preference =
              @{ $config->{_DATA}->{$tvshows_preference}{'regexp'} };
            foreach my $expression (@regexp_preference) {
                if ( $name =~ m/$expression/ ) {
                    $name      = $tvshows_preference;
                    $showfound = 1;
                }
            }
        }
    }
    if ( !$showfound ) {
        if ( $name =~ m/^.*[Ss]\d*[Ee]\d.*$/ ) {   #File Format $name.S02E12.mkv
            $name =~ s/\.[Ss]\d*[Ee]\d.*$//;
            $name =~ s/\./ /g;
        }
        elsif ( $name =~ m/^.*\d\d.*$/ ) {
            $name =~ s/\.\d\d\d.*$//; #We can assume Dubios naming $name.212.mkv
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

                    print color("yellow"),
                      "\nMore than one TV show found for $_[0]\n\n",
                      color("reset");
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
                        print color("red"),
                          "Incorrect selection please re-enter:",
                          color("reset");
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
    }
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
