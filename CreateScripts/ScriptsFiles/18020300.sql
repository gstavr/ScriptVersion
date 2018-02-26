/*
You are recommended to back up your database before running this script
Version 18.2.3.0 
Date 26/02/2018
*/
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
PRINT N'Altering [dbo].[SS_ApplicationRunUserValidation]'
GO
ALTER FUNCTION [dbo].[SS_ApplicationRunUserValidation](@UserID int, @ApplicationID int, @ApproverID int)
RETURNS @RetTbl TABLE (
Info varchar(1000)
, HREditorInfo varchar(1000)
, AdditionalApproverInfo varchar(1000)
, AllowView int
, AllowEdit int
, AllowCancel int
, AllowApproverTransaction int
, AllowAddNewDocuments int
, AllowEditDocuments int
, AllowPrint int
, AllowSubmit int
, AllowTempSave int
, ExpenseEditOverdraft int
, ExpenseApproveOverdraft int
, ExpenseChooseCostCenter int
, ShowApproverCombo int
, RetApproverID int
, AllowCancelWithApplication int --DESS-122705 2/11/2017
)
AS
BEGIN

--
-- Define Roles
--
DECLARE @HREditorRole int, @AdminRole int, @AccountingRole int, @HREditorPerCompany int, @AttendanceKeeper int, @AttedanceKeeperWithExtendedRights int,@ApplicationViewer int,@HRViewer int, @EmployeeInfoSubmitter int;
SET @HREditorRole = 1005;
SET @AdminRole = 1003;
SET @AccountingRole = 1009;
SET @HREditorPerCompany = 1011;

SET @AttendanceKeeper = 1010;
SET @AttedanceKeeperWithExtendedRights = -2; -- Can view multiple departments
SET @ApplicationViewer = 1015;
SET @HRViewer = 1018;
SET @EmployeeInfoSubmitter = 1012;
--
-- Define return default values
--
DECLARE @Info varchar(1000)
, @HREditorInfo varchar(1000)
, @AdditionalApproverInfo varchar(1000)
, @AllowView int
, @AllowEdit int
, @AllowCancel int
, @AllowApproverTransaction int
, @AllowAddNewDocuments int
, @AllowEditDocuments int
, @AllowPrint int
, @AllowSubmit int
, @AllowTempSave int
, @ExpenseEditOverdraft int
, @ExpenseApproveOverdraft int
, @ExpenseChooseCostCenter int
, @ShowApproverCombo int
, @RetApproverID int
, @AllowCancelWithApplication int; --DESS-122705 2/11/2017

SET @Info = null;
SET @HREditorInfo = null;
SET @AdditionalApproverInfo = null;
SET @AllowView = 0;
SET @AllowEdit = 0;
SET @AllowCancel = 0;
SET @AllowApproverTransaction = 0;
SET @AllowAddNewDocuments = 0;
SET @AllowEditDocuments = 0;
SET @AllowPrint = 1;
SET @AllowSubmit = 0;
SET @AllowTempSave = 0;
SET @ExpenseEditOverdraft = 0;
SET @ExpenseApproveOverdraft = 0;
SET @ExpenseChooseCostCenter = 0;
SET @ShowApproverCombo = 0;
SET @RetApproverID = null;
SET @AllowCancelWithApplication = 0; --DESS-122705 2/11/2017

--
-- Other variables needed
--
DECLARE @EmployeeID int
, @AppTypeID int
, @AppStatusID int
, @CurApproverID int
, @CurApproverStatusID int
, @CurApproverReevaluate int
, @CurApproverCompletingValidations int
, @HasStrictOrder int;

IF @ApplicationID = -1 OR @ApplicationID = -999 OR @ApplicationID IS null BEGIN
INSERT @RetTbl
SELECT 'lbApplicationIsNew'
, null
, null
, 1
, 0
, 0
, 0
, 0	-- @AllowAddNewDocuments   5/1/2018 In ucApplication thid field is calculated from code
, 0 -- @AllowEditDocuments	   5/1/2018 In ucApplication thid field is calculated from code
, 0
, 1
, 1
, 0
, 0
, 0
, 0
, null
, 0; --DESS-122705 2/11/2017

RETURN;
END

--Check if application exists in db
IF (select count(*) FROM SS_Applications where ID = @ApplicationID) = 0 BEGIN
SET @Info = 'lbApplicationIDNotExists';
END
ELSE BEGIN
-- Calc all necessary fields for this application
SET @EmployeeID = (select EmployeeID FROM SS_Applications where ID = @ApplicationID);
SET @AppTypeID = (select TypeID FROM SS_Applications where ID = @ApplicationID);
SET @AppStatusID = (select StatusID FROM SS_Applications where ID = @ApplicationID);
SET @CurApproverID = (select TOP 1 ID FROM SS_Application_WorkFlowApprovers WHERE ApplicationID = @ApplicationID AND ApproverID = @UserID);
SET @CurApproverStatusID = (select TOP 1 ApprovalStatusID FROM SS_Application_WorkFlowApprovers WHERE ApplicationID = @ApplicationID AND ApproverID = @UserID);
SET @CurApproverReevaluate = (select TOP 1 ReEvaluateApprover FROM SS_Application_WorkFlowApprovers WHERE ApplicationID = @ApplicationID AND ApproverID = @UserID);
SET @CurApproverCompletingValidations = (select TOP 1 CompletingValidations FROM SS_Application_WorkFlowApprovers WHERE ApplicationID = @ApplicationID AND ApproverID = @UserID);

-- Added 28/9/2016
DECLARE @SubmitterID int;
SET @SubmitterID = (select SubmitterID FROM SS_Applications where ID = @ApplicationID);

-- Added 18/10/2016
DECLARE @ERExported bit;
SET @ERExported = (select Exported FROM SS_Applications where ID = @ApplicationID);

DECLARE @WorkflowStrictOrder AS INT, @SiteStrictOrder AS INT;
SET @WorkflowStrictOrder = isnull((SELECT TOP 1 aw.KeepStrictOrder from SS_ApplicationTypes t JOIN SS_ApprovalWorkflows aw on t.ApprovalWorkflowID = aw.ID WHERE t.ID = @AppTypeID),0);
SET @SiteStrictOrder = isnull((select TOP 1 varValue from X_Vars WHERE varKey = 'AppStrictOrder'),0);
SET @HasStrictOrder = (case when @WorkflowStrictOrder + @SiteStrictOrder >=1 then 1 else 0 end);

IF @ApproverID = -999 BEGIN
-- Special case to calculate ApproverID automatically (HR Editor case to get the "next" approver)
DECLARE @AutoCalcAwaID int;
SET @AutoCalcAwaID = (SELECT TOP 1 ID FROM SS_Application_WorkFlowApprovers awa WHERE ApplicationID = @ApplicationID AND ApprovalStatusID is null ORDER BY OrderNum);
IF @AutoCalcAwaID is not null BEGIN
SET @ApproverID = @AutoCalcAwaID;
END;
END;

--Check if the user has submitted this application
IF @EmployeeID = @UserID
-- Added 28/9/2016
OR (@SubmitterID = @UserID AND @AppStatusID=6)
BEGIN
-- Added 28/9/2016
IF @EmployeeID = @UserID BEGIN
IF @SubmitterID <> @UserID BEGIN
SET @Info = 'lbUserIsApplicationEmployeeSubmittedFromOtherEmployee';
END
ELSE BEGIN
SET @Info = 'lbUserIsApplicationEmployee';
END
END
ELSE BEGIN
SET @Info = 'lbUserIsSubmittingApplicationForOtherEmployee';
END;
-- Added 30/9/2016
IF (@SubmitterID = @UserID AND @AppStatusID=6) BEGIN
if (select varvalue from X_Vars where varkey = 'UseExpenseReportMode') = 1  AND @AppTypeID = 13  -- 27/6/2017 GP Added @AppTypeID. Used only for expense reports
SET @AllowEdit = 0
else SET @AllowEdit = 1
;

END;


--Added 1/3/2017 Case: When user is submitter or application employee and status is temp save, user can edit
IF ((@EmployeeID = @UserID) OR (@SubmitterID = @UserID AND @AppStatusID=6)) BEGIN
if (select varvalue from X_Vars where varkey = 'UseExpenseReportMode') = 2  AND @AppTypeID = 13 begin -- 27/6/2017 GP Added @AppTypeID. Used only for expense reports
SET @AllowEdit = 1
END
END

SET @AllowView = 1;

-- Additional Actions, depending on app workflow
IF @AppStatusID = 1 BEGIN
-- Application is Pending
-- Allow Cancelling App, and providing new documents or editing existing documents
SET @AllowCancel = 1;
SET @AllowAddNewDocuments = 1;
SET @AllowEditDocuments = 1;
END
ELSE BEGIN
IF @AppStatusID = 3 BEGIN
-- Application is Complete (Approved)
-- Allow Printing App, and providing new documents
SET @AllowPrint = 1;
SET @AllowAddNewDocuments = 1;
END
ELSE BEGIN
IF @AppStatusID = 6 BEGIN
-- Application is temporarily saved
SET @AllowSubmit = 1;
SET @AllowTempSave = 1;
SET @AllowCancel = 1;
-- Added 6/10/2016
SET @AllowAddNewDocuments = 1;
SET @AllowEditDocuments = 1;
--
END;
END;
END;
END
ELSE BEGIN
--Check if this is an application that an employee the user substitutes for has submitted
IF (select count(*) from dbo.[SS_GetSubstituteForContactAndAppType](@UserID, @AppTypeID) where IsTheSubstituteFor = @EmployeeID) > 0 BEGIN
SET @Info = 'lbUserIsApplicationEmployeeSub';
SET @AllowView = 1;

-- Additional Actions, depending on app workflow
IF @AppStatusID = 1 BEGIN
-- Application is Pending
-- Allow Cancelling App, and providing new documents or editing existing documents
SET @AllowCancel = 1;
SET @AllowAddNewDocuments = 1;
SET @AllowEditDocuments = 1;
END
ELSE BEGIN
IF @AppStatusID = 3 BEGIN
-- Application is Complete (Approved)
-- Allow Printing App, and providing new documents
SET @AllowPrint = 1;
SET @AllowAddNewDocuments = 1;
END
ELSE BEGIN
IF @AppStatusID = 6 BEGIN
-- Application is temporarily saved
SET @AllowSubmit = 1;
SET @AllowTempSave = 1;
SET @AllowCancel = 1;
-- Added 6/10/2016
SET @AllowAddNewDocuments = 1;
SET @AllowEditDocuments = 1;
END;
END;
END;
END
ELSE BEGIN
--Check if the User is HR Editor or Admin
--17/11/2016 Added HREditorPerCompany role
IF (select count(*) FROM XU_UserRoles WHERE UsrID = @UserID AND RoleID in (@HREditorRole, @AdminRole,@HREditorPerCompany)) > 0 BEGIN
SET @Info = 'lbUserIsApplicationHREditor';
SET @AllowView = 1;

-- An HR Editor can add/edit documents at any time (provided the application is submitted and not temporarily saved)
IF isnull(@AppStatusID,0) <> 6 BEGIN
SET @AllowAddNewDocuments = 1;
SET @AllowEditDocuments = 1;
SET @AllowPrint = 1;
END;

-- An HR Editor can choose for which approver the transaction will be made
-- Added 5/10/2016:  Approver Combo should not be shown if Application is still @ Temporary Status
IF @AppStatusID = 6 BEGIN
SET @ShowApproverCombo = 0;
END
ELSE BEGIN
SET @ShowApproverCombo = 1;
END;

-- An HR Editor has the right to cancel a user application, if it is not complete
IF isnull(@AppStatusID,1) = 1 BEGIN
SET @AllowCancel = 1;
END;

-- An HR Editor has the right to edit all approver additional stuff for expense applications, if the application is still Pending
IF @AppTypeID = 13 AND isnull(@AppStatusID,1) = 1 BEGIN
SET @ExpenseEditOverdraft = 1;
SET @ExpenseApproveOverdraft = 1;
SET @ExpenseChooseCostCenter = 1;
END;

-- Check if ApproverID was provided and if it is valid
IF @ApproverID is not null BEGIN
IF (select count(*) from SS_Application_WorkflowApprovers WHERE ApplicationID = @ApplicationID AND ID = @ApproverID) = 0 BEGIN
-- This is not a valid ApproverID, clear it
SET @ApproverID = null;
END
ELSE BEGIN
-- This is a valid ApproverID, recalc necessary info from provided ApproverID
SET @CurApproverStatusID = (select TOP 1 ApprovalStatusID FROM SS_Application_WorkFlowApprovers WHERE ID = @ApproverID);
SET @CurApproverReevaluate = (select TOP 1 ReEvaluateApprover FROM SS_Application_WorkFlowApprovers WHERE ID = @ApproverID);
SET @CurApproverCompletingValidations = (select TOP 1 CompletingValidations FROM SS_Application_WorkFlowApprovers WHERE ID = @ApproverID);
END;
END;

-- Use provided valid ApproverID or automatically choose it if the HR Editor user already exists in the list of approvers for this application
IF isnull(@ApproverID, @CurApproverID) is not null BEGIN
SET @HREditorInfo = 'lbHREditorSubmitsApplicationAsApprover';
SET @RetApproverID = isnull(@ApproverID, @CurApproverID);
--Check the status of this application (as a whole)
IF @AppStatusID = 1 BEGIN
-- It's a Pending Application
-- Check if the approver has already made a transaction
IF @CurApproverStatusID is null BEGIN
-- There is no transaction yet
-- Check if it's the approver's turn
IF @CurApproverReevaluate = 1 BEGIN
--It isn't the approver's turn yet
--Check if there is strict order
IF @HasStrictOrder = 1 BEGIN
--There is strict order, no transaction can be made
SET @AdditionalApproverInfo = 'lbApplicationEarlyApproveStrictOrder';
END
ELSE BEGIN
--There is no strict order, HR Editor can still do transaction (will bypass all previous approvers)
SET @AdditionalApproverInfo = 'lbApplicationEarlyApproveNoStrictOrder';
IF isnull(@AppStatusID,0) <> 6 BEGIN
SET @AllowApproverTransaction = 1;
SET @AllowEdit = 1;
END
ELSE BEGIN
-- Employee has not officially submitted the application yet, approver should not act on it
SET @AllowApproverTransaction = 0;
END;
END;
END
ELSE BEGIN
--It's Approver's turn
IF isnull(@AppStatusID,0) <> 6 BEGIN
SET @AllowApproverTransaction = 1;
SET @AllowEdit = 1;
END
ELSE BEGIN
-- Employee has not officially submitted the application yet, approver should not act on it
SET @AllowApproverTransaction = 0;
END;
END;
END
ELSE BEGIN
--Transaction for this approver has already been made, HR Editor can still do transaction
SET @AdditionalApproverInfo = 'lbApplicationPendingWorkflowTransactionExists';
IF isnull(@AppStatusID,0) <> 6 BEGIN
SET @AllowApproverTransaction = 1;
SET @AllowEdit = 1;
END
ELSE BEGIN
-- Employee has not officially submitted the application yet, approver should not act on it
SET @AllowApproverTransaction = 0;
END;
END;
END
ELSE BEGIN
-- It's a Complete Application, HR Editor can still do Transaction
IF @AppStatusID = 3 BEGIN
-- Added 18/10/2016
-- Logic for Expense Reports
IF @AppTypeID = 13 BEGIN
IF @ERExported = 1 BEGIN
SET @AdditionalApproverInfo = 'lbExpenseReportDoneAndExported';
END
ELSE BEGIN
SET @AdditionalApproverInfo = 'lbExpenseReportDoneNotExported';
END;
END
ELSE BEGIN
SET @AdditionalApproverInfo = 'lbApplicationDoneWorkFlowAdminUser';
END;
END
ELSE BEGIN
SET @AdditionalApproverInfo = 'lbApplicationDoneWorkFlowAdminUserReject';
END;
IF isnull(@AppStatusID,0) <> 6 BEGIN
SET @AllowApproverTransaction = 1;
SET @AllowEdit = 1;
END
ELSE BEGIN
-- Employee has not officially submitted the application yet, approver should not act on it
SET @AllowApproverTransaction = 0;
END;
END;
END
ELSE BEGIN
-- HR Editor / Admin has not selected an approver to do the transaction
SET @HREditorInfo = 'lbHREditorSubmitsApplicationChooseApprover';
END;
END
ELSE BEGIN
-- User is not an HR Editor / Admin
-- Check if the user appears in the approvers
IF @CurApproverID is not null BEGIN
-- User is an approver
SET @Info = 'lbUserIsApplicationApprover';
SET @AllowView = 1;
SET @RetApproverID = @CurApproverID;
-- Check the status of this application (as a whole)
IF @AppStatusID = 1 BEGIN
-- It's a Pending Application
-- Allow adding new documents
SET @AllowAddNewDocuments = 1;
-- Check if the approver has already made a transaction
IF @CurApproverStatusID is null BEGIN
-- There is no transaction yet
-- Check if it's the approver's turn
IF @CurApproverReevaluate = 1 BEGIN
--It isn't the approver's turn yet
--Check if there is strict order
IF @HasStrictOrder = 1 BEGIN
--There is strict order, no transaction can be made
SET @AdditionalApproverInfo = 'lbApplicationEarlyApproveStrictOrder';
END
ELSE BEGIN
--There is no strict order, regular user can still do transaction (will bypass all previous approvers)
SET @AdditionalApproverInfo = 'lbApplicationEarlyApproveNoStrictOrder';
IF isnull(@AppStatusID,0) <> 6 BEGIN
SET @AllowApproverTransaction  = 1;
SET @AllowEdit = 1;
-- An Approver can edit stuff for expense applications, if the application is still Pending
IF @AppTypeID = 13 AND isnull(@AppStatusID,1) = 1 BEGIN
SET @ExpenseEditOverdraft = 1;
SET @ExpenseApproveOverdraft = 1;
iF EXISTS (SELECT * FROM x_vars WHERE varkey = 'UseExpenseReportMode'
and varvalue = 1 ) and @AppTypeID = 13 and 	isnull(@AppStatusID,1) = 1
begin
set @AllowSubmit = 1;
end;
IF @CurApproverCompletingValidations = 1 BEGIN
SET @ExpenseChooseCostCenter = 1;
END;
END;
END
ELSE BEGIN
-- Employee has not officially submitted the application yet, approver should not act on it
SET @AllowApproverTransaction = 0;
END;
END;
END
ELSE BEGIN
--It's Approver's turn
IF isnull(@AppStatusID,0) <> 6 BEGIN
SET @AllowApproverTransaction = 1;
SET @AllowEdit = 1;
-- An Approver can edit stuff for expense applications, if the application is still Pending
IF @AppTypeID = 13 AND isnull(@AppStatusID,1) = 1 BEGIN
SET @ExpenseEditOverdraft = 1;
SET @ExpenseApproveOverdraft = 1;
iF EXISTS (SELECT * FROM x_vars WHERE varkey = 'UseExpenseReportMode'
and varvalue = 1 ) and @AppTypeID = 13 and 	isnull(@AppStatusID,1) = 1
begin
set @AllowSubmit = 1;
end;
IF @CurApproverCompletingValidations = 1 BEGIN
SET @ExpenseChooseCostCenter = 1;
END;
END;
END
ELSE BEGIN
-- Employee has not officially submitted the application yet, approver should not act on it
SET @AllowApproverTransaction = 0;
END;
END;
END
ELSE BEGIN
--Transaction for this approver has already been made, regular user can still do transaction
SET @AdditionalApproverInfo = 'lbApplicationPendingWorkflowTransactionExists';
IF isnull(@AppStatusID,0) <> 6 BEGIN
--22/5/2017
IF EXISTS (SELECT * FROM x_vars WHERE varkey = 'ApplicationHideApproveActionWhenAppApproved' and varvalue = 1 ) BEGIN
SET @AllowApproverTransaction = 0;
END
ELSE BEGIN
SET @AllowApproverTransaction = 1;
END
SET @AllowEdit = 1;
-- An Approver can edit stuff for expense applications, if the application is still Pending
IF @AppTypeID = 13 AND isnull(@AppStatusID,1) = 1 BEGIN
SET @ExpenseEditOverdraft = 1;
SET @ExpenseApproveOverdraft = 1;
iF EXISTS (SELECT * FROM x_vars WHERE varkey = 'UseExpenseReportMode'
and varvalue = 1 ) and @AppTypeID = 13 and 	isnull(@AppStatusID,1) = 1
begin
set @AllowSubmit = 1;
end;
IF @CurApproverCompletingValidations = 1 BEGIN
SET @ExpenseChooseCostCenter = 1;
END;
END;
END
ELSE BEGIN
-- Employee has not officially submitted the application yet, approver should not act on it
SET @AllowApproverTransaction = 0;
END;
END;
END
ELSE BEGIN
-- It's a Complete Application, regular user cannot do Transaction
SET @AdditionalApproverInfo = 'lbApplicationDoneWorkFlowRegularUser';
-- Allow Printing App, and providing new documents (for HR use after completion)
SET @AllowPrint = 1;
SET @AllowAddNewDocuments = 1;
END;
END
ELSE BEGIN
--Check if the user substitutes for the manager of the employee who should give approval
DECLARE @CurApproverCount int;
SET @CurApproverCount = (select count(*) From SS_Application_WorkFlowApprovers where ApplicationID = @ApplicationID AND ApproverID in (select IsTheSubstituteFor from dbo.[SS_GetSubstituteForContactAndAppType](@UserID, @AppTypeID)));
IF  @CurApproverCount > 0 BEGIN
SET @CurApproverID = (select TOP 1 ID From SS_Application_WorkFlowApprovers where ApplicationID = @ApplicationID AND ApproverID in (select IsTheSubstituteFor from dbo.[SS_GetSubstituteForContactAndAppType](@UserID, @AppTypeID)));

