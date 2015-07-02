=head1 NAME
    NTupleModules::Analyse

=head1 SYNOPSIS

    USE CASE : PRINT N-GRAM SUMMARY AND PRODUCE TAB-SEPARATED FILE AND BARPLOT

    my $ref_ngram2count = AnalyseNgram($n, \@arr_arr_toks, $outfile)
    dumpAnalysis($ref_ngram2count, $outfile);
    printSummary($ref_ngram2count, $outfile);

=head1 DESCRIPTION

    Perform an n-gram analysis on an array of array of tokens. Return a hash ngram => count and describe the n-gram count by providing the number of unique n-grams, the five most frequent n-grams, the number of hapax and a barplot showing the frequency distribution of the forty most frequent n-grams.

=head1 AUTHOR - Rachel Bawden

    Rachel Bawden rachel.bawden@keble.oxon.org

=head1 APPENDIX

    subroutines:
    AnalyseNgram
    dumpAnalysis
    loadAnalysisFromFile
    printSummary

=cut
package NTupleModules::Analyse;
use Algorithm::NGram;
use DBD::Chart::Plot;
use strict;
use warnings;
use utf8;
binmode STDOUT, ":utf8"; 
#-------------------------------------------------------------
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION     = 0.02;                                    
@ISA         = qw(Exporter);                            
@EXPORT      = ();                                     
@EXPORT_OK   = qw(AnalyseNgram dumpAnalysis loadAnalysisFromFile printSummary);  
%EXPORT_TAGS = ( DEFAULT => [qw(&AnalyseNgram &dumpAnalysis &loadAnalysisFromFile &printSummary)],               
                 Both    => [qw(&AnalyseNgram)]);
#-------------------------------------------------------------

=head2 AnalyseNgram

  Title    : Analyse Ngram
  Usage    : my $ref_ngram2count = AnalyseNgram($n, $ref_arr_arr_toks);
  Function : creates a hash of n-grams to their number of occurrences
  Returns  : the reference to the hash n-gram => count
  Args     : positional arguments:
           : - 0 (n) => number
           : - 1 (ref_arr_arr_toks) => reference to an array of array of tokens
           : - 2 (name_outfile)
           : - 3 (flag for boundary toks)
=cut
sub AnalyseNgram{
    my $ngram_width = $_[0]; 
    my $ref_arr_arr_toks = $_[1]; 
    my $name_outfile = $_[2];
    my $boundarytok = defined $_[3] ? $_[3] : 0; 

    my %ngram2count;
    # for each of the arrays of tokens
    for my $arr_toks(@$ref_arr_arr_toks){
        my $ng = Algorithm::NGram->new(ngram_width => $ngram_width); # specify n
        # add n-1 start tokens (if boundarytok =1)
        if ($boundarytok == 1){
            for (my $i = 1; $i < $ngram_width; $i++) {$ng->add_start_token;} 
        }
        $ng->add_tokens(@$arr_toks);
        if ($boundarytok == 1){
            # add n-1 end tokens
            for (my $i = 1; $i < $ngram_width; $i++) {$ng->add_end_token;} 
        }
        # always add one end-tok because of structure of ngram hash ( N => Grams => following_word => count)
        # so as not to ignore last word
        $ng->add_end_token; 

        my %output = %{$ng->analyze};
        my $ngram_table =$output{$ngram_width}; #

        # count total number of each ngram
        while (my ($gram, $following_words) = each %$ngram_table){
            if (!(exists $ngram2count{$gram})){ 
                $ngram2count{$gram} = 0;
            }
            while (my ($following_word, $count) = each %$following_words){
                $ngram2count{$gram}+=$count;
            } 
        }
    }
    return \%ngram2count;
}



=head2 dumpAnalysis

  Title    : Dump n-gram analysis
  Usage    : dumpAnalysis($ref_ngram2count, $outfile_name);
  Function : Writes the n-gram analysis to the file indicated
  Returns  : Nothing
  Args     : positional arguments:
           : - 0 (ref_ngram2count) => reference to a hash ngram => count
           : - 1 (outfile_name) => string (e.g. bigramHello.csv)
