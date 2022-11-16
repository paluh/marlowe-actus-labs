module Actus.Domain
  ( module Actus.Domain.BusinessEvents
  , module Actus.Domain.ContractState
  , module Actus.Domain.ContractTerms
  , module Actus.Domain.Schedule
  , class ActusFrac
  , _ceiling
  , _abs
  , _max
  , _min
  , class ActusOps
  , CashFlow(..)
  , RiskFactors(..)
  , setDefaultContractTermValues
  , sign
  , marloweFixedPoint
  , Value'(..)
  , Observation'(..)
  ) where

import Prelude

import Actus.Domain.BusinessEvents (EventType(..))
import Actus.Domain.ContractState (ContractState(..))
import Actus.Domain.ContractTerms (BDC(..), CEGE(..), CETC(..), CR(..), CT(..), Calendar(..), ContractTerms(..), Cycle, DCC(..), DS(..), EOMC(..), FEB(..), IPCB(..), OPTP(..), OPXT(..), PPEF(..), PRF(..), PYTP(..), Period(..), SCEF(..), ScheduleConfig, Stub(..))
import Actus.Domain.Schedule (ShiftedDay, ShiftedSchedule, mkShiftedDay)
import Control.Alt ((<|>))
import Data.BigInt.Argonaut (BigInt, abs, fromInt, quot, rem)
import Data.DateTime (DateTime)
import Data.Int (ceil)
import Data.Maybe (Maybe(..))
import Data.Number as Number
import Data.Ord (signum)
import Data.Show.Generic (genericShow)
import Data.Generic.Rep (class Generic)

class ActusOps a <= ActusFrac a where
  _ceiling :: a -> Int

class ActusOps a where
  _min :: a -> a -> a
  _max :: a -> a -> a
  _abs :: a -> a

instance ActusOps Number where
  _min = min
  _max = max
  _abs = Number.abs

instance ActusFrac Number where
  _ceiling = ceil

data Value'
  = Constant' BigInt
  | NegValue' Value'
  | AddValue' Value' Value'
  | SubValue' Value' Value'
  | MulValue' Value' Value'
  | Cond' Observation' Value' Value'

data Observation'
  = AndObs' Observation' Observation'
  | OrObs' Observation' Observation'
  | NotObs' Observation'
  | ValueGE' Value' Value'
  | ValueGT' Value' Value'
  | ValueLT' Value' Value'
  | ValueLE' Value' Value'
  | ValueEQ' Value' Value'
  | TrueObs'
  | FalseObs'

instance Semiring Value' where
  add x y = AddValue' x y
  mul x y = division (MulValue' x y) (Constant' marloweFixedPoint)
  one = Constant' marloweFixedPoint
  zero = Constant' (fromInt 0)

instance Ring Value' where
  sub x y = SubValue' x y

instance CommutativeRing Value'

instance EuclideanRing Value' where
  degree _ = 1
  div = division -- different rounding, not using DivValue
  mod x y = Constant' $ evalVal x `mod` evalVal y

instance ActusOps Value' where
  _min x y = Cond' (ValueLT' x y) x y
  _max x y = Cond' (ValueGT' x y) x y
  _abs a = _max a (NegValue' a)
    where
    _max x y = Cond' (ValueGT' x y) x y

instance ActusFrac Value' where
  _ceiling _ = 0 -- FIXME

marloweFixedPoint :: BigInt
marloweFixedPoint = fromInt 1000000

division :: Value' -> Value' -> Value'
division lhs rhs =
  do
    let
      n = evalVal lhs
      d = evalVal rhs
    Constant' (division' n d)
  where
  division' :: BigInt -> BigInt -> BigInt
  division' x _ | x == fromInt 0 = fromInt 0
  division' _ y | y == fromInt 0 = fromInt 0
  division' n d =
    let
      q = n `quot` d
      r = n `rem` d
      ar = abs r * (fromInt 2)
      ad = abs d
    in
      if ar < ad then q -- reminder < 1/2
      else if ar > ad then q + signum n * signum d -- reminder > 1/2
      else
        let -- reminder == 1/2
          qIsEven = q `rem` (fromInt 2) == (fromInt 0)
        in
          if qIsEven then q else q + signum n * signum d