-- Check if the user substitutes for more than 1 people in the approvers list
IF @CurApproverCount > 1 BEGIN
-- Added 5/10/2016:  Approver Combo should not be shown if Application is still @ Temporary Status
IF @AppStatusID = 6 BEGIN
SET @ShowApproverCombo = 0;
END
ELSE BEGIN
SET @ShowApproverCombo = 1;
END;

-- Check if there is a provided ApproverID, and if so, if is valid
IF (select count(*) from SS_Application_WorkflowApprovers WHERE ApplicationID = @ApplicationID AND ID = @ApproverID) = 0 BEGIN
-- This is not a valid ApproverID, clear it
SET @ApproverID = null;
END
ELSE BEGIN
-- This is a valid ApproverID
SET @CurApproverID = @ApproverID;
END;
END;

SET @Info = 'lbUserIsApplicationApproverSub';
SET @AllowView = 1;

-- Recalc Status and ReEvaluate
SET @CurApproverStatusID = (select TOP 1 ApprovalStatusID FROM SS_Application_WorkFlowApprovers WHERE ID = @CurApproverID);
SET @CurApproverReevaluate = (select TOP 1 ReEvaluateApprover FROM SS_Application_WorkFlowApprovers WHERE ID = @CurApproverID);
SET @CurApproverCompletingValidations = (select TOP 1 CompletingValidations FROM SS_Application_WorkFlowApprovers WHERE ID = @CurApproverID);
SET @RetApproverID = @CurApproverID;

-- Check the status of the workflow for this application
IF @AppStatusID = 1 BEGIN
-- It's a Pending Application
-- Allow adding new documents
SET @AllowAddNewDocuments = 1;
-- Check if the approver has already made a transaction
IF @CurApproverStatusID is null BEGIN
-- There is no transaction yet
-- Check if it's the approver's turn
IF @CurApproverReevaluate = 1 BEGIN
--It isn't the approver's turn yet
--Check if there is strict order
IF @HasStrictOrder = 1 BEGIN
--There is strict order, no transaction can be made
SET @AdditionalApproverInfo = 'lbApplicationEarlyApproveStrictOrder';
END
ELSE BEGIN
--There is no strict order, regular user can still do transaction (will bypass all previous approvers)
SET @AdditionalApproverInfo = 'lbApplicationEarlyApproveNoStrictOrder';
IF isnull(@AppStatusID,0) <> 6 BEGIN
SET @AllowApproverTransaction = 1;
SET @AllowEdit = 1;
-- An Approver can edit stuff for expense applications, if the application is still Pending
IF @AppTypeID = 13 AND isnull(@AppStatusID,1) = 1 BEGIN
SET @ExpenseEditOverdraft = 1;
SET @ExpenseApproveOverdraft = 1;
iF EXISTS (SELECT * FROM x_vars WHERE varkey = 'UseExpenseReportMode'
and varvalue = 1 ) and @AppTypeID = 13 and 	isnull(@AppStatusID,1) = 1
begin
set @AllowSubmit = 1;
end;
IF @CurApproverCompletingValidations = 1 BEGIN
SET @ExpenseChooseCostCenter = 1;
END;
END;
END
ELSE BEGIN
-- Employee has not officially submitted the application yet, approver should not act on it
SET @AllowApproverTransaction = 0;
END;
END;
END
ELSE BEGIN
--It's Approver's turn
IF isnull(@AppStatusID,0) <> 6 BEGIN
SET @AllowApproverTransaction = 1;
SET @AllowEdit = 1;
-- An Approver can edit stuff for expense applications, if the application is still Pending
IF @AppTypeID = 13 AND isnull(@AppStatusID,1) = 1 BEGIN
SET @ExpenseEditOverdraft = 1;
SET @ExpenseApproveOverdraft = 1;
iF EXISTS (SELECT * FROM x_vars WHERE varkey = 'UseExpenseReportMode'
and varvalue = 1 ) and @AppTypeID = 13 and 	isnull(@AppStatusID,1) = 1
begin
set @AllowSubmit = 1;
end;
IF @CurApproverCompletingValidations = 1 BEGIN
SET @ExpenseChooseCostCenter = 1;
END;
END;
END
ELSE BEGIN
-- Employee has not officially submitted the application yet, approver should not act on it
SET @AllowApproverTransaction = 0;
END;
END;
END
ELSE BEGIN
--Transaction for this approver has already been made, regular user can still do transaction
SET @AdditionalApproverInfo = 'lbApplicationPendingWorkflowTransactionExists';
IF isnull(@AppStatusID,0) <> 6 BEGIN
--22/5/2017
IF EXISTS (SELECT * FROM x_vars WHERE varkey = 'ApplicationHideApproveActionWhenAppApproved' and varvalue = 1 ) BEGIN
SET @AllowApproverTransaction = 0;
END
ELSE BEGIN
SET @AllowApproverTransaction = 1;
END
SET @AllowEdit = 1;
-- An Approver can edit stuff for expense applications, if the application is still Pending
IF @AppTypeID = 13 AND isnull(@AppStatusID,1) = 1 BEGIN
SET @ExpenseEditOverdraft = 1;
SET @ExpenseApproveOverdraft = 1;
iF EXISTS (SELECT * FROM x_vars WHERE varkey = 'UseExpenseReportMode'
and varvalue = 1 ) and @AppTypeID = 13 and 	isnull(@AppStatusID,1) = 1
begin
set @AllowSubmit = 1;
end;
IF @CurApproverCompletingValidations = 1 BEGIN
SET @ExpenseChooseCostCenter = 1;
END;
END;
END
ELSE BEGIN
-- Employee has not officially submitted the application yet, approver should not act on it
SET @AllowApproverTransaction = 0;
END;
END;
END
ELSE BEGIN
-- It's a Complete Application, regular user cannot do Transaction
SET @AdditionalApproverInfo = 'lbApplicationDoneWorkFlowRegularUser';
-- Allow Printing App, and providing new documents (for HR use after completion)
SET @AllowPrint = 1;
SET @AllowAddNewDocuments = 1;
END;
END
ELSE BEGIN
-- Check if this application was made by an employee of the user
DECLARE @IsMyEmployeeApp int;
SET @IsMyEmployeeApp =
(
SELECT count(*)
FROM SS_Applications a
WHERE a.ID = @ApplicationID
AND a.EmployeeID in (
SELECT ndc.ContactID AS MyEmployeeID
FROM  AC_Departments_FullView  nv    --AC_Department_NodeView nv
JOIN AC_Department_Contacts ndc ON ndc.DepartmentID = nv.ID AND ndc.ContactID <> @UserID AND getdate() BETWEEN ndc.StartDate AND isnull(ndc.EndDate, '2049-12-31')
WHERE nv.TopID in (
SELECT DepartmentID
FROM AC_Department_Contacts
WHERE ContactID = @UserID AND IsManager = 1 AND getdate() BETWEEN StartDate AND isnull(EndDate, '2049-12-31')
)
)
);
IF @IsMyEmployeeApp > 0 BEGIN
-- Application was made by an employee of the user
SET @Info = 'lbUserEmployeeApplicationNoApprover';
SET @AllowView = 1;
IF @AppStatusID = 3 BEGIN
--App is Approved, allow Printing
SET @AllowPrint = 1;
END;
END
ELSE BEGIN
-- Check if this application was made by an employee whose manager the user substitutes for
DECLARE @IsEmployeeAppForManagerISubstitute int;
SET @IsEmployeeAppForManagerISubstitute =
(
SELECT count(*)
FROM SS_Applications a
WHERE a.ID = @ApplicationID
AND a.EmployeeID in (
SELECT ndc.ContactID AS MyEmployeeID
FROM AC_Departments_FullView nv --AC_Department_NodeView nv
JOIN AC_Department_Contacts ndc ON ndc.DepartmentID = nv.ID AND ndc.ContactID <> @UserID AND getdate() BETWEEN ndc.StartDate AND isnull(ndc.EndDate, '2049-12-31')
WHERE nv.TopID in (
SELECT DepartmentID
FROM AC_Department_Contacts
WHERE ContactID = @UserID AND IsManager = 1 AND getdate() BETWEEN StartDate AND isnull(EndDate, '2049-12-31')
)
)
);
IF @IsEmployeeAppForManagerISubstitute > 0 BEGIN
-- Application was made by an employee whose manager the user substitutes for
SET @Info = 'lbUserEmployeeApplicationNoApproverSub';
SET @AllowView = 1;
IF @AppStatusID = 3 BEGIN
--App is Approved, allow Printing
SET @AllowPrint = 1;
END;
END
ELSE BEGIN
DECLARE @UserIsViewOnlyForThisEmployee int;
SET @UserIsViewOnlyForThisEmployee = (
SELECT count(*)
FROM SS_ApplicationESSPermissions aep
CROSS APPLY dbo.SS_GetDeptListFromNodeDown(aep.DepartmentID) nl
JOIN AC_Department_Contacts dc on nl.ID = dc.DepartmentID and dc.ContactID = @EmployeeID and getdate() between dc.StartDate and isnull(dc.EndDate, '2049-12-31')
WHERE aep.ContactID = @UserID
AND getdate() between aep.StartDate and isnull(aep.EndDate, '2049-12-31')
);

--22/11/2016 Added the role of AttendanceKeeper  and AttedanceKeeperWithExtendedRights in order to have view only rights to see an application (Attendace Keeper view - view application)
IF @UserIsViewOnlyForThisEmployee > 0  OR (select count(*) FROM XU_UserRoles WHERE UsrID = @UserID AND RoleID in (@AttendanceKeeper, @AttedanceKeeperWithExtendedRights)) > 0
OR (@AppTypeID = 1 AND ((select count(*) FROM XU_UserRoles WHERE UsrID = @UserID AND RoleID in (@ApplicationViewer)) >0))
OR ((select count(*) FROM XU_UserRoles WHERE UsrID = @UserID AND RoleID in (@HRViewer)) >0)  BEGIN  --6/3/2017 Added ApplicationViewer role to view applications
SET @Info = 'lbUserEmployeeApplicationForViewOnly';
SET @AllowView = 1;
IF @AppStatusID = 3 SET @AllowPrint = 1; --App is Approved, allow Printing
END
ELSE BEGIN
-- No criteria were met.  User should not see this application.
SET @Info = 'lbUserApplicationNoPermission';
END;
END;
END;
END;
END;
END;
END;
END;
END;

IF @AppTypeID = 13 AND @AppStatusID = 3 AND (select count(*) FROM XU_UserRoles WHERE UsrID = @UserID AND RoleID = @AccountingRole) > 0 BEGIN
-- Added 18/10/2016
-- Expense Report should not be editable if already exported
IF isnull(@ERExported,0) = 0 BEGIN
SET @AllowEdit = 1;
IF @HREditorInfo is not null AND ltrim(rtrim(@HREditorInfo)) <> '' BEGIN
SET @HREditorInfo = 'lbAccountantUserEditsApprovedExpenses';
END;
END
ELSE BEGIN
SET @HREditorInfo = 'lbExpenseReportDoneAndExported';
END;
END;

--Accountant can view all expenses applications
--Added 3/4/2017
IF @AppTypeID = 13 AND (select count(*) FROM XU_UserRoles WHERE UsrID = @UserID AND RoleID = @AccountingRole) > 0 BEGIN
SET @AllowView = 1;
SET @AllowAddNewDocuments = 1;
SET @Info = 'lbUserApplicationIsAccountant'; --Overlaps all
END;

--
-- Cancel Application Special Logic
--
IF (select count(*) from X_Vars where varKey = 'SSAppCancelSpecialLogic' and varValue = '1') > 0 BEGIN
--17/11/2016 Added HREditorPerCompany role
IF @AppTypeID in (1,2) AND @AppStatusID = 3 AND (select count(*) FROM XU_UserRoles WHERE UsrID = @UserID AND RoleID in (@HREditorRole,@HREditorPerCompany)) > 0 BEGIN
SET @AllowCancel = 1;
END;
END;

--Added 31/3/2017
--If expense report and status rejected, do not show print
IF @AppStatusID = 2 AND @AppTypeID = 13 BEGIN
SET @AllowPrint = 0;
END;

IF @AppStatusID = 2 AND @AppTypeID not in (13,24) BEGIN
SET @AllowEdit = 0;
END;

IF @AppTypeID in (10,3) BEGIN
--21/4/2017 AdvancePayment & Loan type. Always not editable
SET @AllowEdit = 0;
END;

IF @AppTypeID = 29  BEGIN
IF (select count(*) FROM XU_UserRoles WHERE UsrID = @UserID AND RoleID  in (@HREditorRole,@EmployeeInfoSubmitter)) > 0 AND @AllowEdit = 1 BEGIN  -- 21/2/2012 (129368)
SET @AllowEdit = 1;
END
ELSE BEGIN
SET @AllowEdit = 0;
END
END;

--DESS-117353 - Vacation (1) & Change Employee Info application (1).  SS_ADEIES_TYPE.NeedsProof = 1 then show attachenments
-- Emploee/submitter/HR can add attachments when application is not canceled or temp
--Added 1/6/2017
DECLARE  @TimeOffTypeID int, @ApplicationTypeHasAttachments int, @NeedsProof_ShowAttachments int;
SET @TimeOffTypeID = (select TimeOffTypeID FROM SS_Applications where ID = @ApplicationID AND @AppTypeID = 1 );
SEt @NeedsProof_ShowAttachments = (select isnull(NeedsProof,0) from SS_ADEIES_TYPE where id = @TimeOffTypeID)
SET @ApplicationTypeHasAttachments = (select isnull(HasAttachments,0) from SS_ApplicationTypes where id = @AppTypeID)

IF ((@AppTypeID =  1 AND @ApplicationTypeHasAttachments = 1 AND @NeedsProof_ShowAttachments = 1) OR  (@AppTypeID <> 1 AND @ApplicationTypeHasAttachments = 1))  --9/11/2017 GP Use global the attachment settings
AND
@AppStatusID <> 4
AND
(@EmployeeID = @UserID
OR @SubmitterID = @UserID
OR ((select count(*) FROM XU_UserRoles WHERE UsrID = @UserID AND RoleID in (@HREditorRole,@HREditorPerCompany)) > 0) )  BEGIN
SET @AllowAddNewDocuments = 1;
SET @AllowEditDocuments = 1;
END;

--IF ((@AppTypeID =  1 AND (@NeedsProof_ShowAttachments = 0 OR @ApplicationTypeHasAttachments = 0)) OR  (@AppTypeID = 11 AND @ApplicationTypeHasAttachments = 0)) BEGIN
IF ((@AppTypeID =  1 AND (@NeedsProof_ShowAttachments = 0 OR @ApplicationTypeHasAttachments = 0)) OR  (@AppTypeID <> 1 AND @ApplicationTypeHasAttachments = 0)) BEGIN	--9/11/2017 GP Use global the attachment settings
SET @AllowAddNewDocuments = 0;
SET @AllowEditDocuments = 0;
END



--DESS-122705 2/11/2017
--New Button for Cancelling Application. Uses application type 28 (Application for cancelling application)
--When
--SS_ApplicationTypes.UseApplicationForCancel = 1(true)
-- Application is completed (StatusID=3)
-- the old cancel button is hidden (@AllowCancel) (eg an HR Editor does not need to make an application for cancelling)
-- The new button is visible
DECLARE @UseApplicationForCancel bit;
SET @UseApplicationForCancel = (select isnull(UseApplicationForCancel,0) FROM SS_ApplicationTypes where ID = @AppTypeID);

IF ( @AppTypeID <> 28 AND @UseApplicationForCancel = 1 AND @AppStatusID = 3 AND @AllowView =1 AND @AllowCancel = 0) BEGIN
SET @AllowCancelWithApplication = 1;
END

---
-- Added 18/10/2016
-- Overwrite return values for Cancelled Application
IF @AppStatusID = 4 BEGIN
INSERT @RetTbl
SELECT @Info
, null
, 'lbApplicationIsCancelled'
, @AllowView
, 0
, 0
, 0
, 0
, 0
, 0
, 0
, 0
, 0
, 0
, 0
, 0
, @RetApproverID
, 0; --DESS-122705 2/11/2017
RETURN;
END;

--
-- Return Values
--
INSERT @RetTbl
SELECT @Info
, @HREditorInfo
, @AdditionalApproverInfo
, @AllowView
, @AllowEdit
, @AllowCancel
, @AllowApproverTransaction
, @AllowAddNewDocuments
, @AllowEditDocuments
, @AllowPrint
, @AllowSubmit
, @AllowTempSave
, @ExpenseEditOverdraft
, @ExpenseApproveOverdraft
, @ExpenseChooseCostCenter
, @ShowApproverCombo
, @RetApproverID
, @AllowCancelWithApplication;
RETURN;
END
GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[PM_AttendanceSettings_UIParams_Results]'
GO
ALTER FUNCTION [dbo].[PM_AttendanceSettings_UIParams_Results](
@GUID uniqueidentifier
, @FormAttendanceType int
, @CurrentUserID int
, @ReasonID int
)
RETURNS @RetTbl TABLE (PMUIID int
, EmployeeID int
, AttendanceTypeID_Value int
, DepartmentID_Value int
, AttendanceCalendarSubmitTypeID int
, AttendanceDate_Value varchar(255)
, TimeIn_Value datetime, TimeOut_Value datetime
, TimeIn_Value_2 datetime, TimeOut_Value_2 datetime , AllowMultiplePresenceDeclaration int
, HoursNum_Value int
, AttendanceTypeID_Visible int, AttendanceTypeID_Enabled int, AttendanceTypeID_Required int
, DepartmentID_Visible int, DepartmentID_Enabled int, DepartmentID_Required int
, ProjectID_Visible int, ProjectID_Enabled int, ProjectID_Required int
, AttendanceDate_Visible int, AttendanceDate_Enabled int, AttendanceDate_Required int
, TimeIn_Visible int, TimeIn_Enabled int, TimeIn_Required int
, TimeOut_Visible int, TimeOut_Enabled int, TimeOut_Required int
, HoursNum_Visible int, HoursNum_Enabled int, HoursNum_Required int
, ReasonID_Visible int, ReasonID_Enabled int, ReasonID_Required int
, SubReasonID_Visible int, SubReasonID_Enabled int, SubReasonID_Required int
, SubReasonText_Visible int, SubReasonText_Enabled int, SubReasonText_Required int
, Comments_Visible int, Comments_Enabled int, Comments_Required int
, ProjectsGridEnabled int, ProjectsGridMin int, ProjectsGridMax int, ProjectsGridSearchType int
, ValidateDateInID int, ValidateDaysBefore int, ValidateDaysAfter int, ValidateDaysBuffer int
, LabelReasonCombo varchar(255), LabelSubReasonCombo varchar(255), LabelSubReasonText varchar(255), LabelComments varchar(255), LabelMainProject varchar(255), LabelProjectDetails varchar(255)
, AllowSave int
, AllowCancel int
, AllowFinalize int
, AllowDefinalize int
, SelectedPMSettingID int
, TimeInOutSource int -- 1. Assigned shifts, 2. Default schedules, 3. Setting
)
AS
BEGIN
--
-------------------------------Internal Variables----------------------------------------------
--
DECLARE @FormEmployeeID int                            -- If one employee is selected, set this value. Else -1 for Multiple Employees
, @FormDateType int                                  -- 1 to specify a single date, -1 for Multiple Dates
, @FormSingleDate datetime                    -- Date if @FormDateType = 1
, @FormProjectID int                                 -- (Future Feature - now always null)
, @DateAutoFillLogicFromReason int
, @IsNewForm int, @IsFinalized int, @IsCancelled int, @FormIsForCurrentDay int
, @IsHREditor int, @IsAttendanceKeeper int, @FormEmployeeIsCurrentUser int, @FormEmployeeHasManagerCurrentUser int
, @AttendanceKeeperCanUnfinalize int   --DESS-114636
, @FormEmployeeHasCurrentUserAsGroupLeader_View int, @FormEmployeeHasCurrentUserAsGroupLeader_Edit int
, @ProjectAttendanceCalendarSubmitTypeID int, @ProjectAttendanceAutoFillTimesID int;
--
-------------------------------Constants-------------------------------------------------------
--
DECLARE @Role_HR_Editor int, @Role_HR_Editor_PerCompany int, @Role_AttendanceKeeper int, @Role_AttendanceKeeperExtended int, @Scenario_ViewAttendance int, @Scenario_EditAttendance int;
SET @Role_HR_Editor=1005;
SET @Role_HR_Editor_PerCompany=1011;
SET @Role_AttendanceKeeper=1010;
SET @Role_AttendanceKeeperExtended=-2;
SET @Scenario_ViewAttendance=1;
SET @Scenario_EditAttendance=2;
--
-------------------------------Basic Initialization-------------------------------------------
--
-- Set parameter so that Monday is the first day of the week
--SET DATEFIRST 1;
--@FormEmployeeID
IF (SELECT count(DISTINCT EmployeeID) FROM PM_AttendanceSettings_UIParams WHERE [GUID]=@GUID)>1 SET @FormEmployeeID=-1;
ELSE SELECT DISTINCT @FormEmployeeID=EmployeeID FROM PM_AttendanceSettings_UIParams WHERE [GUID]=@GUID;
--@FormDateType / @FormSingleDate
IF (SELECT count(DISTINCT ActionDate) FROM PM_AttendanceSettings_UIParams WHERE [GUID]=@GUID)>1 SET @FormDateType=-1;
ELSE BEGIN
SET @FormDateType=1;
SELECT DISTINCT @FormSingleDate=ActionDate FROM PM_AttendanceSettings_UIParams WHERE [GUID]=@GUID;
END;
--@DateAutoFillLogicFromReason
IF @ReasonID is not null SELECT @DateAutoFillLogicFromReason=AutoFillDateTimesID FROM PM_AttendanceReasons where ID = @ReasonID ;

