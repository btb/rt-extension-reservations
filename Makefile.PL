use inc::Module::Install;

RTx('RT-Extension-Reservations');

all_from('lib/RT/Extension/Reservations.pm');

#requires_rt('4.0.7');

# XXX: This should be reported by M::I::RTx
my ($lib_path) = $INC{'RT.pm'} =~ /^(.*)[\\\/]/;
my $local_lib_path = "$RT::LocalPath/lib";

substitute( {
        RT_LIB_PATH => join( ' ', $local_lib_path, $lib_path ),
    },
    {
        sufix => '.in',
    },
    'lib/RT/Extension/Reservations/Test.pm',
);

WriteAll();
