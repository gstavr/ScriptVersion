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
IF NOT EXISTS (select 1 from [SS_ApplicationTypes]  where [ID] = 29)
BEGIN
	INSERT INTO [dbo].[SS_ApplicationTypes] ([ID], [Descr], [ApprovalWorkFlowID], [EmailSubjectTemplateID], [EmailBodyTemplateID], [SenderEmailAccountID], [ApplicationCardUIViewID], [SendRegularApprovalEmail], [SendAutoApprovalEmail], [SendCompletionEmail], [LockTypeId], [LockDays], [ActivateApplicationTypes], [AppManualForwardToHR], [EmailEmpOnModByOther], [EmailEmpOnModByOtherSubjTemplateID], [EmailEmpOnModByOtherBodyTemplateID], [CompletionEmailSubjTemplateID], [CompletionEmailBodyTemplateID], [ApproveNotNeedSubjTemplateID], [ApproveNotNeedBodyTemplateID], [AutoApproveSubjTemplateID], [AutoApproveBodyTemplateID], [SendApproveNotNeededEmail], [Hidden], [SendEmailToApproverOnCompletion], [HasAttachments], [ApplicationMessageLabel], [MaxApprovedAppsAnnually], [BlockSync], [UseApplicationForCancel]) VALUES (29, N'Αίτηση Οικογενειακής Κατάστασης', 1, 1, 2, 1, 10022, 1, NULL, NULL, -1, NULL, 1, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, NULL, NULL, NULL, NULL)
END
GO
IF NOT EXISTS (select 1 from [X_Request]  where [ID] = 100378)
BEGIN
	INSERT INTO [dbo].[X_Request] ([ID], [UIControl], [Entity], [RequestStyle], [Params], [Edition], [Descr], [CardNameFieldCD]) VALUES (100378, N'ucManageAdditionalRightsPerNode', NULL, N'UnBound', N'', 1, N'lbManageAdditionalRightsPerNode', NULL)
END
GO
IF NOT EXISTS (select 1 from [X_UIControls]  where [ID] = 155)
BEGIN
	INSERT INTO [dbo].[X_UIControls] ([ID], [Cd], [Descr]) VALUES (155, N'ucManageAdditionalRightsPerNode', N'ManageAdditionalRightsPerNode')
END
GO
IF NOT EXISTS (select 1 from [X_UIControl_Settings]  where [ControlID] = 24 AND [varKey] = 'LoanAppCommentsRequired' )
BEGIN
	INSERT INTO [dbo].[X_UIControl_Settings] ([ID], [ControlID], [varKey], [varValue]) VALUES (97, 24, N'LoanAppCommentsRequired', N'1')
END
GO
IF NOT EXISTS (select 1 from [X_UIControl_Settings]  where [ControlID] = 118 AND [varKey] = 'ShiftPlanShowPrintComments' )
BEGIN
	INSERT INTO [dbo].[X_UIControl_Settings] ([ID], [ControlID], [varKey], [varValue]) VALUES (98, 118, N'ShiftPlanShowPrintComments', N'1')
END
GO
IF NOT EXISTS (select 1 from [X_UIControl_Settings]  where [ControlID] = 118 AND [varKey] = 'ShiftPlanPrintComments' )
BEGIN
	INSERT INTO [dbo].[X_UIControl_Settings] ([ID], [ControlID], [varKey], [varValue]) VALUES (99, 118, N'ShiftPlanPrintComments', N'<p><strong>1st line</strong></p><hr /><p><em>2nd line</em></p><hr /><p>3 line!</p>')
END
GO
IF NOT EXISTS (select 1 from [X_UIControl_Settings]  where [ControlID] = 24 AND [varKey] = 'FamilyStatusShowEmployeeDependent' )
BEGIN
	INSERT INTO [dbo].[X_UIControl_Settings] ([ID], [ControlID], [varKey], [varValue]) VALUES (100, 24, N'FamilyStatusShowEmployeeDependent', N'0')
END
GO
IF NOT EXISTS (select 1 from [X_UIControl_Settings]  where [ControlID] = 24 AND [varKey] = 'FamilyStatusShowIncreasesTaxDeductible' )
BEGIN
	INSERT INTO [dbo].[X_UIControl_Settings] ([ID], [ControlID], [varKey], [varValue]) VALUES (101, 24, N'FamilyStatusShowIncreasesTaxDeductible', N'1')
END
GO
COMMIT TRANSACTION
GO
