use inc::Module::Install;

name     'FCGI-EV-Std';
all_from 'lib/FCGI/EV/Std.pm';
author   'Alex Efros <powerman-asdf@ya.ru>';
license  'perl';

requires 'version';

build_requires 'Test::More';

auto_install;

WriteAll;

