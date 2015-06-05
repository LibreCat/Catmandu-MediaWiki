package Catmandu::Importer::MediaWiki;
use Catmandu::Sane;
use MediaWiki::API;
use Catmandu::Util qw(:is :check array_includes);
use Moo;
use Data::Dumper;

my $lists = [qw(
    allcategories
    allfileusages
    allimages
    alllinks
    allpages
    allredirects
    alltransclusions
    allusers
    backlinks
    blocks
    categorymembers
    deletedrevs
    embeddedin
    exturlusage
    filearchive
    imageusage
    iwbacklinks
    langbacklinks
    logevents
    pagepropnames
    pageswithprop
    prefixsearch
    protectedtitles
    querypage
    random
    recentchanges
    search
    tags
    usercontribs
    users
    watchlist
    watchlistraw
)];
my $list_prefix = {
    allcategories => "ac",
    allfileusages => "af",
    allimages => "ai",
    alllinks => "al",
    allpages => "ap",
    allredirects => "ar",
    alltransclusions => "at",
    allusers => "au",
    backlinks => "bl",
    blocks => "bk",
    categorymembers => "cm",
    deletedrevs => "dr",
    embeddedin => "ei",
    exturlusage => "eu",
    filearchive => "fa",
    imageusage => "iu",
    iwbacklinks => "iwbl",
    langbacklinks => "lbl",
    logevents => "le",
    pagepropnames => "ppn",
    pageswithprop => "pwp",
    prefixsearch => "ps",
    protectedtitles => "pt",
    querypage => "qp",
    random => "rn",
    recentchanges => "rc",
    search => "sr",
    tags => "tg",
    usercontribs => "uc",
    users => "us",
    watchlist => "wl",
    watchlistraw => "wr"
};

has url => (
    is => 'ro',
    isa => sub { check_string($_[0]); }
);
#cf. http://www.mediawiki.org/wiki/API:Lists
has list => (
    is => 'ro',
    isa => sub {
        array_includes($lists,$_[0]) or die("invalid list module");
    },
    lazy => 1,
    default => sub { "allpages"; }
);
has list_args => (
    is => 'ro',
    isa => sub { check_hash_ref($_[0]); },
    lazy => 1,
    default => sub {
        +{
            prop => "revisions",
            rvprop => "ids|flags|timestamp|user|comment|size|content",
            aplimit => 100,
            apfilterredir => "nonredirects"
        };
    }
);

with 'Catmandu::Importer';

sub _build_mw {
    my $self = $_[0];
    my $mw = MediaWiki::API->new( { api_url => $self->url() }  );

    my $ua = $mw->{ua};

    if(is_string($ENV{LWP_TRACE})){
        $ua->add_handler("request_send",  sub { shift->dump; return });
        $ua->add_handler("response_done", sub { shift->dump; return });
    }

    $mw;
}

sub generator {
    my $self = $_[0];

    my $list = $self->list();
    my $list_args = $self->list_args();
    my $prefix = $list_prefix->{$list};

    #map module arguments to generator. e.g. aplimit => gaplimit
    my @module_keys = grep { index($_,$prefix) == 0 } keys %$list_args;
    for(@module_keys){
        $list_args->{'g'.$_} = delete $list_args->{$_};
    }

    sub {
        state $mw = $self->_build_mw();
        state $pages = [];
        state $cont_args = { continue => '' };

        unless(@$pages){
            my $args = {
                %$list_args,
                %$cont_args,
                action => "query",
                indexpageids => 1,
                generator => $list,
                format => "json",
            };
            my $res = $mw->api($args) or die(Dumper($mw->{error}));
            return unless defined $res;
            return unless exists $res->{'continue'};

            $cont_args = $res->{'continue'};

            if(exists($res->{'query'}->{'pageids'})){
                for my $pageid(@{ $res->{'query'}->{'pageids'} }){
                    push @$pages,$res->{'query'}->{'pages'}->{$pageid};
                }
            }
        }

        shift @$pages;
    };
}

1;
