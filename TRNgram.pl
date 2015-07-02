#!/usr/bin/perl

use strict;
use warnings;

# include our web module in @INC, we need to add the current dir '.' to the include directory:
# FindBin::Bin does this
use FindBin;
use lib "$FindBin::Bin";
use NTupleModules::Web qw(&get_texts_from_search &get_texts_from_url &new);
use NTupleModules::Analyse qw(&AnalyseNgram &dumpAnalysis &loadAnalysisFromFile &printSummary);
use NTupleModules::PreProcessing qw(&Preprocessing &Tokenise);
use NTupleModules::Cache qw(&getFileFromCache &getCache &addToCache &dumpCache);
use Getopt::Long;

#------------------------------------------------------------------------
#  Command line options, arguments and flags
#------------------------------------------------------------------------
my $stemmatise = 0;   # flag
my $n; # required integer value
my $query; # required string value
my $outfile;
my $lang;
my $reload = 0; # force reload (not from cache)
my $boundarytok = 0; # add starttoks et endtoks to sentences
my $corpusSize = 50; # default value of 50 and max value of 64
my $use_paragraphs = 0; # default off
my $verbose = 0; # default off
my $keepPunctuation = 1; # default yes

GetOptions ("query=s" => \$query, 
            "n=i" => \$n, 
            "s" => \$stemmatise,
            "o=s" => \$outfile,
            "lang=s" => \$lang,
            "reload" => \$reload,
            "boundarytok" => \$boundarytok,
            "corpusSize=i" => \$corpusSize,
            "use_paragraphs" => \$use_paragraphs,
            "verbose" => \$verbose,
            "keepPunctuation" => \$keepPunctuation)
or die("Error in command line arguments\n");

# ajouter option = nbr de textes

# check for required arguments
if (!(defined $n)){
    die("\nError : The option -n is obligatory and must have an integer as an argument\n");
}
if (!(defined $query)){
    die("\nError : The option -query is obligatory and must have a string as an argument");
}
if (!(defined $outfile)){
    die("\nError : The option -o is obligatory and you must specify an output file pathname as an argument");
}
if (defined $lang){
    if ($lang ne "en" && $lang ne "fr"){
        die("\nError : The option -lang, if specified, must have one of the following two values: en, fr");
    }
}
if ($corpusSize<1){
    die("\n Error : The corpus size must be greater than 0 texts");
}
elsif ($corpusSize>64){
    print "Warning : You have asked for a greater corpus size than the maximum. Your corpus size is limited to 64 texts";
}
#------------------------------------------------------------------------

# try to reload from cache if user does not wish to force reload
my $filepath;
if ($reload == 0){
    $filepath = getFileFromCache($query, $n, $stemmatise, $corpusSize);
}

my $ref_ngram2count;
# either it does not exist in the cache or the user wishes to reload
if (!(defined $filepath)){

    print "Redownloading and/or does not already exist in cache\n";

    my $web_getter = NTupleModules::Web->new( num_pages => $corpusSize,
                                              language => $lang,
                                              verbose => $verbose,
                                              use_paragraphs=>$use_paragraphs);
    my %lang2texts = $web_getter->get_texts_from_search( search_request =>$query, );

    # si $lang pas spécifié - on prend tous les textes en et fr (on jette les autres)
    # si $lang spécifié, on garde que $lang
    # 50 textes par défaut + warning si >64
    my @arr_arr_toks;
    while (my ($langtext, $ref_texts) = each %lang2texts){

        foreach my $text(@$ref_texts) {
            my $ref_arr_arr_toks = Preprocessing($text, $langtext, $stemmatise, $keepPunctuation);
            @arr_arr_toks = (@arr_arr_toks, @$ref_arr_arr_toks);
            
        }
    }
    $ref_ngram2count = AnalyseNgram($n, \@arr_arr_toks, $outfile, $boundarytok);
}
else{
    print "Reloading from cache\n";
    # load from file
    $ref_ngram2count = loadAnalysisFromFile($filepath);
}

# print ngram count to outfile
dumpAnalysis($ref_ngram2count, $outfile);
printSummary($ref_ngram2count, $outfile);

# add outfile to cache
my $ref_cache =getCache();
$ref_cache = addToCache($ref_cache, "$query+$n+$stemmatise+$corpusSize", $outfile); 
dumpCache($ref_cache);

# with dumpCache I have to press enter after each line ? (Nick)



