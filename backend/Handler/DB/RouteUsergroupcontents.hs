{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE DeriveDataTypeable #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE ConstraintKinds #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# OPTIONS_GHC -fno-warn-overlapping-patterns #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# OPTIONS_GHC -fno-warn-unused-do-bind #-}
module Handler.DB.RouteUsergroupcontents where
import Handler.DB.Enums
import Handler.DB.Esqueleto
import Handler.DB.Internal
import Handler.DB.Validation
import qualified Handler.DB.PathPieces as PP
import Prelude
import Database.Esqueleto
import Database.Esqueleto.Internal.Sql (unsafeSqlBinOp)
import qualified Database.Persist as P
import Database.Persist.TH
import Yesod.Auth (requireAuth, requireAuthId, YesodAuth, AuthId, YesodAuthPersist, AuthEntity)
import Yesod.Core hiding (fileName, fileContentType)
import Yesod.Persist (runDB, YesodPersist, YesodPersistBackend)
import Control.Monad (when)
import Data.Aeson ((.:), (.:?), (.!=), FromJSON, parseJSON, decode)
import Data.Aeson.TH
import Data.Int
import Data.Word
import Data.Time
import Data.Text.Encoding (encodeUtf8)
import Data.Typeable (Typeable)
import qualified Data.Attoparsec as AP
import qualified Data.Aeson as A
import qualified Data.Aeson.Types as AT
import qualified Data.ByteString.Lazy as LBS
import Data.Maybe
import qualified Data.Text.Read
import qualified Data.Text as T
import Data.Text (Text)
import qualified Data.List as DL
import Control.Monad (mzero, forM_)
import Control.Monad.Trans.Resource (runResourceT)
import qualified Data.ByteString as B
import qualified Data.ByteString.Lazy as L
import qualified Network.HTTP.Conduit as C
import qualified Network.Wai as W
import Data.Conduit.Lazy (lazyConsume)
import Network.HTTP.Types (status200, status400, status403, status404)
import Blaze.ByteString.Builder.ByteString (fromByteString)
import Control.Applicative ((<$>), (<*>))  
import qualified Data.HashMap.Lazy as HML
import qualified Data.HashMap.Strict as HMS
import Handler.Utils (nonEmpty)
import Handler.Utils (hasWritePerm,hasReadPermMaybe,hasReadPerm)

getUsergroupcontentsR :: forall master. (
    YesodAuthPersist master,
    AuthEntity master ~ User,
    AuthId master ~ Key User,
    YesodPersistBackend master ~ SqlBackend)
    => HandlerT DB (HandlerT master IO) A.Value
getUsergroupcontentsR  = lift $ runDB $ do
    authId <- lift $ requireAuthId
    (filterParam_hideDeleted :: Maybe Text) <- lookupGetParam "hideDeleted"
    defaultFilterParam <- lookupGetParam "filter"
    let defaultFilterJson = (maybe Nothing (decode . LBS.fromChunks . (:[]) . encodeUtf8) defaultFilterParam) :: Maybe [FilterJsonMsg]
    defaultSortParam <- lookupGetParam "sort"
    let defaultSortJson = (maybe Nothing (decode . LBS.fromChunks . (:[]) . encodeUtf8) defaultSortParam) :: Maybe [SortJsonMsg]
    defaultOffsetParam <- lookupGetParam "start"
    defaultLimitParam <- lookupGetParam "limit"
    let defaultOffset = (maybe Nothing PP.fromPathPiece defaultOffsetParam) :: Maybe Int64
    let defaultLimit = (maybe Nothing PP.fromPathPiece defaultLimitParam) :: Maybe Int64
    let baseQuery limitOffsetOrder = from $ \(ugc `InnerJoin` ug) -> do
        on ((ugc ^. UserGroupContentUserGroupId) ==. (ug ^. UserGroupId))
        let ugcId' = ugc ^. UserGroupContentId
        where_ (hasReadPerm (val authId) (ugc ^. UserGroupContentUserGroupId))

        _ <- if limitOffsetOrder
            then do 
                offset 0
                limit 10000
                case defaultSortJson of 
                    Just xs -> mapM_ (\sjm -> case sortJsonMsg_property sjm of
                            "userGroupName" -> case (sortJsonMsg_direction sjm) of 
                                "ASC"  -> orderBy [ asc (ug  ^.  UserGroupName) ] 
                                "DESC" -> orderBy [ desc (ug  ^.  UserGroupName) ] 
                                _      -> return ()
                
                            _ -> return ()
                        ) xs
                    Nothing -> orderBy [  ]

                case defaultOffset of
                    Just o -> offset o
                    Nothing -> return ()
                case defaultLimit of
                    Just l -> limit (min 10000 l)
                    Nothing -> return ()
                 
            else return ()
        case defaultFilterJson of 
            Just xs -> mapM_ (\fjm -> case filterJsonMsg_field_or_property fjm of
                "id" -> case (PP.fromPathPiece $ filterJsonMsg_value fjm) of 
                    (Just v') -> where_ $ defaultFilterOp (filterJsonMsg_comparison fjm) (ugc  ^.  UserGroupContentId) (val v')
                    _        -> return ()
                "current" -> case (PP.fromPathPiece $ filterJsonMsg_value fjm) of 
                    (Just v') -> where_ $ defaultFilterOp (filterJsonMsg_comparison fjm) (ug  ^.  UserGroupCurrent) ((val v'))
                    _        -> return ()
                "name" -> case (PP.fromPathPiece $ filterJsonMsg_value fjm) of 
                    (Just v') -> where_ $ defaultFilterOp (filterJsonMsg_comparison fjm) (ug  ^.  UserGroupName) ((val v'))
                    _        -> return ()
                "userGroupId" -> case (PP.fromPathPiece $ filterJsonMsg_value fjm) of 
                    (Just v') -> where_ $ defaultFilterOp (filterJsonMsg_comparison fjm) (ugc  ^.  UserGroupContentUserGroupId) ((val v'))
                    _        -> return ()
                "fileContentId" -> case (PP.fromPathPiece $ filterJsonMsg_value fjm) of 
                    (Just v') -> where_ $ defaultFilterOp (filterJsonMsg_comparison fjm) (ugc  ^.  UserGroupContentFileContentId) (just ((val v')))
                    _        -> return ()
                "userGroupContentId" -> case (PP.fromPathPiece $ filterJsonMsg_value fjm) of 
                    (Just v') -> where_ $ defaultFilterOp (filterJsonMsg_comparison fjm) (ugc  ^.  UserGroupContentUserGroupContentId) (just ((val v')))
                    _        -> return ()
                "userContentId" -> case (PP.fromPathPiece $ filterJsonMsg_value fjm) of 
                    (Just v') -> where_ $ defaultFilterOp (filterJsonMsg_comparison fjm) (ugc  ^.  UserGroupContentUserContentId) (just ((val v')))
                    _        -> return ()

                _ -> return ()
                ) xs
            Nothing -> return ()  
        if hasDefaultFilter filterParam_hideDeleted defaultFilterJson "hideDeleted" 
            then do 
                 
                where_ $ (ugc ^. UserGroupContentDeletedVersionId) `is` (nothing)
            else return ()
        return (ugc ^. UserGroupContentId, ug ^. UserGroupName)
    count <- select $ do
        baseQuery False
        let countRows' = countRows
        orderBy []
        return $ (countRows' :: SqlExpr (Database.Esqueleto.Value Int))
    results <- select $ baseQuery True
    return $ A.object [
        "totalCount" .= ((\(Database.Esqueleto.Value v) -> (v::Int)) (head count)),
        "result" .= (toJSON $ map (\row -> case row of
                ((Database.Esqueleto.Value f1), (Database.Esqueleto.Value f2)) -> A.object [
                    "id" .= toJSON f1,
                    "userGroupName" .= toJSON f2                                    
                    ]
                _ -> A.object []
            ) results)
       ]