--
---------------------------------------- Validations ----------------------------------------
--
IF  --PM_AttendanceSettings_UIParams is empty
NOT EXISTS (SELECT 1 FROM PM_AttendanceSettings_UIParams WHERE [GUID]=@GUID)
--There are no employees other than System or Admin
OR NOT EXISTS (SELECT 1 FROM PM_AttendanceSettings_UIParams WHERE [GUID]=@GUID AND EmployeeID not in (-1,-2))
--There is one or more rows with employees that do not exist in AC_Contacts
OR EXISTS (SELECT 1 FROM PM_AttendanceSettings_UIParams ui LEFT JOIN AC_Contacts a ON a.ContactID=ui.EmployeeID WHERE [GUID]=@GUID AND a.ContactID is null)
--There are one or more rows with departments that do not exist in AC_Departments
OR (@FormEmployeeID=-1 AND EXISTS (SELECT 1 FROM PM_AttendanceSettings_UIParams ui LEFT JOIN AC_Departments d ON d.ID=ui.DepartmentID WHERE [GUID]=@GUID AND d.ID is null))
--Empty or Invalid Parameters
OR @CurrentUserID is null
OR @FormAttendanceType is null
OR @FormAttendanceType not in (0,1)
RETURN;
--
---------------------------------------- Calculate Parameters ---------------------------------
--
-- Initialize Form Status
SET @IsFinalized=0;
SET @IsCancelled=0;
SET @IsNewForm=1;

--Current user is HREditor/AttendanceKeeper
IF EXISTS (SELECT 1 FROM XU_UserRoles WHERE UsrID=@CurrentUserID AND (RoleID=@Role_HR_Editor OR RoleID=@Role_HR_Editor_PerCompany)) SET @IsHREditor=1 ELSE SET @IsHREditor=0;
IF EXISTS (SELECT 1 FROM XU_UserRoles WHERE UsrID=@CurrentUserID AND (RoleID=@Role_AttendanceKeeper OR RoleID = @Role_AttendanceKeeperExtended)) SET @IsAttendanceKeeper=1 ELSE SET @IsAttendanceKeeper=0;
SET @AttendanceKeeperCanUnfinalize = isnull((select varValue from X_Vars where varKey ='AttendaceKeeperCanUnfinalize'),0);

--Form Employee is the Current User
IF @FormEmployeeID not in (-1,-2) AND @FormEmployeeID=@CurrentUserID SET @FormEmployeeIsCurrentUser=1 ELSE SET @FormEmployeeIsCurrentUser=0;

--Form Employee has Current User as Manager
IF @FormEmployeeID<>-1 AND @FormEmployeeID in (
SELECT distinct y.ContactID FROM AC_Department_Contacts dc
CROSS APPLY dbo.SS_GetDeptListFromNodeDown(dc.DepartmentID) dl
JOIN AC_Department_Contacts y ON y.DepartmentID=dl.ID AND getdate() between y.StartDate AND isnull(y.EndDate,'2049-12-31')
WHERE dc.ContactID=@CurrentUserID AND dc.IsManager=1 AND getdate() between dc.StartDate AND isnull(dc.EndDate,'2049-12-31')
AND y.ContactID<>@CurrentUserID
)
SET @FormEmployeeHasManagerCurrentUser=1
ELSE SET @FormEmployeeHasManagerCurrentUser=0;

--Current user is Attendance Viewer in a group where the Form Employee is in
IF @FormEmployeeID<>-1 AND @FormEmployeeID in (SELECT ugc.ContactID FROM XU_UserGroup_Rights ugr JOIN XU_UserGroup_Contacts ugc on ugr.GroupID=ugc.GroupID WHERE ugr.UserID=@CurrentUserID AND ugr.ScenarioID=@Scenario_ViewAttendance)
SET @FormEmployeeHasCurrentUserAsGroupLeader_View=1
ELSE SET @FormEmployeeHasCurrentUserAsGroupLeader_View=0;

--Current user is Attendance Editor in a group where the Form Employee is in
IF @FormEmployeeID<>-1 AND @FormEmployeeID in (SELECT ugc.ContactID FROM XU_UserGroup_Rights ugr JOIN XU_UserGroup_Contacts ugc on ugr.GroupID=ugc.GroupID WHERE ugr.UserID=@CurrentUserID AND ugr.ScenarioID=@Scenario_EditAttendance)
SET @FormEmployeeHasCurrentUserAsGroupLeader_Edit=1
ELSE SET @FormEmployeeHasCurrentUserAsGroupLeader_Edit=0;

-- Form is for Current Date
IF @FormDateType=1 AND DATEADD(dd,0,DATEDIFF(dd,0,@FormSingleDate))=DATEADD(dd,0,DATEDIFF(dd,0,GETDATE())) SET @FormIsForCurrentDay=1 ELSE SET @FormIsForCurrentDay=0;

-- Form Project Vars
SELECT @ProjectAttendanceCalendarSubmitTypeID=AttendanceCalendarSubmitTypeID
, @ProjectAttendanceAutoFillTimesID=AttendanceAutoFillTimesID
FROM PM_Projects WHERE ID=@FormProjectID;

---------------------------------------- Results (ALWAYS new form) ----------------------------------------

-- Create rows with Basic Fields
INSERT INTO @RetTbl (PMUIID
, EmployeeID
, AttendanceTypeID_Value
, DepartmentID_Value
, AttendanceCalendarSubmitTypeID
, AttendanceDate_Value
, SelectedPMSettingID
)
SELECT asu.ID
, asu.EmployeeID AS EmployeeID
, @FormAttendanceType AS AttendanceTypeID_Value
, asu.DepartmentID AS DepartmentID_Value
, (case when s.AttendanceCalendarSubmitTypeID in (1,2,3) then s.AttendanceCalendarSubmitTypeID
when s.AttendanceCalendarSubmitTypeID=99 then (select AttendanceCalendarSubmitTypeID from PM_Projects where ID=@FormProjectID)
else 1 end) AS AttendanceCalendarSubmitTypeID
, convert(varchar(255),asu.ActionDate,103) AS AttendanceDate_Value
, asu.AttendanceSettingID AS SelectedPMSettingID
FROM PM_AttendanceSettings_UIParams asu
JOIN PM_AttendanceSettings s ON s.ID=asu.AttendanceSettingID
LEFT JOIN PM_EmployeeDefaultDailySchedules ds ON ds.ContactID=asu.EmployeeID
WHERE asu.[GUID]=@GUID;

-- Calculate Times In/Out and Hours fields
UPDATE r
SET TimeIn_Value=( case when (s.AutoFillDateTimesID in (1,2,3) AND isnull(@DateAutoFillLogicFromReason,0)=0) OR isnull(@DateAutoFillLogicFromReason,0) in (1,2,3) then s.AutoFillTimeIn
when (s.AutoFillDateTimesID=6 AND isnull(@DateAutoFillLogicFromReason,0)=0)  OR isnull(@DateAutoFillLogicFromReason,0)=6 OR (((s.AutoFillDateTimesID=5 AND isnull(@DateAutoFillLogicFromReason,0)=0)  OR isnull(@DateAutoFillLogicFromReason,0)=5) and asu.DataSource=1) then asu.StartDate1
when (s.AutoFillDateTimesID=4 AND isnull(@DateAutoFillLogicFromReason,0)=0)  OR isnull(@DateAutoFillLogicFromReason,0)=4 then case datepart(dw,asu.ActionDate) when 1 then ds.MondayFrom when 2 then ds.TuesdayFrom when 3 then ds.WednesdayFrom when 4 then ds.ThursdayFrom when 5 then ds.FridayFrom when 6 then ds.SaturdayFrom when 7 then ds.SundayFrom else null end
when ((s.AutoFillDateTimesID=5 AND isnull(@DateAutoFillLogicFromReason,0)=0) OR isnull(@DateAutoFillLogicFromReason,0)=5) and asu.DataSource=2 then isnull(case datepart(dw,asu.ActionDate) when 1 then ds.MondayFrom when 2 then ds.TuesdayFrom when 3 then ds.WednesdayFrom when 4 then ds.ThursdayFrom when 5 then ds.FridayFrom when 6 then ds.SaturdayFrom when 7 then ds.SundayFrom else null end, s.AutoFillTimeIn)
else null end)
, TimeOut_Value=(case when (s.AutoFillDateTimesID in (1,2,3) AND isnull(@DateAutoFillLogicFromReason,0)=0) OR isnull(@DateAutoFillLogicFromReason,0) in (1,2,3) then s.AutoFillTimeOut
when (s.AutoFillDateTimesID=6 AND isnull(@DateAutoFillLogicFromReason,0)=0)  OR isnull(@DateAutoFillLogicFromReason,0)=6 OR (((s.AutoFillDateTimesID=5 AND isnull(@DateAutoFillLogicFromReason,0)=0)  OR isnull(@DateAutoFillLogicFromReason,0)=5) and asu.DataSource=1) then asu.EndDate1
when (s.AutoFillDateTimesID=4 AND isnull(@DateAutoFillLogicFromReason,0)=0)  OR isnull(@DateAutoFillLogicFromReason,0)=4 then case datepart(dw,asu.ActionDate) when 1 then ds.MondayTo when 2 then ds.TuesdayTo when 3 then ds.WednesdayTo when 4 then ds.ThursdayTo when 5 then ds.FridayTo when 6 then ds.SaturdayTo when 7 then ds.SundayTo else null end
when ((s.AutoFillDateTimesID=5 AND isnull(@DateAutoFillLogicFromReason,0)=0) OR isnull(@DateAutoFillLogicFromReason,0)=5) and asu.DataSource=2 then isnull(case datepart(dw,asu.ActionDate) when 1 then ds.MondayTo when 2 then ds.TuesdayTo when 3 then ds.WednesdayTo when 4 then ds.ThursdayTo when 5 then ds.FridayTo when 6 then ds.SaturdayTo when 7 then ds.SundayTo else null end, s.AutoFillTimeOut)
else null end)
, TimeIn_Value_2=(case when (s.AutoFillDateTimesID in (1,2,3) AND isnull(@DateAutoFillLogicFromReason,0)=0)  OR isnull(@DateAutoFillLogicFromReason,0) in (1,2,3) then s.AutoFillTimeIn_2
when (s.AutoFillDateTimesID=6 AND isnull(@DateAutoFillLogicFromReason,0)=0)  OR isnull(@DateAutoFillLogicFromReason,0)=6 OR (((s.AutoFillDateTimesID=5 AND isnull(@DateAutoFillLogicFromReason,0)=0)  OR isnull(@DateAutoFillLogicFromReason,0)=5) and asu.DataSource=1) then asu.StartDate2
when ((s.AutoFillDateTimesID=5 AND isnull(@DateAutoFillLogicFromReason,0)=0) OR isnull(@DateAutoFillLogicFromReason,0)=5) and asu.DataSource=2 then isnull(case datepart(dw,asu.ActionDate) when 1 then ds.MondayFrom when 2 then ds.TuesdayFrom when 3 then ds.WednesdayFrom when 4 then ds.ThursdayFrom when 5 then ds.FridayFrom when 6 then ds.SaturdayFrom when 7 then ds.SundayFrom else null end, s.AutoFillTimeIn_2)
else null end)
, TimeOut_Value_2=(case when (s.AutoFillDateTimesID in (1,2,3) AND isnull(@DateAutoFillLogicFromReason,0)=0) OR isnull(@DateAutoFillLogicFromReason,0) in (1,2,3) then s.AutoFillTimeOut_2
when (s.AutoFillDateTimesID=6 AND isnull(@DateAutoFillLogicFromReason,0)=0) OR isnull(@DateAutoFillLogicFromReason,0)=6 OR (((s.AutoFillDateTimesID=5 AND isnull(@DateAutoFillLogicFromReason,0)=0)  OR isnull(@DateAutoFillLogicFromReason,0)=5) and asu.DataSource=1) then asu.EndDate2
when ((s.AutoFillDateTimesID=5 AND isnull(@DateAutoFillLogicFromReason,0)=0) OR isnull(@DateAutoFillLogicFromReason,0)=5) and asu.DataSource=2 then isnull(case datepart(dw,asu.ActionDate) when 1 then ds.MondayTo when 2 then ds.TuesdayTo when 3 then ds.WednesdayTo when 4 then ds.ThursdayTo when 5 then ds.FridayTo when 6 then ds.SaturdayTo when 7 then ds.SundayTo else null end, s.AutoFillTimeOut_2)
else null end)
, HoursNum_Value=(case when (s.AutoFillDateTimesID in (1,2,3) AND isnull(@DateAutoFillLogicFromReason,0)=0)  OR isnull(@DateAutoFillLogicFromReason,0) in (1,2,3) then isnull(s.AutoFillHoursNum,8) else null end)
, TimeInOutSource=(case
when ((s.AutoFillDateTimesID=5 AND isnull(@DateAutoFillLogicFromReason,0)=0)  OR isnull(@DateAutoFillLogicFromReason,0)=5) and asu.datasource=1 then 1
when ((s.AutoFillDateTimesID=5 AND isnull(@DateAutoFillLogicFromReason,0)=0)  OR isnull(@DateAutoFillLogicFromReason,0)=5) and asu.datasource=2 then (case when (datepart(dw,asu.ActionDate)=1 AND ds.MondayFrom is not null) OR (datepart(dw,asu.ActionDate)=2 AND ds.TuesdayFrom is not null) OR (datepart(dw,asu.ActionDate)=3 AND ds.WednesdayFrom is not null) OR (datepart(dw,asu.ActionDate)=4 AND ds.ThursdayFrom  is not null) OR (datepart(dw,asu.ActionDate)=5 AND ds.FridayFrom is not null) OR (datepart(dw,asu.ActionDate)=6 AND ds.SaturdayFrom is not null) OR (datepart(dw,asu.ActionDate)=7 AND ds.SundayFrom is not null) then 2 else 3 end)
else asu.datasource end)
FROM @RetTbl r
JOIN PM_AttendanceSettings_UIParams asu on r.PMUIID=asu.ID
JOIN PM_AttendanceSettings s ON s.ID=asu.AttendanceSettingID
LEFT JOIN PM_EmployeeDefaultDailySchedules ds ON ds.ContactID=asu.EmployeeID
WHERE asu.[GUID]=@GUID;

