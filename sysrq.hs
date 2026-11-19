module Main (main) where

import System.IO
  (readFile'
  ,hPutStrLn
  ,stderr)
import System.Environment (getArgs, getProgName)
import Control.Exception (try)
import Text.Read (readMaybe)
import Data.Foldable (traverse_)
import Data.Bits ((.&.))

-- A type to manage the different behaviours of our program.
data Action = DecodeSysRq Int -- decode /proc/sys/kernel/sysrq
            | ListCommands    -- list all SysRq commands
            | Help            -- show help

main :: IO ()
main = initProg >>= either printError goOn
  where
    printError e = hPutStrLn stderr ("Error: " <> show e)

    goOn (DecodeSysRq sysrq) = printAuths (decodeSysRq sysrq)
    goOn ListCommands        = printCmds commands
    goOn Help                = help


help :: IO ()
help = do
  progName <- getProgName
  let spaces = replicate (length progName) ' '
  putStrLn (progName <> " [options]")
  putStrLn (spaces <> " find out what we can do with SysRq.")
  putStrLn (spaces <> " -l| --list-cmds: list all SysRq commands.")
  putStrLn (spaces <> " -c| --current-options: list current possible actions.")
  putStrLn (spaces <> " -h| --help print this help page.")
  putStrLn "Without argument lists actions we can do with the current value in /proc/sys/kernel/sysrq"

printCmds :: [(String, String)] -> IO ()
printCmds = traverse_ (\(key, command) ->
                             putStrLn (key <> ": " <> command))

printAuths :: [String] -> IO ()
printAuths = traverse_ putStrLn

-- decode using bit wise functions. We are using a list comprehension
-- rather than the combo filter/map, but that makes no difference.
decodeSysRq :: Int -> [String]
decodeSysRq sysrq
  | sysrq == 1 = values authorizations
  | otherwise  = [auth
                 |(key, auth) <- authorizations
                 ,sysrq .&. key /= 0
                 ]

-- Get rid of the keys of an association list.
-- Just keep the values.
values :: [(Int, String)] -> [String]
values = map snd

-- A type to manage errors when parsing the command line
-- and when reading the file sysrq.
data ProgError = NotAnInt String
                |InvalidOption String
                |IOErr String -- in case sysRqFile doesn't exist,
                              -- or it cannot be read.

instance Show ProgError where
  show (NotAnInt s)      = "readSysRq: It's not an Int: " <> s
  show (IOErr s)     =  s
  show (InvalidOption s) = "initProg: invalid option: `"
                           <> s
                           <> "'. Try -h for help."

-- Initialization of the program. We parse the cmdline.
-- and read the sysrq file if there is nothing on cmline.
-- We try to manage nicely errors.
initProg ::  IO (Either ProgError Action)
initProg = do
  args <- getArgs
  case args of
    []  -> readSysRq
    [opt] | opt == "-h"
            || opt == "--help"            -> pure (Right Help)
          | opt == "-l"
            || opt == "--list-cmds"       -> pure (Right ListCommands)
          | opt == "-c"
            || opt == "--current-options" -> readSysRq
          | otherwise                     -> pure (Left (InvalidOption opt))
    xs  -> pure (Left (InvalidOption (unwords xs)))

sysRqFile :: String
sysRqFile = "/proc/sys/kernel/sysrq"

readSysRq :: IO (Either ProgError Action)
readSysRq = either ioErr readInt <$> try (readFile' sysRqFile)
  where
    ioErr :: IOError -> Either ProgError Action
    ioErr = Left . IOErr . show

readInt :: String -> Either ProgError Action
readInt s = maybe (Left (NotAnInt s)) -- signal that s doesn't match an Int.
                  (Right . DecodeSysRq) -- tell to continue with the decoding of sysrq.
                  (readMaybe s)


-- The mapping between the authorization and the bits value expressed as a
-- power of 2 is hard-coded.
-- This mapping can be found in kernel documentation in the file:
-- Documentation/admin-guide/sysrq.rst
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

-- the mapping between keys and the performed commands found in
-- the kernel documentation.
commands :: [(String, String)]
commands =
  [("b", "Will immediately reboot the system without syncing or unmounting your disks.")
  ,("c", "Will perform a system crash and a crashdump will be taken if configured.")
  ,("d", "Shows all locks that are held.")
  ,("e", "Send a SIGTERM to all processes, except for init.")
  ,("f", "Will call the oom killer to kill a memory hog process, but do not panic if nothing can be killed.")
  ,("g", "Used by kgdb (kernel debugger)")
  ,("h", "Will display help (actually any other key than those listed here will display help. but 'h' is easy to remember :-)")
  ,("i", "Send a SIGKILL to all processes, except for init.")
  ,("j", "Forcibly \"Just thaw it\" - filesystems frozen by the FIFREEZE ioctl.")
  ,("k", "Secure Access Key (SAK) Kills all programs on the current virtual console.")
  ,("l", "Shows a stack backtrace for all active CPUs.")
  ,("m", "Will dump current memory info to your console.")
  ,("n", "Used to make RT tasks nice-able")
  ,("o", "Will shut your system off (if configured and supported).")
  ,("p", "Will dump the current registers and flags to your console.")
  ,("q", "Will dump per CPU lists of all armed hrtimers (but NOT regular timer_list timers) and detailed information about all clockevent devices.")
  ,("r", "Turns off keyboard raw mode and sets it to XLATE.")
  ,("s", "Will attempt to sync all mounted filesystems.")
  ,("t", "Will dump a list of current tasks and their information to your console.")
  ,("u", "Will attempt to remount all mounted filesystems read-only.")
  ,("v", "Forcefully restores framebuffer console")
  -- "v": 'Causes ETM buffer dump [ARM-specific]',
  ,("w", "Dumps tasks that are in uninterruptible (blocked) state.")
  -- "x": 'Used by xmon interface on ppc/powerpc platforms. Show global PMU Registers on sparc64. Dump all TLB entries on MIPS.',
  -- "y": 'Show global CPU Registers [SPARC-64 specific]',
  ,("z", "Dump the ftrace buffer")
  ,("0-9", "Sets the console log level, controlling which kernel messages will be printed to your console. ('0', for example would make it so that only emergency messages like PcommaANICs or OOPSes would make it to your console.)")
   ,("R", "Replay the kernel log messages on consoles.")
  ]
