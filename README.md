tvstir.pl
=========

Organize your TV shows into the correct directory structure

Perl script to move tv series into organized directories
At present the only output format is 

{TV show}->{Season 1}
Lets say you have a file called Burn.Notice.S01E03 in /tmp/
running 

`tvstir.pl --directory /tmp --write --lucky`


this would create a folder stucture "Burn Notice/Season 1/" in 
the current working directory and move the file into this dir

The only naming conventions currently supported are

Burn.Notice.S01E02.tags.mp4

Burn.Notice.102.tags.mp4

TODO

Add a preference file for TVSHOW's for unatended stirs

Add more file naming convention formats 
