requires 'perl','5.12.1';
requires 'Catmandu';
requires 'Moo';
requires 'MediaWiki::API';

on 'test', sub {
    requires 'Test::Exception','0';
    requires 'Test::More','0';
};

