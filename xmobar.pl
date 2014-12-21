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

Irssi::settings_add_str( "xmobar", "xmobar_pipe", "/tmp/irssi2xmobar" );
Irssi::settings_add_str( "xmobar", "xmobar_level_1_color", "" );
Irssi::settings_add_str( "xmobar", "xmobar_level_2_color", "" );
Irssi::settings_add_str( "xmobar", "xmobar_level_3_color", "" );
Irssi::settings_add_str( "xmobar", "xmobar_minlevels", "" );
Irssi::settings_add_int( "xmobar", "xmobar_act_timeout", 60 );
Irssi::settings_add_str( "xmobar", "xmobar_nick_watches", "" );

# use 4 to disable all notifications from given window
my %winminlevel;
my %actbuffer;
my $msgbuf;
my @nicktempwatches;

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

sub flushPipe() {
    my $pipe = Irssi::settings_get_str( "xmobar_pipe" );
    POSIX::mkfifo( $pipe, $pipemode ) unless ( -p $pipe );
    open( my $handle, ">", $pipe ) or die "Pipe open error";

    my @act = ();
    my $timeout = Irssi::settings_get_int( "xmobar_act_timeout" );
    my $tm = time - $timeout;
    for my $k ( keys %actbuffer ) {
        if ( $actbuffer{ $k }->{ time } > $tm ) {
            push( @act, $actbuffer{ $k }->{ sign } . $k );
        } else {
            delete( $actbuffer{ $k } );
        }
    }

    my $msg = "$msgbuf " . join( " ", @act );
    $msg =~ s/^\s+//;
    $msg =~ s/\s+$//;

    print $handle "$msg\n";
    $handle->autoflush;
    Irssi::timeout_add_once( 1000 * $timeout, \&flushPipe, 0 ) if ( @act > 0 );
    close( $handle );
}

sub actPush($$) {
    my ( $sign, $act ) = @_;
    $actbuffer{ $act } = { 'time' => time, 'sign' => $sign };
}

