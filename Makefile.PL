use inc::Module::Install;

RTx('RT-Extension-Reservations');

all_from('lib/RT/Extension/Reservations.pm');

#requires_rt('4.0.7');

WriteAll();
