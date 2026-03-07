package Plugins::DaphileRamPlay::Plugin;

# DaphileRamPlay - Automatic RAM Play for Daphile
# Author: Emilio Russo
# Version: 1.0
# 
# Automatically activates "Play from RAM" on Daphile for all clients
# including iPeng and any other LMS-compatible controller.
#
# Reverse engineered endpoint:
#   GET /cgi-bin/ramplay.json?cmd=start&player=<mac>
#   GET /cgi-bin/ramplay.json?cmd=status&player=<mac>
#   Response: {"status":"start"} = NOT active | {"status":"stop"} = ACTIVE

use strict;
use warnings;

use base qw(Slim::Plugin::Base);

use Slim::Utils::Log;
use Slim::Utils::Prefs;
use Slim::Utils::Timers;
use Slim::Networking::SimpleAsyncHTTP;

my $log = Slim::Utils::Log->addLogCategory({
    'category'     => 'plugin.daphileramplay',
    'defaultLevel' => 'ERROR',
    'description'  => 'DaphileRamPlay',
});

my $prefs = Slim::Utils::Prefs::preferences('plugin.daphileramplay');

sub initPlugin {
    my $class = shift;

    $prefs->init({
        enabled => 1,   # Plugin attivo di default
        delay   => 3,   # Secondi di attesa prima di attivare (la copia in RAM ha bisogno di tempo)
    });

    # Sottoscrivi all'evento "nuova canzone"
    Slim::Control::Request::subscribe(
        \&onNewSong,
        [['playlist'], ['newsong']]
    );

    $log->info("DaphileRamPlay plugin initialized");

    $class->SUPER::initPlugin(@_);
}

sub onNewSong {
    my $request = shift;
    my $client  = $request->client() || return;

    # Controlla se il plugin è abilitato nelle preferenze
    return unless $prefs->get('enabled');

    my $delay = $prefs->get('delay') || 3;

    $log->info("New song detected, scheduling RAM play activation in ${delay}s");

    # Aspetta qualche secondo che Daphile inizi la riproduzione
    # prima di attivare il RAM play
    Slim::Utils::Timers::setTimer(
        $client,
        time() + $delay,
        \&activateRamPlay
    );
}

sub activateRamPlay {
    my $client = shift;
    return unless $client;

    # Usa 127.0.0.1 perché il plugin gira sullo stesso host di Daphile
    my $mac         = $client->macaddress();
    my $mac_encoded = $mac;
    $mac_encoded    =~ s/:/\%3A/g;

    my $statusUrl = "http://127.0.0.1/cgi-bin/ramplay.json?cmd=status&player=$mac_encoded";

    $log->info("Checking RAM play status for player $mac");

    Slim::Networking::SimpleAsyncHTTP->new(
        sub {
            my $http    = shift;
            my $content = $http->content() || '';

            $log->info("RAM play status response: $content");

            # Logica API Daphile (verificata da log reale):
            #   {"status":"stop"}  = RAM play NON attivo -> dobbiamo attivarlo
            #   {"status":"start"} = RAM play GIA' attivo -> non fare nulla

            if ( $content =~ /"status"\s*:\s*"stop"/ ) {
                $log->info("RAM play not active, activating for $mac");
                _doActivate($mac_encoded);
            } else {
                $log->info("RAM play already active for $mac, nothing to do");
            }
        },
        sub {
            my $http  = shift;
            my $error = $http->error() || 'unknown error';
            $log->error("Failed to check RAM play status for $mac: $error");
        }
    )->get($statusUrl);
}

sub _doActivate {
    my $mac_encoded = shift;

    my $startUrl = "http://127.0.0.1/cgi-bin/ramplay.json?cmd=start&player=$mac_encoded";

    Slim::Networking::SimpleAsyncHTTP->new(
        sub {
            my $http    = shift;
            my $content = $http->content() || '';
            $log->info("RAM play activation response: $content");
        },
        sub {
            my $http  = shift;
            my $error = $http->error() || 'unknown error';
            $log->error("Failed to activate RAM play: $error");
        }
    )->get($startUrl);
}

sub getDisplayName { return 'PLUGIN_DAPHILERAMPLAY_NAME' }

1;
