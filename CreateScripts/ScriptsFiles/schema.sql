-------------------------- Schema Script -----------------------------

SET NUMERIC_ROUNDABORT OFF
GO
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
IF EXISTS (SELECT * FROM tempdb..sysobjects WHERE id=OBJECT_ID('tempdb..#tmpErrors')) DROP TABLE #tmpErrors
GO
CREATE TABLE #tmpErrors (Error int)
GO
SET XACT_ABORT ON
GO
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
GO
BEGIN TRANSACTION
GO
PRINT N'Altering [dbo].[spSS_getPROYPHRESIA]'
GO
-- =============================================
-- Author:		Pantelis Chatzimichalis
-- Create date: 10-12-2012
-- Description:	Sync HRM PROYPHRESIA Data
-- =============================================
ALTER  PROCEDURE [dbo].[spSS_getPROYPHRESIA] @DT DATETIME AS
BEGIN
--CREATE #T SCHEMA
--declare @dt datetime = getdate();
--2/2/2018 Fixed #T SCHEMA
SELECT CAST(NULL AS int) Vat, CAST(NULL AS int) ID_CMP,
ID_PROYP,	ID_EMP,	PROYP_TYPE,	FROM_DATE,	TO_DATE,	EMPLOYER,	SPC,	ENSHMA,	FR_REASON_EXP,	YEARS_DURATION,	MONTHS_DURATION,	PLASMATIKOI_MHNES
INTO #T FROM dbo.SS_PROYPHRESIA WHERE ID_EMP<0

--FILL #T
DECLARE @qry VARCHAR(2000);

DECLARE @hrmSRV VARCHAR(2000);
DECLARE @hrmdb VARCHAR(2000);
SELECT @hrmdb = p.DbName + '.' + p.DefaultSchema + '.', @hrmSRV = p.SrvSynonym from dbo.SS_Params p

select  @qry = 'INSERT INTO #T SELECT VAT,	ID_CMP,	ID_PROYP,	ID_EMP,	PROYP_TYPE,	FROM_DATE,	TO_DATE,	EMPLOYER,	SPC,	ENSHMA,	FR_REASON_EXP,	YEARS_DURATION,	MONTHS_DURATION,	PLASMATIKOI_MHNES	 FROM OPENQUERY(['+@hrmSRV+'],''SELECT * from ' + @hrmdb + 'fnSS_getPROYPHRESIA_CHANGES(''' +QUOTENAME(convert(varchar, @dt, 120),'''')+ ''')'') ';

--PRINT @qry
EXEC (@qry)
--SELECT * FROM #T
--drop table #t


--SELECT * FROM #t
BEGIN TRAN;
BEGIN TRY
--delete ALL SS PROYPHRESIA for employees changed
DELETE ssRecs
--select *
FROM #t T
JOIN dbo.SS_EMPLOYEE SSEmpRecs ON T.Vat = SSEmpRecs.VAT AND SSEmpRecs.ID_CMP = T.ID_CMP
JOIN dbo.SS_PROYPHRESIA ssRecs ON SSEmpRecs.ID_EMP = ssRecs.ID_EMP;

--insert not existing records
INSERT INTO dbo.SS_PROYPHRESIA
( ID_PROYP ,ID_EMP ,PROYP_TYPE ,FROM_DATE ,TO_DATE ,
EMPLOYER ,SPC ,ENSHMA ,FR_REASON_EXP ,YEARS_DURATION ,MONTHS_DURATION ,
StatusID /*,ProcessDate*/)
SELECT  HRMRecs.ID_PROYP
,SSEmpRecs.ID_EMP
,HRMRecs.PROYP_TYPE
,HRMRecs.FROM_DATE
,HRMRecs.TO_DATE
,HRMRecs.EMPLOYER
,HRMRecs.SPC
,HRMRecs.ENSHMA
,HRMRecs.FR_REASON_EXP
,HRMRecs.YEARS_DURATION
,HRMRecs.MONTHS_DURATION
,1 /*,GETDATE() */
FROM #t HRMRecs
JOIN dbo.SS_EMPLOYEE SSEmpRecs ON HRMRecs.Vat = SSEmpRecs.VAT AND SSEmpRecs.ID_CMP = HRMRecs.ID_CMP

COMMIT TRAN;

DROP TABLE #t
--DELETE FROM CDC_PROYPHRESIA WHERE AuditDate <= @DT;
END TRY
BEGIN CATCH
IF @@TRANCOUNT > 0 ROLLBACK TRAN;

if OBJECT_ID('tempdb..#t') is not null
DROP TABLE #t

INSERT INTO dbo.SS_LogErrors
SELECT GETDATE()
,'Error on line ' + CONVERT(nvarchar(10), ERROR_LINE()) + ': ' + ERROR_MESSAGE()
,ERROR_SEVERITY()
,ERROR_STATE();

END CATCH
END
GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[spSS_getEMP_LANGUAGES]'
GO
-- =============================================
-- Author:		Pantelis Chatzimichalis
-- Create date: 10-12-2012
-- Description:	Sync HRM EMP_LANGUAGES Data
-- =============================================
ALTER  PROCEDURE [dbo].[spSS_getEMP_LANGUAGES] @DT DATETIME AS
BEGIN

--CREATE #T SCHEMA
--declare @dt datetime = getdate();
--2018/2/2 Fixed #T SCHEMA
SELECT CAST(NULL AS int) Vat, CAST(NULL AS int) ID_CMP
,id_emp_lan,id_emp,	LANG,LANG_LEVEL,LANG_DEGREE,LANG_RANK,LANG_LEVEL_TALK,LANG_LEVEL_WRITE
INTO #T FROM dbo.SS_EMP_LANGUAGES WHERE ID_EMP<0

--FILL #T
DECLARE @qry VARCHAR(2000);

DECLARE @hrmSRV VARCHAR(2000);
DECLARE @hrmdb VARCHAR(2000);
SELECT @hrmdb = p.DbName + '.' + p.DefaultSchema + '.', @hrmSRV = p.SrvSynonym from dbo.SS_Params p

select  @qry = 'INSERT INTO #T SELECT VAT,ID_CMP,id_emp_lan,id_emp,LANG,LANG_LEVEL,LANG_DEGREE,LANG_RANK,LANG_LEVEL_TALK,LANG_LEVEL_WRITE FROM OPENQUERY(['+@hrmSRV+'],''SELECT * from ' + @hrmdb + 'fnSS_getEMP_LANGUAGES_CHANGES(''' +QUOTENAME(convert(varchar, @dt, 120),'''')+ ''')'') ';
--PRINT @qry
EXEC (@qry)
--SELECT * FROM #T
--drop table #t


--SELECT * FROM #t
BEGIN TRAN;
BEGIN TRY
--delete ALL SS EMP_LANGUAGES for employees changed
DELETE ssRecs
--select *
FROM #t T
JOIN dbo.SS_EMPLOYEE SSEmpRecs ON T.Vat = SSEmpRecs.VAT AND SSEmpRecs.ID_CMP = T.ID_CMP
JOIN dbo.SS_EMP_LANGUAGES ssRecs ON SSEmpRecs.ID_EMP = ssRecs.ID_EMP;

--insert not existing records
INSERT INTO dbo.SS_EMP_LANGUAGES
( id_emp_lan ,
id_emp ,
LANG ,
LANG_LEVEL ,
LANG_DEGREE ,
LANG_RANK ,
LANG_LEVEL_TALK ,
LANG_LEVEL_WRITE ,
StatusID
)
SELECT
HRMRecs.id_emp_lan ,
SSEmpRecs.id_emp ,
HRMRecs.LANG ,
HRMRecs.LANG_LEVEL ,
HRMRecs.LANG_DEGREE ,
HRMRecs.LANG_RANK ,
HRMRecs.LANG_LEVEL_TALK ,
HRMRecs.LANG_LEVEL_WRITE
,1 /*,GETDATE() */
FROM #t HRMRecs
JOIN dbo.SS_EMPLOYEE SSEmpRecs ON HRMRecs.Vat = SSEmpRecs.VAT AND SSEmpRecs.ID_CMP = HRMRecs.ID_CMP




