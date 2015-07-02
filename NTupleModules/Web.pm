
=head1 NAME

    NTupleModules::Web

=head1 SYNOPSIS

  1) Performs a google search on an input expression
  2) downloads the resulting N pages and takes the text from them
  (if they meet the input language requirements)
  3) returns a hash language => list of texts.
  
  For example:

  USE CASE: PRINT A LIST OF PRIMARY IDS OF RELATED FEATURES

    use NTupleModules::Web;
    my webGetter = NTupleModules::Web->new(num_pages => 25,
                                           language => "en")
    %lang2texts = get_texts_from_search( search_request => "chocolate");
    
    while (my ($langtext, $ref_texts) = each %lang2texts){
      my @arr_arr_toks;
      print "language: $langtext";
      foreach my $text(@$ref_texts) {
        print "$text\n\n";
      }
    }

=head1 DESCRIPTION

   The module uses Google::Search to get the search results, if an input 
   language is specified (currently 'fr' and 'en' possible) will use the Google
   api's language restriction downloads the pages and loops over them.
   The text is recuperated using HTML::FormatText::WithLInks which 
   returns a lynx-like interpretation of the page. Some pages will be
   refused loading (e.g. due to terms of use excluding scraping), the
   dowloading will continue with other pages until the input N pages
   have been downloaded or the max pages (64) limit is reached.

=head1 AUTHOR - Nicholas Parslow

    Nicholas Parslow nparslow@yahoo.com.au

=head1 APPENDIX

    subroutines:
    get_texts_from_url
    get_texts_from_search
    
    note threads are officially discouraged in perl, so everything is performed 
    linearly
    re: http://perldoc.perl.org/threads.html

=cut
# package declaration
# directory::filename (sans .pm), note the file must be .pm for a package
package NTupleModules::Web;

use strict;
use warnings;
# the following line allows for package installations to a non-root directory
BEGIN {
  if (!$ENV{HOME}) { $ENV{HOME} ="."; }
}
use lib "$ENV{HOME}/perl5/lib/perl5";
use utf8;

# bug in Google::Search module gives error line:
# overload arg '' is invalid at /usr/local/share/perl/5.18.2/Google/Search/ Error.pm line 7.
# re: http://www.perlmonks.org/?node_id=1062384
# temporarily turning off string and/or warnings doesnt change anything
# solution with IO::Null doesn't work:
# redirecting Std::out and std::err don't work
# redirecting warnings doesn't work
#print "The following warning about overload arg is safe to ignore \n";
# this will be printed too late!
use Google::Search;

use HTTP::Request; # to get the HTTP from a given website:
use HTML::TreeBuilder;  # to interpret the html:
use HTML::FormatText::WithLinks; # gets Lynx -like text from a webpage
use Params::Validate qw(:all);  # to have well constrained input parameters
use Lingua::Identify qw(:language_identification); # language identification

# next lines are for exporting this as a module
use Exporter;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);

$VERSION     = 0.09;             # we assign a version number
@ISA         = qw(Exporter);     # this line is always the same
@EXPORT      = ();               # default elements to export, best empty
# functions which can be exported by request :
@EXPORT_OK   = qw(get_texts_from_search get_texts_from_url new);  
# groups of functions which can be exported by request with the defined name :
%EXPORT_TAGS = (DEFAULT => [qw(&get_texts_from_search &new)],               
                All   => [qw(&get_texts_from_search &get_texts_from_url &new)]);
# to be a package, at the end of the file a '1;' is required for importing

binmode STDOUT, ":encoding(UTF-8)"; # sets the std::out encoding to utf-8


=head2 new

  Title    : new
  Usage    : my $webGetter = NTupleModules::Web->new( language => 'fr',
                                                      num_pages => 25, );
  Function : initalises a Web package (class)
  Returns  : the Web class
  Args     : named arguments:
           :  (optional) language => string
           :      (can be 'en', 'fr' or undef(the default))
           :      if undef will accumulate results in english or french
           :  (optional) use_paragraphs => boolean (default = 0)
           :      default means use lynx-like page interpretation
           :      this gets more text more often but includes headings etc.
           :      alternatively paragraphs tag are used
           :      this gets much less text but perhaps with less noise
           :  (optional) num_pages => integer the number of web pages
           :      to download (between 1 and 64, default=50)
           :  (optional)verbose => boolean (default = 0)
=cut
sub new {

    my $class = shift;        # Get the request class name

    #my $this = {};  # Create an anonymous hash, and #self points to it.
    my $this = validate(
            @_, {
                language => { type => SCALAR | UNDEF, 
                              optional => 1,  # i.e. optional
                              callbacks => {
                                'undef or en or fr' => sub {
                                  defined  $_[0] ?
                                    $_[0] eq 'en' || $_[0] eq 'fr' : 1}
                              },
                              default => undef }, 
                use_paragraphs => { type => SCALAR, 
                                    optional => 1,  # i.e. optional
                                    default => 0 }, 
                num_pages => {type => SCALAR,
                              optional => 1,
                              default => 50,
                              callbacks => {
                                'less than 64' => sub {$_[0] > 0 && $_[0] < 64}
                                           },
                             },
                verbose => { type => SCALAR,
                             optional => 1,
                             default => 0,
                           },
            }
    );
    # Connect the hash to this package,  Use class name to bless() reference
    bless $this, $class;       

    return $this;     # Return the reference to the hash.
}