evalVal :: Value' -> BigInt
evalVal (Constant' n) = n
evalVal (NegValue' n) = -evalVal n
evalVal (AddValue' a b) = (evalVal a) + (evalVal b)
evalVal (SubValue' a b) = (evalVal a) - (evalVal b)
evalVal (MulValue' a b) = (evalVal a) * (evalVal b)
evalVal (Cond' o a b)
  | evalObs o = evalVal a
  | otherwise = evalVal b

evalObs :: Observation' -> Boolean
evalObs (AndObs' a b) = evalObs a && evalObs b
evalObs (OrObs' a b) = evalObs a || evalObs b
evalObs (NotObs' a) = not $ evalObs a
evalObs (ValueGE' a b) = evalVal a >= evalVal b
evalObs (ValueGT' a b) = evalVal a > evalVal b
evalObs (ValueLT' a b) = evalVal a < evalVal b
evalObs (ValueLE' a b) = evalVal a <= evalVal b
evalObs (ValueEQ' a b) = evalVal a == evalVal b
evalObs TrueObs' = true
evalObs FalseObs' = false

-- | Risk factor observer
data RiskFactors a = RiskFactors
  { o_rf_CURS :: a
  , o_rf_RRMO :: a
  , o_rf_SCMO :: a
  , pp_payoff :: a
  , xd_payoff :: a
  , dv_payoff :: a
  }

-- deriving stock (Show, Generic)
-- deriving anyclass (FromJSON, ToJSON)

-- | Cash flows
data CashFlow a = CashFlow
  { tick :: Int
  , cashParty :: String
  , cashCounterParty :: String
  , cashPaymentDay :: DateTime
  , cashCalculationDay :: DateTime
  , cashEvent :: EventType
  , amount :: a
  , notional :: a
  , cashCurrency :: String
  }

derive instance Generic (CashFlow a) _
instance Show a => Show (CashFlow a) where
  show = genericShow

sign :: forall a. Ring a => CR -> a
sign CR_RPA = one
sign CR_RPL = negate one
sign CR_CLO = one
sign CR_CNO = one
sign CR_COL = one
sign CR_LG = one
sign CR_ST = negate one
sign CR_BUY = one
sign CR_SEL = negate one
sign CR_RFL = one
sign CR_PFL = negate one
sign CR_RF = one
sign CR_PF = negate one

-- == Default instance (Number)

setDefaultContractTermValues :: ContractTerms Number -> ContractTerms Number
setDefaultContractTermValues (ContractTerms ct) = ContractTerms $
  ct
    { scheduleConfig =
        { endOfMonthConvention: applyDefault EOMC_SD ct.scheduleConfig.endOfMonthConvention
        , businessDayConvention: applyDefault BDC_NULL ct.scheduleConfig.businessDayConvention
        , calendar: applyDefault CLDR_NC ct.scheduleConfig.calendar
        }
    , contractPerformance = applyDefault PRF_PF ct.contractPerformance
    , interestCalculationBase = applyDefault IPCB_NT ct.interestCalculationBase
    , premiumDiscountAtIED = applyDefault 0.0 ct.premiumDiscountAtIED
    , scalingEffect = applyDefault SE_OOO ct.scalingEffect
    , penaltyRate = applyDefault 0.0 ct.penaltyRate
    , penaltyType = applyDefault PYTP_O ct.penaltyType
    , prepaymentEffect = applyDefault PPEF_N ct.prepaymentEffect
    , rateSpread = applyDefault 0.0 ct.rateSpread
    , rateMultiplier = applyDefault 1.0 ct.rateMultiplier
    , feeAccrued = applyDefault 0.0 ct.feeAccrued
    , feeRate = applyDefault 0.0 ct.feeRate
    , accruedInterest = applyDefault 0.0 ct.accruedInterest
    , nominalInterestRate = applyDefault 0.0 ct.nominalInterestRate
    , priceAtPurchaseDate = applyDefault 0.0 ct.priceAtPurchaseDate
    , priceAtTerminationDate = applyDefault 0.0 ct.priceAtTerminationDate
    , scalingIndexAtContractDealDate = applyDefault 0.0 ct.scalingIndexAtContractDealDate
    , periodFloor = applyDefault (-infinity) ct.periodFloor
    , periodCap = applyDefault infinity ct.periodCap
    , lifeCap = applyDefault infinity ct.lifeCap
    , lifeFloor = applyDefault (-infinity) ct.lifeFloor
    }
  where
  infinity :: Number
  infinity = 1.0 / 0.0 :: Number

  applyDefault :: forall a. a -> Maybe a -> Maybe a
  applyDefault v o = o <|> Just v