-- Calculate Visible/Enabled/Required (except TimeOut_*), Validation, and Label fields
UPDATE r
SET AttendanceTypeID_Visible=1
, AttendanceTypeID_Enabled=(case when s.LockAttendanceIfSupplied = 1 then 0 else 1 end)
, AttendanceTypeID_Required=1
, DepartmentID_Visible=(case when s.EnableMainProjectID in (1,2) OR s.EnableProjectsDetail=1 then 1 else 0 end)
, DepartmentID_Enabled=(case when s.EnableMainProjectID in (1,2) OR s.EnableProjectsDetail=1 then 1 else 0 end)
, DepartmentID_Required=(case when s.EnableMainProjectID in (1,2) OR s.EnableProjectsDetail=1 then 1 else 0 end)
, ProjectID_Visible=(case when s.EnableMainProjectID in (1,2) then 1 else 0 end)
, ProjectID_Enabled=(case when s.EnableMainProjectID in (1,2) then 1 else 0 end)
, ProjectID_Required=(case when s.EnableMainProjectID = 2 then 1 else 0 end)
, AttendanceDate_Visible=1
, AttendanceDate_Enabled=(case when @FormDateType=-1 OR (@FormDateType=1 AND @FormSingleDate is not null AND s.AttendanceCalendarSubmitTypeID=1 AND s.LockDateIfSupplied=1) then 0 else 1 end)
, AttendanceDate_Required=1
, TimeIn_Visible=(case
-- Not Visible
when s.AttendanceCalendarSubmitTypeID=3 OR (s.AttendanceCalendarSubmitTypeID=99 AND (SELECT AttendanceCalendarSubmitTypeID from PM_Projects where ID=@FormProjectID)=3) OR (s.AttendanceCalendarSubmitTypeID in (1,2) AND ((s.AutoFillDateTimesID=3 AND isnull(@DateAutoFillLogicFromReason,0)=0)  OR isnull(@DateAutoFillLogicFromReason,0)=3)) OR (s.AttendanceCalendarSubmitTypeID in (1,2) AND @ProjectAttendanceAutoFillTimesID=3) then 0
-- Visible when Form Type=Absence (7/7/2017 GP)
when @FormAttendanceType=0 then 1
-- Visible (5.2) Υπάρχουν 1 ή περισσότεροι εργαζόμενοι με ρύθμιση για συμπλήρωση Ωρών από Ανάθεση Ωραρίων οι οποίοι δεν έχουν ανατεθιμένο ωράριο σε 1 ή περισσότερες ημερομηνίες.
when EXISTS (SELECT 1 FROM PM_AttendanceSettings_UIParams WHERE [GUID]=@GUID and Status_FromShifts_Missing=1) then 1
-- Visible (NOT 5.1) NOT: Οι δηλώσεις για τους επιλεγμένους εργαζόμενους και ημερομηνίες έχουν διαφορετικές προεπιλεγμένες ώρες
when (SELECT count(*) FROM (SELECT distinct rr.TimeIn_Value, rr.TimeOut_Value,rr.TimeIn_Value_2,rr.TimeOut_Value_2 FROM @RetTbl rr) InnerTbl)<=1 then 1
else 0 end)
, TimeIn_Enabled=(case
-- Not Enabled
when s.AttendanceCalendarSubmitTypeID=3 OR (s.AttendanceCalendarSubmitTypeID=99 AND (SELECT AttendanceCalendarSubmitTypeID FROM PM_Projects WHERE ID=@FormProjectID)=3) OR (s.AttendanceCalendarSubmitTypeID in (1,2) AND ((s.AutoFillDateTimesID in (2,3) AND isnull(@DateAutoFillLogicFromReason,0)=0)  OR isnull(@DateAutoFillLogicFromReason,0) in (2,3))) OR (s.AttendanceCalendarSubmitTypeID in (1,2) AND @ProjectAttendanceAutoFillTimesID in (2,3)) then 0
-- Enabled (5.2) Υπάρχουν 1 ή περισσότεροι εργαζόμενοι με ρύθμιση για συμπλήρωση Ωρών από Ανάθεση Ωραρίων οι οποίοι δεν έχουν ανατεθιμένο ωράριο σε 1 ή περισσότερες ημερομηνίες
when EXISTS (SELECT 1 FROM PM_AttendanceSettings_UIParams WHERE [GUID]=@GUID AND Status_FromShifts_Missing=1) then 1
-- Read only (NOT 5.1) NOT: Οι δηλώσεις για τους επιλεγμένους εργαζόμενους και ημερομηνίες έχουν διαφορετικές προεπιλεγμένες ώρες
when (SELECT count(*) FROM (SELECT distinct rr.TimeIn_Value, rr.TimeOut_Value,rr.TimeIn_Value_2,rr.TimeOut_Value_2 FROM @RetTbl rr) InnerTbl)<=1 then 1
else 1 end)
, TimeIn_Required=(case when s.AttendanceCalendarSubmitTypeID=3 OR (s.AttendanceCalendarSubmitTypeID=99 AND @ProjectAttendanceCalendarSubmitTypeID=3) then 0
when ((s.AutoFillDateTimesID=6 AND isnull(@DateAutoFillLogicFromReason,0)=0)  OR isnull(@DateAutoFillLogicFromReason,0)=6) AND s.AllowMultiplePresenceDeclaration=1 AND ((asu.StartDate1 is not null AND asu.EndDate1 is not null AND asu.StartDate2 is not null AND asu.EndDate2 is not null) OR (asu.StartDate1 is not null AND asu.EndDate1 is not null)) then 0
when ((s.AutoFillDateTimesID=4 AND isnull(@DateAutoFillLogicFromReason,0)=0)  OR isnull(@DateAutoFillLogicFromReason,0)=4) AND ((datepart(dw,asu.ActionDate)=1 AND ds.MondayFrom is not null AND ds.MondayTo is not null) OR (datepart(dw,asu.ActionDate)=2 AND ds.TuesdayTo is not null AND ds.TuesdayTo is not null) OR (datepart(dw,asu.ActionDate)=3 AND ds.WednesdayFrom is not null AND ds.WednesdayTo is not null) OR (datepart(dw,asu.ActionDate)=4 AND ds.ThursdayFrom is not null AND ds.ThursdayTo is not null) OR (datepart(dw,asu.ActionDate)=5 AND ds.FridayFrom is not null AND ds.FridayTo is not null) OR (datepart(dw,asu.ActionDate)=6 AND ds.SaturdayFrom is not null AND ds.SaturdayTo is not null) OR (datepart(dw,asu.ActionDate)=7 AND ds.SundayFrom is not null AND ds.SundayTo is not null)) then 0
else 1 end)
, HoursNum_Visible=(case when s.AttendanceCalendarSubmitTypeID in (1,2) OR (s.AttendanceCalendarSubmitTypeID=99 AND @ProjectAttendanceCalendarSubmitTypeID in (1,2)) OR (s.AttendanceCalendarSubmitTypeID=3 AND ((s.AutoFillDateTimesID=3 AND isnull(@DateAutoFillLogicFromReason,0)=0)  OR isnull(@DateAutoFillLogicFromReason,0)=3)) OR (s.AttendanceCalendarSubmitTypeID=3 AND @ProjectAttendanceAutoFillTimesID=3) then 0 else 1 end)
, HoursNum_Enabled=(case when s.AttendanceCalendarSubmitTypeID in (1,2) OR (s.AttendanceCalendarSubmitTypeID= 99 AND @ProjectAttendanceCalendarSubmitTypeID in (1,2)) OR (s.AttendanceCalendarSubmitTypeID=3 AND ((s.AutoFillDateTimesID in (2,3) AND isnull(@DateAutoFillLogicFromReason,0)=0)  OR isnull(@DateAutoFillLogicFromReason,0) in (2,3))) OR (s.AttendanceCalendarSubmitTypeID=3 AND @ProjectAttendanceAutoFillTimesID in (2,3)) then 0 else 1 end)
, HoursNum_Required=(case when s.AttendanceCalendarSubmitTypeID in (1,2) OR (s.AttendanceCalendarSubmitTypeID = 99 AND @ProjectAttendanceCalendarSubmitTypeID in (1,2)) then 0 else 1 end)
, ReasonID_Visible=(case when s.EnableReasonID in (1,2,3,4) then 1 else 0 end)
, ReasonID_Enabled=(case when s.EnableReasonID in (1,2,3,4) then 1 else 0 end)
, ReasonID_Required=(case when s.EnableReasonID=4 then 1 when s.EnableReasonID=2 and @FormAttendanceType=1 then 1 when s.EnableReasonID=3 and @FormAttendanceType=0 then 1 else 0 end)
, SubReasonID_Visible=(case when s.EnableReasonID in (1,2,3,4) AND s.EnableSubReasonCombo=1 then 1 else 0 end)
, SubReasonID_Enabled=(case when s.EnableReasonID in (1,2,3,4) AND s.EnableSubReasonCombo=1 then 1 else 0 end)
, SubReasonID_Required=(case when s.EnableReasonID=4 AND s.EnableSubReasonCombo=1 then 1 when s.EnableReasonID=2 and @FormAttendanceType=1 AND s.EnableSubReasonCombo=1 then 1 when s.EnableReasonID=3 and @FormAttendanceType=0 AND s.EnableSubReasonCombo=1 then 1 else 0 end)
, SubReasonText_Visible=(case when s.EnableReasonID in (1,2,3,4) AND s.EnableSubReasonTextID in (1,2) then 1 else 0 end)
, SubReasonText_Enabled=(case when s.EnableReasonID in (1,2,3,4) AND s.EnableSubReasonTextID in (1,2) then 1 else 0 end)
, SubReasonText_Required=(case when s.EnableReasonID=4 AND s.EnableSubReasonTextID=2 then 1 when s.EnableReasonID=2 and @FormAttendanceType=1 AND s.EnableSubReasonTextID=2 then 1 when s.EnableReasonID=3 and @FormAttendanceType=0 AND s.EnableSubReasonTextID=2 then 1 else 0 end)
, Comments_Visible=(case when s.EnableCommentsID in (1,2,3,4) then 1 else 0 end)
, Comments_Enabled=(case when s.EnableCommentsID in (1,2,3,4) then 1 else 0 end)
, Comments_Required=(case when s.EnableCommentsID= 4 then 1 when s.EnableCommentsID=2 and @FormAttendanceType=1 then 1 when s.EnableCommentsID=3 and @FormAttendanceType=0 then 1 else 0 end)
, ProjectsGridEnabled=(case when s.EnableProjectsDetail=1 then 1 else 0 end)
, ProjectsGridMin=(case when s.EnableProjectsDetail=1 then isnull(s.ProjectDetailMin,0) else null end)
, ProjectsGridMax=(case when s.EnableProjectsDetail=1 then isnull(s.ProjectDetailMax,10) else null end)
, ProjectsGridSearchType=(case when s.EnableProjectsDetail=1 then s.ProjectDetailSearchTypeID  else null end)
, ValidateDateInID=(case when @IsHREditor=1 then 0 when @FormAttendanceType=0 then s.ValidateDateInAbsenceID else s.ValidateDateInPresenceID end)
, ValidateDaysBefore=(case when (@FormAttendanceType=0 AND s.ValidateDateInAbsenceID=6) OR (@FormAttendanceType=1 AND s.ValidateDateInPresenceID=6) then s.ValidateDaysBefore else null end)
, ValidateDaysAfter=(case when (@FormAttendanceType=0 AND s.ValidateDateInAbsenceID=6) OR (@FormAttendanceType=1 AND s.ValidateDateInPresenceID=6) then s.ValidateDaysAfter else null end)
, ValidateDaysBuffer=(case when (@FormAttendanceType=0 AND s.ValidateDateInAbsenceID in (3,5)) OR (@FormAttendanceType=1 AND s.ValidateDateInPresenceID in (3,5)) then s.ValidateDaysBuffer else null end)
, LabelReasonCombo=isnull(s.LabelReasonCombo,'lbReason')
, LabelSubReasonCombo=isnull(s.LabelSubReasonCombo,'lbExplanation')
, LabelSubReasonText=isnull(s.LabelSubReasonText,'lbExplanation')
, LabelComments=isnull(s.LabelComments,'lbComments')
, LabelMainProject=isnull(s.LabelMainProject,'lbProject')
, LabelProjectDetails=isnull(s.LabelProjectDetails,'lbProjects')
FROM @RetTbl r
JOIN PM_AttendanceSettings_UIParams asu on r.PMUIID=asu.ID
JOIN PM_AttendanceSettings s ON s.ID=asu.AttendanceSettingID
LEFT JOIN PM_EmployeeDefaultDailySchedules ds ON ds.ContactID=asu.EmployeeID
WHERE asu.[GUID]=@GUID;

-- Calculate TimeOut_Visible/Enabled/Required fields
UPDATE r
SET TimeOut_Visible=r.TimeIn_Visible
, TimeOut_Enabled=r.TimeIn_Enabled
, TimeOut_Required=r.TimeIn_Required
FROM @RetTbl r
JOIN PM_AttendanceSettings_UIParams asu on r.PMUIID=asu.ID
JOIN PM_AttendanceSettings s ON s.ID=asu.AttendanceSettingID
LEFT JOIN PM_EmployeeDefaultDailySchedules ds ON ds.ContactID=asu.EmployeeID
WHERE asu.[GUID]=@GUID;

-- Calculate Interactivity fields
UPDATE r
SET AllowMultiplePresenceDeclaration=isnull(s.AllowMultiplePresenceDeclaration,0)
, AllowSave=(case when @IsHREditor=1 then 1
when @FormEmployeeIsCurrentUser=1 AND @IsFinalized=0 AND @IsCancelled=0 then 1
when asu.EmployeeID=@CurrentUserID then 1 -- If many employees are selected and current user is one of them
when @FormEmployeeHasManagerCurrentUser=1 AND @IsFinalized=0 AND @IsCancelled=0 then 1
when (asu.EmployeeID in (
SELECT distinct y.ContactID  -- If many employees are selected and current user is manager
FROM AC_Department_Contacts dc
CROSS APPLY dbo.SS_GetDeptListFromNodeDown(dc.DepartmentID) dl
JOIN AC_Department_Contacts y ON y.DepartmentID=dl.ID AND getdate() between y.StartDate AND isnull(y.EndDate,'2049-12-31')
WHERE dc.ContactID=@CurrentUserID AND dc.IsManager=1 AND getdate() between dc.StartDate AND isnull(dc.EndDate,'2049-12-31')
AND y.ContactID<>@CurrentUserID)
) then 1
when @IsAttendanceKeeper=1 AND @FormIsForCurrentDay=1 AND @IsFinalized=0 AND @IsCancelled=0 then 1
when @FormEmployeeHasCurrentUserAsGroupLeader_Edit=1 AND @IsFinalized=0 AND @IsCancelled=0 then 1
else 0 end)
, AllowCancel=(case when @IsNewForm=1 then 0
when @IsHREditor=1 then 1
when @FormEmployeeIsCurrentUser=1 AND @IsFinalized=0 AND @IsCancelled=0 then 1
when asu.EmployeeID=@CurrentUserID then 1 -- If many employees are selected and current user is one of them
when @FormEmployeeHasManagerCurrentUser=1 AND @IsFinalized=0 AND @IsCancelled=0 then 1
when (asu.EmployeeID in (
SELECT distinct y.ContactID  -- If many employees are selected and current user is manager
FROM AC_Department_Contacts dc
CROSS APPLY dbo.SS_GetDeptListFromNodeDown(dc.DepartmentID) dl
JOIN AC_Department_Contacts y ON y.DepartmentID=dl.ID AND getdate() between y.StartDate AND isnull(y.EndDate,'2049-12-31')
WHERE dc.ContactID=@CurrentUserID AND dc.IsManager=1 AND getdate() between dc.StartDate AND isnull(dc.EndDate,'2049-12-31')
AND y.ContactID<>@CurrentUserID)
) then 1
when @IsAttendanceKeeper=1 AND @FormIsForCurrentDay=1 AND @IsFinalized=0 AND @IsCancelled=0 then 1
when @FormEmployeeHasCurrentUserAsGroupLeader_Edit=1 AND @IsFinalized=0 AND @IsCancelled=0 then 1
else 0 end)
, AllowFinalize=(case when @IsHREditor=1 AND @IsFinalized=0 AND @IsCancelled=0 then 1
when @IsAttendanceKeeper=1 AND @FormIsForCurrentDay=1 AND @IsFinalized=0 AND @IsCancelled=0 then 1
else 0 end)
, AllowDefinalize=(case when @IsHREditor=1 AND @IsFinalized=1 AND @IsCancelled=0 then 1
when @IsAttendanceKeeper=1 AND @AttendanceKeeperCanUnfinalize=1 AND @IsFinalized=1 AND @IsCancelled=0 then 1
else 0 end)
FROM @RetTbl r
JOIN PM_AttendanceSettings_UIParams asu on r.PMUIID=asu.ID
JOIN PM_AttendanceSettings s ON s.ID=asu.AttendanceSettingID
LEFT JOIN PM_EmployeeDefaultDailySchedules ds ON ds.ContactID=asu.EmployeeID
WHERE asu.[GUID]=@GUID;

IF @IsHREditor=0 AND @IsAttendanceKeeper=0 AND (@IsFinalized=1 OR @IsCancelled=1) BEGIN
UPDATE @RetTbl
SET AttendanceTypeID_Enabled=0
, AttendanceTypeID_Required=0
, DepartmentID_Enabled=0
, DepartmentID_Required=0
, AttendanceDate_Enabled=0
, AttendanceDate_Required=0
, TimeIn_Enabled=0
, TimeIn_Required=0
, TimeOut_Enabled=0
, TimeOut_Required=0
, HoursNum_Enabled=0
, HoursNum_Required=0
, ReasonID_Enabled=0
, ReasonID_Required=0
, SubReasonID_Enabled=0
, SubReasonID_Required=0
, SubReasonText_Enabled=0
, SubReasonText_Required=0
, Comments_Enabled=0
, Comments_Required=0
, AllowFinalize=0
, AllowDefinalize=0;
END;

RETURN;
END
GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[SS_Aplication_FileBlobs]'
GO
IF COL_LENGTH(N'[dbo].[SS_Aplication_FileBlobs]', N'TransferedToHRM') IS NULL
ALTER TABLE [dbo].[SS_Aplication_FileBlobs] ADD[TransferedToHRM] [int] NULL
IF COL_LENGTH(N'[dbo].[SS_Aplication_FileBlobs]', N'TransferedToHRMDate') IS NULL
ALTER TABLE [dbo].[SS_Aplication_FileBlobs] ADD[TransferedToHRMDate] [datetime] NULL
GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[SS_ApplicationFamilyStatusDatasource]'
GO



ALTER FUNCTION [dbo].[SS_ApplicationFamilyStatusDatasource]
(
@ApplicationID  int, @GUID  uniqueidentifier, @EmployeeID int, @CurLanguageID int
)
RETURNS @RetTbl TABLE (RowStatus varchar(max),ContactID int,	ChildName varchar(max), GenderID int,Gender varchar(max), Birthdate datetime, IsEmployeeDependent int, IncreasesTaxDeductible int, Comments varchar(2000), Ext_ID_CHILDREN int,  GUID uniqueidentifier, EmployeeChildrenID int)
AS
BEGIN

INSERT @RetTbl
SELECT case when ssa.ID is null then	'lbExistingRowNoChanges' else 'lbExistingRowChangesRequested' end AS RowStatus
, @EmployeeID AS ContactID
, isnull(ssa.Name,ec.CHILD_NAME) AS ChildName
, isnull(aec_g.ID,ec_g.ID)  as GenderID
, isnull(isnull(aec_o.VALUE,aec_g.Descr ),isnull(ec_o.value,ec_g.Descr)) AS Gender
, isnull(ssa.Birthdate,ec.BIRTHDATE) As Birthdate
, isnull (ssa.IsEmployeeDependent,ec.VARINEI) As IsEmployeeDependent
, isnull(ssa.IncreasesTaxDeductible,ec.AFKSISI_AFOROL) As IncreasesTaxDeductible
, ssa.Comments
, ec.ID_CHILDREN AS Ext_ID_CHILDREN
, ssa.GUID
, ssa.ID as EmployeeChildrenID
FROM SS_EMP_CHILDREN ec
INNER JOIN SS_EMPLOYEE e on e.ID_EMP = ec.ID_EMP
LEFT JOIN L_Genders ec_g on ec_g.Ext_ID = ec.FYLO
LEFT JOIN L_Object ec_o ON ec_o.TABLE_NAME='L_Genders' AND ec_o.ID_TABLE=ec_g.ID AND isnull(ec_o.FieldName,'DESCR')='DESCR' AND ec_o.ID_LANGUAGES=@CurLanguageID
LEFT JOIN SS_Application_EmployeeChildren ssa on ssa.Ext_ID_EMP = ec.ID_EMP AND ssa.Ext_ID_CHILDREN = ec.ID_CHILDREN AND ssa.GUID = @GUID
LEFT JOIN L_Genders aec_g on aec_g.ID = ssa.GenderID
LEFT JOIN L_Object aec_o ON aec_o.TABLE_NAME='L_Genders' AND aec_o.ID_TABLE=aec_g.ID AND isnull(aec_o.FieldName,'DESCR')='DESCR' AND aec_o.ID_LANGUAGES=@CurLanguageID
WHERE e.ContactID=@EmployeeID AND ec.StatusID <> 2
AND (@ApplicationID=-999 OR ssa.ApplicationID=@ApplicationID)
UNION
SELECT 'lbNewRow'
, @EmployeeID
, ssa.Name
, ssa_g.ID  as GenderID
, isnull(ssa_o.value,ssa_g.Descr) AS Gender
, ssa.Birthdate
, ssa.IsEmployeeDependent
, ssa.IncreasesTaxDeductible
, ssa.Comments
, ssa.Ext_ID_CHILDREN
, ssa.GUID
, ssa.ID as EmployeeChildrenID
FROM SS_Application_EmployeeChildren ssa
LEFT JOIN L_Genders ssa_g on ssa_g.ID = ssa.GenderID
LEFT JOIN L_Object ssa_o ON ssa_o.TABLE_NAME='L_Genders' AND ssa_o.ID_TABLE=ssa_g.ID AND isnull(ssa_o.FieldName,'DESCR')='DESCR' AND ssa_o.ID_LANGUAGES=@CurLanguageID
WHERE (@ApplicationID=-999 AND ssa.[GUID]=@GUID AND ssa.Ext_ID_CHILDREN is null) OR (ssa.ApplicationID=@ApplicationID AND @ApplicationID<>-999 AND ssa.Ext_ID_CHILDREN is null)

RETURN
END

GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[SO_TimesheetDetails_Finalize]'
GO
ALTER PROCEDURE [dbo].[SO_TimesheetDetails_Finalize] @ApplicationID int, @CurrentContactID int, @RetVal int OUTPUT
AS
BEGIN
SET NOCOUNT ON;

DECLARE @DebugMode int;
SET @DebugMode = isnull((SELECT varValue FROM X_Vars WHERE varKey='SOAssignShiftSaveRowsDebugMode'),1);  -- 0: None, 1: Basic, 2: Fluent

IF isnull((SELECT StatusID FROM SS_Applications WHERE ID=@ApplicationID),0)<>3 BEGIN
IF isnull(@DebugMode,0)>=1
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', 'lbAppTimeSheetFinalization_Fail_NotExistsOrNotComplete', -1, @ApplicationID);
SET @RetVal=-1; -- Application does not exist or it is not Complete
RETURN;
END;

IF (SELECT count(*) FROM SO_TimesheetDetails WHERE ApplicationID=@ApplicationID)=0 BEGIN
IF isnull(@DebugMode,0)>=1
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', 'lbAppTimeSheetFinalization_Fail_NoCellsToFinalize', -1, @ApplicationID);
SET @RetVal=-1; -- Application does not have any cells
RETURN;
END;

--
-- Figure out the Update modes for each Timesheet Table
--
DECLARE @SQL nvarchar(max), @SETSQL nvarchar(max);
DECLARE @SOHmerisiaOrariaMode int, @SORepoMode int, @SOAdeiesMode int, @SOAstheneiesMode int;
SET @SOHmerisiaOrariaMode = isnull((SELECT varValue FROM X_Vars WHERE varKey='SOHmerisiaOrariaMode'),0);
SET @SORepoMode = isnull((SELECT varValue FROM X_Vars WHERE varKey='SORepoMode'),0);
SET @SOAdeiesMode = isnull((SELECT varValue FROM X_Vars WHERE varKey='SOAdeiesMode'),0);
SET @SOAstheneiesMode = isnull((SELECT varValue FROM X_Vars WHERE varKey='SOAstheneiesMode'),0);

IF isnull(@DebugMode,0)>=1
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', 'lbAppTimeSheetFinalization_Begin', -1, @ApplicationID);

--
-- Do updates to TimeSheet Tables
--
IF @SOHmerisiaOrariaMode <> 0 OR @SORepoMode <> 0 OR @SOAdeiesMode <> 0 OR @SOAstheneiesMode <> 0 BEGIN
IF OBJECT_ID('tempdb..#TempPeriods') is not null DROP TABLE #TempPeriods;

--
--  Figure out distinct Pay Periods (Months) that will appear as separate rows in Timesheet Tables
--  Note:  the UI should be limiting the number of pay periods to a max of 2
--
SELECT distinct month(EditDate) AS CellMonth, year(EditDate) AS CellYear
INTO #TempPeriods
FROM SO_TimesheetDetails
WHERE ApplicationID = @ApplicationID;


--
-- Loop through each distinct Pay Period
--
DECLARE @CMonth int, @CYear int;
DECLARE cr__PeriodsLoop CURSOR LOCAL FOR SELECT CellMonth, CellYear FROM #TempPeriods;
OPEN cr__PeriodsLoop;
FETCH NEXT FROM cr__PeriodsLoop INTO @CMonth, @CYear;



WHILE @@FETCH_STATUS = 0 BEGIN
IF OBJECT_ID('tempdb..#TempPeriodEmps') is not null DROP TABLE #TempPeriodEmps;
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', 'Updating Period ' + cast(@CMonth as varchar(255)) + '/' + cast(@CYear as varchar(255)), -1, @ApplicationID);

--
-- Get all data that refers to the specific Pay Period in the loop
--
SELECT ContactID, day(EditDate) AS CDay, OrarioID, HasRepo, AdeiaTypeID, SicknessTypeID
INTO #TempPeriodEmps
FROM SO_TimesheetDetails
WHERE ApplicationID=@ApplicationID
AND month(EditDate) = @CMonth and year(EditDate) = @CYear;