=head2 get_texts_from_url

  Title    : get_texts_from_url
  Usage    : my %lang2texts = $your_web_object->$get_texts_from_url( url=>$url );
  Function : downloads and reads content of a url
           : if 'use_paragraphs' is set to true, will use <p> tags to find text
           : otherwise will use a lynx-like interpretation of page
           : (this is the default)
  Returns  : a hash of language -> list of extracted texts
  Args     : named arguments:
           :  url => string (mandatory)
           :
=cut
sub get_texts_from_url{
  my $this = shift;
  my %args = validate(
            @_, {
                url => { type => SCALAR  | SCALARREF},  # mandatory
            },
  );
  my $url = $args{url};
  print "Trying : $url\n";

  # initialise the possible languages as a set/hash in perl:
  my @keys = qw/en fr/;
  if (defined $this->{language}){ @keys = ($this->{language}); }
  my %lang2texts;
  @lang2texts{@keys} = (); # each key is undefined so it's a set atm
  
  # get the HTML from the webpage:
  my $ua = LWP::UserAgent->new;
  my $resp = $ua->get($url);
  
  if ( $resp->is_success ) {
    # parse the tree with html::treebuilder
    # treebuilder extends html::parser and html::element
    # (this is where to find a lot of the documentation)
    my $root = HTML::TreeBuilder->new_from_content($resp->decoded_content);
    # don't remove excess space at beginning and end of text segments:
    $root->no_space_compacting(1); 
    
    my @texts;
    if ($this->{use_paragraphs}) {
      # search for any subtree between 'p' tags, and take the text from there
      my @found_paras = $root->find_by_tag_name('p');
      for my $paragraph (@found_paras){
        # trimmed removes leading and trailing whitespace:
        push(@texts, $paragraph->as_trimmed_text);
      }
    } else {
      # initialise the text formatter, we don't want to show links,
      # so leave these empty
      my $f = HTML::FormatText::WithLinks->new(
          before_link => '',
          after_link => '',
          footnote => ''
      );
      # we only get one element this way so set it to the first text in the list
      
      # we need to remove the page elements added by the interpretter
      # sequences of =====, and -------
      my $outtext = $f->parse($resp->decoded_content);
      $outtext =~ s/\[IMAGE\]//g; # replace all [IMAGE] by nothing
      $outtext =~ s/   \* //g; # remove 3 spaces then  * followed by a space
      $outtext =~ s/===+//g; # remove 3 or more = 
      $outtext =~ s/---+//g; # remove 3 or more -
      $outtext =~ s/   [0-9]+\. //g; # remove 3 space number. space
      # but leaves " - " as could be real
      # remove single lines but replace anything with more than 1 by a single
      $outtext =~ s/\n\n+/END_LINE/g;
      $outtext =~ s/\n       / /g; # newline with 3 spaces, replace with single space
      $outtext =~ s/\n   / /g; # newline with 3 spaces, replace with single space
      $outtext =~ s/END_LINE/\n/g;
      $outtext =~ s/\n\s+\n/\n/g; # remove white lines
      $outtext =~ s/   / /g; # remove groups of 3 whitespace
      $outtext =~ s/\n /\n/g; # still have spaces at start of line
      #$outtext =~ s/ - / /g;
      $outtext =~ s/[^((\w+[:punct:]?)+|\s)]/ /g; # trim the uninteresting stuff
      $texts[0] = $outtext;
    }
    
    # we join the text(s) all together to check the language
    # if no language it will be uninitialised but not undefined (i.e. if no text)
    # usually with 100 chars guaranteed to get things right
    my $lang_found = langof( join("\n"), @texts);
    
    
    # require at least 3 characters, removes pages which often just have a space
    # and a number in the paragraph method
    if ($lang_found) { 
      if ($this->{verbose}) {print "Language found: $lang_found \n";}
      
      # check if language is in the ones of interest to us,
      # and add the texts if it is:
      if (exists $lang2texts{$lang_found}) {
        if (defined $lang2texts{$lang_found}) {
          # add to an existing list
          push(@{$lang2texts{$lang_found}}, @texts);
        } else {
          # make a new list
          $lang2texts{$lang_found} = \@texts;
        }
        
        if ($this->{verbose}) {
          # show the number of texts found.
          my $arr_size = @{$lang2texts{$lang_found}};
          print "no. texts found $arr_size \n";
        }
      } 

      # print example(s) of the found text(s)
      if ($this->{verbose}) { # >> = append, > = new file
        #open(FLUX, ">>:encoding(UTF-8)","sample_pages.txt"); # open file
        
        for my $lango (keys %lang2texts) {
          my $max_texts = 3;
          for my $t ( @{ $lang2texts{$lango}}) {
            print "$lango: text sample\n". substr($t, 0, 40 ) ."\n";
        #    print FLUX "$lango: text example\n". $t . "\n\n";
            $max_texts --;
            if ($max_texts == 0) {last;}
          }
        }
        print "\n";
        #close(FLUX);
      }
    } else {
      # we couldn't get enough info from the page
      if ($this->{verbose}) {
        print "Insufficient text found when trying to retrieve:".
          " $url\n ignoring page\n";
      }
    }
  } else {
    # we couldn't get the page
    if ($this->{verbose}) {
      print $resp->status_line . "\n when trying to retrieve:".
        " $url\n ignoring page\n";
    }
  }
  return %lang2texts;
}


