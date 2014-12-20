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

$VERSION = "0.02";
%IRSSI = (
    authors    => 'Vladimír Štill',
    contact     => 'xstill@fi.muni.cz',
    name        => 'xmobar.pl',
    description => 'simple xmobar binding (using pipe reader)',
    license     => 'BSD2',
    url         => 'https://github.com/vlstill/irssiScripts/blob/master/xmobar.pl',
);

my $pipemode = 0600;
my $maxlength = 32;

Irssi::settings_add_str( "xmobar", "xmobar_pipe", "/tmp/irssi2xmobar" );
Irssi::settings_add_str( "xmobar", "xmobar_level_1_color", "" );
Irssi::settings_add_str( "xmobar", "xmobar_level_2_color", "" );
Irssi::settings_add_str( "xmobar", "xmobar_level_3_color", "" );
Irssi::settings_add_str( "xmobar", "xmobar_minlevels", "" );

# use 4 to disable all notifications from given window
my %winminlevel;

sub savelevels() {
    my @levels = ();
    for my $k ( keys %winminlevel ) {
        push( @levels, "$k=$winminlevel{$k}" );
    }
    Irssi::settings_set_str( "xmobar_minlevels", join( ":", @levels ) );
}

sub loadlevels() {
    my @levels = split( /:/, Irssi::settings_get_str( "xmobar_minlevels" ) );
    %winminlevel = ();
    for my $level ( @levels ) {
        my ( $k, $v ) = split( /=/, $level );
        $winminlevel{ $k } = $v;
    }
}

loadlevels();

sub printPipe($) {
    my ( $msg ) = @_;

    my $pipe = Irssi::settings_get_str( "xmobar_pipe" );
    POSIX::mkfifo( $pipe, $pipemode ) unless ( -p $pipe );
    open( my $handle, ">", $pipe ) or die "Pipe open error";

    print $handle "$msg\n";
    $handle->autoflush;
    close( $handle );
}

sub colorBegin($) {
    my ( $level ) = @_;
    my $color = Irssi::settings_get_str( "xmobar_level_${level}_color" );
    if ( $color ne "" ) {
        return "<fc=$color>";
    }
    return "";
}

sub colorEnd($) {
    my ( $level ) = @_;
    my $color = Irssi::settings_get_str( "xmobar_level_${level}_color" );
    if ( $color ne "" ) {
        return "</fc>";
    }
    return "";
}

printPipe( "" );
window_activity();

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

sub setting {
    my ( $_data, $server, $witem ) = @_;

    my $wprint = sub {
        if ( exists( $witem->{type} ) ) {
            $witem->print( @_ );
        } else {
            print @_;
        }
    };

    my @data = split( /\s+/, $_data );
    $wprint->( "data = (". scalar @data . ")'@data'" );
    my $name = $$witem{name};
    if ( @data > 0 && $data[ 0 ] eq "minlevel" ) {
        if ( @data > 1 && $data[ 1 ] =~ /[0-9]+/ ) {
            my $level = $data[ 1 ] + 0;
            if ( $level < 1 || $level > 4 ) {
                $wprint->( "invalid minimal level '$data[ 1 ]' (expected 1-4)" );
                return;
            }
            $winminlevel{ $name } = $level;
            $wprint->( "xmobar.minlevel.$name = $level" );
            savelevels();
        } else {
            my $level = 1;
            $level = $winminlevel{ $name } if exists( $winminlevel{ $name } );
            $wprint->( "xmobar.minlevel.$name = $level" );
        }
    } else {
        $wprint->( "xmobar binding configuration" );
        for my $k ( keys %winminlevel ) {
            $wprint->( "xmobar.minlevel.$k = $winminlevel{ $k }" );
        }
    }
}

Irssi::command_bind( "xmobar", \&setting );

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

Irssi::signal_add_last( "window activity", \&window_activity );