=cut
sub dumpAnalysis{
    my $ref_ngram2count = $_[0];
    my $fileout = $_[1];
    my %ngram2count = %$ref_ngram2count;
    
    # write to file (ordered by descending count and alphabetically in case of count egality)
    open(FLUX, ">:encoding(UTF-8)", $fileout) or die "cannot open > $fileout: $!"; # open file
    foreach my $gram(sort {$ngram2count{$b} <=> $ngram2count{$a} || $a cmp $b} keys %ngram2count) {
        print FLUX "$gram\t$ngram2count{$gram}\n";
    }
    close(FLUX);
}



=head2 loadAnalysisFromFile

  Title    : Load N-gram analysis from file
  Usage    : $ref_ngram2count = loadAnalysisFromFile($filepath);
  Function : Loads the reference to a hash n-gram => count from the file indicated
  Returns  : The reference to the hash n-gram => count
  Args     : positional arguments:
           : - 0 (filepath) => string (e.g. bigramHello.csv)
=cut
sub loadAnalysisFromFile{
    my $filename = $_[0];
    my %ngram2count;
    open(FLUX, "<:encoding(UTF-8)", $filename);
    while( my $line = <FLUX>){

        my @ngram_count = split("\t", $line);
        chomp $ngram_count[1];
        $ngram2count{$ngram_count[0]} = $ngram_count[1];
    }
    close FLUX;

    return \%ngram2count;
}



=head2 printSummary

  Title    : Print summary of n-gram analysis
  Usage    : printSummary($ref_ngram2count, $outfile);
  Function : Prints a summary of the n-gram analysis and saves a barplot to a file.
  Returns  : Nothing
  Args     : positional arguments:
           : - 0 (ref_ngram2count) => reference to a hash ngram => count
           : - 1 (outfile_name) => string (e.g. bigramHello.csv, converted to bigramHello.png)
=cut
sub printSummary{
    my $ref_ngram2count = $_[0];
    my $outfile_name = $_[1];
    $outfile_name=~s/\.[^\.]+//;

    my %ngram2count = %$ref_ngram2count;
    my $num_ngrams = keys %ngram2count;

    print "\n--------------------------------\n";
    print "Number of unique ngrams : $num_ngrams\n";
    print "The 5 most common ngrams : \n";
    my $i=0; 
    my $max_value = 0;
    my @keys = ();
    my @values = ();
    # for each ngram (sorted by descending value and then by alphabetic value), save to keys and values (for plot)
    foreach my $gram(sort {$ngram2count{$b} <=> $ngram2count{$a} || $a cmp $b} keys %ngram2count){
        # print five most frequent
        if ($i < 5){
            if ($i==0){
                $max_value = $ngram2count{$gram};
            }
            print "\t",$i+1," : $gram ($ngram2count{$gram})\n";
            
        }
        if ($i<40){
            push(@keys, $i+1);
            push(@values, $ngram2count{$gram});
        }
        $i++;
    }
    my $num_hapax = grep { $_ == 1 } values %ngram2count;
    print "The number of hapax : $num_hapax\n";

    # only plot when there are some ngrams to plot
    if ($num_ngrams>1){

        # create barplot
        my $img = DBD::Chart::Plot->new(600,400);
        $img->setPoints(\@keys, \@values, 'dpurple bar nopoints');
        $img->setOptions (
            horizMargin => 0,
            vertMargin => 0,
            title => 'Frequency Distribution of Ngrams',
            xAxisLabel => 'Frequency rank of ngram',
            yAxisLabel => 'Number of occurrences', 
            );

        open (WR,">$outfile_name.png") or die ("Failed to write file: $!");
        binmode WR;
        print WR $img->plot('png');
        close WR;

        utf8::decode($outfile_name);
        print "Barchart for the frequency distribution of the 40 most common ngrams saved to $outfile_name.png\n";
        print "--------------------------------\n";
    }
}

1;