sub watched($) {
    my ( $nick ) = @_;
    my @nickwatches = split( / /, Irssi::settings_get_str( "xmobar_nick_watches" ) );
    for my $n ( @nickwatches ) {
        return 1 if ( $n eq $nick );
    }
    for my $n ( @nicktempwatches ) {
        return 1 if ( $n eq $nick );
    }
    return 0;
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
    my $name = $$witem{name};
    if ( @data == 0 ) {
        $wprint->( "[xmobar binding configuration]" );
        $wprint->( "use '/xmobar help' for help\n" );
        for ( my $i = 1; $i <= 3; $i++ ) {
            $wprint->( "xmobar.level_${i}_color = " . Irssi::settings_get_str( "xmobar_level_${i}_color" ) );
        }
        $wprint->( "xmobar.pipe = " . Irssi::settings_get_str( "xmobar_pipe" ) );
        for my $k ( keys %winminlevel ) {
            $wprint->( "xmobar.minlevel.$k = $winminlevel{ $k }" );
        }
        return;
    }
    if ( $data[ 0 ] eq "minlevel" ) {
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
    } elsif ( $data[ 0 ] =~ "level_[1-3]_color" ) {
        Irssi::settings_set_str( "xmobar_$data[ 0 ]", $data[ 1 ] ) if ( @data > 1 );
        $wprint->( $data[ 0 ] . " = " . Irssi::settings_get_str( "xmobar_$data[ 0 ]" ) );
    } elsif ( $data[ 0 ] eq "pipe" ) {
        Irssi::settings_set_str( "xmobar_pipe", $data[ 1 ] ) if ( @data > 1 );
        $wprint->( "xmobar.pipe = " . Irssi::settings_get_str( "xmobar_pipe" ) );
    } elsif ( $data[ 0 ] eq "watch" ) {
        my @nickwatches = split( / /, Irssi::settings_get_str( "xmobar_nick_watches" ) );
        my $printall = sub {
            $wprint->( "[xmobar activity watches]\n"
                     . "permanent: @nickwatches\n"
                     . "temporary: @nicktempwatches" );
        };
        if ( @data > 2 ) {
            my @nicks = @data[2 .. $#data];
            if ( $data[ 1 ] eq "add" ) {
                push( @nickwatches, @nicks );
                Irssi::settings_set_str( "xmobar_nick_watches", join( " ", @nickwatches ) );
                $printall->();
            } elsif ( $data[ 1 ] eq "tempadd" ) {
                push( @nicktempwatches, @nicks );
                $printall->();
            } elsif ( $data[ 1 ] eq "drop" ) {
                my @newnw = ();
                for my $n ( @nickwatches ) {
                    my $drop = 0;
                    for my $nd ( @nicks ) {
                        $drop = 1 if ( $n eq $nd );
                    }
                    push( @newnw, $n ) if ( not $drop );
                }
                @nickwatches = @newnw;
                Irssi::settings_set_str( "xmobar_nick_watches", join( " ", @newnw ) );

                my @newtnw = ();
                for my $n ( @nicktempwatches ) {
                    my $drop = 0;
                    for my $nd ( @nicks ) {
                        $drop = 1 if ( $n eq $nd );
                    }
                    push( @newtnw, $n ) if ( not $drop );
                }
                @nicktempwatches = @newtnw;

                $printall->();
            } elsif ( $data[ 1 ] eq "timeout" ) {
                my $tmo = $data[ 2 ] + 0;
                if ( $tmo < 0 ) {
                    $wprint->( "Invalid timout (must be >= 0)" );
                    return;
                }
                Irssi::settings_set_int( "xmobar_act_timeout", $tmo );
                $wprint->( "xmobar.watch.timeout = $tmo" );
            }
        } elsif ( @data == 2 && $data[ 1 ] eq "cleartemp" ) {
            @nicktempwatches = ();
            $wprint->( "temporary watches cleared" );
        } elsif ( @data == 2 && $data[ 1 ] eq "clear" ) {
            @nicktempwatches = ();
            Irssi::settings_set_str( "xmobar_nick_watches", "" );
            $wprint->( "watches cleared" );
        } elsif ( @data == 2 && $data[ 1 ] eq "timeout" ) {
            $wprint->( "xmobar.watch.timeout = "
                   . Irssi::settings_get_int( "xmobar_act_timeout" ) );
        } elsif ( @data == 2 && $data[ 1 ] eq "help" ) {
            $wprint->( "/xmobar watch [command]    where command can be one of:\n"
                     . "(nothing)            list watched nicks\n"
                     . "add NICKS...         add permanent watches for listed nicks (space separated)\n"
                     . "tempadd NICKS...     add temporary watches for listed nicks\n"
                     . "drop NICKS...        do not watch those nicks any more\n"
                     . "clear                clear all watches\n"
                     . "cleartemp            clear temporary watches\n"
                     . "timeout [SECONDS]    get/set timeout for nick activity display" );
        } else {
            $printall->();
        }
    } elsif ( $data[ 0 ] eq "help" ) {
        $wprint->( "/xmobar usage:" );
        $wprint->( "/xmobar                 show all settings" );
        $wprint->( "/xmobar minlevel [N]    get/set minimal notification level for current window\n"
                 . "                        N = 1  all including status changes\n"
                 . "                        N = 2  all messages\n"
                 . "                        N = 3  highlighted messages\n"
                 . "                        N = 4  disable notification" );
        $wprint->( "/xmobar watches help    see help for nick watches" );
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

    $msgbuf = join( ", ", @msgs );
    flushPipe();
}

Irssi::signal_add_last( "window activity", \&window_activity );

sub msg_join {
    my ( $server, $channel, $nick, $address ) = @_;
    actPush( "+", $nick ) if ( watched( $nick ) );
    flushPipe();
}

sub msg_part {
    my ( $server, $channel, $nick, $address, $reason ) = @_;
    actPush( "-", $nick ) if ( watched( $nick ) );
    flushPipe();
}

sub msg_quit {
    my ( $server, $nick, $address, $reason ) = @_;
    actPush( "-", $nick ) if ( watched( $nick ) );
    flushPipe();
}

Irssi::signal_add_last( "message join", \&msg_join );
Irssi::signal_add_last( "message part", \&msg_part );
Irssi::signal_add_last( "message quit", \&msg_quit );

