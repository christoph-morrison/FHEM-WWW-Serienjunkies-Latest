# Remarks

This is a somewhat special test: I wanted to test a new approach for defining modules more CPAN-style and capsulated.

So in [FHEM/](FHEM/) (the legacy library path) just exists a very [minimal loader](FHEM/98_Serienjunkies.pm) for legacy loading a module. The loader dispatches the module initialization to [FHEM::WWW:Serienjunkies](lib/FHEM/WWW/Serienjunkies.pm).

Surprisingly, this works and supports the common idioms from the legacy module development.

See als the [list](reverse-engineering/device-list.md) for the testing device for further entertainment.