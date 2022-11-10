{-| = ACTUS contract state initialization per t0
The implementation is a transliteration of the ACTUS specification v1.1
Note: initial states rely also on some schedules (and vice versa)
-}

module Actus.Model.StateInitialization
  ( initializeState
  ) where

import Prelude

import Actus.Domain (CEGE(..), CT(..), ContractState(..), ContractTerms(..), Cycle(..), FEB(..), IPCB(..), PRF(..), SCEF(..), sign)
import Actus.Model.StateTransition (CtxSTF(..))
import Actus.Utility (annuity, generateRecurrentSchedule, inf, sup, yearFraction)
import Control.Alt ((<|>))
import Control.Monad.Reader (Reader, asks)
import Data.List (List(..), dropEnd, length, singleton, tail, zipWith, (:))
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Ring (class Ring, zero)
import Data.Semiring (one)

{-# ANN module "HLint: ignore Use camelCase" #-}

-- |'initializeState' initializes the state variables at t0 based on the
-- provided context
initializeState :: forall a. EuclideanRing a => Reader (CtxSTF a) (ContractState a)
initializeState = asks initializeState'
  where
    initializeState' :: forall a. EuclideanRing a => CtxSTF a -> ContractState a
    initializeState' ctx =
      ContractState
        { sd: t0,
          prnxt: nextPrincipalRedemptionPayment ctx.contractTerms,
          ipcb: interestPaymentCalculationBase ctx.contractTerms,
          tmd: ctx.maturity,
          nt: notionalPrincipal ctx.contractTerms,
          ipnr: nominalInterestRate ctx.contractTerms,
          ipac: interestAccrued ctx.contractTerms,
          ipla: Nothing,
          feac: feeAccrued ctx.contractTerms,
          nsc: notionalScaling ctx.contractTerms,
          isc: interestScaling ctx.contractTerms,
          prf: contractPerformance ctx.contractTerms
        }
      where
        ContractTerms ct = ctx.contractTerms
        t0 = ct.statusDate

        tMinusFP = fromMaybe t0 (sup ctx.fpSchedule t0)
        tPlusFP = fromMaybe t0 (inf ctx.fpSchedule t0)
        tMinusIP = fromMaybe t0 (sup ctx.ipSchedule t0)

        scalingEffect_xNx :: SCEF -> Boolean
        scalingEffect_xNx SE_ONO = true
        scalingEffect_xNx SE_ONM = true
        scalingEffect_xNx SE_INO = true
        scalingEffect_xNx SE_INM = true
        scalingEffect_xNx _      = false

        scalingEffect_Ixx :: SCEF -> Boolean
        scalingEffect_Ixx SE_INO = true
        scalingEffect_Ixx SE_INM = true
        scalingEffect_Ixx SE_IOO = true
        scalingEffect_Ixx SE_IOM = true
        scalingEffect_Ixx _      = false

        interestScaling
          (ContractTerms
            { scalingEffect: Just scef,
              interestScalingMultiplier: Just scip
            }) | scalingEffect_Ixx scef = scip
        interestScaling _ = one

        notionalScaling
          (ContractTerms
            { scalingEffect: Just scef,
              notionalScalingMultiplier: Just scnt
            }) | scalingEffect_xNx scef = scnt
        notionalScaling _ = one

        notionalPrincipal
          (ContractTerms
            { initialExchangeDate: Just ied
            }) | ied > t0 = zero
        notionalPrincipal
          ct@(ContractTerms
            { notionalPrincipal: Just nt,
              contractRole
            }) = sign contractRole * nt
        notionalPrincipal _ = zero

        nominalInterestRate
          (ContractTerms
            { initialExchangeDate: Just ied
            }) | ied > t0 = zero
        nominalInterestRate
          (ContractTerms
            { nominalInterestRate: Just ipnr
            }) =
            ipnr
        nominalInterestRate _ = zero

        interestAccrued
          (ContractTerms
            { nominalInterestRate: Nothing
            }) = zero
        interestAccrued
          (ContractTerms
            { accruedInterest: Just ipac
            }) = ipac
        interestAccrued
          (ContractTerms
            { dayCountConvention: Just dcc
            }) =
            let nt = notionalPrincipal ctx.contractTerms
                ipnr = nominalInterestRate ctx.contractTerms
             in yearFraction dcc tMinusIP t0 ctx.maturity * nt * ipnr
        interestAccrued _ = zero

        nextPrincipalRedemptionPayment (ContractTerms {contractType: PAM}) = zero
        nextPrincipalRedemptionPayment (ContractTerms {nextPrincipalRedemptionPayment: Just prnxt}) = prnxt
-- FIXME
--         nextPrincipalRedemptionPayment
--           (ContractTerms
--             { contractType: LAM,
--               nextPrincipalRedemptionPayment: Nothing,
--               maturityDate: Just md,
--               notionalPrincipal: Just nt,
--               cycleOfPrincipalRedemption: Just prcl,
--               cycleAnchorDateOfPrincipalRedemption: Just pranx,
--               scheduleConfig
--             }) = nt / (length $ generateRecurrentSchedule pranx (prcl {includeEndDay: true}) md scheduleConfig) 
        nextPrincipalRedemptionPayment
          (ContractTerms
            { contractType: ANN,
              nextPrincipalRedemptionPayment: Nothing,
              accruedInterest: Just ipac,
              maturityDate: md,
              notionalPrincipal: Just nt,
              nominalInterestRate: Just ipnr,
              dayCountConvention: Just dcc
            }) =
            let scale = nt + ipac
                frac = annuity ipnr ti
             in frac * scale
            where
              prDates = ctx.prSchedule ++ maybeToList ctx.maturity
              ti = zipWith (\tn tm -> yearFraction dcc tn tm md) prDates (dropEnd 1 prDates)
        nextPrincipalRedemptionPayment _ = zero

        interestPaymentCalculationBase
          (ContractTerms
            { contractType: LAM,
              initialExchangeDate: Just ied
            }) | t0 < ied = zero
        interestPaymentCalculationBase
          ct@(ContractTerms
            { notionalPrincipal: Just nt,
              interestCalculationBase: Just ipcb,
              contractRole
            }) | ipcb == IPCB_NT = sign contractRole * nt
        interestPaymentCalculationBase
          ct@(ContractTerms
            { interestCalculationBaseA: Just ipcba,
              contractRole
            }) = sign contractRole * ipcba
        interestPaymentCalculationBase _ = zero

        feeAccrued
          (ContractTerms
            { feeRate: Nothing
            }) = zero
        feeAccrued
          (ContractTerms
            { feeAccrued: Just feac
            }) = feac
        feeAccrued
          (ContractTerms
            { feeBasis: Just FEB_N,
              dayCountConvention: Just dcc,
              feeRate: Just fer,
              notionalPrincipal: Just nt,
              maturityDate: md
            }) = yearFraction dcc tMinusFP t0 md * nt * fer
        feeAccrued
          (ContractTerms
            { dayCountConvention: Just dcc,
              feeRate: Just fer,
              maturityDate: md
            }) = yearFraction dcc tMinusFP t0 md / yearFraction dcc tMinusFP tPlusFP md * fer
        feeAccrued _ = zero

        contractPerformance (ContractTerms {contractPerformance: Just prf}) = prf
        contractPerformance _                                             = PRF_PF

append' :: forall a. List a -> List a -> List a
append' Nil ys = ys
append' (x:xs) ys = x : (append' xs ys)

infixl 8 append' as ++

maybeToList :: forall a. Maybe a -> List a
maybeToList (Just x) = singleton x
maybeToList Nothing = mempty