/*

FROM HRM_EMP_LANGUAGES HRMRecs
LEFT JOIN dbo.SS_EMP_LANGUAGES SSRecs ON HRMRecs.ID_EMP_LAN = SSRecs.ID_EMP_LAN
JOIN #t T ON HRMRecs.ID_EMP_LAN = T.ID_EMP_LAN AND T.statusid<>2
JOIN  SS_vEMP_CARD V ON V.ID_EMP = SSRecs.ID_EMP --PRESERVE ORPHAN RECORDS
WHERE SSRecs.ID_EMP_LAN IS NULL
*/
--SELECT * FROM HRM_EMP_LANGUAGES P LEFT JOIN dbo.SS_vEMP_CARD V ON P.ID_EMP=V.ID_EMP WHERE P.ID_EMP IS NULL

--Mark records for delete
--		UPDATE SSRecs  SET StatusID = 2 ,ProcessDate=null
--		FROM dbo.SS_EMP_LANGUAGES SSRecs
--		JOIN #t T ON SSRecs.ID_EMP_LAN = T.ID_EMP_LAN AND T.statusid=2

COMMIT TRAN;

DROP TABLE #t
--DELETE FROM CDC_EMP_LANGUAGES WHERE AuditDate <= @DT;
END TRY
BEGIN CATCH
IF @@TRANCOUNT > 0 ROLLBACK TRAN;

if OBJECT_ID('tempdb..#t') is not null
DROP TABLE #t

INSERT INTO dbo.SS_LogErrors
SELECT GETDATE()
,'Error on line ' + CONVERT(nvarchar(10), ERROR_LINE()) + ': ' + ERROR_MESSAGE()
,ERROR_SEVERITY()
,ERROR_STATE();

END CATCH
END
GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[spSS_getEMP_CHILDREN]'
GO
-- =============================================
-- Author:		Pantelis Chatzimichalis
-- Create date: 10-12-2012
-- Description:	Sync HRM EMP_CHILDREN Data
-- =============================================
ALTER  PROCEDURE [dbo].[spSS_getEMP_CHILDREN] @DT DATETIME AS
BEGIN

SELECT CAST(NULL AS int) Vat, CAST(NULL AS int) ID_CMP, * INTO #T FROM dbo.SS_EMP_CHILDREN WHERE ID_EMP<0

--FILL #T
DECLARE @qry VARCHAR(2000);

DECLARE @hrmSRV VARCHAR(2000);
DECLARE @hrmdb VARCHAR(2000);
SELECT @hrmdb = p.DbName + '.' + p.DefaultSchema + '.', @hrmSRV = p.SrvSynonym from dbo.SS_Params p
select  @qry = 'INSERT INTO #T SELECT *,NULL,NULL FROM OPENQUERY(['+@hrmSRV+'],''SELECT * from ' + @hrmdb + 'fnSS_getEMP_CHILDREN_CHANGES(''' +QUOTENAME(convert(varchar, @dt, 120),'''')+ ''')'') ';
--SELECT *,NULL,NULL FROM OPENQUERY(DB_HRM,'SELECT * from xmixalis_bm.dbo.fnSS_getEMP_CHILDREN_CHANGES(''2012-12-20 12:27:21'')')
--PRINT @qry
EXEC (@qry)
--SELECT * FROM #T
--drop table #t

BEGIN TRAN;
BEGIN TRY
--delete ALL SS children for employees changed
DELETE ssRecs
--select *
FROM #t T
JOIN dbo.SS_EMPLOYEE SSEmpRecs ON T.Vat = SSEmpRecs.VAT AND SSEmpRecs.ID_CMP = T.ID_CMP
JOIN dbo.SS_EMP_CHILDREN ssRecs ON SSEmpRecs.ID_EMP = ssRecs.ID_EMP;

--insert HRM children records
INSERT INTO dbo.SS_EMP_CHILDREN
( ID_EMP ,
ID_CHILDREN ,
FYLO ,
BIRTHDATE ,
STATUS ,
VARINEI ,
AFKSISI_AFOROL ,
CHILD_NAME ,
OTHER_FATHER ,
STUDY_REG_DATE ,
STUDY_YEARS ,
STUDY_MONTHS ,
STUDY_CONFIRMATION ,
STUDY_CONFIRMATION_END ,
DIED ,
DEATH_DATE ,
EDU_DESCR ,
METAPTYX_EXP_DATE,
StatusID
)
SELECT
SSEmpRecs.ID_EMP ,
HRMRecs.ID_CHILDREN ,
HRMRecs.FYLO ,
HRMRecs.BIRTHDATE ,
HRMRecs.STATUS ,
HRMRecs.VARINEI ,
HRMRecs.AFKSISI_AFOROL ,
HRMRecs.CHILD_NAME ,
HRMRecs.OTHER_FATHER ,
HRMRecs.STUDY_REG_DATE ,
HRMRecs.STUDY_YEARS ,
HRMRecs.STUDY_MONTHS ,
HRMRecs.STUDY_CONFIRMATION ,
HRMRecs.STUDY_CONFIRMATION_END ,
HRMRecs.DIED ,
HRMRecs.DEATH_DATE ,
HRMRecs.EDU_DESCR ,
HRMRecs.METAPTYX_EXP_DATE
,1 /*,GETDATE() */
FROM #t HRMRecs
JOIN dbo.SS_EMPLOYEE SSEmpRecs ON HRMRecs.Vat = SSEmpRecs.VAT AND SSEmpRecs.ID_CMP = HRMRecs.ID_CMP

COMMIT TRAN;

DROP TABLE #t
--DELETE FROM CDC_EMP_CHILDREN WHERE AuditDate <= @DT;
END TRY
BEGIN CATCH
IF @@TRANCOUNT > 0 ROLLBACK TRAN;

if OBJECT_ID('tempdb..#t') is not null
DROP TABLE #t

INSERT INTO dbo.SS_LogErrors
SELECT GETDATE()
,'Error on line ' + CONVERT(nvarchar(10), ERROR_LINE()) + ': ' + ERROR_MESSAGE()
,ERROR_SEVERITY()
,ERROR_STATE();

END CATCH
END
GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[SS_HRM_ASS_AssessedInfo]'
GO



ALTER FUNCTION [dbo].[SS_HRM_ASS_AssessedInfo] ( @ContactID int, @InstanceID int, @LangID int)
RETURNS @RetTbl TABLE
(
ContactID int,	TimeinCurrentPosition varchar(255), Position varchar(255), PrintVisibility int

)
AS
BEGIN
DECLARE @Ass_Year int, @Ass_YearMinDate datetime, @Ass_YearMaxDate datetime, @EmployeeStartDate datetime, @EmployeeEndDate datetime, @AssessmentDetailExport int, @HasDetailedForms int;

SET @Ass_Year = (select Ass_Year from SS_HRM_ASS_INSTANCES where id = @InstanceID);
SET @Ass_YearMinDate = DATEADD(yy, @Ass_Year-1900, 0);
SET @Ass_YearMaxDate = DATEADD(yy, DATEDIFF(yy, 0, DATEADD(yy, @Ass_Year-1900, 0)) + 1, -1)
SET @EmployeeStartDate = (SELECT TOP 1 Startdate FROM AC_Department_Contacts WHERE ContactID = @ContactID AND Startdate <= @Ass_YearMaxDate AND isnull(Enddate, '2049-12-31') >= @Ass_YearMinDate ORDER by Startdate DESC)
SET @EmployeeEndDate = (SELECT TOP 1 Enddate FROM AC_Department_Contacts WHERE ContactID = @ContactID AND Startdate <= @Ass_YearMaxDate AND isnull(Enddate, '2049-12-31') >= @Ass_YearMinDate ORDER by Startdate DESC)
SET @AssessmentDetailExport = isnull((SELECT varValue FROM X_Vars WHERE varKey = 'AssessmentDetailExport'),0);
SET @HasDetailedForms = (select isnull(HasDetailedForms,0) from SS_HRM_ASS_INSTANCES where id = @InstanceID);

