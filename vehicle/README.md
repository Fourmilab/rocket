# Fourmilab Vehicle Scripts

This directory tree contains the scripts for the Fourmilab Rocket and
its UFO alternative vehicle.  The scripts, written in Linden Scripting
Language (LSL), include special comments which allow a common set of
scripts to support multiple vehicles.  The generic scripts are stored
in the `source` directory and may be configured for any of the specific
vehicles supported.

The generic scripts are configured for a specific vehicle with the
`lslconf.pl` utility, a Perl program included in this directory.  It
reads a configuration file containing variable settings which control
conditional compilation of code within the generic scripts.  Complete
documentation of `lslconf.pl` is included as comments in its source
code.

Configurations for the two vehicles included in the distribution are
supplied in the files:

    *   rocket.lslc
    *   ufo.lslc

Generation of the specific scripts is usually performed using the
`Makefile` in this directory, with targets:

    *   rocket          Build rocket scripts
    *   lint_rocket     Check rocket scripts with lslint
    *   ufo             Build UFO scripts
    *   lint_ufo        Check UFO scripts with lslint

Once the scripts have been generated, they are copied into the scripts
of the corresponding objects within Second Life by copying and pasting
into the viewer's Script Editor window.

Note that the scripts are in the UTF-8 character set and may be wrecked
is edited or processed with a utility which does not preserve that
character set.

If you modify the scripts within Second Life, be sure to copy your 
modified version(s) back to the `source` directory here lest your 
changes be lost if you re-generate them.  Files in the `source` 
directory may be configured for any specific vehicle: `lslconf.pl` 
doesn't cart about the initial specific configuration of its generic 
input files.
