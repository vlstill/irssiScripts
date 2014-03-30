##
## Put me in ~/.irssi/scripts, and then execute the following in irssi:
##
##       /load perl
##       /script load xmobar
##

use strict;
use warnings;
use Irssi;
use vars qw($VERSION %IRSSI);
use IO::Handle;
use POSIX;

$VERSION = "0.01";
%IRSSI = (
    authors    => 'Vladimír Štill',
    contact     => 'xstill@fi.muni.cz',
    name        => 'xmobar.pl',
    description => 'simple xmobar binding (using pipe reader)',
    license     => 'BSD',
    url         => 'TODO',
);

my $pipe = "/tmp/cache/irssi2xmobar";
my $pipemode = 0600;
my $maxlength = 32;
my $minlevel = 1;
my %levelcolor = ( 1 => "#46a4ff",
                   3 => "#ff6565",
                 );
# use 4 to disable all notifications from given window
my %winminlevel = ( "root" => 4,
                    "&bitlbee" => 4,
                    "#nixos" => 3,
                    "#darcs" => 2,
                  );

POSIX::mkfifo( $pipe, $pipemode ) unless ( -p $pipe );
open( my $handle, ">", $pipe ) or die "Pipe open error";

sub printPipe($) {
    my ( $msg ) = @_;
#    if ( length( $msg ) > $maxlength ) {
#        $msg =~ s/^(.{0,$maxlength})\b.*$/$1…/s;
#    }        
    print $handle "$msg\n";
    $handle->autoflush;
}

sub colorBegin($) {
    my ( $level ) = @_;
    if ( exists( $levelcolor{ $level } ) ) {
        return "<fc=$levelcolor{ $level }>";
    }
    return "";
}

sub colorEnd($) {
    my ( $level ) = @_;
    if ( exists( $levelcolor{ $level } ) ) {
        return "</fc>";
    }
    return "";
}

printPipe( "" );
window_activity();

# print $handle "initialized\n";

sub testing {
    my ($data, $server, $witem) = @_;
    return unless $witem;
    # $witem (window item) may be undef.

    $witem->print( 'It works!' );
    my @windows = Irssi::windows();
    for my $w ( @windows ) {
        $witem->print( "-----" );
        for my $k ( keys %$w ) {
            $witem->print( "$k = $$w{ $k }" );
        }

        my $active = $$w{ active };
        for my $k ( keys %$active ) {
            $witem->print( "    $k = $$active{ $k }" );
        }
    }
}

Irssi::command_bind( "test", \&testing );

sub event_privmsg {
    # $data = "nick/#channel :text"
    my ($server, $data, $nick, $address) = @_;
    # my ($target, $text) = split(/ :/, $data, 2);
      
    printPipe( "$nick" );
}

sub window_highlight {
    my ( $window ) = @_;
    return unless $window;

    printPipe( "highlight" );
}

sub window_activity {

    my @windows = Irssi::windows();
    my @msgs = ();
    for my $win ( @windows ) {
        my $level = $$win{ data_level };

        if ( $level > 0 ) {
            my $active = $$win{ active };
            my $name = $$active{ visible_name };
            next unless $name;
            next if ( exists( $winminlevel{ $name } )
                      && $winminlevel{ $name } > $level );

            my $msg = colorBegin( $level ) . $name . colorEnd( $level );
            push( @msgs, $msg );
        }
    }

    printPipe( join( ", ", @msgs ) );
}

# Irssi::signal_add_last( "event privmsg", \&event_privmsg );
# Irssi::signal_add_last( "window highlight", \&window_highlight );
Irssi::signal_add_last( "window activity", \&window_activity );

