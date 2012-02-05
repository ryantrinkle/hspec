{-# LANGUAGE GeneralizedNewtypeDeriving #-}
module Test.Hspec.Formatters.Internal (
  Formatter (..)
, FormatterState (..)
, totalCount
, FormatM
, runFormatM
, increaseSuccessCount
, increasePendingCount
, increaseFailCount
, getFailCount
, addFailMessage
, getSuccessCount
, getPendingCount
, getFailMessages
, getTotalCount
, withNormalColor
, withPassColor
, withPendingColor
, withFailColor
, hPutStr
, hPutStrLn
, restoreFormat
) where

import Test.Hspec.Core
import qualified System.IO as IO
import System.IO (Handle)
import Control.Monad (when)
import System.Console.ANSI
import Control.Monad.Trans.State hiding (gets, modify)
import qualified Control.Monad.Trans.State as State
import Control.Monad.IO.Class

-- | A lifted version of `State.gets`
gets :: (FormatterState -> a) -> FormatM a
gets f = FormatM (State.gets f)

-- | A lifted version of `State.modify`
modify :: (FormatterState -> FormatterState) -> FormatM ()
modify f = FormatM (State.modify f)

data FormatterState = FormatterState {
  stateHandle   :: Handle
, stateUseColor :: Bool
, successCount  :: Int
, pendingCount  :: Int
, failCount     :: Int
, failMessages  :: [String]
}

totalCount :: FormatterState -> Int
totalCount s = successCount s + pendingCount s + failCount s

newtype FormatM a = FormatM (StateT FormatterState IO a)
  deriving (Monad, Functor, MonadIO) -- FIXME: remove MonadIO instance

runFormatM :: Bool -> Handle -> FormatM a -> IO a
runFormatM useColor handle (FormatM action) = evalStateT action (FormatterState handle useColor 0 0 0 [])

increaseSuccessCount :: FormatM ()
increaseSuccessCount = modify $ \s -> s {successCount = succ $ successCount s}

increasePendingCount :: FormatM ()
increasePendingCount = modify $ \s -> s {pendingCount = succ $ pendingCount s}

increaseFailCount :: FormatM ()
increaseFailCount = modify $ \s -> s {failCount = succ $ failCount s}

getSuccessCount :: FormatM Int
getSuccessCount = gets successCount

getPendingCount :: FormatM Int
getPendingCount = gets pendingCount

getFailCount :: FormatM Int
getFailCount = gets failCount

getTotalCount :: FormatM Int
getTotalCount = gets totalCount

addFailMessage :: String -> FormatM ()
addFailMessage err = modify $ \s -> s {failMessages = err : failMessages s}

getFailMessages :: FormatM [String]
getFailMessages = reverse `fmap` gets failMessages

data Formatter = Formatter {
  formatterName       :: String
, exampleGroupStarted :: Spec -> FormatM ()
, examplePassed       :: Spec -> FormatM ()
, exampleFailed       :: Spec -> FormatM ()
, examplePending      :: Spec -> FormatM ()
, errorsFormatter     :: FormatM ()
, footerFormatter     :: Double -> FormatM ()
}

hPutStrLn :: Handle -> String -> FormatM ()
hPutStrLn h = liftIO . IO.hPutStrLn h

hPutStr :: Handle -> String -> FormatM ()
hPutStr h = liftIO . IO.hPutStr h

withFailColor :: (Handle -> FormatM a) -> FormatM a
withFailColor = withColor (SetColor Foreground Dull Red)

withPassColor :: (Handle -> FormatM a) -> FormatM a
withPassColor = withColor (SetColor Foreground Dull Green)

withPendingColor :: (Handle -> FormatM a) -> FormatM a
withPendingColor = withColor (SetColor Foreground Dull Yellow)

withNormalColor :: (Handle -> FormatM a) -> FormatM a
withNormalColor = withColor Reset

-- | Set a color, run an action, and finally reset colors.
withColor :: SGR -> (Handle -> FormatM a) -> FormatM a
withColor color action = do
  useColor <- gets stateUseColor
  h <- gets stateHandle
  when useColor (liftIO $ hSetSGR h [color])
  r <- action h

  -- FIXME:  When action throws an exception, restoreFormat is never called.
  -- We can remedy this by using finally in combination with `monad-control`,
  -- `MonadCatchIO-transformers`, or something.
  when useColor (liftIO $ restoreFormat h)
  return r

restoreFormat :: Handle -> IO ()
restoreFormat h = hSetSGR h [ Reset ]
