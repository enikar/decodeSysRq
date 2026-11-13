A little toy to decode the value of "/proc/sys/kernel/sysrq" on linux
systems.

The documentation how to decode it can be found in the kernel
documentation in Documentation/admin-guide/sysrq.rst.
Or if you prefer read online documentation:
https://www.kernel.org/doc/html/latest/admin-guide/sysrq.html

I wrote the program in haskell to practice a bit, but the main reason is
I love haskell despite of it's often difficult to me to think in
haskell.

I wrote it as a real program with minumum dependencies (just base and
directory packages are needed). Maybe at some point I'll choose to use
optparse-applicative to manage the command line arguments.
