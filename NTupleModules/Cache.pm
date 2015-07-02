=head1 NAME

    NTupleModules::PreProcessing

=head1 SYNOPSIS

    USE CASE : DO SOMETHING IF QUERY EXISTS IN CACHE

    my $filepath = getFileFromCache($query, $n, $stemmatise);

    if (!(defined $filepath)){
        # DO SOMETHING
    }

=head1 DESCRIPTION
    Subroutines for manipulating a cache, in the form of a tab-separated file. The first column corresponds to the query entried (composed of the string query, the n (ex: 1 for unigrams, 2 for bigrams etc.), the boolean stemmatise (0 or 1) separated by '+'). The second column is the absolute path to the file. The absolute path helps the comparison of files when checking if two files are identical.

=head1 AUTHOR - Rachel Bawden

    Rachel Bawden rachel.bawden@keble.oxon.org

=head1 APPENDIX

    subroutines:
    getFileFromCache
    getCache
    addToCache
    dumpCache

=cut
package NTupleModules::Cache;
use strict;
use warnings;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
$VERSION     = 0.02;
@ISA         = qw(Exporter);
@EXPORT      = ();
@EXPORT_OK   = qw(getFileFromCache getCache addToCache dumpCache);  
%EXPORT_TAGS = ( DEFAULT => [qw(&getFileFromCache &getCache &addToCache &dumpCache)],               
                 Both   => [qw(&getFileFromCache &getCache &addToCache &dumpCache)]);

=head2 getFileFromCache

  Title    : Get file from cache
  Usage    : $filepath = getFileFromCache($query, $n, $stemmatise);
  Function : Retrieve a filepath from the cache corresponding to the options specified.
  Returns  : The filepath if it exists or undef
  Args     : positional arguments:
           : - 0 (query) => string (e.g. "chocolate muffins"
           : - 1 (n) => number
           : - 2 (stemmatise) => boolean (1 or 0)
           : - 3 (corpus size) => number
           : - 4 (lang) => en, fr or en/fr
           : - 5 (noPunctuation) => boolean (1 or 0)
=cut
sub getFileFromCache{
    my $query = lc $_[0];
    my $n = $_[1];
    my $stemmatise = $_[2];
    my $corpusSize = defined $_[3] ? $_[3] : 0; # to avoid warnings line 65
    my $lang = $_[4] = defined $_[4] ? $_[4] : 0; # to avoid warnings line 65
    my $noPunctuation = defined $_[5] ? $_[5] : 0; # to avoid warnings line 65

    my $querykey = "$query+$n+$stemmatise+$corpusSize+$lang+$noPunctuation";

    if (-e "_cache"){
        open(FLUX, "_cache") or die "cannot open < _cache: $!";
        while( my $line = <FLUX>){
            my @key_filepath = split('\t', $line);
            chomp $key_filepath[1];
            if ($key_filepath[0] eq $querykey){
                # check to see if file actually exists
                if (-f $key_filepath[1]){
                    return $key_filepath[1];
                }
            }
        }
        close FLUX;
    }
    else{
        open(FLUX, ">_cache") or die "cannot open > _cache: $!"; 
        close FLUX;
    }
    return undef; # return undef by default
}


=head2 getCache

  Title    : Get cache
  Usage    : my $ref_cache =getCache();
  Function : retrieve a hash containing the cache
  Returns  : A reference to a hash with querykey => filepath
=cut
sub getCache{
    my %cache;
    if (-e "_cache"){
        open(FLUX, "<:encoding(UTF-8)", "_cache") or die "cannot open < _cache: $!";
        while( my $line = <FLUX>){
            my @key_filepath = split('\t', $line);
            chomp $key_filepath[1];
            $cache{$key_filepath[0]} = $key_filepath[1];
        }
        close FLUX;
    }
    return \%cache;
}

=head2 addToCache

  Title    : Add to cache
  Usage    : $ref_cache = addToCache($ref_cache, "$query+$n+$stemmatise", $outfile); 
  Function : Add a querykey and filepath to the cache and return the new hash
  Returns  : A reference to the updated hash with querykey => filepath
  Args     : positional arguments:
           : - 0 (ref_cache) => reference to hash
           : - 1 (key_file) => string (key containing the query, the n, stemmatise (bool)
           : - 2 (file_added) => string (filepath)
=cut
sub addToCache{
    my $ref_cache = $_[0];
    my $key_file = $_[1];
    my $file_added = $_[2];

    my %new_cache;
    # cache only contains absolute paths to help comparison of files later on
    my $abs_fileadded =  File::Spec->rel2abs($file_added);

    while (my ($key, $filepath) = each %$ref_cache){
        # replace existing filepaths if querykey already present
        if (!($abs_fileadded eq $filepath)){ 
            $new_cache{$key} = $filepath;
        }
    }
    # add new query and filepath
    $new_cache{$key_file} = $abs_fileadded;

    return \%new_cache;
}


=head2 dumpCache

  Title    : Dump cache
  Usage    : dumpCache($ref_cache);
  Function : Write cache (hash) to file
  Returns  : Nothing
  Args     : positional arguments:
           : - 0 (ref_cache) => reference to hash
=cut
sub dumpCache{
    my $ref_cache = $_[0];
    open(FLUX, ">_cache") or die "cannot open > _cache: $!";
    while (my ($key, $filepath) = each %$ref_cache){
        # clean up at the same time (only if files exist)
        if (-f $filepath){
            print FLUX "$key\t$filepath\n";
        }
    }
    close FLUX;
}


1;
