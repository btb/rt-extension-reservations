
use strict;
use warnings;

use lib 't/lib';
use RT::Extension::Reservations::Test tests => undef;


{

use_ok ('RT::Queue');
ok(my $testqueue = RT::Queue->new(RT->SystemUser));
ok($testqueue->Create( Name => 'reservation tests', Lifecycle => 'reservations' ));
isnt($testqueue->Id , 0);
is($testqueue->Lifecycle->Name, 'reservations');


use_ok ('RTx::AssetTracker::Type');
ok(my $testtype = RTx::AssetTracker::Type->new(RT->SystemUser));
ok($testtype->Create( Name => 'reservable assets' ));
isnt($testtype->Id , 0);


}

{

ok(require RT::Ticket, "Loading the RT::Ticket library");
ok(require RTx::AssetTracker::Asset, "Loading the RT::Ticket library");

}


{

my $asset = RTx::AssetTracker::Asset->new(RT->SystemUser);
my ($id, $tid, $msg)= $asset->Create(Type => 'reservable assets',
            Name => 'test asset');
ok($id, $msg);


my $ticket1 = RT::Ticket->new(RT->SystemUser);
($id, $tid, $msg)= $ticket1->Create(Queue => 'reservation tests',
            Subject => 'reservation 1');
ok($id, $msg);
is($ticket1->Status, 'tentative', "New ticket is created as tentative");

($id, $msg) = $ticket1->SetStatus('booked');
ok(!$id, $msg);
like($msg, qr/must be in the future/i, "Status message is correct");

my $date = RT::Date->new(RT->SystemUser);
$date->Set( Format => 'unknown', Value => 'tomorrow' );
($id, $msg) = $ticket1->SetStarts($date->ISO);
ok($id, $msg);
($id, $msg) = $ticket1->SetStatus('out');
ok(!$id, $msg);
like($msg, qr/must be after/i, "Status message is correct");
$date->Set( Format => 'unknown', Value => '+1 week' );
($id, $msg) = $ticket1->SetDue($date->ISO);
ok($id, $msg);
($id, $msg) = $ticket1->SetStatus('out');
ok(!$id, $msg);
like($msg, qr/No referred asset/i, "Status message is correct");


($id, $msg) = $ticket1->AddLink( Type => 'RefersTo', Target => $asset->URI );
ok($id, $msg);

($id, $msg) = $ticket1->SetStatus('booked');
ok($id, $msg);
like($msg, qr/changed/i, "Status message is correct");

($id, $msg) = $ticket1->SetStatus('returned');
ok(!$id,$msg);
like($msg, qr/can't change/i, "Status message is correct");

($id, $msg) = $ticket1->SetStatus('cancelled');
ok($id, $msg);
like($msg, qr/Status changed/i, "Status message is correct");


my $ticket2 = RT::Ticket->new(RT->SystemUser);
($id, $tid, $msg)= $ticket2->Create(Queue => 'reservation tests',
            Subject => 'reservation 2');
ok($id, $msg);
is($ticket2->Status, 'tentative', "New ticket is created as tentative");

$date->Set( Format => 'unknown', Value => 'tomorrow' );
($id, $msg) = $ticket2->SetStarts($date->ISO);
ok($id, $msg);
$date->Set( Format => 'unknown', Value => '+1 week' );
($id, $msg) = $ticket2->SetDue($date->ISO);
ok($id, $msg);

($id, $msg) = $ticket2->AddLink( Type => 'RefersTo', Target => $asset->URI );
ok($id, $msg);

($id, $msg) = $ticket2->SetStatus('booked');
ok($id, $msg);
like($msg, qr/Status changed/i, "Status message is correct");


my $ticket3 = RT::Ticket->new(RT->SystemUser);
($id, $tid, $msg)= $ticket3->Create(Queue => 'reservation tests',
            Subject => 'reservation 2');
ok($id, $msg);
is($ticket3->Status, 'tentative', "New ticket is created as tentative");

$date->Set( Format => 'unknown', Value => 'tomorrow' );
($id, $msg) = $ticket3->SetStarts($date->ISO);
ok($id, $msg);
$date->Set( Format => 'unknown', Value => '+1 week' );
($id, $msg) = $ticket3->SetDue($date->ISO);
ok($id, $msg);

($id, $msg) = $ticket3->AddLink( Type => 'RefersTo', Target => $asset->URI );
ok($id, $msg);

($id, $msg) = $ticket3->SetStatus('booked');
ok(!$id, $msg);
like($msg, qr/already reserved/i, "Status message is correct");

$date->Set( Format => 'unknown', Value => '+3 days' );
($id, $msg) = $ticket2->SetDue($date->ISO);
ok($id, "Ticket " . $ticket2->Id . ": $msg");

$date->Set( Format => 'unknown', Value => '+4 days' );
($id, $msg) = $ticket3->SetStarts($date->ISO);
ok($id, "Ticket " . $ticket3->Id . ": $msg");

($id, $msg) = $ticket3->SetStatus('booked');
ok($id, $msg);
like($msg, qr/Status changed/i, "Status message is correct");



}


done_testing;