=head2 get_texts_from_search

  Title    : new
  Usage    : my %lang2texts = $your_web_object->$get_texts_from_search(
           :                                   search_request =>$search_request,
                                               );
  Function : gets N google search results for search string,
           : applies get_texts_from_url to each result and combines
           : the resulting hashes.
  Returns  : a hash of language -> list of strings
           :(the visible text from the web page)
  Args     : named arguments:
           :  search_request=> string (e.g. "chocolate") (mandatory)
           :  if language in the module is non-specified uses no language
           :  input to Google and takes results classified as English
           :  or French. If a page can't be loaded tries an additional page
           :  instead
           :
=cut
sub get_texts_from_search{
  my $this = shift;
  my %args = validate(
            @_, {
                search_request => { type => SCALAR },
             },
  );
  my $search_request= $args{search_request};
  # convert the search request to utf8 if it isn't already:
  if (!utf8::is_utf8($search_request )){
    utf8::decode($search_request);
  }

  # establish the output hash
  my @keys = qw/en fr/;
  if (defined $this->{language}){ @keys = ($this->{language}); }
  my %lang2texts;
  @lang2texts{@keys} = (); # each key is undefined
  
  
  if ($this->{verbose}) {print "Num pages to search: ".$this->{num_pages}."\n";}

  # currently max pages = 64 will bug if more
  if ($this->{verbose}) {print "Searching Web for $search_request\n\n";}
  # for parameters to search see full list:
  # http://stackoverflow.com/questions/11419407/using-query-string-parameters-with-google-maps-api-v3-services
  # for languages:
  # https://sites.google.com/site/tomihasa/google-language-codes
  # unfortunately the 'start=>"63"' is the highest we can go so that limits
  # our max no. pages to download
  my $search;
  if (defined $this->{language}){
    my $request_lang = "lang_".$this->{language};
    $search = Google::Search->Web( query => {q=>$search_request,
                                             lr=>$request_lang } );
  } else {
    $search = Google::Search->Web( query => { q=>$search_request} );
  }
  # no error given even if less than 64 results so it doesn't come
  # in here in such cases
  if (defined $search->error) { 
    if ($this->{verbose}) {die "Search error: ".$search->error . "\n\n";}
  }
  
  # leads to a 403 terms of service abuse error message
  #@results = $search->all; 
  my $pages_loaded = 0; # pages with data taken from them
  my $pages_tried = 0; # pages looked at
  while (my $result = $search->next and $pages_loaded < $this->{num_pages} ) {
    if (defined $result) {
      my $url = $result->uri;
    
      #if ($this->{verbose}) {print "Getting text from webpage: $url\n";}
      my %new_lang2texts = $this->get_texts_from_url( url => $url );
      if ( %new_lang2texts){ # 'defined' is depreciated for hashes 
        my $language_ok = 0;
        # check each language is ok i.e. if required language is undefined or
        #found language matches required language
        foreach my $lango (keys %new_lang2texts) {
          if (defined $new_lang2texts{$lango} and
                (!defined($this->{language}) or $lango eq $this->{language}) ) { 
            $language_ok = 1;
            if (defined $lang2texts{$lango}) {
              my @b = @{$new_lang2texts{$lango}};
              my @a = $lang2texts{$lango};
              push( @a, @b);
              push(@{$lang2texts{$lango}}, @{$new_lang2texts{$lango}});          
            } else {
              $lang2texts{$lango} = $new_lang2texts{$lango};
            }

          }
        }
        if ($language_ok) { $pages_loaded ++; }
      } else {
         # don't increment pages_loaded if we can't get any texts we want
      }  
 
    } else {
      print "empty search result for " . $result->uri . "\n";
    }
    $pages_tried ++;
  }
  if ($pages_tried == 0) {
    warn "Warning: No Pages found for search $search_request \n" .
         "Please check your internet connection or try a more common query \n";
    
  } elsif ($pages_loaded < $this->{num_pages} and $pages_tried < 64) {
    warn "Warning: Only $pages_tried results found.\n".
          "The search may have been interrupted and stopped early\n".
          "We recommend repeating the query\n";
  }
  if ($this->{verbose}) {print "$pages_loaded pages loaded".
    " in appropriate language of $pages_tried pages tried\n";}
  
  return %lang2texts;

}


# required to make this file importable:
#(file must return 'True' and convention is 1)
1;
