=head1 NAME

    NTupleModules::PreProcessing

=head1 SYNOPSIS

    USE CASE : PRE-PROCESS A RAW TEXT

    my $stemmatise = 1; # True (False=0)
    my $langtext = "en"; # all texts are English
    my @arr_arr_toks;
    foreach my $text(@$ref_texts) {
        my $ref_arr_arr_toks = Preprocessing($text, $langtext, $stemmatise);
        @arr_arr_toks = (@arr_arr_toks, @$ref_arr_arr_toks);
    }

=head1 DESCRIPTION
    Pre-processes a raw text by segmenting (dividing into sentences), tokenising each sentence and stemmatising each token if the boolean $stemmatise has the value 1. Pre-processing is dependent on the language. Two languages "en" (English) and "fr" (French) are supported.

=head1 AUTHOR - Timothée Bernard & Rachel Bawden

    Timothée Bernard timothee.bernard@ens-lyon.fr
    Rachel Bawden rachel.bawden@keble.oxon.org

=head1 APPENDIX

    subroutines:
    Tokenise
    Preprocessing

=cut
package NTupleModules::PreProcessing;

BEGIN {
  if (!$ENV{HOME}) { $ENV{HOME} ="."; }
}
use lib "$ENV{HOME}/perl5/lib/perl5";
use Lingua::Sentence;
use Lingua::Stem::En;
use Lingua::Stem::Fr;
use strict;
use warnings;
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
$VERSION     = 0.02;                                    
@ISA         = qw(Exporter);                            
@EXPORT      = ();                                      
@EXPORT_OK   = qw(Preprocessing Tokenise);  
%EXPORT_TAGS = ( DEFAULT => [qw(&Preprocessing &Tokenise)],               
                 Both    => [qw(&Preprocessing &Tokenise)]);

=head2 Tokenise

  Title    : Tokenise
  Usage    : my $ref_toks = Tokenise($sent, $lang); 
  Function : Tokenises a sentence (string)
  Returns  : a reference to an array of tokens
  Args     : positional arguments:
           : - 0 (sent) => string
           : - 1 (lang) => string ("en" or "fr")
=cut
sub Tokenise{
    my $sentence = $_[0];

    utf8::encode($sentence); # need to encode to substitute certain characters    

#print $sentence, "\n";
	
    my $language = $_[1];
	
    my $noPunctuation = $_[2];
	
    my @punctuations = (', ', ':', ';', '\!', '\?', '-', '"', '\(', '\)', '\[', '\]');
    my @exceptions = ('n\'t', '\'s', '\'re', '\'ve', '\'d', '\'ll');

    my @smileys = (':/', '/:', ':\\', '\:', ':(', '(:', ':)', '):', ':D', 'D:', ':p', ':P', 'P:', ':d', 'd:', ':-/', '/-:', ':-\\', '\-:', ':-(', '(-:', ':-)', ')-:', ':-D', 'D-:', ':-p', ':-P', 'P-:', ':-d', 'd-:', ';(', ';)', ';D', '=(', '(=', '=)', ')=', '=D', '=p', '=P', 'P=');

    my $tmp = $sentence;

# Normalization of apostrophes
    $tmp =~ s/’/'/g;

    # We delete everything that is in square brackets (that are often found in Wikipedia pages)
    $tmp =~ s/\[[^]]*\]//g;

# Stars *
    $tmp =~ s/\*+/ /g;

	# URL
	$tmp =~ s/(^|[^\w@])(https?\:\/\/)?([\da-zA-Z\.-]+)\.([a-zA-Z\.]{2,6})(\/[\w\.-]+)*\/?($|[^\w@])/$1URL$6/g;

	# Email address
	$tmp =~ s/([\da-zA-Z_\.-]+)\@([\da-zA-Z\.-]+)\.([a-zA-Z\.]{2,6})/EMAIL_ADDRESS/g;

	# Escaping the smileys
	foreach my $smiley(@smileys) {
		my $rep = $smiley;
		$rep =~ s/(\:|\)|\()/\\$1/g;
		$tmp =~ s/\Q$smiley/$rep/g;
	}

	#print $tmp;

	if ($language eq 'en') {
		# Exceptions
		foreach my $exception(@exceptions) {
			$tmp =~ s/($exception)/ $1/g;
		}
	}
	elsif ($language eq 'fr') {
		# Apostrophes
		$tmp =~ s/([a-zA-Z]')/$1 /g;
		
		# "aujourd'hui" is an exception
		$tmp =~ s/ujourd' hui/ujourd'hui/g;
	}

	#print $tmp;

	# Punctuations
	foreach my $punctuation(@punctuations) {
		$tmp =~ s/(^|[^\\])($punctuation+)/$1 $2 /g;
	}

	#print $tmp;

	# Unescaping the smileys
	foreach my $smiley(@smileys) {
		my $pat = $smiley;
		$pat =~ s/(\:|\)|\(|\\)/\\$1/g;
		$tmp =~ s/\Q$pat/$smiley/g;
	}

	#print $tmp;

    # re-decode result
    utf8::decode($tmp);

	# Splitting
	my @toks;
	if($noPunctuation == 0) {
		@toks = split '\s+', $tmp;
	}
	else {
		@toks = split /[ ,.;:!?\-"()[\]]+/, $tmp;
	}
	
	return \@toks;
}




=head2 Preprocessing

  Title    : Preprocessing
  Usage    : my $ref_arr_arr_toks = Preprocessing($text, $langtext, $stemmatise);
  Function : Transforms raw text into an array of arrays of tokens (stemmatised or not)
  Returns  : An array of arrays of tokens (stemmatised or not)
  Args     : positional arguments:
           : -0 (text) => string
           : -1 (langtext) => string ("en" or "fr")
           : -2 (stemmatise) => boolean (1 or 0)
=cut
sub Preprocessing{
    my $raw_text = $_[0]; 
    my $lang = $_[1]; 
    my $stemmatise = $_[2]; # 1=true, 0=false
    my $noPunctuation = $_[3];

    #-------- segment into sentences (default = "en") --------
    my $splitter = Lingua::Sentence->new($lang);

    my $newline_sep =  $splitter->split($raw_text);
    my @list_sents = split("\n", $newline_sep);

    #-------- tokenise for each sentence & stem if option specified --------
    my @arr_arr_toks;
    my %stem_exceptions;
    foreach my $sent(@list_sents){

        # consider only strings with at least one word character
        if ($sent =~/\w/){
            my $ref_toks = Tokenise($sent, $lang, $noPunctuation); 
            # stemmatise for each tok of each array if option
            if ($stemmatise == 1){
                if ($lang eq "en"){
                    $ref_toks = Lingua::Stem::En::stem({ -words => $ref_toks,
                                               -locale => $lang,
                                               -exceptions => \%stem_exceptions,
                                               });
                }
                elsif ($lang eq "fr"){
                    $ref_toks = Lingua::Stem::Fr::stem({ -words => $ref_toks,
                                               -locale => $lang,
                                               -exceptions => \%stem_exceptions,
                                               });
                }  
            }
            push(@arr_arr_toks, $ref_toks);
        }
    }
    return \@arr_arr_toks; # return an array of arrays of tokens
}


1;