DECLARE @CurUserAccessToPrint int, @ExtId_ass_instance int ;
SET @ExtId_ass_instance = (SELECT Ext_id_ass_instance FROM SS_HRM_ASS_INSTANCES where ID = @InstanceID);

;WITH AssessmentSummary(EnforceFormPrivacyAssessee,EnforceFormPrivacyAssesseeTill, Status) AS
(
SELECT max(ia.EnforceFormPrivacyAssessee), max(ia.EnforceFormPrivacyAssesseeTill), max(rd.Status)
FROM SS_HRM_ASS_Results_Detail rd
JOIN AC_All_EmpIDS ae on ae.EMP_ID = rd.Ext_id_emp
JOIN SS_HRM_ASS_Results r ON rd.Ext_id_ass_res = r.Ext_id_ass_res
JOIN SS_HRM_ASS_INSTANCE_ASSESSMENTS ia ON rd.id_ass_instance = ia.id_ass_assistance AND r.id_ass = ia.id_ass
WHERE rd.id_ass_instance = @ExtId_ass_instance AND ae.ContactID = @ContactID
GROUP BY ae.ContactID
)

SELECT @CurUserAccessToPrint =  (SELECT CASE WHEN (isnull(EnforceFormPrivacyAssessee,0) =1 AND CONVERT(date,getdate()) <= isnull(EnforceFormPrivacyAssesseeTill,'2049-12-31'))
OR (isnull(EnforceFormPrivacyAssessee,0) =1 AND CONVERT(date,getdate()) > isnull(EnforceFormPrivacyAssesseeTill,'2049-12-31') AND isnull([Status],0) <> 3)
THEN 0 ELSE 1 END
FROM AssessmentSummary)


--SET @CurUserAccessToPrint = (SELECT CASE WHEN  ((@CurUserID = @ContactID) OR (@CurUserID <> @Assessor1 AND @HasHREditorRights = 0 AND @HRPerNodeViewEmployee = 0)) AND isnull(ia.EnforceFormPrivacyAssessee,0) =1 AND CONVERT(date,getdate()) <= isnull(ia.EnforceFormPrivacyAssesseeTill,'2049-12-31') then 0
--			 WHEN  ((@CurUserID = @ContactID) OR (@CurUserID <> @Assessor1 AND @HasHREditorRights = 0 AND @HRPerNodeViewEmployee = 0)) AND isnull(ia.EnforceFormPrivacyAssessee,0) =1 AND CONVERT(date,getdate()) > isnull(ia.EnforceFormPrivacyAssesseeTill,'2049-12-31') AND isnull(rd.[Status],0) <> 3 then 0
--		else 1 end AS AllowView)

INSERT @RetTbl
SELECT @ContactID
, 	CONVERT( varchar(255),CASE WHEN @EmployeeStartDate > @Ass_YearMinDate THEN @EmployeeStartDate ELSE @Ass_YearMinDate END, 103)  + ' - '
+ CONVERT (varchar(255),CASE WHEN isnull(@EmployeeEndDate,@Ass_YearMaxDate) < @Ass_YearMaxDate THEN isnull(@EmployeeEndDate,@Ass_YearMaxDate) ELSE  @Ass_YearMaxDate END, 103) AS TimeinCurrentPosition
, isnull(l_posname.VALUE, pos.DESCR) AS Position
, CASE WHEN @AssessmentDetailExport =1 AND @HasDetailedForms = 1 then 1
WHEN @AssessmentDetailExport = 2  AND @CurUserAccessToPrint = 1 then 1  -- Plus logic
ELSE 0 END AS PrintVisibility
FROM AC_Department_Contacts dc
LEFT JOIN SS_POSITION pos on pos.ID_POS = dc.PositionID
LEFT JOIN L_Object l_posname on l_posname.ID_TABLE = pos.ID_POS and l_posname.TABLE_NAME = 'SS_POSITION' and l_posname.ID_LANGUAGES = @LangID
WHERE cast(getdate() as date) between dc.[StartDate] AND isnull(dc.EndDate, '2049-12-31') AND dc.ContactID = @ContactID

RETURN;
END

GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[SS_HRM_ASS_EvaluationCardSettings]'
GO

ALTER FUNCTION [dbo].[SS_HRM_ASS_EvaluationCardSettings](@ResultDetailID int,@CurUserID int, @AllowAnyManagerAboveForType2 int)
RETURNS @RetTbl TABLE (AllowView int,AllowEdit int, AllowReset int, AllowCorrect int, Form_Status int,AssessorType_1 int,Form_Assessor1_ID_EMP int, Form_UseAssessor1ForManager int, AssessorType_2 int, Form_Assessor2_ID_EMP int, AssessorType_3 int,Form_Assessor3_ID_EMP int)
AS
BEGIN
SET @AllowAnyManagerAboveForType2 = 0;

--
-- Notes:
--		Substituting for a manager is not taken into account (TBD)
--		"Direct Manager" is not the "Effective Manager", just if the manager is in the same dept as the employee.
--

DECLARE @AssesseeID int;
SET @AssesseeID = (SELECT a.ContactID
FROM SS_HRM_ASS_Results_Detail rd
JOIN AC_All_EmpIDS a on rd.Ext_id_emp = a.EMP_ID
WHERE rd.ID = @ResultDetailID);

DECLARE @Assessor1 int;
SET @Assessor1 = (SELECT a.ContactID
FROM SS_HRM_ASS_Results_Detail rd
JOIN AC_All_EmpIDS a on rd.id_emp_assessor = a.EMP_ID
WHERE rd.ID = @ResultDetailID);

DECLARE @HasHREditorRights int, @HasHREditorPerCompanyRights int;
SET @HasHREditorRights = case when
(SELECT count(*)
FROM XU_UserRoles ur
WHERE ur.UsrId=@CurUserID
AND ur.RoleId=1005) > 0 then 1 else 0 end;

SET @HasHREditorPerCompanyRights = case when
(SELECT count(*)
FROM XU_UserRoles ur
WHERE ur.UsrId=@CurUserID
AND ur.RoleId=1011) > 0 then 1 else 0 end;

DECLARE @ManagerList TABLE (AA int, ManagerID int);
INSERT INTO @ManagerList
SELECT AA, ManagerID
FROM
(
SELECT mdl.ManagerLevel AS AA, mdl.RegularManager AS ManagerID
FROM AC_Department_Contacts dc
CROSS APPLY SS_ContactCurrentManagerTreeUp(dc.ContactID,dc.DepartmentID) mdl
WHERE dc.ContactID = @AssesseeID
AND getdate() between dc.StartDate and isnull(dc.Enddate, '2049-12-31')
--SELECT ROW_NUMBER() OVER (ORDER BY mdc.ContactID) AS AA, mdc.ContactID AS ManagerID
--FROM AC_Department_Contacts dc
--CROSS APPLY SS_GetDeptListFromNodeUp(dc.DepartmentID) mdl
--JOIN AC_Department_Contacts mdc on mdc.DepartmentID = mdl.DepartmentID and mdc.IsManager=1 and mdc.ContactID <> @AssesseeID and getdate() between mdc.StartDate and isnull(mdc.Enddate, '2049-12-31')
--WHERE dc.ContactID = @AssesseeID
--AND getdate() between dc.StartDate and isnull(dc.Enddate, '2049-12-31')
) InnerTbl
WHERE (isnull(@AllowAnyManagerAboveForType2,0)=1 OR AA=1);

DECLARE @EvaluationShowEditBtnForHR int; --DESS-115639
SET @EvaluationShowEditBtnForHR= isnull((SELECT varValue
FROM X_UIControl_Settings s
JOIN X_UIControls c on s.ControlID=c.ID
WHERE c.Cd='ucEvaluationCard' and s.varKey='EvaluationShowEditBtnForHR'),0);

