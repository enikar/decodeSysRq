A little toy to decode the value of the file **/proc/sys/kernel/sysrq**
on linux systems.


The documentation how to decode it can be found in the kernel
documentation in **Documentation/admin-guide/sysrq.rst**.
Or if you prefer read online documentation:
<https://www.kernel.org/doc/html/latest/admin-guide/sysrq.html>


I wrote the program in Haskell to practice a bit, but the main reason is
I love Haskell despite of it's often difficult to me to think in
Haskell.


I wrote it as a real program with minimum dependencies (just **base** and
**directory** packages are needed). Maybe at some point I'll choose to use
**optparse-applicative** to manage the command line arguments.


The code is essentially a wrapper around the `decodeSysRq` function.
As describe in kernel documentation the value in the **sysrq** file is a bit
field. The information is coded with 9 bits. The meaning is as follow:

- `sysrq = 0`, deactivate all SysRq commands
- `sysrq = 1`, allow all SysRq commands


For other value it's a bit more complex. It depends on value of bits
from 1 to 8, they are described with power of two, from kernel
documentation:
| power of 2  |             What SysRq commands are allow             |
|-------------|:-----------------------------------------------------:|
| 2 =   0x2   |        enable control of console logging level        |
| 4 =   0x4   |        enable control of keyboard (SAK, unraw)        |
| 8 =   0x8   |       enable debugging dumps of processes etc.        |
| 16 =  0x10  |                  enable sync command                  |
| 32 =  0x20  |               enable remount read-only                |
| 64 =  0x40  | enable signalling of processes (term, kill, oom-kill) |
| 128 =  0x80 |                 allow reboot/poweroff                 |
| 256 = 0x100 |             allow nicing of all RT tasks              |


Well, my first idea was to get a binary representation of `sysrq` value.
Then I thought it is useless. I just need to subtract the greater value
from the table above. Hence I used a foldr. I can stop thinking in term
of fold… at some point maybe I need to begin a therapy coding more in
imperative language… `</joke>`. I let this code in the `decodeSysRq'''`
function.


At the end, I realized there even was a simpler way to get the value
of individual bit. From beginning, I put the above table in an
associative list:


```haskell
authorizations :: [(Int, String)]
authorizations =
  [(2, "enable control of console logging level: a number 0..9")
  ,(4, "enable control keyboard (SAK, unraw): k r")
  ,(8, "enable debugging dumps of processes, etc…")
  ,(16, "enable sync command: s")
  ,(32, "enable remount read-only: u")
  ,(64, "enable signalling processes (term, kill, oom-kill): e i f")
  ,(128, "allow reboot/poweroff: b o")
  ,(256, "allow renicing of all RT tasks: n")
  ]
```

So, it's simple. To get the value of bit 1, I just need to perform a bit
wise `and` between `sysrq` with `2`. The value of bit 2 is an `and`
between `sysrq` and `4`, and so on. I wrote 3 versions that uses this
method which are almost the same.
