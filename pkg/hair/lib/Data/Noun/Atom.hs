{-# LANGUAGE MagicHash, GeneralizedNewtypeDeriving, UnboxedTuples #-}

module Data.Noun.Atom where

import ClassyPrelude
import Control.Lens
-- import Prelude ((^))
import GHC.Integer.GMP.Internals
import GHC.Natural
import GHC.Prim
import GHC.Word
import GHC.Int
import Data.Bits
import Test.QuickCheck.Arbitrary
import Test.QuickCheck.Gen
import Text.Printf

--------------------------------------------------------------------------------

newtype Atom = MkAtom Natural
  deriving newtype (Eq, Ord, Num, Bits, Enum, Real, Integral)

instance Show Atom where
  show (MkAtom a) = show a

{-
  An Atom with a bit-offset.
-}
data Cursor = Cursor
    { _cOffset :: {-# UNPACK #-} !Int
    , _cBuffer :: {-# UNPACK #-} !Atom
    }
  deriving (Eq, Ord, Show)

data Slice = Slice
    { _sOffset :: {-# UNPACK #-} !Int
    , _sWidth  :: {-# UNPACK #-} !Int
    , _sBuffer :: {-# UNPACK #-} !Atom
    }
  deriving (Eq, Ord, Show)

makeLenses ''Cursor
makeLenses ''Slice


-- Instances -------------------------------------------------------------------

instance Arbitrary Natural where
  arbitrary = fromInteger . abs <$> arbitrary

instance Arbitrary Atom where
  arbitrary = MkAtom <$> arbitrary


-- Conversion ------------------------------------------------------------------

class IsAtom a where
  toAtom   :: a -> Atom
  fromAtom :: Atom -> a

instance IsAtom Natural where
  toAtom              = MkAtom
  fromAtom (MkAtom a) = a

instance IsAtom Word where
  toAtom   = fromIntegral
  fromAtom = fromIntegral

instance IsAtom Int where
  toAtom   = fromIntegral
  fromAtom = fromIntegral

instance IsAtom Integer where
  toAtom   = fromIntegral
  fromAtom = fromIntegral


--------------------------------------------------------------------------------

{-
  TODO Support 32-bit archetectures.
-}

wordBitWidth :: Word# -> Word#
wordBitWidth w = minusWord# 64## (clz# w)

bigNatBitWidth :: BigNat -> Word#
bigNatBitWidth nat =
    lswBits `plusWord#` ((int2Word# lastIdx) `timesWord#` 64##)
  where
    (# lastIdx, _ #) = subIntC# (sizeofBigNat# nat) 1#
    lswBits          = wordBitWidth (indexBigNat# nat lastIdx)

bitWidth :: Atom -> Int
bitWidth (MkAtom (NatS# gl)) = I# (word2Int# (wordBitWidth gl))
bitWidth (MkAtom (NatJ# bn)) = I# (word2Int# (bigNatBitWidth bn))


--------------------------------------------------------------------------------

cursor :: Atom -> Atom -> Cursor
cursor offset buf = Cursor (fromIntegral offset) buf

fromCursor :: Cursor -> Atom
fromCursor (Cursor off buf) = shiftR buf off

bumpCursor :: Word -> Cursor -> Cursor
bumpCursor off = over cOffset (+ fromIntegral off)


--------------------------------------------------------------------------------

slice :: (Atom, Atom) -> Atom -> Atom
slice (offset, size) buf =
  fromSlice (Slice (fromAtom offset) (fromAtom size) buf)

fromSlice :: Slice -> Atom
fromSlice (Slice off wid buf) = mask .&. (shiftR buf off)
  where mask = shiftL (MkAtom 1) wid - 1


--------------------------------------------------------------------------------

takeBits :: Int -> Atom -> Atom
takeBits wid buf = mask .&. buf
  where mask = shiftL (MkAtom 1) wid - 1

bitIdx :: Int -> Atom -> Bool
bitIdx idx buf = testBit buf idx

bitConcat :: Atom -> Atom -> Atom
bitConcat x y = x .|. shiftL y (bitWidth x)


-- Bit Buffers -----------------------------------------------------------------

data Buf = Buf !Int !Atom

instance Show Buf where
  show (Buf sz bits) = "0b"
                    <> replicate (sz - bitWidth bits) '0'
                    <> printf "%b (%d bits)" (toInteger bits) sz

instance Semigroup Buf where
  Buf xSz xBuf <> Buf ySz yBuf = Buf (xSz+ySz) (xBuf .|. shiftL yBuf xSz)

instance Monoid Buf where
  mempty = Buf 0 0

instance IsAtom Buf where
  toAtom (Buf _ bits) = bits
  fromAtom bits = Buf (bitWidth bits) bits
