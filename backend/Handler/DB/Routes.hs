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
{-# LANGUAGE ViewPatterns #-}
{-# OPTIONS_GHC -fno-warn-overlapping-patterns #-}
{-# OPTIONS_GHC -fno-warn-orphans #-}
{-# OPTIONS_GHC -fno-warn-unused-do-bind #-}
module Handler.DB.Routes where
import Prelude (const)
import Handler.DB.Enums
import Handler.DB.Esqueleto
import Handler.DB.Internal
import Handler.DB.RouteFiles
import Handler.DB.RouteFilesFile
import Handler.DB.RouteFileusergroupcontents
import Handler.DB.RouteUsergroupcontents
import Handler.DB.RouteUsergroups
import Handler.DB.RouteUsergroupsUserGroup
import Handler.DB.RouteUsergroupitems
import Handler.DB.RouteUsergroupitemsUserGroupItem
import Handler.DB.RouteUsers
import Handler.DB.RouteUsersUser
import Handler.DB.RouteVersions
import Handler.DB.RouteTransferreceipts
import Handler.DB.RouteReceipts
import Handler.DB.RouteReceiptsReceipt
import Handler.DB.RouteProcessperiods
import Handler.DB.RouteProcessperiodsProcessPeriod
import Handler.DB.RouteSettings

import Yesod.Auth (requireAuth, requireAuthId, YesodAuth, AuthId, YesodAuthPersist)
import Yesod.Core
import Yesod.Persist (runDB, YesodPersist, YesodPersistBackend)


getDB :: a -> DB
getDB = const DB

mkYesodSubData "DB" [parseRoutes|
/files        FilesR      GET
/files/#FileId        FilesFileIdR      GET PUT DELETE
/fileusergroupcontents        FileusergroupcontentsR      DELETE POST
/usergroupcontents        UsergroupcontentsR      GET
/usergroups        UsergroupsR      GET POST
/usergroups/#UserGroupId        UsergroupsUserGroupIdR      PUT DELETE
/usergroupitems        UsergroupitemsR      GET POST
/usergroupitems/#UserGroupItemId        UsergroupitemsUserGroupItemIdR      DELETE
/users        UsersR      GET POST
/users/#UserId        UsersUserIdR      GET DELETE PUT
/versions        VersionsR      GET
/transferreceipts        TransferreceiptsR      POST
/receipts        ReceiptsR      GET POST
/receipts/#ReceiptId        ReceiptsReceiptIdR      GET DELETE PUT
/processperiods        ProcessperiodsR      GET
/processperiods/#ProcessPeriodId        ProcessperiodsProcessPeriodIdR      POST
/settings        SettingsR      POST
|]

