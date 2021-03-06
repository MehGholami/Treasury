USE [Treasury]
GO
/****** Object:  StoredProcedure [Treasury].[ReceiveRequestLink_Insert_POST]    Script Date: 3/15/2022 9:29:59 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- Create the stored procedure in the specified schema
ALTER   PROCEDURE   [Treasury].[ReceiveRequestLink_Insert_POST]
	@ReceiveRequestLinkJSON					    NVARCHAR(MAX)          ,
	/*'[{"ReceiveRequestDetailId":"10","ReceiveDetailId":"25","AllocatedAmount":"450000"},{"ReceiveRequestDetailId":"11","ReceiveDetailId":"546","AllocatedAmount":"65400"}]'*/
	@LinkDate                           DATETIME               ,
	@Description                        NVARCHAR(100 )         ,
	@NoteId															UNIQUEIDENTIFIER
AS
BEGIN
  
  DECLARE @TErrMsg		NVARCHAR(300);
  BEGIN TRY   
        DECLARE  @Trancount   INT 
        SET @TranCount = @@TRANCOUNT
				IF @Trancount = 0 
				BEGIN TRAN RecReqLinkInsertTrans
				 
						  DECLARE
							    @UserId               INT                            
						  SET @UserId = (SELECT UserId FROM dbo.CurrentUserGet())
				     -----------------------------------------------------------------
							IF  @UserId IS  NULL  OR  NOT  EXISTS  (select * from Treasury.Users where Id = @UserId)
							BEGIN 
									RAISERROR ('کاربر یافت نشد ',18,1)
							END 
								
						 -----------------------------------------------------------------
							IF (SELECT COUNT(*) FROM OPENJSON(@ReceiveRequestLinkJSON)) = 0 
					    BEGIN 
					        RAISERROR  (' مقادیر اقلام درخواست دریافت نمی تواند خالی باشند  ',18,1) 
					    END 
							------------------------------------------------------------------
						  ----==========================================================----
							DECLARE @ReceiveRequestLinkList  TABLE  
							       (ReceiveRequestDetailId  UNIQUEIDENTIFIER , ReceiveDetailId      UNIQUEIDENTIFIER , AllocatedAmount DECIMAL(32,6) )
					    INSERT INTO @ReceiveRequestLinkList
					                (ReceiveRequestDetailId , ReceiveDetailId , AllocatedAmount)
					    SELECT       ReceiveRequestDetailId , ReceiveDetailId , AllocatedAmount
					    FROM    OPENJSON (@ReceiveRequestLinkJSON)
					    WITH
							   (ReceiveRequestDetailId  UNIQUEIDENTIFIER , 
								  ReceiveDetailId         UNIQUEIDENTIFIER ,
								  AllocatedAmount         DECIMAL(32,6)
								 ) AS  RRD
              ----==========================================================----
							
              ----=========================================================----
							IF (SELECT COUNT(*)
							    FROM (
							          SELECT   ReceiveRequestDetailId
							          FROM     @ReceiveRequestLinkList 
									      GROUP BY ReceiveRequestDetailId
											 ) T
								 ) > 1 
							    AND
								(SELECT COUNT(*)
							   FROM (
							          SELECT   ReceiveDetailId
							          FROM     @ReceiveRequestLinkList 
									      GROUP BY ReceiveDetailId
											 ) T
								 ) > 1  
						  BEGIN 
							    RAISERROR(' انتخاب همزمان چند قلم درخواست و چند قلم دریافت با هم وجود ندارد ',18,1)
							END
							----------------------------------------------------------------------
							IF EXISTS (SELECT ReceiveRequestDetailId FROM @ReceiveRequestLinkList
							           WHERE ReceiveRequestDetailId NOT IN (SELECT Id  FROM Treasury.ReceiveRequestDetail)
							          ) 
							BEGIN 
							    RAISERROR (' قلم درخواست دارای شناسه نامعتبر می باشد  ',18,1)
							END 
							-------------------------------------------------------------------
							IF EXISTS (SELECT ReceiveDetailId FROM @ReceiveRequestLinkList
							           WHERE  ReceiveDetailId NOT IN (SELECT Id  FROM Treasury.FinancialTransactionDetail)
							          ) 
							BEGIN 
							    RAISERROR (' قلم دریافت دارای شناسه نامعتبر می باشد  ',18,1)
							END 
							-------------------------------------------------------------------
							DECLARE @ReqIdList   TABLE (ReqId           UNIQUEIDENTIFIER      , RequestDetailAmount     DECIMAL(32,6)    , 
							                            AllocatedAmount DECIMAL(32,6)         , RemainAmount            DECIMAL(32,6) 
																				  ) 
							DECLARE @RecIdList   TABLE (RecId                UNIQUEIDENTIFIER , ReceiveDetailAmount  DECIMAL(32,6)    , 
							                            AllocatedAmount      DECIMAL(32,6)   ,	RemainAmount            DECIMAL(32,6) 
																				 )
							-----------------------------------------------------------------
							INSERT INTO      @ReqIdList(ReqId , AllocatedAmount)
							SELECT DISTINCT  ReceiveRequestDetailId,AllocatedAmount  FROM @ReceiveRequestLinkList
							---------------------------------------------------------------------
							INSERT INTO      @RecIdList(RecId , AllocatedAmount)
							SELECT DISTINCT  ReceiveDetailId  , AllocatedAmount  FROM @ReceiveRequestLinkList
							---*************************************************************---
							UPDATE @ReqIdList SET RequestDetailAmount = RDA
							FROM (
							      SELECT Id , Amount RDA FROM Treasury.ReceiveRequestDetail  
										WHERE  Id IN (SELECT ReceiveRequestDetailId  FROM @ReceiveRequestLinkList)
							     )A1
							WHERE A1.Id = [@ReqIdList].ReqId
							------------------------------------------------------------
							UPDATE @ReqIdList SET AllocatedAmount = ISNULL(AllocatedAmount,0) + 
							       TotA FROM 
										          (
															 SELECT   ReceiveRequestDetailId , ISNULL(SUM(AllocatedAmount),0) TotA FROM Treasury.ReceiveRequestLink
															 GROUP BY ReceiveRequestDetailId
															)T
						  WHERE T.ReceiveRequestDetailId = [@ReqIdList].ReqId
							------------------------------------------------------------
							UPDATE @ReqIdList SET RemainAmount = RequestDetailAmount - ISNULL(AllocatedAmount,0) 
							-------------------------------------------------------------
							IF EXISTS (SELECT * FROM @ReqIdList WHERE ISNULL(RemainAmount,0) < 0 )
							BEGIN 
							   RAISERROR(' با تخصیص برخی از مبالغ مانده بعضی از درخواست ها منفی می شود  ',18,1)
							END 
							---*************************************************************---

							UPDATE @RecIdList SET ReceiveDetailAmount = FTD
							FROM (
							      SELECT Id ,  Amount FTD FROM Treasury.FinancialTransactionDetail  
										WHERE Id IN (SELECT ReceiveDetailId  FROM @ReceiveRequestLinkList)
							     )A1
							WHERE A1.Id = [@RecIdList].RecId
							------------------------------------------------------------
							UPDATE @RecIdList SET AllocatedAmount = ISNULL(AllocatedAmount,0) + 
							       TotA FROM 
										          (
															 SELECT   FinancialTransactionDetailId , ISNULL(SUM(AllocatedAmount),0) TotA FROM Treasury.ReceiveRequestLink
															 GROUP BY FinancialTransactionDetailId
															)T
						  WHERE T.FinancialTransactionDetailId = [@RecIdList].RecId
							-----------------------------------------------------------------------
							UPDATE @RecIdList SET RemainAmount = ReceiveDetailAmount - ISNULL(AllocatedAmount,0) 
							-----------------------------------------------------------------------
							IF EXISTS (SELECT * FROM @RecIdList  WHERE ISNULL(RemainAmount,0) < 0 ) 
							BEGIN 
							  RAISERROR (' با تخصیص برخی از مبالغ مانده قابل استفاده برخی از اقلامی منفی میشود ',18,1)
							END 
							---************************************************************---
							/*UPDATE @ReceiveRequestLinkList SET 
							SELECT ReceiveRequestDetailId , ISNULL(SUM(AllocatedAmount),0)  FROM Treasury.ReceiveRequestLink
							WHERE ReceiveRequestDetailId IN (SELECT ReceiveRequestDetailId  FROM @ReceiveRequestLinkList)
							GROUP BY ReceiveRequestDetailId
							*/

              DECLARE @OutId UNIQUEIDENTIFIER;
							SET @OutId = NEWID();
							INSERT INTO Treasury.ReceiveRequestLink
							       ( Id             , ReceiveRequestDetailId , FinancialTransactionDetailId , AllocatedAmount ,
							         LinkDate       , CreatedDate            , UserId                       , [Description]   ,
							         LastUpdateDate , LastUpdateUserId       , NoteId
							       )
							SELECT   @OutId         , ReceiveRequestDetailId , ReceiveDetailId , AllocatedAmount ,
							         @LinkDate      , GETDATE()              , @UserId         , @Description   ,
							         GETDATE()      , @UserId                , @NoteId
						 FROM @ReceiveRequestLinkList
							
        SELECT 2 AS [outputType],'NEW' AS [name] ;
		    SELECT * from Treasury.ReceiveRequestLink WHERE Id = @OutId
        IF @Trancount = 0 
        COMMIT TRAN  RecReqLinkInsertTrans
  END TRY 
  BEGIN CATCH
			SET @TErrMsg = ( SELECT ERROR_MESSAGE())
			IF @Trancount = 0 
			 ROLLBACK TRAN RecReqLinkInsertTrans
			RAISERROR (@TErrMsg,18,1)
		--	RETURN 
   END CATCH  
END

