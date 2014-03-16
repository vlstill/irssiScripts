##
## Put me in ~/.irssi/scripts, and then execute the following in irssi:
##
##       /load perl
##       /script load xaway
##

use strict;
use warnings;
use Irssi;
use vars qw($VERSION %IRSSI);
use IO::Handle;
use X11::Protocol;

$VERSION = "0.01";
%IRSSI = (
    authors    => 'Vladimír Štill',
    contact     => 'xstill@fi.muni.cz',
    name        => 'xaway',
    description => 'TODO',
    license     => 'BSD',
    url         => 'TODO',
);

my $x = X11::Protocol->new();

my ( $root, $parent, @kids ) = $x->QueryTree( $x->root );

my $irssi;

for my $win ( @kids ) {
    my ( $name ) = $x->GetProperty( $win,
                      $x->atom( "WM_NAME" ),
                      $x->atom( "STRING" ), 0, ~0, 0 );
    if ( $name eq "irssi" ) {
        $irssi = $win;
        last;
    }
}

####################

my $lastwin = 2;
my $inFocus = 1;

sub check_x {
    my %atrs = $x->GetWindowAttributes( $irssi );
    return unless exists $atrs{ map_state };
    if ( $atrs{ map_state } eq "Viewable" ) {
        if ( $inFocus == 0 ) {
            Irssi::command( "window goto $lastwin" );
            $inFocus = 1;
        }
    } elsif ( $atrs{ map_state } eq "Unmapped" ) {
        if ( $inFocus == 1 ) {
            my $win = Irssi::active_win();
            $lastwin = $$win{ refnum };
            Irssi::command( "window goto 1" );
            $inFocus = 0;
        }
    } else {
        print "invalid state";
    }
};

my $timerName = Irssi::timeout_add( 100, \&check_x, '' );
