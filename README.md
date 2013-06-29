tvstir.pl
=========

Perl script to move tv series into organized directories
At present the only output format is {TV show}->{Season 1}
Lets saw you have a file called Burn.Notice.S01E03 in /tmp/
running tvstir.pl --directory /tmp --write --lucky
this would create a folder stucture "Burn Notice/Season 1/" in 
the current working directory and move the file into this dir

Also the only anmeing convections currently supported are

Burn.NoticeS01E02.tags.mp4
Burn.Notice102.tags.mp4

TODO

Add a preference file for TVSHOW's for unnatended stirs
Add more file naming convention formats 
