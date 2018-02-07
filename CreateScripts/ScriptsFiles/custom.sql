-------------------------- Custom Script ---------------------------
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbAllowViewMessage' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbAllowViewMessage', 1, N'Δεν μπορείτε ή δεν έχετε δικαίωμα να δείτε τη φόρμα',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbAllowViewMessage' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbAllowViewMessage', 2, N'You can not view or you do not have permissions to view the form',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbConfirmEmployeesDeletion' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbConfirmEmployeesDeletion', 1, N'Προσοχή! Θα πρέπει να υπάρχει τουλάχιστον ένα άτομο στην Αξιολόγηση.',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbConfirmEmployeesDeletion' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbConfirmEmployeesDeletion', 2, N'Warning! There must be at least one person in the assessement.',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbConfirmEmployeesDeletion_2' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbConfirmEmployeesDeletion_2', 1, N'Είστε σίγουροι ότι θέλετε να διαγράψετε τους επιλεγμένους εργαζόμενους;',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbConfirmEmployeesDeletion_2' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbConfirmEmployeesDeletion_2', 2, N'Are you sure you want to delete the selected employees?',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbDeactivateParticipantsModalHeader' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbDeactivateParticipantsModalHeader', 1, N'Απενεργοποίηση συμμετεχόντων',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbDeactivateParticipantsModalHeader' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbDeactivateParticipantsModalHeader', 2, N'Deactivate participants',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbAsfmAssessmentsVisibility' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbAsfmAssessmentsVisibility', 1, N'Ορατότητα αξιολογήσεων',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbAsfmAssessmentsVisibility' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbAsfmAssessmentsVisibility', 2, N'Assessments visibility',2)
END
GO


IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbAssessmentsVisibilityModalHeader' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbAssessmentsVisibilityModalHeader', 1, N'Ορατότητα αξιολογήσεων',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbAssessmentsVisibilityModalHeader' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbAssessmentsVisibilityModalHeader', 2, N'Assessments visibility',2)
END
GO


IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbAvml_EnforceFormPrivacyAssessee' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbAvml_EnforceFormPrivacyAssessee', 1, N'Απόκρυψη Αξιολόγησης από Αξιολογούμενο',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbAvml_EnforceFormPrivacyAssessee' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbAvml_EnforceFormPrivacyAssessee', 2, N'Hide assessment from assessee',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbAvml_EnforceFormPrivacyAssesseeTill' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbAvml_EnforceFormPrivacyAssesseeTill', 1, N'Έως',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbAvml_EnforceFormPrivacyAssesseeTill' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbAvml_EnforceFormPrivacyAssesseeTill', 2, N'Until',2)
END
GO


IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbAvml_EnforceFormPrivacyAssessorTill' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbAvml_EnforceFormPrivacyAssessorTill', 1, N'Έως',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbAvml_EnforceFormPrivacyAssessorTill' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbAvml_EnforceFormPrivacyAssessorTill', 2, N'Until',2)
END
GO

IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbAvml_EnforceFormPrivacyAssessor' AND [Language] = 1)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbAvml_EnforceFormPrivacyAssessor', 1, N'Απόκρυψη Αξιολόγησης από Αξιολογητή ',2)
END
GO
IF NOT EXISTS (select 1 from X_StaticTranslations_FactoryDefaults where [Cd] = 'lbAvml_EnforceFormPrivacyAssessor' AND [Language] = 2)
BEGIN
INSERT INTO X_StaticTranslations_FactoryDefaults ([Cd], [Language], [TranslatedText], [Category]) VALUES ('lbAvml_EnforceFormPrivacyAssessor', 2, N'Hide assessment from assessor',2)
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