--
-- Loop through each (distinct) Employee in this data
--
DECLARE @CContactID int, @CEMP_ID int, @CFEMP_ID int;
DECLARE cr__PeriodEmpsLoop CURSOR LOCAL FOR SELECT DISTINCT ContactID FROM #TempPeriodEmps;

OPEN cr__PeriodEmpsLoop;
FETCH NEXT FROM cr__PeriodEmpsLoop INTO @CContactID;
WHILE @@FETCH_STATUS = 0 BEGIN
SET @CFEMP_ID = (SELECT ID_EMP FROM SS_EMPLOYEE WHERE ContactID = @CContactID);
SET @CEMP_ID = (SELECT EMP_ID FROM AC_All_EmpIDS WHERE COntactID = @CContactID);

IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', 'Updating Employee ' + cast(@CContactID as varchar(255)), -1, @ApplicationID);

DECLARE @ESSDailyID int, @PayrollPKAutoInc int, @SSID int;
SET @ESSDailyID = null;
SET @PayrollPKAutoInc = null;
SET @SSID = null;

--
-- Update Shift Schedules Table(s)
--
IF @SOHmerisiaOrariaMode <> 0 BEGIN
SET @ESSDailyID = (SELECT TOP 1 ID FROM HR_SO_Daily_Emp WHERE EmpID = @CFEMP_ID AND PeriodosID=@CMonth AND Xrisi=@CYear ORDER by ID DESC);
IF @ESSDailyID is not null BEGIN
SET @SSID = (SELECT [sID] FROM HR_SO_Daily_Emp WHERE ID = @ESSDailyID);
IF @SSID is not null BEGIN
SET @PayrollPKAutoInc = (SELECT PKAUTOINC FROM SS_SO_HMERISIA_ORARIA_EMP WHERE ID = @SSID);
END;
END;
IF @ESSDailyID is null OR @SSID is null OR @PayrollPKAutoInc is null BEGIN
IF @SOHmerisiaOrariaMode = 1 BEGIN
IF @PayrollPKAutoInc is null BEGIN
SET @PayrollPKAutoInc = (SELECT TOP 1 PKAUTOINC FROM HRM_SO_HMERISIA_ORARIA_EMP WHERE ID_EMP = @CEMP_ID AND Xrisi = @CYear AND ID_Periodos = @CMonth ORDER BY PKAUTOINC DESC);
IF @PayrollPKAutoInc is null BEGIN
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', 'Creating HRM_SO_HMERISIA_ORARIA_EMP', -1, @ApplicationID);
SET @SQL = 'INSERT INTO HRM_SO_HMERISIA_ORARIA_EMP (ID_EMP,Xrisi,ID_Periodos) VALUES (' + cast(@CEMP_ID as varchar(255)) + ',' + cast(@CYear as varchar(255)) + ',' + cast(@CMonth as varchar(255)) + ');';
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', left(@SQL,2000), -1, @ApplicationID);
EXEC (@SQL);
--INSERT INTO HRM_SO_HMERISIA_ORARIA_EMP (ID_EMP,Xrisi,ID_Periodos) VALUES (@CEMP_ID,@CYear,@CMonth);
SET @PayrollPKAutoInc = (SELECT PKAUTOINC FROM HRM_SO_HMERISIA_ORARIA_EMP WHERE ID_EMP = @CEMP_ID AND Xrisi = @CYear AND ID_Periodos = @CMonth);
END;
END;
IF @SSID is null BEGIN
SET @SSID = (SELECT TOP 1 ID FROM SS_SO_HMERISIA_ORARIA_EMP WHERE PKAUTOINC = @PayrollPKAutoInc ORDER BY ID DESC);
IF @SSID is null BEGIN
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', 'Creating SS_SO_HMERISIA_ORARIA_EMP', -1, @ApplicationID);

SET @SQL = 'INSERT INTO SS_SO_HMERISIA_ORARIA_EMP (Ext_ID_EMP,Ext_Xrisi,Ext_ID_PERIODOS,StatusID,ProcessDate,PKAUTOINC) VALUES (' + cast(@CEMP_ID as varchar(255))+ ',' + cast(@CYear as varchar(255)) + ',' + cast(@CMonth as varchar(255)) + ',11,getdate(),' + cast(@PayrollPKAutoInc as varchar(255)) + ');'
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', left(@SQL,2000), -1, @ApplicationID);
EXEC (@SQL);
--INSERT INTO SS_SO_HMERISIA_ORARIA_EMP (Ext_ID_EMP,Ext_Xrisi,Ext_ID_PERIODOS,StatusID,ProcessDate,PKAUTOINC) VALUES (@CEMP_ID,@CYear,@CMonth,11,getdate(),@PayrollPKAutoInc);
SET @SSID = (SELECT ID FROM SS_SO_HMERISIA_ORARIA_EMP WHERE PKAUTOINC = @PayrollPKAutoInc);
END;
END;
IF @ESSDailyID is null BEGIN
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', 'Creating HR_SO_Daily_Emp', -1, @ApplicationID);
EXEC @ESSDailyID = X_getGID 'HR_SO_Daily_Emp';
SET @SQL = 'INSERT INTO HR_SO_Daily_Emp(ID, EmpID, Ext_EMPID, Xrisi, PeriodosID,[sID]) VALUES (' + cast(@ESSDailyID as varchar(255))  + ',' + cast(@CFEMP_ID as varchar(255)) + ',' + cast(@CEMP_ID as varchar(255)) + ',' + cast(@CYear as varchar(255)) + ',' + cast(@CMonth as varchar(255)) + ',' + cast(@SSID as varchar(255)) + ');';
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', left(@SQL,2000), -1, @ApplicationID);
EXEC (@SQL);
--INSERT INTO HR_SO_Daily_Emp(ID, EmpID, Ext_EMPID, Xrisi, PeriodosID,[sID]) VALUES (@ESSDailyID, @CFEMP_ID, @CEMP_ID, @CYear, @CMonth,@SSID);
END;
END
ELSE BEGIN
IF @ESSDailyID is null BEGIN
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', 'Creating HR_SO_Daily_Emp_ESSONLY', -1, @ApplicationID);
EXEC @ESSDailyID = X_getGID 'HR_SO_Daily_Emp_ESSONLY';
SET @SQL = 'INSERT INTO HR_SO_Daily_Emp_ESSONLY(ID, EmpID, Ext_EMPID, Xrisi, PeriodosID) VALUES (' + cast(@ESSDailyID as varchar(255)) + ',' + cast(@CFEMP_ID as varchar(255)) + ',' + cast(@CEMP_ID as varchar(255)) + ',' + cast(@CYear as varchar(255)) + ',' + cast(@CMonth as varchar(255)) + ');';
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', left(@SQL,2000), -1, @ApplicationID);
EXEC (@SQL);
--INSERT INTO HR_SO_Daily_Emp_ESSONLY(ID, EmpID, Ext_EMPID, Xrisi, PeriodosID) VALUES (@ESSDailyID, @CFEMP_ID, @CEMP_ID, @CYear, @CMonth);
END;
END;
END;

IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization'
, 'ESSID: ' + cast(@ESSDailyID as varchar(255)) + ', SSID: ' + cast(@SSID as varchar(255)) + ', PKAUTOINC: ' + cast(@PayrollPKAutoInc as varchar(255))
, -1, @ApplicationID);

SET @SETSQL = (SELECT STUFF((
SELECT ', [D' + cast(CDay as varchar(255)) + ']=' + case when OrarioID is null then 'null' else cast(OrarioID as varchar(255)) end
FROM #TempPeriodEmps
WHERE ContactID = @CContactID
FOR XML PATH(''), TYPE).value('(./text())[1]','NVARCHAR(MAX)'), 1, 1, '')
);

SET @SQL = 'UPDATE ' + case when @SOHmerisiaOrariaMode=1 then 'HR_SO_DAILY_EMP' else 'HR_SO_DAILY_EMP_ESSONLY' end +  ' SET ' +  @SETSQL + ' WHERE ID = ' + cast(@ESSDailyID as varchar(255)) + ';';
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', left(@SQL,2000), -1, @ApplicationID);
EXEC (@SQL);

IF @SOHmerisiaOrariaMode = 1 BEGIN
SET @SQL = 'UPDATE HRM_SO_HMERISIA_ORARIA_EMP SET ' +  @SETSQL + ' WHERE PKAUTOINC = ' + cast(@PayrollPKAutoInc as varchar(255)) + ';';
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', left(@SQL,2000), -1, @ApplicationID);
EXEC (@SQL);

SET @SQL = 'UPDATE SS_SO_HMERISIA_ORARIA_EMP SET ' +  @SETSQL + ' WHERE ID = ' + cast(@SSID as varchar(255)) + ';';
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', left(@SQL,2000), -1, @ApplicationID);
EXEC (@SQL);
END;
END;
--
-- End Update Shift Schedules Table
--

SET @ESSDailyID = null;
SET @PayrollPKAutoInc = null;
SET @SSID = null;

--
-- Update Day Off Table
--
IF @SORepoMode <> 0 BEGIN
SET @ESSDailyID = (SELECT TOP 1 ID FROM HR_SO_DayOff WHERE EmpID = @CFEMP_ID AND PeriodosID=@CMonth AND Xrisi=@CYear ORDER by ID DESC);

IF @ESSDailyID is not null BEGIN
SET @SSID = (SELECT [sID] FROM HR_SO_DayOff WHERE ID = @ESSDailyID);
IF @SSID is not null BEGIN
SET @PayrollPKAutoInc = (SELECT PKAUTOINC FROM SS_SO_REPO WHERE ID = @SSID);
END;
END;

IF @ESSDailyID is null OR @SSID is null OR @PayrollPKAutoInc is null BEGIN
IF @SORepoMode = 1 BEGIN
IF @PayrollPKAutoInc is null BEGIN
SET @PayrollPKAutoInc = (SELECT TOP 1 PKAUTOINC FROM HRM_SO_REPO WHERE ID_EMP = @CEMP_ID AND Xrisi = @CYear AND ID_Periodos = @CMonth ORDER BY PKAUTOINC DESC);
IF @PayrollPKAutoInc is null BEGIN
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', 'Creating HRM_SO_REPO', -1, @ApplicationID);
SET @SQL = 'INSERT INTO HRM_SO_REPO (ID_EMP,Xrisi,ID_Periodos) VALUES (' + cast(@CEMP_ID as varchar(255)) + ',' + cast(@CYear as varchar(255)) + ',' + cast(@CMonth as varchar(255)) + ');';
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', left(@SQL,2000), -1, @ApplicationID);
EXEC (@SQL);
--INSERT INTO HRM_SO_REPO (ID_EMP,Xrisi,ID_Periodos) VALUES (@CEMP_ID,@CYear,@CMonth);
SET @PayrollPKAutoInc = (SELECT PKAUTOINC FROM HRM_SO_REPO WHERE ID_EMP = @CEMP_ID AND Xrisi = @CYear AND ID_Periodos = @CMonth);
END;
END;
IF @SSID is null BEGIN
SET @SSID = (SELECT TOP 1 ID FROM SS_SO_REPO WHERE PKAUTOINC = @PayrollPKAutoInc ORDER BY ID DESC);
IF @SSID is null BEGIN
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', 'Creating SS_SO_REPO', -1, @ApplicationID);

SET @SQL = 'INSERT INTO SS_SO_REPO (Ext_ID_EMP,Ext_Xrisi,Ext_ID_PERIODOS,StatusID,ProcessDate,PKAUTOINC) VALUES (' + cast(@CEMP_ID as varchar(255))+ ',' + cast(@CYear as varchar(255)) + ',' + cast(@CMonth as varchar(255)) + ',11,getdate(),' + cast(@PayrollPKAutoInc as varchar(255)) + ');'
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', left(@SQL,2000), -1, @ApplicationID);
EXEC (@SQL);
--INSERT INTO SS_SO_REPO (Ext_ID_EMP,Ext_Xrisi,Ext_ID_PERIODOS,StatusID,ProcessDate,PKAUTOINC) VALUES (@CEMP_ID,@CYear,@CMonth,11,getdate(),@PayrollPKAutoInc);
SET @SSID = (SELECT ID FROM SS_SO_REPO WHERE PKAUTOINC = @PayrollPKAutoInc);
END;
END;
IF @ESSDailyID is null BEGIN
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', 'Creating HR_SO_DayOff', -1, @ApplicationID);
EXEC @ESSDailyID = X_getGID 'HR_SO_DayOff';
SET @SQL = 'INSERT INTO HR_SO_DayOff(ID, EmpID, Ext_EMPID, Xrisi, PeriodosID,[sID]) VALUES (' + cast(@ESSDailyID as varchar(255))  + ',' + cast(@CFEMP_ID as varchar(255)) + ',' + cast(@CEMP_ID as varchar(255)) + ',' + cast(@CYear as varchar(255)) + ',' + cast(@CMonth as varchar(255)) + ',' + cast(@SSID as varchar(255)) + ');';
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', left(@SQL,2000), -1, @ApplicationID);
EXEC (@SQL);
--INSERT INTO HR_SO_DayOff(ID, EmpID, Ext_EMPID, Xrisi, PeriodosID,[sID]) VALUES (@ESSDailyID, @CFEMP_ID, @CEMP_ID, @CYear, @CMonth,@SSID);
END;
END
ELSE BEGIN
IF @ESSDailyID is null BEGIN
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', 'Creating HR_SO_DayOff_ESSONLY', -1, @ApplicationID);
EXEC @ESSDailyID = X_getGID 'HR_SO_DayOff_ESSONLY';
SET @SQL = 'INSERT INTO HR_SO_DayOff_ESSONLY(ID, EmpID, Ext_EMPID, Xrisi, PeriodosID) VALUES (' + cast(@ESSDailyID as varchar(255)) + ',' + cast(@CFEMP_ID as varchar(255)) + ',' + cast(@CEMP_ID as varchar(255)) + ',' + cast(@CYear as varchar(255)) + ',' + cast(@CMonth as varchar(255)) + ');';
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', left(@SQL,2000), -1, @ApplicationID);
EXEC (@SQL);
--INSERT INTO HR_SO_DayOff_ESSONLY(ID, EmpID, Ext_EMPID, Xrisi, PeriodosID) VALUES (@ESSDailyID, @CFEMP_ID, @CEMP_ID, @CYear, @CMonth);
END;
END;
END;

IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization'
, 'ESSID: ' + cast(@ESSDailyID as varchar(255)) + ', SSID: ' + cast(@SSID as varchar(255)) + ', PKAUTOINC: ' + cast(@PayrollPKAutoInc as varchar(255))
, -1, @ApplicationID);

SET @SETSQL = (SELECT STUFF((
SELECT ', [D' + cast(CDay as varchar(255)) + ']=' + case when HasRepo is null then 'null' else cast(HasRepo as varchar(255))  end
+', [T' + cast(CDay as varchar(255)) + ']=' + case when isnull(HasRepo,0) in (1,-1) then '-1' when isnull(HasRepo,0)=-2 then '-2' else 'null' end
FROM #TempPeriodEmps
WHERE ContactID = @CContactID
FOR XML PATH(''), TYPE).value('(./text())[1]','NVARCHAR(MAX)'), 1, 1, '')
);

SET @SQL = 'UPDATE ' + case when @SORepoMode=1 then 'HR_SO_DayOff' else 'HR_SO_DayOff_ESSONLY' end +  ' SET ' +  @SETSQL + ' WHERE ID = ' + cast(@ESSDailyID as varchar(255)) + ';';
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', left(@SQL,2000), -1, @ApplicationID);
EXEC (@SQL);

IF @SORepoMode = 1 BEGIN
SET @SQL = 'UPDATE HRM_SO_REPO SET ' +  @SETSQL + ' WHERE PKAUTOINC = ' + cast(@PayrollPKAutoInc as varchar(255)) + ';';
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', left(@SQL,2000), -1, @ApplicationID);
EXEC (@SQL);

SET @SQL = 'UPDATE SS_SO_REPO SET ' +  @SETSQL + ' WHERE ID = ' + cast(@SSID as varchar(255)) + ';';
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', left(@SQL,2000), -1, @ApplicationID);
EXEC (@SQL);
END;
END;

--
-- End Update Day Off Table
--

SET @ESSDailyID = null;
SET @PayrollPKAutoInc = null;
SET @SSID = null;

--
-- Update Vacations Table
--


IF @SOAdeiesMode <> 0 BEGIN
SET @ESSDailyID = (SELECT TOP 1 ID FROM HR_SO_TimeOff WHERE EmpID = @CFEMP_ID AND PeriodosID=@CMonth AND Xrisi=@CYear ORDER by ID DESC);
IF @ESSDailyID is not null BEGIN
SET @SSID = (SELECT [sID] FROM HR_SO_TimeOff WHERE ID = @ESSDailyID);
IF @SSID is not null BEGIN
SET @PayrollPKAutoInc = (SELECT PKAUTOINC FROM SS_SO_ADEIES WHERE ID = @SSID);
END;
END;
IF @ESSDailyID is null OR @SSID is null OR @PayrollPKAutoInc is null BEGIN
IF @SOAdeiesMode = 1 BEGIN
IF @PayrollPKAutoInc is null BEGIN
SET @PayrollPKAutoInc = (SELECT TOP 1 PKAUTOINC FROM HRM_SO_ADEIES WHERE ID_EMP = @CEMP_ID AND Xrisi = @CYear AND ID_Periodos = @CMonth ORDER BY PKAUTOINC DESC);
IF @PayrollPKAutoInc is null BEGIN
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', 'Creating HRM_SO_ADEIES', -1, @ApplicationID);
SET @SQL = 'INSERT INTO HRM_SO_ADEIES (ID_EMP,Xrisi,ID_Periodos) VALUES (' + cast(@CEMP_ID as varchar(255)) + ',' + cast(@CYear as varchar(255)) + ',' + cast(@CMonth as varchar(255)) + ');';
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', left(@SQL,2000), -1, @ApplicationID);
EXEC (@SQL);
--INSERT INTO HRM_SO_HMERISIA_ORARIA_EMP (ID_EMP,Xrisi,ID_Periodos) VALUES (@CEMP_ID,@CYear,@CMonth);
SET @PayrollPKAutoInc = (SELECT PKAUTOINC FROM HRM_SO_ADEIES WHERE ID_EMP = @CEMP_ID AND Xrisi = @CYear AND ID_Periodos = @CMonth);
END;
END;
IF @SSID is null BEGIN
SET @SSID = (SELECT TOP 1 ID FROM SS_SO_ADEIES WHERE PKAUTOINC = @PayrollPKAutoInc ORDER BY ID DESC);
IF @SSID is null BEGIN
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', 'Creating SS_SO_ADEIES', -1, @ApplicationID);

SET @SQL = 'INSERT INTO SS_SO_ADEIES (Ext_ID_EMP,Ext_Xrisi,Ext_ID_PERIODOS,StatusID,ProcessDate,PKAUTOINC) VALUES (' + cast(@CEMP_ID as varchar(255))+ ',' + cast(@CYear as varchar(255)) + ',' + cast(@CMonth as varchar(255)) + ',11,getdate(),' + cast(@PayrollPKAutoInc as varchar(255)) + ');'
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', left(@SQL,2000), -1, @ApplicationID);
EXEC (@SQL);
--INSERT INTO SS_SO_ADEIES (Ext_ID_EMP,Ext_Xrisi,Ext_ID_PERIODOS,StatusID,ProcessDate,PKAUTOINC) VALUES (@CEMP_ID,@CYear,@CMonth,11,getdate(),@PayrollPKAutoInc);
SET @SSID = (SELECT ID FROM SS_SO_ADEIES WHERE PKAUTOINC = @PayrollPKAutoInc);
END;
END;
IF @ESSDailyID is null BEGIN
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', 'Creating HR_SO_TimeOff', -1, @ApplicationID);
EXEC @ESSDailyID = X_getGID 'HR_SO_TimeOff';
SET @SQL = 'INSERT INTO HR_SO_TimeOff(ID, EmpID, Ext_EMPID, Xrisi, PeriodosID,[sID]) VALUES (' + cast(@ESSDailyID as varchar(255))  + ',' + cast(@CFEMP_ID as varchar(255)) + ',' + cast(@CEMP_ID as varchar(255)) + ',' + cast(@CYear as varchar(255)) + ',' + cast(@CMonth as varchar(255)) + ',' + cast(@SSID as varchar(255)) + ');';
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', left(@SQL,2000), -1, @ApplicationID);
EXEC (@SQL);
--INSERT INTO HR_SO_TimeOff(ID, EmpID, Ext_EMPID, Xrisi, PeriodosID,[sID]) VALUES (@ESSDailyID, @CFEMP_ID, @CEMP_ID, @CYear, @CMonth,@SSID);
END;
END
ELSE BEGIN
IF @ESSDailyID is null BEGIN
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', 'Creating HR_SO_TimeOff_ESSONLY', -1, @ApplicationID);
EXEC @ESSDailyID = X_getGID 'HR_SO_TimeOff_ESSONLY';
SET @SQL = 'INSERT INTO HR_SO_TimeOff_ESSONLY(ID, EmpID, Ext_EMPID, Xrisi, PeriodosID) VALUES (' + cast(@ESSDailyID as varchar(255)) + ',' + cast(@CFEMP_ID as varchar(255)) + ',' + cast(@CEMP_ID as varchar(255)) + ',' + cast(@CYear as varchar(255)) + ',' + cast(@CMonth as varchar(255)) + ');';
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', left(@SQL,2000), -1, @ApplicationID);
EXEC (@SQL);
--INSERT INTO HR_SO_TimeOff_ESSONLY(ID, EmpID, Ext_EMPID, Xrisi, PeriodosID) VALUES (@ESSDailyID, @CFEMP_ID, @CEMP_ID, @CYear, @CMonth);
END;
END;
END;

IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization'
, 'ESSID: ' + cast(@ESSDailyID as varchar(255)) + ', SSID: ' + cast(@SSID as varchar(255)) + ', PKAUTOINC: ' + cast(@PayrollPKAutoInc as varchar(255))
, -1, @ApplicationID);

SET @SETSQL = (SELECT STUFF((
SELECT ', [T' + cast(CDay as varchar(255)) + ']=' + case when AdeiaTypeID is null then 'null' else cast(AdeiaTypeID as varchar(255)) end
+ ', [D' + cast(CDay as varchar(255)) + ']=' + case when AdeiaTypeID is null then 'null' else '1' end
FROM #TempPeriodEmps
WHERE ContactID = @CContactID
FOR XML PATH(''), TYPE).value('(./text())[1]','NVARCHAR(MAX)'), 1, 1, '')
);

SET @SQL = 'UPDATE ' + case when @SOAdeiesMode=1 then 'HR_SO_TimeOff' else 'HR_SO_TimeOff_ESSONLY' end +  ' SET ' +  @SETSQL + ' WHERE ID = ' + cast(@ESSDailyID as varchar(255)) + ';';
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', left(@SQL,2000), -1, @ApplicationID);
EXEC (@SQL);

IF @SOAdeiesMode = 1 BEGIN
SET @SQL = 'UPDATE HRM_SO_ADEIES SET ' +  @SETSQL + ' WHERE PKAUTOINC = ' + cast(@PayrollPKAutoInc as varchar(255)) + ';';
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', left(@SQL,2000), -1, @ApplicationID);
EXEC (@SQL);

SET @SQL = 'UPDATE SS_SO_ADEIES SET ' +  @SETSQL + ' WHERE ID = ' + cast(@SSID as varchar(255)) + ';';
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', left(@SQL,2000), -1, @ApplicationID);
EXEC (@SQL);
END;
END;

--
-- End Update Vacations Table
--

SET @ESSDailyID = null;
SET @PayrollPKAutoInc = null;
SET @SSID = null;

--
-- Update Sickness Table
--

IF @SOAstheneiesMode <> 0 BEGIN
SET @ESSDailyID = (SELECT TOP 1 ID FROM HR_SO_Astheneia WHERE EmpID = @CFEMP_ID AND PeriodosID=@CMonth AND Xrisi=@CYear ORDER by ID DESC);
IF @ESSDailyID is not null BEGIN
SET @SSID = (SELECT [sID] FROM HR_SO_Astheneia WHERE ID = @ESSDailyID);
IF @SSID is not null BEGIN
SET @PayrollPKAutoInc = (SELECT PKAUTOINC FROM SS_SO_ASTHENIES WHERE ID = @SSID);
END;
END;
IF @ESSDailyID is null OR @SSID is null OR @PayrollPKAutoInc is null BEGIN
IF @SOAstheneiesMode = 1 BEGIN
IF @PayrollPKAutoInc is null BEGIN
SET @PayrollPKAutoInc = (SELECT TOP 1 PKAUTOINC FROM HRM_SO_ASTHENIES WHERE ID_EMP = @CEMP_ID AND Xrisi = @CYear AND ID_Periodos = @CMonth ORDER BY PKAUTOINC DESC);
IF @PayrollPKAutoInc is null BEGIN
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', 'Creating HRM_SO_ASTHENIES', -1, @ApplicationID);
SET @SQL = 'INSERT INTO HRM_SO_ASTHENIES (ID_EMP,Xrisi,ID_Periodos) VALUES (' + cast(@CEMP_ID as varchar(255)) + ',' + cast(@CYear as varchar(255)) + ',' + cast(@CMonth as varchar(255)) + ');';
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', left(@SQL,2000), -1, @ApplicationID);
EXEC (@SQL);
--INSERT INTO HRM_SO_ASTHENIES (ID_EMP,Xrisi,ID_Periodos) VALUES (@CEMP_ID,@CYear,@CMonth);
SET @PayrollPKAutoInc = (SELECT PKAUTOINC FROM HRM_SO_ASTHENIES WHERE ID_EMP = @CEMP_ID AND Xrisi = @CYear AND ID_Periodos = @CMonth);
END;
END;
IF @SSID is null BEGIN
SET @SSID = (SELECT TOP 1 ID FROM SS_SO_ASTHENIES WHERE PKAUTOINC = @PayrollPKAutoInc ORDER BY ID DESC);
IF @SSID is null BEGIN
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', 'Creating SS_SO_ASTHENIES', -1, @ApplicationID);

SET @SQL = 'INSERT INTO SS_SO_ASTHENIES (Ext_ID_EMP,Ext_Xrisi,Ext_ID_PERIODOS,StatusID,ProcessDate,PKAUTOINC) VALUES (' + cast(@CEMP_ID as varchar(255))+ ',' + cast(@CYear as varchar(255)) + ',' + cast(@CMonth as varchar(255)) + ',11,getdate(),' + cast(@PayrollPKAutoInc as varchar(255)) + ');'
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', left(@SQL,2000), -1, @ApplicationID);
EXEC (@SQL);
--INSERT INTO SS_SO_ASTHENIES (Ext_ID_EMP,Ext_Xrisi,Ext_ID_PERIODOS,StatusID,ProcessDate,PKAUTOINC) VALUES (@CEMP_ID,@CYear,@CMonth,11,getdate(),@PayrollPKAutoInc);
SET @SSID = (SELECT ID FROM SS_SO_ASTHENIES WHERE PKAUTOINC = @PayrollPKAutoInc);
END;
END;
IF @ESSDailyID is null BEGIN
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', 'Creating HR_SO_Astheneia', -1, @ApplicationID);
EXEC @ESSDailyID = X_getGID 'HR_SO_Astheneia';
SET @SQL = 'INSERT INTO HR_SO_Astheneia(ID, EmpID, Ext_EMPID, Xrisi, PeriodosID,[sID]) VALUES (' + cast(@ESSDailyID as varchar(255))  + ',' + cast(@CFEMP_ID as varchar(255)) + ',' + cast(@CEMP_ID as varchar(255)) + ',' + cast(@CYear as varchar(255)) + ',' + cast(@CMonth as varchar(255)) + ',' + cast(@SSID as varchar(255)) + ');';
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', left(@SQL,2000), -1, @ApplicationID);
EXEC (@SQL);
--INSERT INTO HR_SO_Astheneia(ID, EmpID, Ext_EMPID, Xrisi, PeriodosID,[sID]) VALUES (@ESSDailyID, @CFEMP_ID, @CEMP_ID, @CYear, @CMonth,@SSID);
END;
END
ELSE BEGIN
IF @ESSDailyID is null BEGIN
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', 'Creating HR_SO_Astheneia_ESSONLY', -1, @ApplicationID);
EXEC @ESSDailyID = X_getGID 'HR_SO_Astheneia_ESSONLY';
SET @SQL = 'INSERT INTO HR_SO_Astheneia_ESSONLY(ID, EmpID, Ext_EMPID, Xrisi, PeriodosID) VALUES (' + cast(@ESSDailyID as varchar(255)) + ',' + cast(@CFEMP_ID as varchar(255)) + ',' + cast(@CEMP_ID as varchar(255)) + ',' + cast(@CYear as varchar(255)) + ',' + cast(@CMonth as varchar(255)) + ');';
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', left(@SQL,2000), -1, @ApplicationID);
EXEC (@SQL);
--INSERT INTO HR_SO_Astheneia_ESSONLY(ID, EmpID, Ext_EMPID, Xrisi, PeriodosID) VALUES (@ESSDailyID, @CFEMP_ID, @CEMP_ID, @CYear, @CMonth);
END;
END;
END;

IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization'
, 'ESSID: ' + cast(@ESSDailyID as varchar(255)) + ', SSID: ' + cast(@SSID as varchar(255)) + ', PKAUTOINC: ' + cast(@PayrollPKAutoInc as varchar(255))
, -1, @ApplicationID);

SET @SETSQL = (SELECT STUFF((
SELECT ', [T' + cast(CDay as varchar(255)) + ']=' + case when SicknessTypeID is null then 'null' else cast(SicknessTypeID as varchar(255)) end
+ ', [D' + cast(CDay as varchar(255)) + ']=' + case when SicknessTypeID is null then 'null' else '1' end
FROM #TempPeriodEmps
WHERE ContactID = @CContactID
FOR XML PATH(''), TYPE).value('(./text())[1]','NVARCHAR(MAX)'), 1, 1, '')
);

SET @SQL = 'UPDATE ' + case when @SOAstheneiesMode=1 then 'HR_SO_Astheneia' else 'HR_SO_Astheneia_ESSONLY' end +  ' SET ' +  @SETSQL + ' WHERE ID = ' + cast(@ESSDailyID as varchar(255)) + ';';
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', left(@SQL,2000), -1, @ApplicationID);
EXEC (@SQL);

IF @SOAstheneiesMode = 1 BEGIN
SET @SQL = 'UPDATE HRM_SO_ASTHENIES SET ' +  @SETSQL + ' WHERE PKAUTOINC = ' + cast(@PayrollPKAutoInc as varchar(255)) + ';';
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', left(@SQL,2000), -1, @ApplicationID);
EXEC (@SQL);

SET @SQL = 'UPDATE SS_SO_ASTHENIES SET ' +  @SETSQL + ' WHERE ID = ' + cast(@SSID as varchar(255)) + ';';
IF isnull(@DebugMode,0)=2
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', left(@SQL,2000), -1, @ApplicationID);
EXEC (@SQL);
END;
END;

--
-- End Update Sickness Table
--

FETCH NEXT FROM cr__PeriodEmpsLoop INTO @CContactID;
END;
CLOSE cr__PeriodEmpsLoop;
DEALLOCATE cr__PeriodEmpsLoop;

FETCH NEXT FROM cr__PeriodsLoop INTO @CMonth, @CYear;
END;
CLOSE cr__PeriodsLoop;
DEALLOCATE cr__PeriodsLoop;
END;

IF isnull(@DebugMode,0)>=1
INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', 'lbAppTimeSheetFinalization_FinishOrometrisiUpdate', -1, @ApplicationID);

--
-- Finalize TimesheetDetails rows
--
UPDATE SO_TimesheetDetails
SET IsFinalized = 1, LastActionMadeContactID = @CurrentContactID, SubmitDate = getdate()
WHERE ApplicationID = @ApplicationID;
INSERT INTO SO_TimesheetDetails_History (TimesheetDetailID, ApplicationID, ContactID, EditDate, OrarioID, HasRepo, AdeiaTypeID, SicknessTypeID, IsFinalized, SubmitDate, SubmitterID, IsFinalizationSnapshot)
SELECT ID, ApplicationID, ContactID, EditDate, OrarioID, HasRepo, AdeiaTypeID, SicknessTypeID, IsFinalized, SubmitDate, SubmitterID, 1
FROM SO_TimesheetDetails
WHERE ApplicationID = @ApplicationID;

--
-- Update Application row
--
UPDATE SS_Applications
SET FinalizedDaysCount = (SELECT count(*) FROM SO_TimesheetDetails WHERE ApplicationID=@ApplicationID)
WHERE ID = @ApplicationID;

INSERT INTO SS_Application_Logs (LogDate, LogType, LogDescr, SubmitterID, ApplicationID)
VALUES (getdate(), 'lbAppTimeSheetFinalization', 'lbAppTimeSheetFinalization_Success', -1, @ApplicationID);

SET @RetVal=1; -- Finalization Process was Successful
RETURN;
END
GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Altering [dbo].[SS_HRM_ASS_GetEmployees]'
GO


ALTER FUNCTION [dbo].[SS_HRM_ASS_GetEmployees]
(
@InstanceID int, @DepartmentID int, @CurUser int, @CurLanguageID int, @ShowOnlyDirect int  -- 0 No, 1 Yes
)
RETURNS @RetTbl TABLE (ID int,	Descr varchar(255),	IsOwnAssessment int,	IsComplete int)
AS
BEGIN
-- Custom (BasicForms 1,2,3): Required fields @InstanceID,@CurUser,@CurLanguageID,@ShowOnlyDirect. @DepartmentID is not used -> NULL
-- Default: Required fields @InstanceID,@CurUser,@CurLanguageID,@DepartmentID. @ShowOnlyDirect is not used -> NULL

DECLARE @Ext_id_ass_instance int,@HasBasicForms int, @ExtCurrentUserID int, @IsHREditor int,@IsHREditorPerCompany int;

SET @Ext_id_ass_instance = (SELECT Ext_id_ass_instance FROM SS_HRM_ASS_INSTANCES WHERE ID = @InstanceID);
SET @HasBasicForms = (SELECT HasBasicForms FROM SS_HRM_ASS_INSTANCES WHERE ID = @InstanceID);
SET @ExtCurrentUserID = (select EMP_ID FROM AC_All_EmpIDS WHERE ContactID = @CurUser);
SET @IsHREditor = case when (select count(*) FROM XU_UserRoles WHERE RoleID = 1005 AND UsrId = @CurUser)>0 then 1 else 0 end;
SET @IsHREditorPerCompany = case when (select count(*) FROM XU_UserRoles WHERE RoleID = 1011 AND UsrId = @CurUser)>0 then 1 else 0 end;

DECLARE @AssessmentEditorRole int; --DESS-115639
SET @AssessmentEditorRole= 1017;

IF @InstanceID is NULL  RETURN;

IF @HasBasicForms is not null BEGIN
IF @HasBasicForms = 3 BEGIN

INSERT @RetTbl
SELECT EmployeeID AS ID,
CASE WHEN min(AADescr) = 0 then ' ' + MAX(coalesce(lo_last.VALUE, ac.Name,'')) + ' ' + MAX(coalesce(lo_first.VALUE, ac.FirstName, '') )
WHEN min(AADescr) = 1 then '[D] ' + MAX(coalesce(lo_last.VALUE, ac.Name,'')) + ' ' + MAX(coalesce(lo_first.VALUE, ac.FirstName, '') )
ELSE '[I] ' + MAX(coalesce(lo_last.VALUE, ac.Name,'')) + ' ' + MAX(coalesce(lo_first.VALUE, ac.FirstName, '') ) END AS Descr,
IsOwnAssessment,
min(IsComplete) AS IsComplete
FROM
(
SELECT distinct a.EmployeeID, (case when a.StatusID = 4 then 1 else 0 end) AS IsComplete, (case when a.EmployeeID = @CurUser then 1 else 0 end) AS IsOwnAssessment
, case when a.EmployeeID = @CurUser then 0 else cm.AA end AS AA
, a.AssessorID
,CASE WHEN EmployeeID = @CurUser THEN 0--' '
WHEN AssessorID = @CurUser THEN 1--'[D] '
ELSE 2 END AS AADescr--'[I] ' END AS AADescr
FROM SS_HRM_ASS_INSTANCE_SimpleAssessments a
CROSS APPLY fnSS_ContactManagers_SubsNew(a.EmployeeID, getdate(),1) cm
JOIN SS_EMPLOYEE e on a.EmployeeID = e.ContactID
WHERE a.InstanceID = @InstanceID
AND (@IsHREditor = 1
OR (@IsHREditorPerCompany=1 AND e.ID_CMP in (select ID_CMP FROM XU_UserHREditorCompanies WHERE ContactID = @CurUser))
OR a.EmployeeID = @CurUser
OR (a.AssessorID = @CurUser AND cm.ManagerContactId = @CurUser)
OR @CurUser = cm.ManagerContactId)

UNION

SELECT distinct g.EmployeeID, (case when g.StatusID = 3 then 1 else 0 end) AS IsComplete, (case when g.EmployeeID = @CurUser then 1 else 0 end) As IsOwnAssessment
, case when g.EmployeeID = @CurUser then 0 else cm.AA end AS AA
, g.AssessorID
,CASE WHEN EmployeeID = @CurUser THEN 0--' '
WHEN AssessorID = @CurUser THEN 1--'[D] '
ELSE 2 END AS AADescr-- '[I] ' END AS AADescr
FROM SS_HRM_ASS_INSTANCE_SimpleGoalSet g
CROSS APPLY fnSS_ContactManagers_SubsNew(g.EmployeeID, getdate(),1) cm
JOIN SS_EMPLOYEE e on g.EmployeeID = e.ContactID
WHERE g.InstanceID = @InstanceID
AND (@IsHREditor = 1
OR (@IsHREditorPerCompany=1 AND e.ID_CMP in (select ID_CMP FROM XU_UserHREditorCompanies WHERE ContactID = @CurUser))
OR g.EmployeeID = @CurUser
OR (g.AssessorID = @CurUser AND cm.ManagerContactId = @CurUser)
OR @CurUser = cm.ManagerContactId)

UNION
-- Assessments
SELECT distinct e.ContactID as EmployeeID
, (case when rd.[Status] in (2,3) then 1 else 0 end) AS IsComplete ---L_AssessmentStatus
, (case when e.ContactID = @CurUser then 1 else 0 end) AS IsOwnAssessment
, case when e.ContactID = @CurUser then 0 else cm.AA end AS AA
, e_assessor.ContactID as AssessorID
,CASE WHEN e.ContactID = @CurUser THEN 0--' '
WHEN e_assessor.ContactID = @CurUser THEN 1--'[D] '
ELSE 2 END AS AADescr --'[I] ' END AS AADescr
FROM SS_HRM_ASS_Results_Detail rd
JOIN SS_HRM_ASS_Results d on rd.Ext_id_ass_res = d.Ext_id_ass_res
JOIN SS_HRM_ASS_ASSESSMENTS a on d.id_ass = a.Ext_id_ass
JOIN SS_HRM_ASS_INSTANCES ai on rd.id_ass_instance = ai.Ext_id_ass_instance
JOIN AC_All_EmpIDS aa on rd.Ext_id_emp = aa.EMP_ID
JOIN SS_EMPLOYEE e on aa.FEMP_ID = e.ID_EMP
LEFT JOIN AC_All_EmpIDS aa_assessor on rd.id_emp_assessor = aa_assessor.EMP_ID
LEFT JOIN SS_EMPLOYEE e_assessor on aa_assessor.FEMP_ID = e_assessor.ID_EMP
OUTER APPLY fnSS_ContactManagers_SubsNew(e.ContactID, getdate(),1) cm
WHERE ai.ID = @InstanceID and ai.HasDetailedForms = 1 and ai.HasBasicForms = 3 -- @ass_instance
AND (@IsHREditor = 1
OR (@IsHREditorPerCompany=1 AND e.ID_CMP in (select ID_CMP FROM XU_UserHREditorCompanies WHERE ContactID = @CurUser))
OR e.ContactID = @CurUser
OR (rd.id_emp_assessor = @CurUser AND cm.ManagerContactId = @CurUser)
OR @CurUser = cm.ManagerContactId)

UNION
--Questioners
SELECT distinct e.ContactID as EmployeeID
, cast( empqnr.IsComplete as Int) as IsComplete
, (case when e.ContactID = @CurUser then 1 else 0 end) AS IsOwnAssessment
, case when e.ContactID = @CurUser then 0 else cm.AA end AS AA
, null as AssessorID
,CASE WHEN e.ContactID = @CurUser THEN 0--' '
--WHEN e_assessor.ContactID = @CurrUser THEN '[D] '
ELSE 2 END AS AADescr--'[I] ' END AS AADescr
FROM SS_HRM_ASS_INSTANCE_QNR_PARTICIPANTS qnrp
JOIN SS_HRM_ASS_INSTANCE_QNR qnr on qnr.Ext_id = qnrp.id_ass_instance_qnr
JOIN SS_HRM_ASS_INSTANCES ai on qnr.id_ass_instance = ai.Ext_id_ass_instance
JOIN SS_HRM_ASS_INSTANCE_EMP_QNR empqnr on empqnr.id_ass_instance_questionnaire = qnrp.id_ass_instance_qnr and empqnr.id_emp = qnrp.id_emp
JOIN AC_All_EmpIDS aa on qnrp.id_emp = aa.EMP_ID
JOIN SS_EMPLOYEE e on aa.FEMP_ID = e.ID_EMP
OUTER APPLY fnSS_ContactManagers_SubsNew(e.ContactID, getdate(),1) cm
WHERE ai.id = @InstanceID and ai.HasDetailedForms = 1 and ai.HasBasicForms = 3 -- @ass_instance
AND (@IsHREditor = 1
OR (@IsHREditorPerCompany=1 AND e.ID_CMP in (select ID_CMP FROM XU_UserHREditorCompanies WHERE ContactID = @CurUser))
OR e.ContactID = @CurUser
--OR (rd.id_emp_assessor = @CurrUser AND cm.ManagerContactId = @CurrUser)
OR @CurUser = cm.ManagerContactId)

) InnerTbl
JOIN AC_Contacts ac ON ac.ContactID = InnerTbl.EmployeeID
LEFT JOIN L_Object lo_last on lo_last.ID_TABLE = ac.ContactID AND lo_last.TABLE_NAME = 'AC_Contacts' AND lo_last.FieldName = 'LastName' AND lo_last.ID_LANGUAGES = @CurLanguageID
LEFT JOIN L_Object lo_first on lo_first.ID_TABLE = ac.ContactID AND lo_first.TABLE_NAME = 'AC_Contacts' AND lo_first.FieldName = 'FirstName' AND lo_first.ID_LANGUAGES = @CurLanguageID
WHERE (CASE WHEN @ShowOnlyDirect = 1 AND (EmployeeID = @CurUser OR AssessorID = @CurUser) THEN 1
WHEN @ShowOnlyDirect = 0 THEN 1 ELSE 0 END) = 1
GROUP BY EmployeeID, IsOwnAssessment--, PreDescr--, AssessorID
ORDER BY Descr

