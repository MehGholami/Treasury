USE [Treasury]
GO
/****** Object:  StoredProcedure [Treasury].[ReceiveReceipt_DepositNotificationDetailInsertHelper]    Script Date: 3/15/2022 9:27:04 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Create the stored procedure in the specified schema
ALTER   PROCEDURE   [Treasury].[ReceiveReceipt_DepositNotificationDetailInsertHelper]
@FinancialTransactionId             UNIQUEIDENTIFIER        ,-- شناسه هدر
@FundId                             UNIQUEIDENTIFIER        ,-- صندوق
@DepositNotificationDetailList      NVARCHAR(MAX)            -- اقلام اعلامیه واریز
AS
BEGIN
  DECLARE @TErrMsg		NVARCHAR(300);
  BEGIN TRY   
        DECLARE  @Trancount   INT 
        SET @TranCount = @@TRANCOUNT
				IF @Trancount = 0 
				BEGIN TRAN ReceiveRequestInsertTrans
						  DECLARE   @UserId               INT       = (SELECT UserId FROM dbo.CurrentUserGet())
              DECLARE   @FinancialAllocateId	SMALLINT  = (SELECT FinancialAllocateID FROM dbo.CurrentUserGet())
				      -------------------------------------------------------------------
							IF  @UserId IS  NULL  OR  NOT  EXISTS  (select * from Treasury.Users where Id = @UserId)
							BEGIN 
									RAISERROR ('کاربر یافت نشد ',18,1)
							END 
							--=============================DepositNotificationDetail=======================----------
              DECLARE @NotificationDetail TABLE (
                    Id                          UNIQUEIDENTIFIER      ,
                    PersonId                     INT                     ,
                    PersonAccountId             UNIQUEIDENTIFIER NULL ,TransactionOperationId       UNIQUEIDENTIFIER        ,
                    VariableFactorId            UNIQUEIDENTIFIER      ,Amount                       DECIMAL(32, 6)          ,
                    AmountInOperatingCurrency   DECIMAL(32, 6)        ,
                    CurrencyId                  SMALLINT              ,CurrencyChangeRate           DECIMAL(32, 6)      NULL,
                    [Description]                NVARCHAR(500)       NULL,
                    -------------------
                    AccountId                   UNIQUEIDENTIFIER      ,DepositNotificationNumber    NVARCHAR(50)      ,
                    DepositNotificationDate     DATETIME
              );
              ---------------------------------insert-------------------------------------
              INSERT INTO @NotificationDetail(
                    Id                                    ,
                    PersonId                              ,
                    PersonAccountId                       ,TransactionOperationId         ,
                    VariableFactorId                      ,Amount                         ,
                    AmountInOperatingCurrency             ,
                    CurrencyId                            ,CurrencyChangeRate             ,
                    [Description]                         ,
                    AccountId                             ,DepositNotificationNumber      ,
                    DepositNotificationDate              
              )  
							SELECT      
                    NEWID()                               ,
                    PersonId                              ,
                    PersonAccountId                       ,TransactionOperationId         ,
                    VariableFactorId                      ,Amount                         ,
                    AmountInOperatingCurrency             ,
                    CurrencyId                            ,CurrencyChangeRate             ,
                    [Description]                         ,
                    AccountId                             ,DepositNotificationNumber      ,
                    DepositNotificationDate       
							FROM
              OPENJSON(@DepositNotificationDetailList)
              WITH (
                    PersonId                     INT                     ,
                    PersonAccountId             UNIQUEIDENTIFIER      ,TransactionOperationId       UNIQUEIDENTIFIER        ,
                    VariableFactorId            UNIQUEIDENTIFIER      ,Amount                       DECIMAL(32, 6)          ,
                    AmountInOperatingCurrency   DECIMAL(32, 6)        ,
                    CurrencyId                  SMALLINT              ,CurrencyChangeRate           DECIMAL(32, 6)          ,
                    [Description]                NVARCHAR(500)           ,
                    AccountId                   UNIQUEIDENTIFIER      ,DepositNotificationNumber    NVARCHAR(50)            ,
                    DepositNotificationDate     DATETIME
                   ) 
              -------------------------------validation-----------------------------------
              IF EXISTS(SELECT * from @NotificationDetail where PersonId IS NULL
                                                        OR
                                                        NOT EXISTS( SELECT Id 
                                                                    FROM TREASURY.Persons 
                                                                    WHERE Id = PersonId)
                        )
									RAISERROR ('طرف مقابل در یکی از اقلام اعلامیه واریز اشتباه است',18,1)
              ---------------------------------------------------------------------------------
              IF EXISTS(SELECT * from @NotificationDetail where PersonAccountId IS NOT NULL
                                                        AND
                                                        NOT EXISTS( SELECT Id 
                                                                    FROM TREASURY.PersonAccount 
                                                                    WHERE Id = PersonAccountId)
                        )
									RAISERROR ('حساب طرف مقابل در یکی از اقلام اعلامیه واریز اشتباه است',18,1)
              ---------------------------------------------------------------------------------
              IF EXISTS(SELECT * from @NotificationDetail where TransactionOperationId IS NULL
                                                        OR
                                                        NOT EXISTS( SELECT Id 
                                                                    FROM TREASURY.TransactionOperation 
                                                                    WHERE Id = TransactionOperationId AND IsAccountingOperation = 1)
                        )
									RAISERROR ('عملیات حسابداری در یکی از اقلام اعلامیه واریز اشتباه است',18,1)
              ---------------------------------------------------------------------------------
              IF EXISTS(SELECT * from @NotificationDetail where VariableFactorId IS NULL
                                                        OR
                                                        NOT EXISTS( SELECT Id 
                                                                    FROM TREASURY.TransactionOperation 
                                                                    WHERE Id = VariableFactorId AND IsAccountingOperation = 0)
                        )
									RAISERROR ('عامل گردش نقدینگی در یکی از اقلام اعلامیه واریز اشتباه است',18,1)
              ---------------------------------------------------------------------------------
              IF EXISTS   ( SELECT * 
                            FROM @NotificationDetail
                                LEFT JOIN Treasury.TransactionOperation T ON 
                                                                          T.Id = TransactionOperationId
                                                                          AND
                                                                          T.IsAccountingOperation = 1
                                                                          AND
                                                                          T.ItemKind = 2
                            WHERE t.Id IS NULL
                          )
									RAISERROR (' عملیاتی حسابداری در یکی از اقلام اعلامیه واریز اشتباه است، دقت کنید که این عملیات باید برای این بخش تعریف شده باشد',18,1)
              ---------------------------------------------------------------------------------
              IF EXISTS   ( SELECT * 
                            FROM @NotificationDetail
                                LEFT JOIN Treasury.TransactionOperation T ON 
                                                                          T.Id = VariableFactorId
                                                                          AND
                                                                          T.IsAccountingOperation = 0
                                                                          AND
                                                                          T.ShowInReceiveOperation = 1
                            WHERE t.Id IS NULL
                          )
									RAISERROR (' عامل گردش نقدینگی در یکی از اقلام اعلامیه واریز اشتباه است، دقت کنید که این عامل باید برای این بخش تعریف شده باشد',18,1)
              ---------------------------------------------------------------------------------
              IF EXISTS(SELECT * from @NotificationDetail where DepositNotificationDate IS NULL)
									RAISERROR ('تاربخ اعلامیه واریز در یکی از اقلام اشتباه است',18,1)
              ---------------------------------------------------------------------------------
              IF EXISTS(SELECT * from @NotificationDetail where Amount IS NULL
                                                        OR
                                                        Amount < 0
                        )
									RAISERROR ('مبلغ در یکی از اقلام اعلامیه واریز اشتباه است',18,1)
              ---------------------------------------------------------------------------------
              -- IF EXISTS(SELECT * from @NotificationDetail where AmountInOperatingCurrency IS NULL
              --                                           OR
              --                                           AmountInOperatingCurrency < 0
              --           )
							-- 		RAISERROR ('مبلغ به ارز عملیاتی در یکی از اقلام اعلامیه واریز اشتباه است',18,1)
              ---------------------------------------------------------------------------------
              IF EXISTS(SELECT * from @NotificationDetail C where C.CurrencyId IS NULL
                                                        OR
                                                        NOT EXISTS( SELECT CurrencyID 
                                                                    FROM TavanaR2.dbo.Currency 
                                                                    WHERE CurrencyID = C.CurrencyId 
                                                                  )
                        )
									RAISERROR (' ارز در یکی از اقلام اعلامیه واریز اشتباه است',18,1)
              ---------------------------------------------------------------------------------
              IF EXISTS(SELECT * from @NotificationDetail where CurrencyId NOT IN (SELECT CurrencyId FROM Treasury.FundEstablishment WHERE FundId = @FundId ) )
							    RAISERROR ('نوع ارز انتخاب شده در یکی از اقلام اعلامیه واریز در این صندوق استفاده نمیشود',18,1)
              ---------------------------------------------------------------------------------
              UPDATE @NotificationDetail SET CurrencyChangeRate = 1 WHERE CurrencyChangeRate IS NULL
                                                        OR
                                                        CurrencyChangeRate < 0
              ------================================== SPECIAL VALIDATION ========================---------
              IF EXISTS(SELECT * from @NotificationDetail where AccountId IS NULL
                                                        OR
                                                        NOT EXISTS( SELECT Id 
                                                                    FROM Treasury.Account 
                                                                    WHERE Id = AccountId 
                                                                  )
                        )
									RAISERROR (' حساب بانکی در یکی از اقلام اعلامیه واریز اشتباه است',18,1)
              ---------------------------------------------------------------------------------------------
              IF EXISTS(SELECT * from @NotificationDetail where ISNULL(DepositNotificationNumber,'') = ''
                        )
									RAISERROR (' شماره اعلامیه واریز در یکی از اقلام اعلامیه واریز اشتباه است',18,1)
              ---------------------------------------------------------------------------------------------
              IF EXISTS(SELECT * from @NotificationDetail where DepositNotificationDate IS NULL)
									RAISERROR (' تاریخ اعلامیه واریز در یکی از اقلام اعلامیه واریز اشتباه است',18,1)
              ---------------------------------------------------------------------------------------------
              ----------------------------------------delete from table-------------------------
              DECLARE @oldDetailIds TABLE (Id UNIQUEIDENTIFIER NOT NULL);
              INSERT INTO @oldDetailIds (Id)
              SELECT FD.Id 
              FROM Treasury.FinancialTransactionDetail FD
                    INNER JOIN Treasury.FinancialTransactionBankDetail FBD ON FBD.FinancialTransactionDetailId = FD.Id
              WHERE FinancialTransactionId = @FinancialTransactionId

              DELETE FROM Treasury.FinancialTransactionBankDetail 
              WHERE FinancialTransactionDetailId IN (
                                                      SELECT e.Id Id 
                                                      FROM Treasury.FinancialTransactionDetail e
                                                      WHERE e.Id IN (SELECT o.Id FROM @oldDetailIds o ) 
                                                    )

              DELETE FROM Treasury.FinancialTransactionDetail WHERE Id IN (SELECT o.Id FROM @oldDetailIds o)
              ----------------------------------insert into table-------------------------
              INSERT INTO Treasury.FinancialTransactionDetail (
                  Id                              ,FinancialTransactionId                 ,PersonId                       ,
                  PersonAccountId                 ,TransactionOperationId                 ,VariableFactorId               ,
                  Amount                          ,AmountInOperatingCurrency              ,
                  CurrencyId                      ,CurrencyChangeRate                     ,
                  [Description]                   ,CreatedDate                            ,CreatorUserId                  ,
                  LastUpdateDate                  ,LastUpdateUserId
              ) 
              SELECT 
                  Id                              ,@FinancialTransactionId                ,PersonId                       ,
                  PersonAccountId                 ,TransactionOperationId                 ,VariableFactorId               ,
                  Amount                          ,AmountInOperatingCurrency              ,
                  CurrencyId                      ,CurrencyChangeRate                     ,
                  [Description]                   ,GETDATE()                              ,@UserId                        ,
                  GETDATE()                       ,@UserId       
              FROM @NotificationDetail 
              -------------------------------------------
              INSERT INTO Treasury.FinancialTransactionBankDetail (
                  Id                          ,FinancialTransactionDetailId    ,AccountId  ,
                  DepositNotificationNumber   ,DepositNotificationDate       
                ) 
              SELECT 
                  NEWID()                     ,Id FinancialTransactionDetailId ,AccountId  ,
                  DepositNotificationNumber   ,DepositNotificationDate
              FROM @NotificationDetail 
              ----==================================================================-----------
        IF @Trancount = 0 
        COMMIT TRAN  ReceiveRequestInsertTrans
  END TRY 
  BEGIN CATCH
			SET @TErrMsg = ( SELECT ERROR_MESSAGE())
			IF @Trancount = 0 
			 ROLLBACK TRAN ReceiveRequestInsertTrans
			RAISERROR (@TErrMsg,18,1)
		--	RETURN 
   END CATCH  
END

