USE [Treasury]
GO
/****** Object:  StoredProcedure [Treasury].[ReceiveRequest_Insert_POST]    Script Date: 3/15/2022 9:27:57 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Create the stored procedure in the specified schema
ALTER   PROCEDURE   [Treasury].[ReceiveRequest_Insert_POST]
	      @Code														BIGINT                     ,    
	    	@ReceiveRequestDate						  DATETIME                   ,
				@PersonId												INT												 ,
				@CurrencyId											SMALLINT									 ,
				@BranchId												INT												 ,
				@PersonAccountId								UNIQUEIDENTIFIER   = NULL  ,
				@TreasuryOtherObjectId					SMALLINT           = NULL  ,
				@BaseDocumentDate								DATE               = NULL  ,
				@BaseDocumentNumber							UNIQUEIDENTIFIER   = NULL  ,
				@BaseDocumentAmount							DECIMAL(32,6)      = NULL  ,
				@BaseDocumentRemainRequestable  DECIMAL(32,6)      = NULL  ,
				@Description							      NVARCHAR(200)      = NULL  ,
				@NoteId													UNIQUEIDENTIFIER           ,
				@StatusId												SMALLINT                   ,
				@ClearingDate                   DATETIME           = NULL  ,
				@ReceiveRequestDetailList       NVARCHAR(MAX)

AS
BEGIN
  
  DECLARE @TErrMsg		NVARCHAR(300);
  BEGIN TRY   
        DECLARE  @Trancount   INT 
        SET @TranCount = @@TRANCOUNT
				IF @Trancount = 0 
				BEGIN TRAN ReceiveRequestInsertTrans
				 
						  DECLARE
							    @UserId               INT     ,@FinancialAllocateId						SMALLINT                                          
						  SET @UserId              = (SELECT UserId FROM dbo.CurrentUserGet())
							SET @FinancialAllocateId = (SELECT FinancialAllocateID FROM dbo.CurrentUserGet())
				     -----------------------------------------------------------------
							IF  @UserId IS  NULL  OR  NOT  EXISTS  (select * from Treasury.Users where Id = @UserId)
							BEGIN 
									RAISERROR ('کاربر یافت نشد ',18,1)
							END 
							----------------------------------------------------------------
							IF  ISNULL(@StatusId ,0) = 0 
							BEGIN 
									RAISERROR ('وضعیت نمی تواند خالی باشد ',18,1)
							END 
							-----------------------------------------------------------------
							IF  ISNULL(@Code ,0) = 0 
							BEGIN 
									RAISERROR ('کد نمی تواند خالی باشد ',18,1)
							END 
							-----------------------------------------------------------------
							IF EXISTS  (SELECT * FROM Treasury.ReceiveRequest WHERE Code = @Code AND FinancialAllocateId = @FinancialAllocateId )
							BEGIN 
							    RAISERROR (' کد نمی تواند تکراری باشد  ',18,1)
							END 
							-----------------------------------------------------------------
    					IF  ISNULL(@ReceiveRequestDate,'') = ''
							BEGIN 
									RAISERROR ('تاریخ درخواست  نمی تواند خالی باشد ',18,1)
							END 
							-----------------------------------------------------------------
							IF  ISNULL(@PersonId ,0) = 0
							BEGIN 
									RAISERROR ('طرف مقابل نمی تواند خالی باشد ',18,1)
							END 
							-----------------------------------------------------------------
							IF  ISNULL(@CurrencyId ,0) = 0 
							BEGIN 
									RAISERROR ('نوع ارز نمی تواند خالی باشد ',18,1)
							END 
							-----------------------------------------------------------------
							IF  ISNULL(@BranchId,0) = 0 
							BEGIN 
									RAISERROR ('شعبه نمی تواند خالی باشد ',18,1)
							END 
							-----------------------------------------------------------------
							IF @ReceiveRequestDetailList IS NULL 
							BEGIN 
							    RAISERROR (' لیست اقلام خالی نمی تواند باشد ',18,1)
							END 
							------------------------------------------------------------------
							IF @FinancialAllocateId IS NULL 
							BEGIN 
							    RAISERROR (' دوره مالی  خالی نمی تواند باشد ',18,1)
							END 
							------------------------------------------------------------------
							
							--================================================================--
							IF @StatusId NOT IN (1,2) -- SELECT * FROM Treasury.ReceiveRequestStaus
							BEGIN 
									RAISERROR ('کد وضعیت معتبر نمی باشد  ',18,1)
							END 
							-----------------------------------------------------------------
							IF ISJSON(@ReceiveRequestDetailList) <=0
							BEGIN
							    RAISERROR(' لیست اقلام معتبر نمی باشد ',18,1)
							END 
							-----------------------------------------------------------------
							IF @FinancialAllocateId NOT IN (SELECT FinancialAllocateID FROM TavanaR2.dbo.FinancialAllocate)
							BEGIN 
							    RAISERROR (' دوره مالی معتبر نمی باشد ',18,1)
							END 
							-----------------------------------------------------------------
							IF EXISTS (SELECT FinancialAllocateID 
							           FROM TavanaR2.dbo.FinancialAllocate 
							           WHERE FinancialAllocateID = @FinancialAllocateId
                               AND 
															 ( FinancialAllocateEndDate < @ReceiveRequestDate
                                 OR
                                 FinancialAllocateStartDate > @ReceiveRequestDate
                               )
									     )
							BEGIN
                  DECLARE  @StartDate NVARCHAR(50) = ( SELECT Treasury.getShamsiDate(FinancialAllocateStartDate) 
                                                      FROM TavanaR2.dbo.FinancialAllocate 
                                                      where FinancialAllocateID = @FinancialAllocateId
                                                    )
                  DECLARE  @EndDate NVARCHAR(50) = ( SELECT Treasury.getShamsiDate(FinancialAllocateEndDate) 
                                                      FROM TavanaR2.dbo.FinancialAllocate 
                                                      where FinancialAllocateID = @FinancialAllocateId
                                                    ) 
                  DECLARE @Msg NVARCHAR(200) = concat('تاریخ درخواست اشتباه است ، توجه کنید که تاریخ درخواست باید در بازه ',@StartDate,' تا ',@EndDate, ' میباشد ')
							    RAISERROR(@Msg, 18, 1)
							END 
							-----------------------------------------------------------------
							IF @PersonId NOT IN (SELECT Id FROM Treasury.Persons)
							BEGIN 
							    RAISERROR (' شخص معتبر نمی باشد ',18,1)
							END 
							------------------------------------------------------------------
							IF @CurrencyId NOT IN (SELECT Id FROM Treasury.Currency)
							BEGIN 
							    RAISERROR (' نوع ارز معتبر نمی باشد ',18,1)
							END 
							------------------------------------------------------------------
							IF @PersonAccountId IS NOT NULL AND NOT EXISTS (SELECT Id FROM Treasury.PersonAccount WHERE Id = @PersonAccountId AND PERSONID = @PersonId)
							BEGIN 
							    RAISERROR ('حساب انتخاب شده برای طرف مقابل معتبر نیست',18,1)
							END 
							------------------------------------------------------------------
							IF @TreasuryOtherObjectId is not null 
							BEGIN 
                  IF @TreasuryOtherObjectId NOT IN (SELECT Id FROM Treasury.TreasuryOtherObject WHERE TreasuryObjectId = 1)
							      RAISERROR (' نوع مبنا معتبر نمی باشد ',18,1)
							END
              ELSE 
              BEGIN
                  SET @BaseDocumentAmount = null
                  SET @BaseDocumentNumber = null
                  SET @BaseDocumentDate = null
              END
							------------------------------------------------------------------
							IF @BranchId NOT IN (SELECT Id FROM Treasury.Branch )
							BEGIN 
							    RAISERROR (' شعبه معتبر نمی باشد ',18,1)
							END 
							------------------------------------------------------------------
							------==============================================================------
							DECLARE @RequestDetail TABLE (DetailKindId            TINYINT          , Amount         DECIMAL(32,6) ,
							                              ReceiveDate             DATETIME         , ReceiveDueDate  DATETIME   , [Description]  NVARCHAR(500), 
																						StatusId                SMALLINT         
							                             )
							INSERT INTO @RequestDetail
							           (DetailKindId           , Amount       ,
							            ReceiveDate            , ReceiveDueDate , [Description] ,
							            StatusId
							           )
							SELECT      DetailKindId           , Amount       ,
							            ReceiveDate            , ReceiveDueDate , [Description] ,
							            StatusId
							FROM
              OPENJSON(@ReceiveRequestDetailList)
              WITH (
                    DetailKindId            TINYINT          , Amount         DECIMAL(32,6) ,
							      ReceiveDate             DATETIME         , ReceiveDueDate  DATETIME   , [Description]  NVARCHAR(500) , 
										StatusId                SMALLINT  
                   ) 
							----------------------------------------------------------------------
							IF EXISTS (SELECT * FROM @RequestDetail WHERE DetailKindId  IS NULL OR DetailKindId not in (select Id from ReceiveRequestDetailKind) )
							BEGIN 
							    RAISERROR(' نوع قلم نمی تواند خالی باشد  ',18,1)
							END 
							------------------------------------------------------------------
							IF EXISTS (SELECT * FROM @RequestDetail WHERE  Amount  IS NULL )
							BEGIN 
							    RAISERROR(' مبلغ نمی تواند خالی باشد  ',18,1)
							END 
							------------------------------------------------------------------
							IF EXISTS (SELECT * FROM @RequestDetail WHERE ReceiveDate  IS NULL )
							BEGIN 
							    RAISERROR(' تاریخ درخواست قلم نمی تواند خالی باشد  ',18,1)
							END 
							------------------------------------------------------------------
							IF EXISTS (SELECT * FROM @RequestDetail WHERE ReceiveDueDate  IS NULL )
							BEGIN 
							    RAISERROR(' تاریخ سررسید قلم نمی تواند خالی باشد  ',18,1)
							END 
							------------------------------------------------------------------
							IF EXISTS ( SELECT * FROM @RequestDetail WHERE  @ReceiveRequestDate < ReceiveDate)
							BEGIN 
							    RAISERROR (' تاریخ دریافت باید کوچکتر یا مساوی تاریخ درخواست باشد ',18,1)
							END 
							-------------------------------------------------------------------
							IF EXISTS (SELECT * FROM @RequestDetail WHERE ReceiveDueDate  < ReceiveDate )
							BEGIN 
							    RAISERROR(' تاریخ سررسید  نمی تواند از تاریخ دریافت کوچکتر باشد  ',18,1)
							END 
							------------------------------------------------------------------
              IF @StatusId IS NULL set @StatusId = 1 
              IF @StatusId = 2 
              BEGIN
                  UPDATE @RequestDetail set StatusId = 2
              END
              IF NOT EXISTS ( SELECT * FROM @RequestDetail WHERE StatusId = 1)
                  SET @StatusId = 2
              ------------------------------------------------------------------

							DECLARE @OutId UNIQUEIDENTIFIER;
							SET @OutId = NEWID();
							INSERT INTO Treasury.ReceiveRequest
							           (Id              , Code                  , ReceiveRequestDate , PersonId           , CurrencyID         , BranchId                      ,
							            PersonAccountId , TreasuryOtherObjectId , BaseDocumentDate   , BaseDocumentNumber , BaseDocumentAmount , BaseDocumentRemainRequestable ,
							            [Description]   , CreatedDate           , CreatorUserId      , LastUpdateDate     , LastUpdateUserId   , FinancialAllocateId           ,
							            NoteId          , ClearingDate          , StatusId
							           )
							VALUES
							          ( @OutId           , @Code                  , @ReceiveRequestDate , @PersonId           , @CurrencyID         , @BranchId                      ,
							            @PersonAccountId , @TreasuryOtherObjectId , @BaseDocumentDate   , @BaseDocumentNumber , @BaseDocumentAmount , @BaseDocumentRemainRequestable ,
							            @Description     , GETDATE()              , @UserId             , GETDATE()           , @UserId             , @FinancialAllocateId           ,
							            @NoteId          , @ClearingDate          , @StatusId
							          )
							--===============================================================--
							INSERT INTO Treasury.ReceiveRequestDetail
							           (Id                , ReceiveRequestId       , DetailKindId    , Amount      , ReceiveDate   , ReceiveDueDate,
							            [Description]     , ReceiveRequestStatusId , UseableRemain   , CreatedDate , CreatorUserId , LastUpdateDate,
							            LastUpdateUserId
							          )
							SELECT 
							            NEWID()           , @OutId                 , DetailKindId    , Amount      , ReceiveDate   , ReceiveDueDate,
							            [Description]     , StatusId               , Amount          , GETDATE()   , @UserId       , GETDATE()       ,
							            @UserId
							FROM @RequestDetail
						
        SELECT 2 AS [outputType],'NEW' AS [name] ;
		    SELECT * from Treasury.ReceiveRequest WHERE Id = @OutId
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