RETURN
END
ELSE IF @HasBasicForms in (1,2) BEGIN
IF @ShowOnlyDirect = 1 BEGIN

INSERT @RetTbl
SELECT distinct InnerTbl.ID
, (CASE when IsOwnAssessment = 1 THEN ' ' + MAX(coalesce(lo_last.VALUE, ac.Name,'')) + ' ' + MAX(coalesce(lo_first.VALUE, ac.FirstName, '') ) else '[D] ' + MAX(coalesce(lo_last.VALUE, ac.Name,'')) + ' ' + MAX(coalesce(lo_first.VALUE, ac.FirstName, '') ) END) AS Descr
, IsOwnAssessment
, min(IsComplete) AS IsComplete
FROM
(
SELECT a.EmployeeID as ID
, (case when a.EmployeeID = @CurUser then 1 else 0 end) AS IsOwnAssessment
, (case when a.StatusID = 4 then 1 else 0 end) AS IsComplete
, a.AssessorID
FROM SS_HRM_ASS_INSTANCE_SimpleAssessments a
WHERE a.InstanceID = @InstanceID
AND (a.EmployeeID = @CurUser OR a.AssessorID = @CurUser)

UNION

SELECT g.EmployeeID AS ID
, (case when g.EmployeeID = @CurUser then 1 else 0 end) AS IsOwnAssessment
, (case when g.StatusID = 3 then 1 else 0 end) AS IsComplete
, g.AssessorID
FROM SS_HRM_ASS_INSTANCE_SimpleGoalSet g
WHERE g.InstanceID = @InstanceID
AND (g.EmployeeID = @CurUser OR g.AssessorID = @CurUser)
) InnerTbl
JOIN AC_Contacts ac ON ac.ContactID = InnerTbl.ID
LEFT JOIN L_Object lo_last on lo_last.ID_TABLE = ac.ContactID AND lo_last.TABLE_NAME = 'AC_Contacts' AND lo_last.FieldName = 'LastName' AND lo_last.ID_LANGUAGES = @CurLanguageID
LEFT JOIN L_Object lo_first on lo_first.ID_TABLE = ac.ContactID AND lo_first.TABLE_NAME = 'AC_Contacts' AND lo_first.FieldName = 'FirstName' AND lo_first.ID_LANGUAGES = @CurLanguageID
GROUP BY InnerTbl.ID, IsOwnAssessment, AssessorID

RETURN
END
ELSE BEGIN

INSERT @RetTbl
SELECT EmployeeID AS ID,
CASE WHEN EmployeeID = @CurUser THEN ' ' + MAX(coalesce(lo_last.VALUE, ac.Name,'')) + ' ' + MAX(coalesce(lo_first.VALUE, ac.FirstName, '') )
WHEN AssessorID = @CurUser THEN '[D] ' + MAX(coalesce(lo_last.VALUE, ac.Name,'')) + ' ' +MAX(coalesce(lo_first.VALUE, ac.FirstName, '') )
ELSE '[I] ' + MAX(coalesce(lo_last.VALUE, ac.Name,'')) + ' ' + MAX(coalesce(lo_first.VALUE, ac.FirstName, '') ) END AS Descr,
IsOwnAssessment,
min(IsComplete) AS IsComplete
FROM
(

SELECT distinct a.EmployeeID, (case when a.StatusID = 4 then 1 else 0 end) AS IsComplete, (case when a.EmployeeID = @CurUser then 1 else 0 end) AS IsOwnAssessment
, case when a.EmployeeID = @CurUser then 0 else cm.AA end AS AA
, a.AssessorID
FROM SS_HRM_ASS_INSTANCE_SimpleAssessments a
CROSS APPLY fnSS_ContactManagers_SubsNew(a.EmployeeID, getdate(),1) cm
JOIN SS_EMPLOYEE e on a.EmployeeID = e.ContactID
WHERE a.InstanceID = @InstanceID
AND (@IsHREditor = 1
OR (@IsHREditorPerCompany=1 AND e.ID_CMP in (select ID_CMP FROM XU_UserHREditorCompanies WHERE ContactID = @CurUser))
OR a.EmployeeID = @CurUser
OR (a.AssessorID = @CurUser AND cm.ManagerContactId = @CurUser)
OR @CurUser = cm.ManagerContactId)

UNION

SELECT distinct g.EmployeeID, (case when g.StatusID = 3 then 1 else 0 end) AS IsComplete, (case when g.EmployeeID = @CurUser then 1 else 0 end) As IsOwnAssessment
, case when g.EmployeeID = @CurUser then 0 else cm.AA end AS AA
, g.AssessorID
FROM SS_HRM_ASS_INSTANCE_SimpleGoalSet g
CROSS APPLY fnSS_ContactManagers_SubsNew(g.EmployeeID, getdate(),1) cm
JOIN SS_EMPLOYEE e on g.EmployeeID = e.ContactID
WHERE g.InstanceID = @InstanceID
AND (@IsHREditor = 1
OR (@IsHREditorPerCompany=1 AND e.ID_CMP in (select ID_CMP FROM XU_UserHREditorCompanies WHERE ContactID = @CurUser))
OR g.EmployeeID = @CurUser
OR (g.AssessorID = @CurUser AND cm.ManagerContactId = @CurUser)
OR @CurUser = cm.ManagerContactId)
) InnerTbl
JOIN AC_Contacts ac ON ac.ContactID = InnerTbl.EmployeeID
LEFT JOIN L_Object lo_last on lo_last.ID_TABLE = ac.ContactID AND lo_last.TABLE_NAME = 'AC_Contacts' AND lo_last.FieldName = 'LastName' AND lo_last.ID_LANGUAGES = @CurLanguageID
LEFT JOIN L_Object lo_first on lo_first.ID_TABLE = ac.ContactID AND lo_first.TABLE_NAME = 'AC_Contacts' AND lo_first.FieldName = 'FirstName' AND lo_first.ID_LANGUAGES = @CurLanguageID
WHERE (CASE WHEN @ShowOnlyDirect = 1 AND (EmployeeID = @CurUser OR AssessorID = @CurUser) THEN 1
WHEN @ShowOnlyDirect = 0 THEN 1 ELSE 0 END) = 1
GROUP BY EmployeeID, IsOwnAssessment, AssessorID
ORDER BY Descr

RETURN
END
END
END
ELSE BEGIN

WITH AssessedEmployees (ContactID,ContactType) AS
(
SELECT up.EmployeeID AS ContactID, (case when EmployeeID = @CurUser then 'Me' else 'MyEmployeeAssessed' end) AS ContactType
FROM SS_HRM_ASS_Results_Detail rd
JOIN AC_All_EmpIDS ae on rd.Ext_id_emp = ae.EMP_ID
JOIN SS_HRM_ASS_INSTANCES i on i.Ext_id_ass_instance = rd.id_ass_instance
LEFT JOIN SS_HRM_ASS_INSTANCE_FinalSignatures fs on fs.InstanceID = i.id AND ae.ContactID = fs.AssessedEmployeeID
CROSS APPLY [dbo].SS_GetUserPermsForDeptOrGroupEmployees (@CurUser,@DepartmentID,null,getdate(),null,null) up
WHERE Rights <> 0 AND rd.id_ass_instance = @Ext_id_ass_instance AND up.EmployeeID = ae.ContactID
AND (rd.Ext_id_emp = @ExtCurrentUserID OR rd.id_emp_assessor = @ExtCurrentUserID OR rd.id_emp_assessor_2 = @ExtCurrentUserID OR rd.id_emp_assessor_3 = @ExtCurrentUserID OR fs.AssignedToContactIDForSignature = @CurUser)

UNION --new Show assessor/assesse/signature not based on rights (an employee to an employee)
SELECT ae.ContactID AS ContactID, (case when ae.ContactID = @CurUser then 'Me' else 'MyEmployeeAssessed' end) AS ContactType
FROM SS_HRM_ASS_Results_Detail rd
JOIN AC_All_EmpIDS ae on rd.Ext_id_emp = ae.EMP_ID
JOIN AC_Department_Contacts dc on ae.ContactID = dc.ContactID and getdate() between dc.StartDate and isnull(dc.EndDate, '2049-12-31')
JOIN SS_HRM_ASS_INSTANCES i on i.Ext_id_ass_instance = rd.id_ass_instance
LEFT JOIN SS_HRM_ASS_INSTANCE_FinalSignatures fs on fs.InstanceID = i.id AND ae.ContactID = fs.AssessedEmployeeID
WHERE rd.id_ass_instance = @Ext_id_ass_instance
AND (rd.Ext_id_emp = @ExtCurrentUserID OR rd.id_emp_assessor = @ExtCurrentUserID OR rd.id_emp_assessor_2 = @ExtCurrentUserID OR rd.id_emp_assessor_3 = @ExtCurrentUserID OR fs.AssignedToContactIDForSignature = @CurUser)
AND dc.DepartmentID in (select ID from SS_GetViewableDepartmentList(@CurUser,6,1))

UNION
SELECT ae.ContactID, 'OutsideMyDeptsAssessed' AS ContactTYpe
FROM SS_HRM_ASS_Results_Detail rd
JOIN AC_All_EmpIDS ae on rd.Ext_id_emp = ae.EMP_ID
JOIN AC_Department_Contacts dc on ae.ContactID = dc.ContactID and getdate() between dc.StartDate and isnull(dc.EndDate, '2049-12-31')
JOIN SS_HRM_ASS_INSTANCES i on i.Ext_id_ass_instance = rd.id_ass_instance
LEFT JOIN SS_HRM_ASS_INSTANCE_FinalSignatures fs on fs.InstanceID = i.id AND ae.ContactID = fs.AssessedEmployeeID
WHERE rd.id_ass_instance = @Ext_id_ass_instance
AND (rd.id_emp_assessor = @ExtCurrentUserID OR rd.id_emp_assessor_2 = @ExtCurrentUserID OR rd.id_emp_assessor_3 = @ExtCurrentUserID OR fs.AssignedToContactIDForSignature = @CurUser)
AND dc.DepartmentID not in (select ID from SS_GetViewableDepartmentList(@CurUser,6,1))
UNION
SELECT c.ContactID, 'MyEmployee' As ContactType
FROM AC_Department_Contacts dc
JOIN AC_Contacts c on dc.ContactID = c.ContactID
JOIN SS_Employee e on e.ContactID = c.ContactID
CROSS APPLY SS_GetUserPermsforDeptEmployees(@CurUser,@DepartmentID,getdate()) up
WHERE getdate() between dc.Startdate and isnull(dc.Enddate, '2049-12-31')
and getdate() <= isnull(e.FRDATE, '2049-12-31')
AND (@DepartmentID is null OR dc.DepartmentID in ( select ID from SS_GetDeptListFromNodeDown(@DepartmentID)))
AND up.Rights <> 0 AND up.EmployeeID = c.ContactID
UNION
--DESS-115639 HR per Node
SELECT c.ContactID, 'HRPerNode' As ContactType
FROM AC_Department_Contacts dc
JOIN AC_Contacts c on dc.ContactID = c.ContactID
JOIN SS_Employee e on e.ContactID = c.ContactID
CROSS APPLY SS_GetViewableDepartmentListPerNodePerRole (@CurUser,@AssessmentEditorRole) dln
WHERE getdate() between dc.Startdate and isnull(dc.Enddate, '2049-12-31')
and getdate() <= isnull(e.FRDATE, '2049-12-31')
AND dln.ID = dc.DepartmentID
AND (@DepartmentID is null OR dc.DepartmentID in ( select ID from SS_GetDeptListFromNodeDown(@DepartmentID)))
--AND (dc.DepartmentID in (select ID from SS_GetViewableDepartmentListPerNodePerRole (@CurUser,@AssessmentEditorRole)) AND @DepartmentID in (select ID from SS_GetViewableDepartmentListPerNodePerRole (@CurUser,@AssessmentEditorRole)))
UNION
--GoalSettings
SELECT c.ContactID, 'GoalSetting' As ContactType
FROM SS_HRM_ASS_INSTANCE_OBJECTIVES_PARTICIPANTS obp
JOIN SS_HRM_ASS_INSTANCES ai on ai.Ext_id_ass_instance = obp.id_ass_instance
LEFT JOIN SS_HRM_ASS_INSTANCE_OBJECTIVES_EMP obemp on obemp.id_ass_instance = obp.id_ass_instance AND obemp.id_emp = obp.id_emp AND obemp.StatusID not in (2,12,22)
JOIN AC_All_EmpIDS ae on obp.id_emp = ae.EMP_ID
JOIN AC_Contacts c on ae.ContactID = c.ContactID
WHERE obp.id_ass_instance = @Ext_id_ass_instance
AND obp.StatusID not in (2,12,22)
AND isnull(ai.GoalSettingMode,1) = 2 AND isnull(ai.CurrentGoalSettingStatus,0) = 1
AND (obp.SettingSubmitterContactID is not null AND obp.SettingSubmitterContactID = @CurUser
OR obp.SettingSubmitterContactID is null AND @CurUser in (select cm.RegularManager
from AC_Department_Contacts dc
CROSS APPLY SS_ContactCurrentManagerTreeUp (dc.ContactID,dc.DepartmentID) cm
where dc.ContactID = c.ContactID AND CONVERT(date,getdate()) between dc.Startdate and isnull(dc.Enddate, '2049-12-31') AND cm.ManagerLevel = 1))
UNION
--Goal Achievement
SELECT c.ContactID, 'GoalAchievement' As ContactType
FROM SS_HRM_ASS_INSTANCE_OBJECTIVES_PARTICIPANTS obp
JOIN SS_HRM_ASS_INSTANCES ai on ai.Ext_id_ass_instance = obp.id_ass_instance
LEFT JOIN SS_HRM_ASS_INSTANCE_OBJECTIVES_EMP obemp on obemp.id_ass_instance = obp.id_ass_instance AND obemp.id_emp = obp.id_emp AND obemp.StatusID not in (2,12,22)
JOIN AC_All_EmpIDS ae on obp.id_emp = ae.EMP_ID
JOIN AC_Contacts c on ae.ContactID = c.ContactID
WHERE obp.id_ass_instance = @Ext_id_ass_instance
AND obp.StatusID not in (2,12,22)
AND isnull(ai.GoalSettingMode,1) = 2 AND isnull(ai.CurrentGoalSettingStatus,0) = 2
AND (obp.AchievementSubmitterContactID is not null AND obp.AchievementSubmitterContactID = @CurUser
OR obp.AchievementSubmitterContactID is null AND @CurUser in (select cm.RegularManager
from AC_Department_Contacts dc
CROSS APPLY SS_ContactCurrentManagerTreeUp (dc.ContactID,dc.DepartmentID) cm
where dc.ContactID = c.ContactID AND CONVERT(date,getdate()) between dc.Startdate and isnull(dc.Enddate, '2049-12-31') AND cm.ManagerLevel = 1))
)

INSERT @RetTbl
SELECT distinct acon.ContactID AS ID
,ISNULL(lo_last.VALUE, acon.Name) + ' ' + coalesce(lo_first.VALUE, acon.FirstName, '') AS Descr
,NULL AS IsOwnAssessment
,NULL AS IsComplete
FROM AssessedEmployees t
JOIN AC_Contacts acon ON acon.ContactID = t.ContactID
LEFT JOIN L_Object lo_last on lo_last.ID_TABLE = acon.ContactID AND lo_last.TABLE_NAME = 'AC_Contacts' AND lo_last.FieldName = 'LastName' AND lo_last.ID_LANGUAGES = @CurLanguageID
LEFT JOIN L_Object lo_first on lo_first.ID_TABLE = acon.ContactID AND lo_first.TABLE_NAME = 'AC_Contacts' AND lo_first.FieldName = 'FirstName' AND lo_first.ID_LANGUAGES = @CurLanguageID

RETURN
END

RETURN
END
GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Creating [dbo].[SS_Application_TrainingEmployees]'
GO
IF OBJECT_ID(N'[dbo].[SS_Application_TrainingEmployees]', 'U') IS NULL
CREATE TABLE [dbo].[SS_Application_TrainingEmployees]
(
[ID] [int] NOT NULL,
[ApplicationID] [int] NULL,
[TraineeContactID] [int] NULL,
[TrainingDescr] [varchar] (2000) COLLATE Greek_CI_AS NULL,
[TrainingDuration] [int] NULL,
[TrainingDate] [datetime] NULL,
[TrainingLocation] [varchar] (2000) COLLATE Greek_CI_AS NULL,
[GUID] [uniqueidentifier] NULL
)
GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Creating primary key [PK_SS_Application_TrainingEmployees] on [dbo].[SS_Application_TrainingEmployees]'
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'PK_SS_Application_TrainingEmployees' AND object_id = OBJECT_ID(N'[dbo].[SS_Application_TrainingEmployees]'))
ALTER TABLE [dbo].[SS_Application_TrainingEmployees] ADD CONSTRAINT [PK_SS_Application_TrainingEmployees] PRIMARY KEY CLUSTERED  ([ID])
GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Creating [dbo].[XU_UserGroup_Occurences]'
GO
IF OBJECT_ID(N'[dbo].[XU_UserGroup_Occurences]', 'U') IS NULL
CREATE TABLE [dbo].[XU_UserGroup_Occurences]
(
[ID] [int] NOT NULL,
[GroupID] [int] NOT NULL,
[Descr] [varchar] (3000) COLLATE Greek_CI_AS NULL,
[TextField1] [varchar] (2000) COLLATE Greek_CI_AS NULL,
[TextField2] [varchar] (2000) COLLATE Greek_CI_AS NULL,
[TextField3] [varchar] (2000) COLLATE Greek_CI_AS NULL,
[CreateDate] [datetime] NOT NULL,
[CreatedBy] [int] NOT NULL
)
GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Creating primary key [PK_XU_UserGroup_Occurences] on [dbo].[XU_UserGroup_Occurences]'
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'PK_XU_UserGroup_Occurences' AND object_id = OBJECT_ID(N'[dbo].[XU_UserGroup_Occurences]'))
ALTER TABLE [dbo].[XU_UserGroup_Occurences] ADD CONSTRAINT [PK_XU_UserGroup_Occurences] PRIMARY KEY CLUSTERED  ([ID])
GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Adding foreign keys to [dbo].[SS_Application_TrainingEmployees]'
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SS_Application_TrainingEmployees$ApplicationID_ref_SS_Applications]', 'F') AND parent_object_id = OBJECT_ID(N'[dbo].[SS_Application_TrainingEmployees]', 'U'))
ALTER TABLE [dbo].[SS_Application_TrainingEmployees] ADD CONSTRAINT [FK_SS_Application_TrainingEmployees$ApplicationID_ref_SS_Applications] FOREIGN KEY ([ApplicationID]) REFERENCES [dbo].[SS_Applications] ([ID])
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_SS_Application_TrainingEmployees$TraineeContactID_ref_AC_Contacts]', 'F') AND parent_object_id = OBJECT_ID(N'[dbo].[SS_Application_TrainingEmployees]', 'U'))
ALTER TABLE [dbo].[SS_Application_TrainingEmployees] ADD CONSTRAINT [FK_SS_Application_TrainingEmployees$TraineeContactID_ref_AC_Contacts] FOREIGN KEY ([TraineeContactID]) REFERENCES [dbo].[AC_Contacts] ([ContactID])
GO
IF @@ERROR<>0 AND @@TRANCOUNT>0 ROLLBACK TRANSACTION
GO
IF @@TRANCOUNT=0 BEGIN INSERT INTO #tmpErrors (Error) SELECT 1 BEGIN TRANSACTION END
GO
PRINT N'Adding foreign keys to [dbo].[XU_UserGroup_Occurences]'
GO
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_XU_UserGroup_Occurences_XU$GroupID_ref_UserGroups]', 'F') AND parent_object_id = OBJECT_ID(N'[dbo].[XU_UserGroup_Occurences]', 'U'))
ALTER TABLE [dbo].[XU_UserGroup_Occurences] ADD CONSTRAINT [FK_XU_UserGroup_Occurences_XU$GroupID_ref_UserGroups] FOREIGN KEY ([GroupID]) REFERENCES [dbo].[XU_UserGroups] ([ID])
IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE object_id = OBJECT_ID(N'[dbo].[FK_XU_UserGroup_Occurences$CreatedBy_ref_AC_Contacts]', 'F') AND parent_object_id = OBJECT_ID(N'[dbo].[XU_UserGroup_Occurences]', 'U'))
ALTER TABLE [dbo].[XU_UserGroup_Occurences] ADD CONSTRAINT [FK_XU_UserGroup_Occurences$CreatedBy_ref_AC_Contacts] FOREIGN KEY ([CreatedBy]) REFERENCES [dbo].[AC_Contacts] ([ContactID])
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
-------------------------- Core Script -----------------------------
SET NUMERIC_ROUNDABORT OFF
GO
SET ANSI_PADDING, ANSI_WARNINGS, CONCAT_NULL_YIELDS_NULL, ARITHABORT, QUOTED_IDENTIFIER, ANSI_NULLS, NOCOUNT ON
GO
SET DATEFORMAT YMD
GO
SET XACT_ABORT ON
GO
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
GO
BEGIN TRANSACTION
-- Pointer used for text / image updates. This might not be needed, but is declared here just in case
IF NOT EXISTS (select 1 from [SS_ApplicationTypes]  where [ID] = 30)
BEGIN
	INSERT INTO [dbo].[SS_ApplicationTypes] ([ID], [Descr], [ApprovalWorkFlowID], [EmailSubjectTemplateID], [EmailBodyTemplateID], [SenderEmailAccountID], [ApplicationCardUIViewID], [SendRegularApprovalEmail], [SendAutoApprovalEmail], [SendCompletionEmail], [LockTypeId], [LockDays], [ActivateApplicationTypes], [AppManualForwardToHR], [EmailEmpOnModByOther], [EmailEmpOnModByOtherSubjTemplateID], [EmailEmpOnModByOtherBodyTemplateID], [CompletionEmailSubjTemplateID], [CompletionEmailBodyTemplateID], [ApproveNotNeedSubjTemplateID], [ApproveNotNeedBodyTemplateID], [AutoApproveSubjTemplateID], [AutoApproveBodyTemplateID], [SendApproveNotNeededEmail], [Hidden], [SendEmailToApproverOnCompletion], [HasAttachments], [ApplicationMessageLabel], [MaxApprovedAppsAnnually], [BlockSync], [UseApplicationForCancel]) VALUES (30, N'Αίτηση για Εκπαίδευση (Generic)', 1, 1, 2, 1, 10022, 0, 0, 0, -1, NULL, 1, NULL, 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 0, 0, NULL, 0, NULL, NULL, 1, 0)
