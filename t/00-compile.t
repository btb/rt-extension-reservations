
use strict;
use warnings;

use RT::Extension::Reservations::Test tests => 7;

require_ok("RT::Extension::Reservations");


# no the following doesn't work yet
__END__
use File::Find::Rule;

my @files = File::Find::Rule->file()
    ->name( '*.pm' )
    ->in( 'lib' );

plan tests => scalar @files;

for (@files) {
    local $SIG{__WARN__} = sub {};
    require_ok($_);
}

