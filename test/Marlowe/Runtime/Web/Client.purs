module Test.Marlowe.Web.Client where

import Prelude

import Contrib.Fetch (FetchError(InvalidStatusCode))
import Control.Monad.Error.Class (catchError, throwError)
import Data.Array (head)
import Data.BigInt.Argonaut as BigInt
import Data.Either (Either(..))
import Data.Map as Map
import Data.Maybe (Maybe(..))
import Data.Newtype (un)
import Data.Time.Duration (Milliseconds(..))
import Debug (traceM)
import Effect.Aff (delay)
import Effect.Class (liftEffect)
import Effect.Exception (throw)
import Language.Marlowe.Core.V1.Semantics.Types (Ada(..))
import Language.Marlowe.Core.V1.Semantics.Types as V1
import Marlowe.Runtime.Web.Client (ClientError(..), foldMapMPages, foldMapMPages', getResource, post, post')
import Marlowe.Runtime.Web.Types (Address(..), ContractsEndpoint(..), GetContractsResponse, Metadata, PostContractsRequest(..), PostContractsResponse(..), ServerURL(..), Tx(..), api)
import Test.Spec (Spec, describe, it)
import Test.Spec.Assertions (fail)

spec :: ServerURL -> Spec Unit
spec serverUrl@(ServerURL serverUrlStr) = do
  describe ("The client" <> serverUrlStr) do
     it "POST contract correctly" do
        let
          -- addr = Address "addr_xvk12wjl5zcq8dd4q7he36667aqvcwm9sjhqpk3vyu625g3tcfex5sckf35hyu3vnhveyqrqvtrvff6m0jqu6xfus5lx5att4h2g7pteqrgu04hjs"
          -- addr = Address "00bf05a62e0a25a1cde8b6f3b5b0d33ea60fde9a9ec8f615169493c7a90f1e33e7772682a03adde020ba989d97339c9b3f32a516aa056a9c7c"
          -- addr = Address "addr1w94f8ywk4fg672xasahtk4t9k6w3aql943uxz5rt62d4dvq8evxaf"
          addr = Address "addr_test1qz4y0hs2kwmlpvwc6xtyq6m27xcd3rx5v95vf89q24a57ux5hr7g3tkp68p0g099tpuf3kyd5g80wwtyhr8klrcgmhasu26qcn"
          req = PostContractsRequest
            { metadata: mempty
            -- , version :: MarloweVersion
            -- , roles :: Maybe RolesConfig
            , contract: V1.Close
            , minUTxODeposit: Lovelace (BigInt.fromInt 2_000_000)
            , changeAddress: addr
            , addresses: [addr]
            , collateralUTxOs: []
            }
        post' serverUrl api req >>= case _ of
          Right ({ resource: PostContractsResponse res, links }) -> do
            traceM res
            pure unit
          Left (FetchError (InvalidStatusCode res)) -> do
            traceM "STATUS CODE ERROR"
            traceM $ res.status
            traceM $ res.statusText
            body <- res.text
            traceM "BODY:"
            traceM body

          Left err -> do
             traceM "Other error"
             traceM err
             pure unit
            -- fail $ "Error: " <> show err

     -- it "GET contracts" do
     --    traceM "TESTING CONTRACTS FETCH"
     --    contracts <- foldMapMPages' serverUrl api (pure <<< _.page) `catchError` \err -> do
     --      traceM $ "ERROR: " <> show err
     --      throwError err
     --    traceM "FETCHED?"
     --    case head <$> contracts of
     --        Right contractHeader -> do
     --          pure unit
     --          -- contract <- fetchContract serverUrl contractHeader.links.contract
     --          -- transactionHeaders <- fetchTransactionHeaders serverUrl contract.links.transactions
     --          -- case head transactionHeaders of
     --          --  Just transactionHeader -> do
     --          --     transaction <- fetchTransaction serverUrl transactionHeader.links.transaction
     --          --     let (Tx tx) = transaction.resource
     --          --     case tx.block of
     --          --            Just _ -> pure unit
     --          --            _ -> fail "Expected block"
     --          --  _ -> fail "Expected transaction"
     --        _ -> fail "Expected contract"
