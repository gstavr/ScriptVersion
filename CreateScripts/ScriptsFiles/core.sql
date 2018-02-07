﻿-------------------------- Core Script -----------------------------
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
IF NOT EXISTS (select 1 from [X_Request]  where [ID] = -10)
BEGIN
INSERT INTO [dbo].[X_Request] ([ID], [UIControl], [Entity], [RequestStyle], [Params], [Edition], [Descr], [CardNameFieldCD]) VALUES (-10, N'ucResourceApplication', NULL, N'UnBound', N'ResourceTypeID=17', 1, N'lbResourceApplication', NULL)
END
GO
IF NOT EXISTS (select 1 from [X_Request]  where [ID] = -1)
BEGIN
INSERT INTO [dbo].[X_Request] ([ID], [UIControl], [Entity], [RequestStyle], [Params], [Edition], [Descr], [CardNameFieldCD]) VALUES (-1, N'ucSSApplication', N'SS_Applications', N'UnBound', N'atype=1&ltype=0&reqMain=1&atgt=1', 1, N'lbApplicationForVacation1', N'SS_Applications.ID')
END
GO
IF NOT EXISTS (select 1 from [X_Request]  where [ID] = 10000055)
BEGIN
INSERT INTO [dbo].[X_Request] ([ID], [UIControl], [Entity], [RequestStyle], [Params], [Edition], [Descr], [CardNameFieldCD]) VALUES (10000055, N'ucInfoPage', NULL, N'UnBound', N'id=1', 1, N'infopage', NULL)
END
GO
IF NOT EXISTS (select 1 from [X_Request]  where [ID] = 10000102)
BEGIN
INSERT INTO [dbo].[X_Request] ([ID], [UIControl], [Entity], [RequestStyle], [Params], [Edition], [Descr], [CardNameFieldCD]) VALUES (10000102, NULL, NULL, N'DBCommand', N'proc=VX_QNR_ChildInfoAAA&mode=ui&Employee=##CurrentContactID##&Chld1Nm=null&Chld1Brt=null&Chld1Gendr=null&Chld2Nm=null&Chld2Brt=null&Chld2Gendr=null&Chld3Nm=null&Chld3Brt=null&Chld3Gendr=null&Chld4Nm=null&Chld4Brt=null&Chld4Gendr=null', 1, N'lbQNR_ChildInfoAAA', NULL)
END
GO
IF NOT EXISTS (select 1 from [X_TablesForDynamicTranslation]  where [ID] = 77)
BEGIN
INSERT INTO [dbo].[X_TablesForDynamicTranslation] ([ID], [TABLE_NAME], [Descr], [ColumnName]) VALUES (77, N'SS_HRM_PR_Projects', N'Projects', NULL)
END
GO
IF NOT EXISTS (select 1 from [X_UIControls]  where [ID] = 123)
BEGIN
INSERT INTO [dbo].[X_UIControls] ([ID], [Cd], [Descr]) VALUES (123, N'ucSampleControl', N'SampleControl')
END
GO
IF NOT EXISTS (select 1 from [X_UIControls]  where [ID] = 151)
BEGIN
INSERT INTO [dbo].[X_UIControls] ([ID], [Cd], [Descr]) VALUES (151, N'ucTrainingSettings', N'TrainingSettings')
END
GO
IF NOT EXISTS (select 1 from [X_UIControls]  where [ID] = 152)
BEGIN
INSERT INTO [dbo].[X_UIControls] ([ID], [Cd], [Descr]) VALUES (152, N'ucSalaryReport', N'SalaryReport')
END
GO

COMMIT TRANSACTION
GO