DECLARE @AssessmentEditorRole int;
SET @AssessmentEditorRole= 1017;

DECLARE @HRPerNodeViewEmployee int;
SET @HRPerNodeViewEmployee = case when (SELECT count(*)
FROM AC_Department_Contacts dc
JOIN SS_Employee e on e.ContactID = dc.ContactID
WHERE getdate() between dc.Startdate and isnull(dc.Enddate, '2049-12-31') and getdate() <= isnull(e.FRDATE, '2049-12-31')
AND dc.ContactID = @AssesseeID
AND dc.DepartmentID in (SELECT ID FROM SS_GetViewableDepartmentListPerNodePerRole (@CurUserID,@AssessmentEditorRole))
) > 0 then 1 else 0 end;

INSERT INTO @RetTbl
SELECT  CASE WHEN  ((@CurUserID = @AssesseeID) OR (@CurUserID <> @Assessor1 AND @HasHREditorRights = 0 AND @HRPerNodeViewEmployee = 0)) AND isnull(ia.EnforceFormPrivacyAssessee,0) =1 AND CONVERT(date,getdate()) <= isnull(ia.EnforceFormPrivacyAssesseeTill,'2049-12-31') then 0
WHEN  ((@CurUserID = @AssesseeID) OR (@CurUserID <> @Assessor1 AND @HasHREditorRights = 0 AND @HRPerNodeViewEmployee = 0)) AND isnull(ia.EnforceFormPrivacyAssessee,0) =1 AND CONVERT(date,getdate()) > isnull(ia.EnforceFormPrivacyAssesseeTill,'2049-12-31') AND isnull(rd.[Status],0) <> 3 then 0
else 1 end AS AllowView
,case

when @HasHREditorRights=1  then 1
when @HRPerNodeViewEmployee = 1  AND @CurUserID <> @AssesseeID then 1
when rd.[Status]=3 then -3 --'You cannot Edit because the Form is complete'
when rd.[Status]=1 and isnull(ia.AssessorType_1,1)=1 and @CurUserID = @AssesseeID then 1
when rd.[Status]=1 and isnull(rd.id_emp_assessor,0)<>0 and @CurUserID in (select ContactID from AC_All_EmpIDS where EMP_ID = rd.id_emp_assessor) then 1
when rd.[Status]=1 and isnull(rd.id_emp_assessor,0)=0 and isnull(ia.AssessorType_1,0)=2 and @CurUserID in (select ManagerID FROM @ManagerList) then 1
when rd.[Status]=2 and isnull(rd.id_emp_assessor,0)<>0 and @CurUserID in (select ContactID from AC_All_EmpIDS where EMP_ID = rd.id_emp_assessor) then 1
when rd.[Status]=2 and isnull(rd.id_emp_assessor,0)=0 and isnull(ia.AssessorType_1,1)=1 and isnull(rd.UseAssessor1ForManager,0)=1 and @CurUserID in (select ManagerID FROM @ManagerList) then 1
when rd.[Status]=2 and isnull(rd.id_emp_assessor,0)=0 and isnull(ia.AssessorType_1,1)=2 and @CurUserID in (select ManagerID FROM @ManagerList) then 1
when rd.[Status]=1 and ia.AssessorType_1=1 and isnull(rd.UseAssessor1ForManager,0)=1 and @CurUserID in (select ManagerID FROM @ManagerList) then -1  --'You cannot Edit because it is not your turn yet'
when rd.[Status]=2 and ia.AssessorType_1=1 and @CurUserID=@AssesseeID then -3  --'You cannot Edit because you do not have a turn --eg directly to Status 2 like Iatriko or Epsilon -- or you have already completed your turn'
-- WARNING:  TO BE CHANGED FOR EVROPAIKI PISTI --
when rd.[Status]=0 and (@HasHREditorRights=1 or @AssesseeID=@CurUserID) then 1
else 0  -- generic lock

end AS AllowEdit
, CASE WHEN @CurUserID <> @AssesseeID AND (@HasHREditorRights = 1 OR @HRPerNodeViewEmployee = 1) THEN 1 ELSE 0 END As AllowReset
, CASE WHEN @CurUserID <> @AssesseeID AND (@HasHREditorRights = 1 OR @HasHREditorPerCompanyRights = 1 OR @HRPerNodeViewEmployee = 1) AND @EvaluationShowEditBtnForHR = 1 THEN 1 ElSE 0 END    As AllowCorrect
, rd.[Status] AS Form_Status
, ia.AssessorType_1, rd.id_emp_assessor AS Form_Assessor1_ID_EMP, rd.UseAssessor1ForManager AS Form_UseAssessor1ForManager
, ia.AssessorType_2, rd.id_emp_assessor_2 AS Form_Assessor2_ID_EMP
, ia.AssessorType_3, rd.id_emp_assessor_3 AS Form_Assessor3_ID_EMP
FROM SS_HRM_ASS_Results_Detail rd
JOIN SS_HRM_ASS_Results r ON rd.Ext_id_ass_res = r.Ext_id_ass_res
JOIN SS_HRM_ASS_INSTANCE_ASSESSMENTS ia ON rd.id_ass_instance = ia.id_ass_assistance AND r.id_ass = ia.id_ass
WHERE rd.ID = @ResultDetailID;

RETURN;
END

GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Creating [dbo].[SS_HRM_ASS_INSTANCE_AssessmentOverviewPerformanceStatistics]'
GO
IF OBJECT_ID(N'[dbo].[SS_HRM_ASS_INSTANCE_AssessmentOverviewPerformanceStatistics]', 'P') IS NULL
EXEC sp_executesql N'
CREATE PROCEDURE [dbo].[SS_HRM_ASS_INSTANCE_AssessmentOverviewPerformanceStatistics] @ExtAssInstance int, @ExtAssFormID int, @DepartmentID int, @ExcludeZeros int, @UseQuestionDescrForColumnNames int , @CurLangID int, @CurUserID int
AS
BEGIN

SET NOCOUNT ON;

SET @UseQuestionDescrForColumnNames = 0;

DECLARE @Questions AS Table (ParID int, ParDescr nvarchar(max))

INSERT INTO @Questions(ParID, ParDescr)
SELECT distinct p.Ext_id_ass_par, pp.DESCR
FROM SS_HRM_ASS_INSTANCE_ASSESSMENTS ia
JOIN SS_HRM_ASS_ASSESSMENTS a on ia.id_ass = a.Ext_id_ass
JOIN SS_HRM_ASS_ASSESSMENTS_TYPE t on t.Ext_id_ass = a.Ext_id_ass
JOIN SS_HRM_ASS_ASSESMENT_PARAMS p on p.Ext_id_ass = a.Ext_id_ass and p.Ext_id_param_type = t.Ext_id_param_type
JOIN SS_HRM_ASS_PARAMS pp on pp.Ext_id_ass_par = p.Ext_id_ass_par
WHERE ia.id_ass_assistance = @ExtAssInstance
AND ia.id_ass = @ExtAssFormID
ORDER BY p.Ext_id_ass_par;

