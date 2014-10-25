module Test.Hspec.Core.Spec (
-- * Types
  Spec
, Example
, Result (..)
, Item (..)

-- * Defining a spec
, describe
, context
, it
, specify
, example
, pending
, pendingWith
, parallel
, runIO
) where

import qualified Control.Exception as E
import           Test.Hspec.Expectations
import           Test.Hspec.Core.Type

-- | Combine a list of specs into a larger spec.
describe :: String -> Spec -> Spec
describe label spec = runIO (runSpecM spec) >>= fromSpecList . return . specGroup label

-- | An alias for `describe`.
context :: String -> Spec -> Spec
context = describe

-- | Create a spec item.
--
-- A spec item consists of:
--
-- * a textual description of a desired behavior
--
-- * an example for that behavior
--
-- > describe "absolute" $ do
-- >   it "returns a positive number when given a negative number" $
-- >     absolute (-1) == 1
it :: Example a => String -> a -> Spec
it label action = fromSpecList [specItem label action]

-- | An alias for `it`.
specify :: Example a => String -> a -> Spec
specify = it

-- | Run spec items of given `Spec` in parallel.
parallel :: Spec -> Spec
parallel = mapSpecItem $ \item -> item {itemIsParallelizable = True}

-- | This is a type restricted version of `id`.  It can be used to get better
-- error messages on type mismatches.
--
-- Compare e.g.
--
-- > it "exposes some behavior" $ example $ do
-- >   putStrLn
--
-- with
--
-- > it "exposes some behavior" $ do
-- >   putStrLn
example :: Expectation -> Expectation
example = id

-- | Specifies a pending example.
--
-- If you want to textually specify a behavior but do not have an example yet,
-- use this:
--
-- > describe "fancyFormatter" $ do
-- >   it "can format text in a way that everyone likes" $
-- >     pending
pending :: Expectation
pending = E.throwIO (Pending Nothing)

-- | Specifies a pending example with a reason for why it's pending.
--
-- > describe "fancyFormatter" $ do
-- >   it "can format text in a way that everyone likes" $
-- >     pendingWith "waiting for clarification from the designers"
pendingWith :: String -> Expectation
pendingWith = E.throwIO . Pending . Just