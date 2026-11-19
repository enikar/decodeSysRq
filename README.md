A little toy to decode the value of the file **/proc/sys/kernel/sysrq**
on linux systems.


The documentation how to decode it can be found in the kernel
documentation in **Documentation/admin-guide/sysrq.rst**.
Or if you prefer read online documentation:
<https://www.kernel.org/doc/html/latest/admin-guide/sysrq.html>


I wrote the program in Haskell to practice a bit, but the main reason is
I love Haskell despite of I feel difficult to think in Haskell.


I wrote it as a real program with minimum dependencies (just **base**).
Maybe at some point I'll choose to use **optparse-applicative** to
manage the command line arguments.


The code is essentially a wrapper around the `decodeSysRq` function.
As describe in kernel documentation the value in the **sysrq** file is a bit
field. The information is coded with 9 bits. The meaning is as follow:

- `sysrq = 0`, deactivate all SysRq commands
- `sysrq = 1`, allow all SysRq commands


For other value it's a bit more complex. It depends on value of bits
from 1 to 8, they are described as power of two, from kernel
documentation:
| power of 2  |            What SysRq commands are allows             |
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
Then I thought it is useless. I just need to try subtract successively
value from the table above beginning with greater one. So I began with
`256`, if `sysrq >= 256`, I subtracted `256` from `sysrq`, add which is
allowed to a list of authorizations. Then continue with `128` and so on.
Hence I used a `foldr`. I can't stop thinking in term of fold… at some
point maybe I need to begin a therapy coding more in imperative
language… `</joke>`.


At the end, I realized there even was a simpler way to get the value
of individual bit. From the beginning, I put the above table in an
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
between `sysrq` and `4`, and so on.
The code of the function uses a list comprehension:
```haskell
decodeSysRq :: Int -> [String]
decodeSysRq sysrq
  | sysrq == 1 = values authorizations
  | otherwise  = [auth
                 |(key, auth) <- authorizations
                 ,sysrq .&. key /= 0
                 ]
```
I named the power of two, `key`, and the string which describe
authorization `auth`. We filter the pair `(key, auth)` retaining only
pairs for which `sysrq .&. key` is different from zero. The operator
`.&.` is the bit wise **and** in Haskell. Finally, we just build a list
of `auth`s.

The values function is just:
```haskell
values :: [(Int, String)] -> [String]
values = map snd
```
That is, we are keeping the second element of each pair.


The program accept some options

- -h or -- help : get a help message
- -c or --current-options : list what are current options with the
  current value in the **sysrq** file.
- -l or -- list-cmds : list all SysRq commands

When no argument is supplied, that acts as with the option `-c`.

I wrote a separate function to parse the command line `initProg` which
yields `Either` a `ProgError` or an `Action`.

`ProgError` is the type I use to report an error during initialization.
Either, the **sysrq** file was not found, either there was an invalid
option pass to the program or the content of the **sysrq** file was not
an Int.

`Action` is the type used to drive the program.
Either we `decodeSysRq`, either we list all **SysRq** commands or we
print the help page.