DECLARE @PivotColumns nvarchar(max), @ScoreFormula nvarchar(max), @SQLQuery nvarchar(max),  @SQLQuery1 nvarchar(max), @SQLQuery2 nvarchar(max), @SQLQuery3 nvarchar(max);
IF isnull(@UseQuestionDescrForColumnNames,0)=1 BEGIN
SELECT @PivotColumns= COALESCE(@PivotColumns + '','','''') + QUOTENAME(ParID) + '' AS '' + QUOTENAME(left(ParDescr,2))
FROM (SELECT DISTINCT ParID, ParDescr FROM @Questions) t;
END
ELSE BEGIN
SELECT @PivotColumns= COALESCE(@PivotColumns + '','','''') + QUOTENAME(ParID)
FROM (SELECT DISTINCT ParID, ParDescr FROM @Questions) t;
END;

DECLARE @Is_Custom_Evropaiki int;
SET @Is_Custom_Evropaiki = isnull((select varValue from X_Vars where varkey = ''TmpEvropaiki''),0);
DECLARE @AssessmentShowWeightedResult int,@GoalObjectivesShowWeightedResult int  --10/7/2017 GP DESS-119178
SET @AssessmentShowWeightedResult = isnull((select varValue from X_UIControl_Settings where varkey = ''AssessmentShowWeightedResult'' AND ControlID = 105),0);
SET @GoalObjectivesShowWeightedResult = isnull((select varValue from X_UIControl_Settings where varkey = ''GoalObjectivesShowWeightedResult'' AND ControlID = 105),0);

;WITH GroupedCriteria (CriterionID, QuestionID, [Weight])
AS
(
SELECT t.Ext_id_param_type, p.Ext_id_ass_par, t.Varitita
FROM SS_HRM_ASS_INSTANCE_ASSESSMENTS ia
JOIN SS_HRM_ASS_ASSESSMENTS a on ia.id_ass = a.Ext_id_ass
JOIN SS_HRM_ASS_ASSESSMENTS_TYPE t on t.Ext_id_ass = a.Ext_id_ass
JOIN SS_HRM_ASS_ASSESMENT_PARAMS p on p.Ext_id_ass = a.Ext_id_ass and p.Ext_id_param_type = t.Ext_id_param_type
WHERE ia.id_ass_assistance = @ExtAssInstance
AND ia.id_ass = @ExtAssFormID
)
, CriteriaFormulas (CriterionID, Formula)
AS
(
SELECT DISTINCT CriterionID
, ''('' + STUFF ((SELECT ''+['' + cast(QuestionID as nvarchar(max)) + '']''
FROM GroupedCriteria WHERE CriterionID = gc.CriterionID
FOR XML PATH(''''), TYPE).value(''(./text())[1]'',''NVARCHAR(MAX)''), 1, 1, '''')
+ '') / '' + cast((SELECT count(*) FROM GroupedCriteria WHERE CriterionID = gc.CriterionID) as nvarchar(max))
+ '' * '' + cast(max([Weight])/100.0 as nvarchar(max)) AS Formula
from GroupedCriteria gc
GROUP BY CriterionID, QuestionID
)

SELECT @ScoreFormula = STUFF((SELECT ''+ ('' + Formula + '')'' FROM CriteriaFormulas FOR XML PATH('''')), 1, 1, '''');

SET @SQLQuery1 = N''DECLARE @ExtAssInstance int, @ExtAssFormID int, @DepartmentID int, @ExcludeZeros int, @Is_Custom_Evropaiki int, @CurLangID int, @CurUserID int;
SET @ExtAssInstance = '' + cast(@ExtAssInstance as varchar(255)) + '';
SET @ExtAssFormID = '' + cast(@ExtAssFormID as varchar(255)) + '';
SET @DepartmentID = '' + case when @DepartmentID is null then ''null'' else cast(@DepartmentID as varchar(255)) end + '';
SET @ExcludeZeros = '' + cast(@ExcludeZeros as varchar(255)) + '';
SET @CurLangID = '' + cast(@CurLangID as varchar(255)) + '';
SET @CurUserID = '' + cast(@CurUserID as varchar(255)) + '';
SET @Is_Custom_Evropaiki = isnull((select varValue from X_Vars where varkey = ''''TmpEvropaiki''''),0);

DECLARE @ExtCurUserID int, @HasHREditorRights int,@AssessmentEditorRole int;
SET @ExtCurUserID = (SELECT EMP_ID FROM AC_All_EmpIDS WHERE ContactID = @CurUserID);
SET @HasHREditorRights = (SELECT case when (SELECT count(*) FROM XU_UserRoles ur WHERE ur.UsrId=@CurUserID AND ur.RoleId=1005) > 0 then 1 else 0 end);
SET @AssessmentEditorRole= 1017;




;WITH EmpsInDept (ExtEmployeeID) AS
(
SELECT a.EMP_ID FROM SS_GetDeptListFromNodeDown(@DepartmentID) d JOIN AC_Department_Contacts dc on dc.DepartmentID = d.ID and getdate() between dc.Startdate and isnull(dc.EndDate,''''2049-12-31'''') JOIN AC_All_EmpIDS a on dc.ContactID = a.ContactID WHERE dc.ContactID <> -2
)
, RawData (ExtEmployeeID, ExtAssessorID, ExtParID, Result) AS
(
SELECT rd.ext_id_emp, rd.id_emp_assessor, e.id_ass_par
, CASE WHEN ( (((@ExtCurUserID = rd.ext_id_emp) OR (@ExtCurUserID <> rd.id_emp_assessor AND @HasHREditorRights = 0
AND (SELECT count(*) FROM AC_Department_Contacts dc JOIN SS_Employee e on e.ContactID = dc.ContactID
JOIN AC_All_EmpIDS_IncludingInactive ae on ae.ContactID = e.ContactID
WHERE getdate() between dc.Startdate and isnull(dc.Enddate, ''''2049-12-31'''') and getdate() <= isnull(e.FRDATE, ''''2049-12-31'''')
AND ae.EMP_ID = rd.ext_id_emp
AND dc.DepartmentID in (SELECT ID FROM SS_GetViewableDepartmentListPerNodePerRole (@ExtCurUserID,@AssessmentEditorRole))) = 0 ))
AND isnull(ia.EnforceFormPrivacyAssessee,0) =1 AND CONVERT(date,getdate()) <= isnull(ia.EnforceFormPrivacyAssesseeTill,''''2049-12-31''''))
OR
(((@ExtCurUserID = rd.ext_id_emp) OR (@ExtCurUserID <> rd.id_emp_assessor AND @HasHREditorRights = 0
AND (SELECT count(*) FROM AC_Department_Contacts dc JOIN SS_Employee e on e.ContactID = dc.ContactID
JOIN AC_All_EmpIDS_IncludingInactive ae on ae.ContactID = e.ContactID
WHERE getdate() between dc.Startdate and isnull(dc.Enddate, ''''2049-12-31'''') and getdate() <= isnull(e.FRDATE, ''''2049-12-31'''')
AND ae.EMP_ID = rd.ext_id_emp
AND dc.DepartmentID in (SELECT ID FROM SS_GetViewableDepartmentListPerNodePerRole (@ExtCurUserID,@AssessmentEditorRole))) = 0 ))
AND isnull(ia.EnforceFormPrivacyAssessee,0) =1 AND CONVERT(date,getdate()) > isnull(ia.EnforceFormPrivacyAssesseeTill,''''2049-12-31'''') AND isnull(rd.[Status],0) <> 3)
) THEN 0
ELSE isnull(e.id_value,0)  END
FROM SS_HRM_ASS_Results_Detail rd
JOIN SS_HRM_ASS_Results r on rd.Ext_id_ass_res = r.Ext_id_ass_res
JOIN SS_HRM_ASS_Results_Detail_Type rdt on rd.Ext_id_ass_res = rdt.Ext_id_ass_res and rd.Ext_id_emp = rdt.Ext_id_emp
JOIN SS_HRM_ASS_Execution e on e.id_ass_res = r.Ext_id_ass_res and e.id_emp = rd.Ext_id_emp and e.id_param_type = rdt.Ext_id_param_type
JOIN SS_HRM_ASS_INSTANCE_ASSESSMENTS ia ON rd.id_ass_instance = ia.id_ass_assistance AND r.id_ass = ia.id_ass
WHERE rd.id_ass_instance = @ExtAssInstance AND r.id_ass = @ExtAssFormID
AND (isnull(@ExcludeZeros,0)=0 OR isnull(Result,0.0)<>0.0)
AND (@DepartmentID is null OR rd.ext_id_emp in (select ExtEmployeeID from EmpsInDept))
)
, PivotedData ([ExtEmployeeID], [ExtAssessorID],'' + @PivotColumns + '') AS
(
SELECT [ExtEmployeeID], [ExtAssessorID], ''+ @PivotColumns + ''
FROM RawData PIVOT (AVG(Result) FOR [ExtParID] IN ('' + @PivotColumns + '')
) AS P
)
, Weights (ExtEmployeeID,AssessmentWeight,GoalSettingWeight) AS
(
SELECT emp.Ext_ID_EMP , ineg.AssessmentWeight,ineg.GoalSettingWeight
FROM PivotedData pd
LEFT JOIN SS_HRM_EMPGROUP_EMPLOYEES emp on emp.Ext_ID_EMP = pd.ExtEmployeeID and DATEADD(dd, DATEDIFF(dd, 0, getdate()), 0) between emp.StartDate and isnull(emp.EndDate,''''2049-12-31'''')
LEFT JOIN SS_HRM_EMPGROUPS eg on eg.EXT_ID_EMPGROUP = emp.Ext_ID_EMPGROUP AND eg.StatusID not in (2,12,22) AND DATEADD(dd, DATEDIFF(dd, 0, getdate()), 0) between eg.StartDate and isnull(eg.EndDate,''''2049-12-31'''')
LEFT JOIN SS_HRM_ASS_INSTANCE_EMPGROUPS ineg on ineg.Ext_ID_EMPGROUP = eg.EXT_ID_EMPGROUP AND ineg.StatusID not in (2,12,22)
WHERE ineg.Ext_ID_ASS_INSTANCE = @ExtAssInstance AND emp.StatusID not in (2,12,22)
)''

SET @SQLQuery2 = case when @Is_Custom_Evropaiki = 1  then ''SELECT *, cast(''+ case when @AssessmentShowWeightedResult = 1 then ''lbWeightedScore'' else ''lbScore'' end + '' + ''+ case when @GoalObjectivesShowWeightedResult = 1 then ''lbWeightedGoalScore'' else ''lbGoalScore'' end + ''  AS decimal(16,2)) AS lbTotalScore
FROM ('' else '''' end
+ ''SELECT a_emp.ContactID
, emp.Code AS lbEmpCode
, ISNULL(lo_last_c.VALUE, c.Name) as lbEmpLastName
, coalesce(lo_first_c.VALUE, c.FirstName, '''''''') as lbEmpFirstName
, emp.HRDATE AS lbHireDate
, isnull(ISNULL(lo_last_assc.VALUE, assc.NAME)  + '''' '''' + coalesce(lo_first_assc.VALUE, assc.FirstName, ''''''''),
(
SELECT TOP 1 ISNULL(lo_last_c.VALUE, c.Name) + '''' '''' + coalesce(lo_first_c.VALUE, c.FirstName, '''''''')
FROM [SS_GetDeptListFromNodeUp]((select TOP 1 DepartmentID from AC_Department_Contacts where ContactID = a_emp.ContactID and getdate() between StartDate and isnull(EndDate,''''2049-12-31''''))) d
JOIN AC_Department_Contacts dc on dc.DepartmentID = d.DepartmentID and dc.IsManager=1 and dc.ContactID not in (-2,a_emp.ContactID)
JOIN AC_Contacts c on dc.ContactID = c.ContactID
LEFT JOIN L_Object lo_last_c on lo_last_c.ID_TABLE = c.ContactID AND lo_last_c.TABLE_NAME = ''''AC_Contacts'''' AND lo_last_c.FieldName = ''''LastName'''' AND lo_last_c.ID_LANGUAGES = @CurLangID
LEFT JOIN L_Object lo_first_c on lo_first_c.ID_TABLE = c.ContactID AND lo_first_c.TABLE_NAME = ''''AC_Contacts'''' AND lo_first_c.FieldName = ''''FirstName'''' AND lo_first_c.ID_LANGUAGES = @CurLangID
)
) AS lbAssessor
, (select TOP 1  ISNULL(o.VALUE, dn.Descr) as Descr
FROM AC_Department_Contacts dc
JOIN AC_Departments d on dc.DepartmentID = d.ID
JOIN AC_DepartmentNames dn on d.DepartmentNameID = dn.ID
LEFT JOIN L_Object o ON o.TABLE_NAME = ''''AC_DepartmentNames'''' AND o.ID_TABLE = dn.ID AND o.ID_LANGUAGES = @CurLangID
WHERE dc.ContactID = a_emp.ContactID
AND getdate() between dc.Startdate and isnull(dc.EndDate, ''''2049-12-31'''')
) AS lbDepartment
,''

SET @SQLQuery3 = N''LEFT((SELECT isnull(lo.value,c.DESCR) + '''' ('''' + cast(cr.PERC as varchar(100)) + '''')''''+ '''' , '''' FROM SS_COST_REC cr JOIN SS_COST c on c.Ext_CODE = cr.COST_CODE and c.Ext_ID_CMP = cr.ID_CMP LEFT JOIN L_Object lo on lo.ID_TABLE = c.ID1 AND lo.TABLE_NAME = ''''SS_COST'''' AND lo.ID_LANGUAGES = @CurLangID WHERE cr.ID_EMP = a_emp.EMP_ID and cr.ID_CMP = a_emp.ID_CMP AND getdate() between cr.[START_DATE] and cr.END_DATE ORDER BY cr.PERC FOR XML PATH(''''''''))
, LEN((SELECT isnull(lo.value,c.DESCR) + '''' ('''' + cast(cr.PERC as varchar(100)) + '''')''''+ '''' , '''' FROM SS_COST_REC cr JOIN SS_COST c on c.Ext_CODE = cr.COST_CODE and c.Ext_ID_CMP = cr.ID_CMP LEFT JOIN L_Object lo on lo.ID_TABLE = c.ID1 AND lo.TABLE_NAME = ''''SS_COST'''' AND lo.ID_LANGUAGES = @CurLangID WHERE cr.ID_EMP = a_emp.EMP_ID and cr.ID_CMP = a_emp.ID_CMP AND getdate() between cr.[START_DATE] and cr.END_DATE ORDER BY cr.PERC FOR XML PATH(''''''''))) - 1)
AS lbCostcenter
, '' + @PivotColumns + '', cast('' + @ScoreFormula  + '' as decimal(16,2)) AS lbScore
''+ case when @AssessmentShowWeightedResult = 1 then '', cast( cast('' + @ScoreFormula  + '' as decimal(16,2)) * w.AssessmentWeight as decimal(16,2) ) AS lbWeightedScore'' else '''' end + ''
''+ case when @Is_Custom_Evropaiki = 1 then '', goalscores.GoalScore AS lbGoalScore
''+ case when @GoalObjectivesShowWeightedResult = 1 then '', cast (goalscores.GoalScore * w.GoalSettingWeight as decimal(16,2) ) AS lbWeightedGoalScore'' else '''' end  else '''' end + ''
FROM PivotedData d
LEFT JOIN AC_All_EmpIDS a_emp on d.ExtEmployeeID = a_emp.EMP_ID
LEFT JOIN SS_Employee emp on a_emp.FEMP_ID = emp.ID_EMP
LEFT JOIN AC_Contacts c on c.ContactID = emp.ContactID
LEFT JOIN L_Object lo_last_c on lo_last_c.ID_TABLE = c.ContactID AND lo_last_c.TABLE_NAME = ''''AC_Contacts'''' AND lo_last_c.FieldName = ''''LastName'''' AND lo_last_c.ID_LANGUAGES = @CurLangID
LEFT JOIN L_Object lo_first_c on lo_first_c.ID_TABLE = c.ContactID AND lo_first_c.TABLE_NAME = ''''AC_Contacts'''' AND lo_first_c.FieldName = ''''FirstName'''' AND lo_first_c.ID_LANGUAGES = @CurLangID
LEFT JOIN AC_All_EmpIDS a_ass on d.ExtAssessorID = a_ass.EMP_ID
LEFT JOIN SS_Employee ass on a_ass.FEMP_ID = ass.ID_EMP
LEFT JOIN AC_Contacts assc on assc.ContactID = ass.ContactID
LEFT JOIN L_Object lo_last_assc on lo_last_assc.ID_TABLE = assc.ContactID AND lo_last_assc.TABLE_NAME = ''''AC_Contacts'''' AND lo_last_assc.FieldName = ''''LastName'''' AND lo_last_assc.ID_LANGUAGES = @CurLangID
LEFT JOIN L_Object lo_first_assc on lo_first_assc.ID_TABLE = assc.ContactID AND lo_first_assc.TABLE_NAME = ''''AC_Contacts'''' AND lo_first_assc.FieldName = ''''FirstName'''' AND lo_first_assc.ID_LANGUAGES = @CurLangID
LEFT JOIN ( SELECT o.id_emp AS ExtEmployeeID, cast(SUM(o.RealPerformance * o.Varitita/100) as decimal(16,2)) AS GoalScore
FROM SS_HRM_ASS_INSTANCE_OBJECTIVES_EMP o
WHERE id_Ass_instance = @ExtAssInstance AND (isnull(@ExcludeZeros,0)=0 OR isnull(o.RealPerformance,0)<>0)
GROUP BY o.id_emp
) goalscores on d.ExtEmployeeID = goalscores.ExtEmployeeID
LEFT JOIN Weights w on w.ExtEmployeeID = d.ExtEmployeeID
''+ case when @Is_Custom_Evropaiki=1 then '') InnerTbl'' else '''' end
;

SET    @SQLQuery = @SQLQuery1 + @SQLQuery2    + @SQLQuery3
Print @SQLQuery;
EXEC sp_executesql @SQLQuery;

END
'
GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[SS_HRM_ASS_RemoveEmployees]'
GO

ALTER PROCEDURE [dbo].[SS_HRM_ASS_RemoveEmployees] @InstanceID	int,  @ContactListStr varchar(max)
, @DeleteEvalFormListStr varchar(max)  --'all' or 'XXX,XXX,XXX'
, @DeleteQuestionnaireListStr varchar(max) --TODO
, @DeleteGoalSetting int --TODO
, @DeleteSignatures int --TODO

AS
BEGIN

SET NOCOUNT ON;

DECLARE @Ext_id_ass_instance int, @RemoveFromPylon int, @Separator varchar(10);
SET @Ext_id_ass_instance = (SELECT Ext_id_ass_instance FROM SS_HRM_ASS_INSTANCES where id = @InstanceID);
SET @RemoveFromPylon = (isnull((SELECT cast(varValue as int) FROM X_Vars WHERE varKey = 'AssessementsUpdatePylon'),1));  --TODO
SET @Separator= ',';

DECLARE @ContactList TABLE(ContactID int, Ext_ID_EMP int);
INSERT @ContactList
SELECT DISTINCT sp.Data, ae.EMP_ID
FROM udf_SplitByXml(@ContactListStr,@SEPARATOR) sp
JOIN AC_All_EmpIDS ae ON ae.ContactID=sp.Data;

IF (SELECT count(*) FROM @ContactList)=0 BEGIN
RETURN 0;
END

DECLARE @EvalFormList TABLE (ID int, Ext_id_ass int);
IF ltrim(rtrim(lower(@DeleteEvalFormListStr)))<>'all' BEGIN
INSERT @EvalFormList
SELECT DISTINCT sp.Data, a.Ext_id_ass
FROM udf_SplitByXml(@DeleteEvalFormListStr,@SEPARATOR) sp
JOIN SS_HRM_ASS_ASSESSMENTS a on sp.Data=a.ID;
END
ELSE BEGIN
INSERT @EvalFormList
SELECT DISTINCT a.ID, d.id_ass
FROM SS_HRM_ASS_Results_Detail rd
JOIN @ContactList cl on rd.Ext_id_emp=cl.Ext_ID_EMP
JOIN SS_HRM_ASS_Results d on rd.Ext_id_ass_res = d.Ext_id_ass_res
JOIN SS_HRM_ASS_ASSESSMENTS a on d.id_ass=a.Ext_id_ass
JOIN SS_HRM_ASS_INSTANCES ai on rd.id_ass_instance=ai.Ext_id_ass_instance
WHERE ai.ext_id_ass_instance=@Ext_id_ass_instance;
END;

IF (SELECT count(*) FROM @EvalFormList)>0 BEGIN
-- Validation
-- CURSOR for each Form, if after deleting specific ContactList there will still be at least 1 employee in there
-- TBD: how to report back denied delete because there would not be anyone left  (Assessment Log, insert with specific GUID, sp returns guid)
DECLARE @CountEmpsPerAss table (CountNum int, ExtRID int);
INSERT INTO @CountEmpsPerAss
SELECT count(*),d.Ext_id_ass_res
FROM SS_HRM_ASS_Results_Detail rd
JOIN SS_HRM_ASS_Results d on rd.Ext_id_ass_res = d.Ext_id_ass_res AND d.StatusID <> 2
JOIN @EvalFormList a on d.id_ass = a.Ext_id_ass
WHERE rd.id_ass_instance=@Ext_id_ass_instance AND rd.StatusID <> 2
GROUP BY d.Ext_id_ass_res

DECLARE @EvalItems TABLE (ExtRID int, ExtRDID int, ExtIDEMP int, ExtRDTID int, Ext_id_ass_par int);
INSERT @EvalItems
SELECT d.Ext_id_ass_res, rd.Ext_ID, rd.Ext_id_emp, rdt.Ext_id_param_type, e.id_ass_par
FROM SS_HRM_ASS_Results_Detail rd
JOIN @ContactList cl on rd.Ext_id_emp=cl.Ext_ID_EMP
JOIN SS_HRM_ASS_Results d on rd.Ext_id_ass_res = d.Ext_id_ass_res
JOIN @EvalFormList a on d.id_ass = a.Ext_id_ass
JOIN SS_HRM_ASS_INSTANCES ai on rd.id_ass_instance = ai.Ext_id_ass_instance
JOIN SS_HRM_ASS_Results_Detail_Type rdt on rdt.Ext_id_ass_res = d.Ext_id_ass_res AND rdt.Ext_id_emp=rd.Ext_id_emp
JOIN SS_HRM_ASS_Execution e on e.id_emp=rdt.Ext_id_emp and e.id_ass_res=rdt.Ext_id_ass_res and e.id_param_type=rdt.Ext_id_param_type
WHERE ai.ext_id_ass_instance=@Ext_id_ass_instance;


DECLARE @DeleteValidation table (ExtRID int, CanDelete int);
INSERT INTO @DeleteValidation
SELECT ei.ExtRID, CASE WHEN ce.CountNum > ei.countTBD THEN 1 ELSE 0 END
FROM @CountEmpsPerAss ce
join ( SELECT COUNT (*) AS countTBD,ExtRID FROM  (SELECT ExtRID,ExtIDEMP FROM @EvalItems GROUP BY ExtRID,ExtIDEMP) tb GROUP BY tb.ExtRID) ei on ei.ExtRID = ce.ExtRID

IF (SELECT MIN(CanDelete) FROM @DeleteValidation) = 1 BEGIN

BEGIN TRY
DELETE e
FROM SS_HRM_ASS_Execution e
JOIN @EvalItems i ON e.id_ass_res=i.ExtRID AND e.id_emp=i.ExtIDEMP AND e.id_param_type=i.ExtRDTID AND e.id_ass_par=i.Ext_id_ass_par;

DELETE e
FROM HRM_HRM_ASS_Execution e
JOIN @EvalItems i ON e.id_ass_res=i.ExtRID AND e.id_emp=i.ExtIDEMP AND e.id_param_type=i.ExtRDTID AND e.id_ass_par=i.Ext_id_ass_par;

DELETE rdt
FROM SS_HRM_ASS_Results_Detail_Type rdt
JOIN @EvalItems i ON rdt.Ext_id_ass_res=i.ExtRID AND rdt.Ext_id_emp=i.ExtIDEMP AND rdt.Ext_id_param_type=i.ExtRDTID;

DELETE rdt
FROM HRM_HRM_ASS_Results_Detail_Type rdt
JOIN @EvalItems i ON rdt.id_ass_res=i.ExtRID AND rdt.id_emp=i.ExtIDEMP AND rdt.id_param_type=i.ExtRDTID;

DELETE rd
FROM SS_HRM_ASS_Results_Detail rd
JOIN @EvalItems i on rd.Ext_id_ass_res=i.ExtRID and rd.Ext_id_emp = i.ExtIDEMP

DELETE rd
FROM HRM_HRM_ASS_Results_Detail rd
JOIN @EvalItems i on rd.id_ass_res=i.ExtRID and rd.id_emp = i.ExtIDEMP

RETURN 1
END TRY
BEGIN CATCH
RETURN -1
END CATCH
END
ELSE
RETURN 0;
END
ELSE
RETURN 0;


--DECLARE @QnrList TABLE (ID int);
--INSERT @QnrList
--     SELECT DISTINCT sp.Data FROM udf_SplitByXml(@DeleteQuestionnaireListStr,@SEPARATOR) sp;

--DELETE
--FROM [HRM_HRM_ASS_Results_Detail_Type]
--WHERE id_ass_res = @Ext_id_ass_res and id_emp in (SELECT EMP_ID FROM #TempEmpsInAss)


--DELETE
--FROM [SS_HRM_ASS_Results_Detail]
--WHERE id_ass_instance = @Id_ass_instance and Ext_id_emp in (SELECT EMP_ID FROM #TempEmpsInAss)

--DELETE
--FROM [HRM_HRM_ASS_Results_Detail]
--WHERE id_ass_instance = @Id_ass_instance and id_emp in (SELECT EMP_ID FROM #TempEmpsInAss)

END
GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[SS_HRM_ASS_ObjectivesSettings]'
GO

ALTER FUNCTION [dbo].[SS_HRM_ASS_ObjectivesSettings](@InstanceID int, @EmployeeID int,@CurUserID int)

--Use when SS_HRM_ASS_INSTANCES.GoalSettingMode = 2
RETURNS @RetTbl TABLE (AddVisibility int,EditVisibility int, DeleteVisibility int, DublicateVisibility int)

BEGIN
DECLARE @ExtInstanceID int, @ID_Emp int, @CurrentGoalSettingStatus int, @IsUserHR int, @CurNoOfObjectives int, @MinObjectives int, @MaxObjectives int, @GoalSettingAchievementStartDate datetime,@GoalSettingAchievementEndDate datetime, @CurUserID_Emp int, @ObjectiveSettingSubmitterContactID int, @ObjectiveAchievementSubmitterContactID int;
DECLARE @CurUserIsEmployeesManager table (ContactID int);
SET @ExtInstanceID =  (Select Ext_id_ass_instance from SS_HRM_ASS_INSTANCES where id = @InstanceID);
SET @ID_Emp = (SELECT EMP_ID FROM AC_All_EmpIDS where ContactID = @EmployeeID);

INSERT INTO  @CurUserIsEmployeesManager
select cm.RegularManager
from AC_Department_Contacts dc
CROSS APPLY SS_ContactCurrentManagerTreeUp (dc.ContactID,dc.DepartmentID) cm
where dc.ContactID = @EmployeeID AND CONVERT(date,getdate()) between dc.Startdate and isnull(dc.Enddate, '2049-12-31') AND cm.ManagerLevel = 1

SET @CurrentGoalSettingStatus = (Select isnull(CurrentGoalSettingStatus,0) from SS_HRM_ASS_INSTANCES where id = @InstanceID);
SET @CurNoOfObjectives = (SELECT count(*) From SS_HRM_ASS_INSTANCE_OBJECTIVES_EMP where id_ass_instance = @ExtInstanceID AND id_emp = @ID_Emp);
SET @MinObjectives = (SELECT ObjectivesMin From SS_HRM_ASS_INSTANCES where ID = @InstanceID);
SET @MaxObjectives = (SELECT ObjectivesMax From SS_HRM_ASS_INSTANCES where ID = @InstanceID);
SET @IsUserHR = (SELECT case when (select count(*) FROM XU_UserRoles WHERE RoleID in ( 1005, 1017) AND UsrId = @CurUserID)>0 then 1 else 0 end);
SET @GoalSettingAchievementStartDate = (Select GoalSettingAchievementStartDate from SS_HRM_ASS_INSTANCES where id = @InstanceID);
SET @GoalSettingAchievementEndDate = (Select isnull(GoalSettingAchievementEndDate,'2049-12-31') from SS_HRM_ASS_INSTANCES where id = @InstanceID);
SET @CurUserID_Emp = (SELECT EMP_ID FROM AC_All_EmpIDS where ContactID = @CurUserID);
SET @ObjectiveSettingSubmitterContactID = (SELECT SettingSubmitterContactID FROM SS_HRM_ASS_INSTANCE_OBJECTIVES_PARTICIPANTS WHERE id_ass_instance = @ExtInstanceID AND id_emp = @ID_Emp);
SET @ObjectiveAchievementSubmitterContactID = (SELECT AchievementSubmitterContactID FROM SS_HRM_ASS_INSTANCE_OBJECTIVES_PARTICIPANTS WHERE id_ass_instance = @ExtInstanceID AND id_emp = @ID_Emp)

DECLARE @AddVisibility int,@EditVisibility int, @DeleteVisibility int,@DublicateVisibility int;

SET @DublicateVisibility = 0;
IF (@CurrentGoalSettingStatus = 0 OR @ID_Emp not in (SELECT id_emp FROM SS_HRM_ASS_INSTANCE_OBJECTIVES_PARTICIPANTS WHERE id_ass_instance = @ExtInstanceID )) BEGIN
SET @AddVisibility = 0;
SET @EditVisibility = 0;
SET @DeleteVisibility = 0;
END
ELSE IF (@CurrentGoalSettingStatus = 1) BEGIN
--Mode=Setting
IF (@CurUserID in (SELECT ContactID FROM @CurUserIsEmployeesManager) OR (@IsUserHR = 1 AND @CurUserID <> @EmployeeID) OR @CurUserID = @ObjectiveSettingSubmitterContactID) BEGIN
IF (@CurNoOfObjectives <= @MaxObjectives) BEGIN
SET @AddVisibility = 1;
SET @DublicateVisibility = 1;
END
ELSE BEGIN
SET @AddVisibility = 0;
SET @DublicateVisibility = 0;
END

SET @EditVisibility = 1;
SET @DeleteVisibility = 1;


END
ELSE BEGIN
SET @AddVisibility = 0;
SET @EditVisibility = 0;
SET @DeleteVisibility = 0;
END
END
ELSE IF (@CurrentGoalSettingStatus = 2) BEGIN
--Mode=Achievement
IF (((@CurUserID in (SELECT ContactID FROM @CurUserIsEmployeesManager) OR @CurUserID = @ObjectiveAchievementSubmitterContactID) AND CONVERT(date,getdate()) between @GoalSettingAchievementStartDate and @GoalSettingAchievementEndDate ) OR (@IsUserHR = 1 AND @CurUserID <> @EmployeeID)) BEGIN
SET @EditVisibility = 1;
END
ELSE BEGIN
SET @EditVisibility = 0;
END

SET @AddVisibility = 0;
SET @DeleteVisibility = 0;
END
ELSE BEGIN
SET @AddVisibility = 0;
SET @EditVisibility = 0;
SET @DeleteVisibility = 0;
END


INSERT @RetTbl
SELECT @AddVisibility,@EditVisibility,@DeleteVisibility, @DublicateVisibility;

RETURN;
END
GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
IF EXISTS (SELECT * FROM #tmpErrors) ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT>0 BEGIN
PRINT 'The schema update succeeded'
COMMIT TRANSACTION
END
ELSE PRINT 'The schema update failed'
GO
DROP TABLE #tmpErrors
GO
