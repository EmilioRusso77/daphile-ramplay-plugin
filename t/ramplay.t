use strict;
use warnings;
use Test::More;
use FindBin;
use JSON::PP ();
BEGIN {
    package main; sub WEBUI () { 1 }
    for my $module (qw(Slim/Plugin/Base.pm Slim/Control/Request.pm Slim/Player/Playlist.pm Slim/Player/Source.pm Slim/Utils/Log.pm Slim/Utils/Prefs.pm Slim/Utils/Timers.pm Slim/Networking/SimpleAsyncHTTP.pm Slim/Web/Settings.pm)) { $INC{$module}=1 }
    package Slim::Plugin::Base; sub initPlugin {}
    package Slim::Web::Settings; our $registered=0; sub new { $registered++; bless {}, shift }
    package Slim::Utils::Log; sub addLogCategory { bless {}, 'TestLog' }
    package TestLog; sub error {} sub warn {} sub info {}
    package Slim::Utils::Prefs; our $prefs=bless {enabled=>1}, 'TestPrefs'; sub preferences { $prefs }
    package TestPrefs; sub init {} sub get { $_[0]->{$_[1]} } sub set { $_[0]->{$_[1]}=$_[2] }
    package Slim::Utils::Timers; our @timers;
    sub killTimers { my $c=shift; @timers=grep { $_->[0] != $c } @timers }
    sub setTimer { push @timers, [@_] }
    package Slim::Player::Playlist; sub count { scalar @{$_[0]->{urls}} } sub url { $_[0]->{urls}[$_[1]] }
    package Slim::Player::Source;
    sub playingSongIndex { $_[0]->{index} }
    sub playmode { my ($c,$m)=@_; if (defined $m) { push @{$c->{events}},$m; $c->{mode}=$m } $c->{mode} }
    package Slim::Control::Request;
    our %handlers;
    sub addDispatch { my ($words,$def)=@_; my $key=$words->[0] eq 'playlist' ? $words->[1] : $words->[0]; $handlers{$key}=$def->[3]; return $key =~ /^(jump|index)$/ ? \&nativeJump : \&nativePlay }
    sub nativeJump {
        my $r=shift; my $c=$r->client;
        $c->{index}=$r->getParam('_index') || 0;
        if ($r->getParam('_noplay') && $c->{mode} eq 'stop') { push @{$c->{events}},'select' }
        else { push @{$c->{events}},'audio'; $c->{mode}='play' }
        $r->setStatusDone;
    }
    sub nativePlay { my $r=shift; push @{$r->client->{events}},'native'; $r->setStatusDone }
    package Slim::Networking::SimpleAsyncHTTP;
    our @calls;
    sub new { my ($class,$ok,$err,$options)=@_; bless {ok=>$ok,err=>$err,options=>$options},$class }
    sub get { my ($s,$url)=@_; $s->{url}=$url; push @calls,$s }
    sub content { $_[0]->{body} }
    package TestClient;
    sub showBriefly {
        my ($c,$message,$options)=@_;
        die 'Display unavailable' if $c->{displayFails};
        push @{$c->{messages}}, [$message,$options];
        $c->{httpAtNotice}=scalar @Slim::Networking::SimpleAsyncHTTP::calls;
    }
    sub id { $_[0]->{id} } sub macaddress { '5a:7b:b0:c0:ee:ba' }
    sub execute { my ($c,$args)=@_; my $r=TestRequest->new($c,'playlist',$args->[1],{_index=>$args->[2],_noplay=>$args->[4]}); $Slim::Control::Request::handlers{$args->[1]}->($r) }
    package TestRequest;
    sub new { my ($class,$c,$a,$b,$params)=@_; bless {client=>$c,terms=>[$a,$b],params=>$params||{}},$class }
    sub client { $_[0]->{client} } sub getRequest { $_[0]->{terms}[$_[1]] }
    sub getParam { $_[0]->{params}{$_[1]} } sub addParam { $_[0]->{params}{$_[1]}=$_[2] }
    sub deleteParam { delete $_[0]->{params}{$_[1]} }
    sub setStatusDone { $_[0]->{status}='done' } sub setStatusBadConfig { $_[0]->{status}='busy' }
}
BEGIN { $INC{'Plugins/DaphileRamPlay/Settings.pm'}="$FindBin::Bin/../DaphileRamPlay/Settings.pm" }
require "$FindBin::Bin/../DaphileRamPlay/Settings.pm";
require "$FindBin::Bin/../DaphileRamPlay/Plugin.pm";
Plugins::DaphileRamPlay::Plugin->initPlugin;
is($Slim::Web::Settings::registered,1,'settings handler registered');
my $seq=0;
sub client { bless {id=>++$seq,mode=>'stop',index=>0,urls=>['file:///music/a.flac','file:///music/b.flac'],events=>[],@_},'TestClient' }
sub request { my ($c,$a,$b,$p)=@_; TestRequest->new($c,$a,$b,$p) }
sub jump { my ($c,$i)=@_; my $r=request($c,'playlist','jump',{_index=>$i}); $Slim::Control::Request::handlers{jump}->($r); $r }
sub finish {
    my $c=shift;
    Plugins::DaphileRamPlay::Plugin::_poll($c);
    my $http=$Slim::Networking::SimpleAsyncHTTP::calls[-1];
    $http->{body}='{"status":"stop"}'; $http->{ok}->($http);
}
my $c=client(mode=>'play'); my $r=jump($c,1);
is_deeply($c->{events},['stop','select'],'no audio before RAM start, even from playing state');
is($c->{index},1,'correct track selected');
is($r->getParam('_index'),1,'index restored');
ok(!defined $r->getParam('_noplay'),'temporary flag removed');
like($Slim::Networking::SimpleAsyncHTTP::calls[-1]{url},qr/cmd=start&player=5a%3A7b/,'Daphile start endpoint with escaped MAC');
my $n=@Slim::Networking::SimpleAsyncHTTP::calls;
is(jump($c,1)->{status},'busy','duplicate start refused');
is(scalar @Slim::Networking::SimpleAsyncHTTP::calls,$n,'no duplicate HTTP start');
$c->{urls}[1]='tmp:///srv/mediaserver/music/RAM%20Drive/RAM%20play%20cache/b.wav';
jump($c,1);
is($c->{events}[-1],'audio','cached playback allowed while operation pending');
is(scalar @Slim::Networking::SimpleAsyncHTTP::calls,$n,'cache does not trigger start');
finish($c); jump($c,1);
is(scalar @Slim::Networking::SimpleAsyncHTTP::calls,$n+1,'idle status does not reload cache');
for my $url ('http://radio.example/stream','https://audio.example/a.flac','tmp:///srv/mediaserver/music/RAM Drive/RAM play cache/a.wav') {
    my $x=client(urls=>[$url]); my $before=@Slim::Networking::SimpleAsyncHTTP::calls;
    jump($x,0); is($x->{events}[-1],'audio',"native playback: $url");
    is(scalar @Slim::Networking::SimpleAsyncHTTP::calls,$before,'bypass makes no HTTP call');
}
my $relative=client(index=>1); jump($relative,'-1'); is($relative->{index},0,'relative jump resolved before stop');
my $wrap=client(index=>1); jump($wrap,'+1'); is($wrap->{index},0,'next at end wraps');
my $select=client(); my $selectReq=request($select,'playlist','jump',{_index=>1,_noplay=>1});
$Slim::Control::Request::handlers{jump}->($selectReq);
is_deeply($select->{events},['select'],'noplay stays selection-only');
for my $cmd ('play','pause') {
    my $paused=client(mode=>'pause'); my $req=request($paused,$cmd,undef, $cmd eq 'pause' ? {_newvalue=>0} : {});
    $Slim::Control::Request::handlers{$cmd}->($req);
    is_deeply($paused->{events},['stop','select'],"$cmd cannot resume disk audio");
}
my $paused=client(mode=>'pause',urls=>['tmp:///srv/mediaserver/music/RAM Drive/RAM play cache/a.wav']);
$Slim::Control::Request::handlers{play}->(request($paused,'play'));
is_deeply($paused->{events},['native'],'cached resume delegated');
my $failed=client(); jump($failed,0); my $failedHttp=$Slim::Networking::SimpleAsyncHTTP::calls[-1];
$failedHttp->{err}->($failedHttp);
is_deeply($failed->{events},['stop','select'],'timeout never starts disk audio');
ok(@Slim::Utils::Timers::timers,'uncertain outcome schedules poll');
finish($failed); is_deeply($failed->{events},['stop','select'],'poll completion never issues play');
my $bad=client(); jump($bad,0); Plugins::DaphileRamPlay::Plugin::_poll($bad);
my $badHttp=$Slim::Networking::SimpleAsyncHTTP::calls[-1]; $badHttp->{body}='not JSON'; $badHttp->{ok}->($badHttp);
is(jump($bad,0)->{status},'busy','invalid JSON cannot unlock start');
$Slim::Utils::Prefs::prefs->set('enabled',0);
my $off=client(); jump($off,0); is_deeply($off->{events},['audio'],'disabled delegates');
$Slim::Utils::Prefs::prefs->set('enabled',1);
my $empty=client(urls=>[]); is(Plugins::DaphileRamPlay::Plugin::_targetIndex($empty,0),undef,'empty queue has no target');
my $notice=client(); my $beforeNotice=@Slim::Networking::SimpleAsyncHTTP::calls;
jump($notice,0);
is(scalar @{$notice->{messages}},1,'one initial loading notice');
is($notice->{messages}[0][0]{jive}{text}[1],'Loading into RAM...','controller receives loading text');
is($notice->{httpAtNotice},$beforeNotice+1,'RAM request dispatched before optional UI feedback');
jump($notice,0);
is(scalar @{$notice->{messages}},1,'duplicate play does not repeat notice');
finish($notice);
is(scalar @{$notice->{messages}},1,'poll completion does not repeat notice');
for my $cmd ('jump','play','pause') {
    my $x=client(displayFails=>1); my $before=@Slim::Networking::SimpleAsyncHTTP::calls;
    my $req;
    my $ok=eval {
        if ($cmd eq 'jump') { $req=jump($x,0) }
        else { $req=request($x,$cmd,undef,$cmd eq 'pause' ? {_newvalue=>0} : {}); $Slim::Control::Request::handlers{$cmd}->($req) }
        1;
    };
    ok($ok,"$cmd survives display exception");
    is($req->{status},'done',"$cmd completes despite display exception");
    is_deeply($x->{events},['stop','select'],"$cmd stays silent despite display exception");
    is(scalar @Slim::Networking::SimpleAsyncHTTP::calls,$before+1,"$cmd starts RAM exactly once despite display exception");
    my $http=$Slim::Networking::SimpleAsyncHTTP::calls[-1]; $http->{ok}->($http);
    ok(grep($_->[0] == $x,@Slim::Utils::Timers::timers),"$cmd still schedules status polling");
    is(jump($x,0)->{status},'busy','failure preserves concurrent-start guard');
    finish($x);
    is(jump($x,0)->{status},'done','completion releases guard after failed notice');
}
for my $url ('https://example.org/radio','tmp:///srv/mediaserver/music/RAM Drive/RAM play cache/a.wav') {
    my $x=client(urls=>[$url]); jump($x,0);
    ok(!$x->{messages},'no loading notice for native playback');
}
done_testing();
