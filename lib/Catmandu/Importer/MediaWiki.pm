package Catmandu::Importer::MediaWiki;
use Catmandu::Sane;
use MediaWiki::API;
use Catmandu::Util qw(:is :check);
use Moo;

has url => (
    is => 'ro',
    isa => sub { check_string($_[0]); }
);
#cf. http://www.mediawiki.org/wiki/API:Lists
has list => (
    is => 'ro',
    isa => sub {
        array_includes([qw(
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
        )] or die("invalid list module");
    }
);
has list_args => (
    is => 'ro',
    isa => sub { check_hash_ref($_[0]); }
);

with 'Catmandu::Importer';

sub _build_mw {
    my $self = $_[0];
    MediaWiki::API->new( { api_url => $self->url() }  );
}

sub generator {
    my $self = $_[0];

    my $list = $self->list();
    my $old_list_args = $self->list_args();
    my $list_args = {}
    #translate 'aplimit' to 'gaplimit'
    for(keys %$old_list_args){
        $list_args->{"g$_"} = $old_list_args->{$_};
    }

    sub {
        state $mw = $self->_build_mw();
        state $pages = [];
        state $cont_key = "continue";
        state $cont_value = "";

        unless(@$pages){
            my $res = $mw->api({
                %$list_args,
                $cont_key => $cont_value,
                generator => $list
            });
            return unless defined $res;
            if(exists( $ref->{'query-continue'})){
                ($cont_key,$cont_value) = each(%{ $ref->{'query-continue'}->{$list} });
            }
        }

        shift @$pages;
    };
}

1;