END
GO
IF NOT EXISTS (select 1 from [X_Request]  where [ID] = 100377)
BEGIN
	INSERT INTO [dbo].[X_Request] ([ID], [UIControl], [Entity], [RequestStyle], [Params], [Edition], [Descr], [CardNameFieldCD]) VALUES (100377, N'ucSSApplication', N'SS_Applications', N'UnBound', N'atype=29', 1, N'lbFamilyStatusApplication', N'SS_Applications.ID')
END
GO
IF NOT EXISTS (select 1 from [X_Request]  where [ID] = 100379)
BEGIN
	INSERT INTO [dbo].[X_Request] ([ID], [UIControl], [Entity], [RequestStyle], [Params], [Edition], [Descr], [CardNameFieldCD]) VALUES (100379, N'ucSSApplication', N'SS_Applications', N'UnBound', N'atype=30', 1, N'lbTrainingEmployees', N'SS_Applications.ID')
END
GO
IF NOT EXISTS (select 1 from [X_Request]  where [ID] = 100380)
BEGIN
	INSERT INTO [dbo].[X_Request] ([ID], [UIControl], [Entity], [RequestStyle], [Params], [Edition], [Descr], [CardNameFieldCD]) VALUES (100380, N'ucOccurrences', NULL, N'UnBound', N'', 1, N'lbOccurrences', NULL)
END
GO
IF NOT EXISTS (select 1 from [X_TablesForDynamicTranslation]  where [ID] = 78)
BEGIN
	INSERT INTO [dbo].[X_TablesForDynamicTranslation] ([ID], [TABLE_NAME], [Descr], [ColumnName]) VALUES (78, N'L_MaritalStatus', N'Marital Status', NULL)
END
GO
IF NOT EXISTS (select 1 from [L_MaritalStatus]  where [ID] = 5)
BEGIN
	INSERT INTO [dbo].[L_MaritalStatus] ([ID], [Descr], [OrderFld]) VALUES (5, N'Σύμφωνο Συμβίωσης', 6)
END
GO
IF NOT EXISTS (select 1 from [XU_UserScenarios]  where [ID] = 18)
BEGIN
	INSERT INTO [dbo].[XU_UserScenarios] ([ID], [Descr]) VALUES (18, N'Submit Occurences')
END
GO
IF NOT EXISTS (select 1 from [X_UIControls]  where [ID] = 156)
BEGIN
	INSERT INTO [dbo].[X_UIControls] ([ID], [Cd], [Descr]) VALUES (156, N'ucOccurrences', N'Occurrences')
END
GO
UPDATE [dbo].[XP_Roles] SET [Cd]=N'rl_EmployeeInfoSubmitter', [Dscr]=N'Employee Info Submitter' WHERE [Id]=1012
PRINT 'Core Scripts Update'
COMMIT TRANSACTION
GO
-------------------------- Custom Script ---------------------------
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbIsEmployeeDependent' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbIsEmployeeDependent', 1, N'Βαρύνει τον εργαζόμενο',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbIsEmployeeDependent' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbIsEmployeeDependent', 2, N'Is employee dependent',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbIncreasesTaxDeductible' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbIncreasesTaxDeductible', 1, N'Αυξάνει το αφορολόγητο του εργαζόμενου',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbIncreasesTaxDeductible' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbIncreasesTaxDeductible', 2, N'Increases tax deductible',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbRowStatus' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbRowStatus', 1, N'Κατάσταση Εγγραφής',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbRowStatus' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbRowStatus', 2, N'Row Status',2)
END
GO


IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbFamilyStatusApplication' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbFamilyStatusApplication', 1, N'Αίτηση Οικογενειακής Κατάστασης',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbFamilyStatusApplication' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbFamilyStatusApplication', 2, N'Application for Family Status',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbChildForm' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbChildForm', 1, N'Στοιχεία τέκνων',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbChildForm' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbChildForm', 2, N'Children information',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbExistingRowNoChanges' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbExistingRowNoChanges', 1, N'Χωρίς Αλλαγές',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbExistingRowNoChanges' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbExistingRowNoChanges', 2, N'Existing Row, No Changes',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbExistingRowChangesRequested' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbExistingRowChangesRequested', 1, N'Αιτούμενες αλλαγές',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbExistingRowChangesRequested' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbExistingRowChangesRequested', 2, N'Existing Row, Changes Requested',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbNewRow' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbNewRow', 1, N'Νέα εγγραφή',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbNewRow' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbNewRow', 2, N'New Row',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbRequiredChildName' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbRequiredChildName', 1, N'To πεδίο Όνομα είναι υποχρεωτικό. Εφόσον δεν έχει γίνει ακόμα ονοματοδοσία, θα πρέπει να καταχωρηθεί ως «ΑΒΑΠΤΙΣΤΟ»',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbRequiredChildName' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbRequiredChildName', 2, N'Child name filed is mandatory. Please submit «Newborn» if no name is given yet.',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbAnnIsGlobal' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbAnnIsGlobal', 1, N'Ορατό σε όλους',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbAnnIsGlobal' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbAnnIsGlobal', 2, N'Visible to all',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbAnnIsGlobalEdit' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbAnnIsGlobalEdit', 1, N'Ορατό σε όλους',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbAnnIsGlobalEdit' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbAnnIsGlobalEdit', 2, N'Visible to all',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrences_Confirm' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrences_Confirm', 1, N'Πρόκειται να διαγράψετε μία ή περισσότερες εγγραφές',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrences_Confirm' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrences_Confirm', 2, N'You are about to delete one or more records',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesFrom' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesFrom', 1, N'Από',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesFrom' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesFrom', 2, N'From',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesTill' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesTill', 1, N'Έως',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesTill' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesTill', 2, N'Till',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesCarPlate' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesCarPlate', 1, N'Πινακίδα',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesCarPlate' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesCarPlate', 2, N'Plate',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesCarColor' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesCarColor', 1, N'Χρώμα',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesCarColor' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesCarColor', 2, N'Color',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesCarModel' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesCarModel', 1, N'Μοντέλο',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesCarModel' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesCarModel', 2, N'Model',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesCarComments' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesCarComments', 1, N'Σχόλια',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesCarComments' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesCarComments', 2, N'Comments',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesEmployees' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesEmployees', 1, N'Εργαζόμενοι',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesEmployees' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesEmployees', 2, N'Employees',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesApplyFilter' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesApplyFilter', 1, N'Εφαρμογή',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesApplyFilter' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesApplyFilter', 2, N'Apply',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesTabTableTitle' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesTabTableTitle', 1, N'Συμβάντα',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesTabTableTitle' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesTabTableTitle', 2, N'Occurrences',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesOpenAddModal' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesOpenAddModal', 1, N'Προσθήκη',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesOpenAddModal' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesOpenAddModal', 2, N'Add',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesOpenEditModal' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesOpenEditModal', 1, N'Επεξεργασία',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesOpenEditModal' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesOpenEditModal', 2, N'Edit',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesOpenDeleteModal' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesOpenDeleteModal', 1, N'Διαγραφή',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesOpenDeleteModal' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesOpenDeleteModal', 2, N'Delete',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesGroup' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesGroup', 1, N'Πύλη',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesGroup' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesGroup', 2, N'Gate',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesDate' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesDate', 1, N'Ημερομηνία',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesDate' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesDate', 2, N'Date',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbExcludedDayExists' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbExcludedDayExists', 1, N'Δεν μπορείτε να προχωρήσετε στην εκτύπωση γιατί υπάρχουν κλειδωμένες ημερομηνίες',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbExcludedDayExists' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbExcludedDayExists', 2, N'You are not permitted to print because the schedule includes locked days',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbAssignShiftsBasicPrintTitle' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbAssignShiftsBasicPrintTitle', 1, N'Εκτύπωση',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbAssignShiftsBasicPrintTitle' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbAssignShiftsBasicPrintTitle', 2, N'Print',2)
END
GO


IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'Hidden_lbFinalizedDaysExist_2' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('Hidden_lbFinalizedDaysExist_2', 1, N'Προσοχή! Σε περίπτωση που δεν υπάρχει ανάθεση για μία ημέρα, αυτή θα οριστικοποιηθεί ως κενή πληροφορία.',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'Hidden_lbFinalizedDaysExist_2' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('Hidden_lbFinalizedDaysExist_2', 2, N'Warning! In case of an empty cell, this will be finalized too',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'Hidden_lbFinalizedDaysExist_3' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('Hidden_lbFinalizedDaysExist_3', 1, N'Προσοχή! Οι αλλαγές που δεν έχουν αποθηκευτεί, θα χαθούν και δεν θα οριστικοποιηθούν.',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'Hidden_lbFinalizedDaysExist_3' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('Hidden_lbFinalizedDaysExist_3', 2, N'Warning! Unsaved changes will be lost and will not be finalized.',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrences' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrences', 1, N'Καταχώρηση Συμβάντων',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrences' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrences', 2, N'Occurrences',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesGridID' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesGridID', 1, N'ID',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesGridID' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesGridID', 2, N'ID',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesGridCreateDate' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesGridCreateDate', 1, N'Ημερομηνία',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesGridCreateDate' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesGridCreateDate', 2, N'Date',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesGridGroupName' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesGridGroupName', 1, N'Πύλη',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesGridGroupName' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesGridGroupName', 2, N'Gate',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesGridCarPlate' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesGridCarPlate', 1, N'Πινακίδα',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesGridCarPlate' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesGridCarPlate', 2, N'Plate',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesGridCarModel' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesGridCarModel', 1, N'Μοντέλο',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesGridCarModel' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesGridCarModel', 2, N'Model',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesGridCarColor' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesGridCarColor', 1, N'Χρώμα',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesGridCarColor' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesGridCarColor', 2, N'Color',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesGridDescr' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesGridDescr', 1, N'Σχόλια',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesGridDescr' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesGridDescr', 2, N'Comments',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesGridCreatedBy' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesGridCreatedBy', 1, N'Φύλακας',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbOccurrencesGridCreatedBy' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbOccurrencesGridCreatedBy', 2, N'Guard',2)
END
GO


IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbApplicationCost' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbApplicationCost', 1, N'Κέντρο Κόστους',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbApplicationCost' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbApplicationCost', 2, N'Cost center',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbApplicationProject' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbApplicationProject', 1, N'Αριθμός Έργου',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbApplicationProject' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbApplicationProject', 2, N'Project Number',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbApplicationDestination' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbApplicationDestination', 1, N'Προορισμός',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbApplicationDestination' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbApplicationDestination', 2, N'Destination',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbFullNameOfTrainee' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbFullNameOfTrainee', 1, N'Ονοματεπώνυμο Εκπαιδευομένου',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbFullNameOfTrainee' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbFullNameOfTrainee', 2, N'Trainee Full name',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbTrainingEducation' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbTrainingEducation', 1, N'Αντικείμενο Εκπαίδευσης',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbTrainingEducation' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbTrainingEducation', 2, N'Training Education',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbTrainingDuration' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbTrainingDuration', 1, N'Διάρκεια Εκπαίδευσης (Ώρες)',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbTrainingDuration' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbTrainingDuration', 2, N'Training Duration (Hours)',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbDateOfEducation' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbDateOfEducation', 1, N'Ημερομηνία Υλοποίησης Εκπαίδευσης',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbDateOfEducation' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbDateOfEducation', 2, N'Date of Education',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbTrainingLocation' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbTrainingLocation', 1, N'Τόπος Διεξαγωγής',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbTrainingLocation' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbTrainingLocation', 2, N'Training Location',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbRecordUpdated' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbRecordUpdated', 1, N'Η εγγραφή ενημερώθηκε επιτυχώς',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbRecordUpdated' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbRecordUpdated', 2, N'Record updated successfully',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbTrainingEmployeeModalTitle' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbTrainingEmployeeModalTitle', 1, N'Εκπαίδευση υπαλλήλων',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbTrainingEmployeeModalTitle' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbTrainingEmployeeModalTitle', 2, N'Training Employee',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbAdministrationDepartment' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbAdministrationDepartment', 1, N'Διεύθυνση - Τμήμα',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbAdministrationDepartment' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbAdministrationDepartment', 2, N'Administration - Department',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbEmployeeFullName' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbEmployeeFullName', 1, N'Ονοματεπώνυμο Εργαζομένου',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbEmployeeFullName' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbEmployeeFullName', 2, N'Employee Full name',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbTrainingDurationHours' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbTrainingDurationHours', 1, N'Διάρκεια Εκπαίδευσης (Ώρες)',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbTrainingDurationHours' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbTrainingDurationHours', 2, N'Training Duration (Hours)',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbTrainingEmployees' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbTrainingEmployees', 1, N'Αίτηση για Εκπαίδευση',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbTrainingEmployees' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbTrainingEmployees', 2, N'Request for Training',2)
END
GO

------Menu
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'X_Menu.FamilyStatus' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('X_Menu.FamilyStatus', 1, N'Αίτηση Οικογενειακής Κατάστασης',1)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'X_Menu.FamilyStatus' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('X_Menu.FamilyStatus', 2, N'Application for Family Status',1)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'X_Menu.Occurrences' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('X_Menu.Occurrences', 1, N'Καταχώρηση Συμβάντων',1)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'X_Menu.Occurrences' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('X_Menu.Occurrences', 2, N'Occurrences',1)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'X_Menu.TrainingEmployees' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('X_Menu.TrainingEmployees', 1, N'Αίτηση για Εκπαίδευση',1)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'X_Menu.TrainingEmployees' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('X_Menu.TrainingEmployees', 2, N'Request for Training',1)
END
GO

UPDATE X_StaticTranslations_FactoryDefaults set TranslatedText = 'Use applicant''s node' WHERE CD = 'lbUseEmployeeDepartmentForDeputyManager' AND [Language] = 2
GO

UPDATE X_StaticTranslations_FactoryDefaults set TranslatedText = 'Δεν μπορείτε να εκτυπώσετε πρόγραμμα εργασίας γιατί υπάρχουν μη οριστικοποιημένες ημέρες. Θέλετε να οριστικοποιηθούν με την υπάρχουσα ανάθεση;' WHERE CD = 'Hidden_lbFinalizedDaysExist' AND [Language] = 1
GO
UPDATE X_StaticTranslations_FactoryDefaults set TranslatedText = 'You can''t print the schedule because there are unfinalized days. Do you want to finalize them with the existing assignment?' WHERE CD = 'Hidden_lbFinalizedDaysExist' AND [Language] = 2
GO


------L_Object
IF NOT EXISTS (select 1 from L_Object_FactoryDefaults where TABLE_NAME = 'SS_ApplicationTypes' AND ID_TABLE = 29 AND ID_LANGUAGES = 1 )
BEGIN
INSERT INTO L_Object_FactoryDefaults  ([ID_TABLE], [ID_LANGUAGES], [DATA_TYPE], [VALUE], [TABLE_NAME]) VALUES (29,1,'TEXT', 'Αίτηση Οικογενειακής Κατάστασης', 'SS_ApplicationTypes')
END
GO
IF NOT EXISTS (select 1 from L_Object_FactoryDefaults where TABLE_NAME = 'SS_ApplicationTypes' AND ID_TABLE = 29 AND ID_LANGUAGES = 2 )
BEGIN
INSERT INTO L_Object_FactoryDefaults  ([ID_TABLE], [ID_LANGUAGES], [DATA_TYPE], [VALUE], [TABLE_NAME]) VALUES (29,2,'TEXT', 'Application for Family Status', 'SS_ApplicationTypes')
END
GO

IF NOT EXISTS (select 1 from L_Object_FactoryDefaults where TABLE_NAME = 'SS_ApplicationTypes' AND ID_TABLE = 30 AND ID_LANGUAGES = 1 )
BEGIN
INSERT INTO L_Object_FactoryDefaults  ([ID_TABLE], [ID_LANGUAGES], [DATA_TYPE], [VALUE], [TABLE_NAME]) VALUES (30,1,'TEXT', 'Αίτηση για Εκπαίδευση', 'SS_ApplicationTypes')
END
GO
IF NOT EXISTS (select 1 from L_Object_FactoryDefaults where TABLE_NAME = 'SS_ApplicationTypes' AND ID_TABLE = 30 AND ID_LANGUAGES = 2 )
BEGIN
INSERT INTO L_Object_FactoryDefaults  ([ID_TABLE], [ID_LANGUAGES], [DATA_TYPE], [VALUE], [TABLE_NAME]) VALUES (30,2,'TEXT', 'Request for Training', 'SS_ApplicationTypes')
END
GO

PRINT('------------ Summary ------------')
GO
UPDATE st
SET st.TranslatedText = fd.TranslatedText
FROM X_StaticTranslations_FactoryDefaults fd
LEFT JOIN X_StaticTranslations st on fd.Cd = st.Cd and fd.[Language] = st.LanguageID
WHERE fd.TranslatedText <> st.TranslatedText and isnull(st.NoUpdate,0) = 0;
GO
INSERT INTO X_StaticTranslations (Cd, LanguageID, Category, TranslatedText)
SELECT fd.Cd, fd.Language, fd.Category,fd.TranslatedText
FROM X_StaticTranslations_FactoryDefaults fd
LEFT JOIN X_StaticTranslations st on fd.Cd = st.Cd and fd.[Language] = st.LanguageID
WHERE st.Cd is null;
GO
UPDATE o
SET o.VALUE = fd.VALUE
FROM L_Object_FactoryDefaults fd
LEFT JOIN L_Object o on o.ID_TABLE =fd.ID_TABLE and o.ID_LANGUAGES = fd.ID_LANGUAGES and o.TABLE_NAME = fd.TABLE_NAME
WHERE o.VALUE <> fd.VALUE and isnull(o.NO_UPDATE,0) = 0;
GO
INSERT INTO L_Object (ID_TABLE, ID_LANGUAGES, DATA_TYPE,VALUE,TABLE_NAME)
SELECT fd.ID_TABLE, fd.ID_LANGUAGES, fd.DATA_TYPE, fd.VALUE, fd.TABLE_NAME
FROM L_Object_FactoryDefaults fd
LEFT JOIN L_Object l on l.ID_TABLE = fd.ID_TABLE and l.ID_LANGUAGES = fd.ID_LANGUAGES and l.TABLE_NAME = fd.TABLE_NAME
WHERE l.ID_TABLE is null AND l.VALUE is null;
GO
PRINT 'Custom Script Completed'
---------------------------------------------X_App -----------------------------------------
GO
UPDATE X_App SET VERSION = '18.2.3.0'
PRINT 'Update X_App Scripts finished 18.2.3.0 Version'
