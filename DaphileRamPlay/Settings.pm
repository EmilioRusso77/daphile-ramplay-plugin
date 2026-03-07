package Plugins::DaphileRamPlay::Settings;

use strict;
use warnings;

use base qw(Slim::Web::Settings);

use Slim::Utils::Prefs;

my $prefs = Slim::Utils::Prefs::preferences('plugin.daphileramplay');

sub name { return Slim::Web::HTTP::CSRF->protectName('PLUGIN_DAPHILERAMPLAY_NAME') }

sub page { return Slim::Web::HTTP::CSRF->protectURI('plugins/DaphileRamPlay/settings/basic.html') }

sub prefs { return ($prefs, qw(enabled delay)) }

1;
