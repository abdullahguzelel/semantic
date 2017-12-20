{-# LANGUAGE MultiParamTypeClasses, TypeFamilies #-}
module Control.Monad.Effect.Address where

import Control.Applicative
import Control.Monad ((<=<))
import Control.Monad.Effect.Store
import Control.Monad.Fail
import Data.Abstract.Address
import Data.Abstract.Environment
import Data.Abstract.FreeVariables
import Data.Abstract.Store
import Data.Abstract.Value
import Data.Foldable (asum, toList)
import Data.Pointed
import Data.Semigroup

class (Ord l, Pointed (Cell l), Monad m) => MonadAddress l m where
  deref :: (MonadStore a m, MonadFail m, l ~ LocationFor a) => Address l a -> m a

  alloc :: (MonadStore a m, l ~ LocationFor a) => Name -> m (Address l a)

envLookupOrAlloc' ::
                  ( FreeVariables t
                  , Semigroup (Cell (LocationFor a) a)
                  , MonadStore a m
                  , MonadAddress (LocationFor a) m
                  )
                  => t -> Environment (LocationFor a) a -> a -> m (Name, Address (LocationFor a) a)
envLookupOrAlloc' term = let [name] = toList (freeVariables term) in
                         envLookupOrAlloc name

envLookupOrAlloc ::
                 ( Semigroup (Cell (LocationFor a) a)
                 , MonadStore a m
                 , MonadAddress (LocationFor a) m
                 )
                 => Name -> Environment (LocationFor a) a -> a -> m (Name, Address (LocationFor a) a)
envLookupOrAlloc name env v = do
  a <- maybe (alloc name) pure (envLookup name env)
  assign a v
  pure (name, a)


instance Monad m => MonadAddress Precise m where
  deref = maybe uninitializedAddress (pure . unLatest) <=< flip fmap getStore . storeLookup

  alloc _ = fmap allocPrecise getStore
    where allocPrecise :: Store Precise a -> Address Precise a
          allocPrecise = Address . Precise . storeSize


instance (Alternative m, Monad m) => MonadAddress Monovariant m where
  deref = asum . maybe [] (map pure . toList) <=< flip fmap getStore . storeLookup

  alloc = pure . Address . Monovariant


uninitializedAddress :: MonadFail m => m a
uninitializedAddress = Control.Monad.Fail.fail "uninitialized address"
