package Plugins::DaphileRamPlay::Plugin;
use strict;
use warnings;
use base qw(Slim::Plugin::Base);
use Slim::Control::Request;
use Slim::Player::Playlist;
use Slim::Player::Source;
use Slim::Utils::Log;
use Slim::Utils::Prefs;
use Slim::Utils::Timers;
use JSON::PP ();
use Slim::Networking::SimpleAsyncHTTP;
use URI::Escape qw(uri_escape_utf8 uri_unescape);

my $log = Slim::Utils::Log->addLogCategory({category => 'plugin.daphileramplay', defaultLevel => 'ERROR', description => 'DaphileRamPlay'});
my $prefs = Slim::Utils::Prefs::preferences('plugin.daphileramplay');
my (%original, %pending);
my $installed;

sub initPlugin {
    my $class = shift;
    $class->SUPER::initPlugin(@_);
    $prefs->init({enabled => 1});
    if (main::WEBUI) {
        require Plugins::DaphileRamPlay::Settings;
        Plugins::DaphileRamPlay::Settings->new;
    }
    return if $installed;
    # load_done is emitted AFTER playlist jump. Wrap the documented dispatch
    # entry points instead of racing notifications against the audio stream.
    for my $command (qw(jump index)) {
        $original{$command} = Slim::Control::Request::addDispatch(
            ['playlist', $command, '_index', '_fadein', '_noplay', '_seekdata'],
            [1, 0, 0, \&jumpCommand]);
    }
    $original{play} = Slim::Control::Request::addDispatch(
        ['play', '_fadein'], [1, 0, 0, \&playCommand]);
    $original{pause} = Slim::Control::Request::addDispatch(
        ['pause', '_newvalue', '_fadein', '_suppressShowBriefly'],
        [1, 0, 0, \&playCommand]);
    $installed = 1;
}

sub _localUncached {
    my $url = shift;
    return 0 unless defined $url && length $url;
    $url = uri_unescape($url);
    return 0 if $url =~ m{(?:^|/)RAM Drive/RAM play cache/};
    return $url =~ m{^(?:file://|/)} ? 1 : 0;
}

sub _targetIndex {
    my ($client, $index) = @_;
    my $count = Slim::Player::Playlist::count($client);
    return unless $count;
    $index = 0 unless defined $index;
    return unless $index =~ /^[+-]?\d+$/;
    $index += Slim::Player::Source::playingSongIndex($client) || 0 if $index =~ /^[+-]/;
    return (($index % $count) + $count) % $count;
}

sub jumpCommand {
    my $request = shift;
    my $delegate = $original{$request->getRequest(1)};
    my $client = $request->client;
    return $delegate->($request) unless $client && $prefs->get('enabled');
    return $delegate->($request) if $request->getParam('_noplay');
    my $index = _targetIndex($client, $request->getParam('_index'));
    return $delegate->($request) unless defined $index;
    my $url = Slim::Player::Playlist::url($client, $index);
    # Daphile's own cached-play command MUST pass through, even while busy.
    return $delegate->($request) unless _localUncached($url);
    return _busy($request) if $pending{$client->id};
    # LMS honours _noplay only while stopped. Stop before calling the delegate.
    Slim::Player::Source::playmode($client, 'stop');
    my $oldIndex = $request->getParam('_index');
    my $oldNoPlay = $request->getParam('_noplay');
    $request->addParam('_index', $index);
    $request->addParam('_noplay', 1);
    $delegate->($request);
    defined $oldIndex ? $request->addParam('_index', $oldIndex) : $request->deleteParam('_index');
    defined $oldNoPlay ? $request->addParam('_noplay', $oldNoPlay) : $request->deleteParam('_noplay');
    _start($client);
}

sub playCommand {
    my $request = shift;
    my $command = $request->getRequest(0);
    my $delegate = $original{$command};
    my $client = $request->client;
    return $delegate->($request) unless $client && $prefs->get('enabled');
    my $mode = Slim::Player::Source::playmode($client);
    if ($command eq 'pause') {
        my $value = $request->getParam('_newvalue');
        my $pausing = defined $value ? $value : $mode eq 'play';
        return $delegate->($request) if $pausing;
    }
    return $delegate->($request) if $mode eq 'play';
    my $index = Slim::Player::Source::playingSongIndex($client) || 0;
    return $delegate->($request) unless _localUncached(Slim::Player::Playlist::url($client, $index));
    return _busy($request) if $pending{$client->id};
    # Uncached resume restarts from the beginning. Cached resume remains native.
    # No software-volume changes: keep the bit-perfect output configuration.
    Slim::Player::Source::playmode($client, 'stop');
    $client->execute(['playlist', 'jump', $index, undef, 1]);
    _start($client);
    $request->setStatusDone;
}

sub _busy {
    my $request = shift;
    $log->warn('RAM preparation in progress: rejecting another uncached start');
    $request->setStatusBadConfig;
}

sub _start {
    my $client = shift;
    my $job = $pending{$client->id} = {started => time()};
    _http($client, 'start', sub {
        return unless $pending{$client->id} && $pending{$client->id} == $job;
        _schedule($client);
    }, sub {
        # A timeout does not prove that start was rejected. Never retry start
        # or fall back to audible disk playback on an uncertain outcome.
        $log->error('RAM start failed or timed out; checking server state');
        _schedule($client) if $pending{$client->id} && $pending{$client->id} == $job;
    });
    # Feedback only, after dispatching start. Never gate RAM preparation on UI.
    eval {
        $client->showBriefly({
            line => ['Daphile RAM Play', 'Loading into RAM...'],
            jive => {text => ['Daphile RAM Play', 'Loading into RAM...'], duration => 4},
        }, {duration => 4});
        1;
    };
}

sub _http {
    my ($client, $command, $ok, $error) = @_;
    my $url = 'http://127.0.0.1/cgi-bin/ramplay.json?cmd=' . $command
        . '&player=' . uri_escape_utf8($client->macaddress);
    Slim::Networking::SimpleAsyncHTTP->new($ok, $error, {timeout => 5})->get($url);
}

sub _schedule {
    my $client = shift;
    Slim::Utils::Timers::killTimers($client, \&_poll);
    Slim::Utils::Timers::setTimer($client, time() + 1, \&_poll);
}

sub _poll {
    my $client = shift;
    my $job = $pending{$client->id} || return;
    if (time() - $job->{started} > 1800) {
        $log->error('RAM preparation exceeded 30 minutes; restart the server before retrying');
        return; # retain guard against a second concurrent operation
    }
    _http($client, 'status', sub {
        my $http = shift;
        return unless $pending{$client->id} && $pending{$client->id} == $job;
        my $data = eval { JSON::PP::decode_json($http->content) };
        if (ref($data) eq 'HASH' && defined($data->{status}) && $data->{status} eq 'stop') {
            delete $pending{$client->id};
            # stop means operation idle, NOT that playback is outside RAM.
            # Daphile owns queue replacement and playback. Do not send play.
            return;
        }
        _schedule($client);
    }, sub { _schedule($client) if $pending{$client->id} && $pending{$client->id} == $job });
}

sub getDisplayName { 'PLUGIN_DAPHILERAMPLAY_NAME' }
1;
