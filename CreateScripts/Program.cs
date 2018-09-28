using System;
using System.IO;
using System.Linq;
using System.Text;

namespace CreateScripts
{
    class Program
    {
        //! Static Variables
        static StringBuilder schemaFile = new StringBuilder();
        static StringBuilder coreFile = new StringBuilder();
        static StringBuilder customFile = new StringBuilder();
        static StringBuilder xAppFile = new StringBuilder();
        static StringBuilder versionTag = new StringBuilder();
        static StringBuilder versionHeaderScript = new StringBuilder();
        static void Main(string[] args)
        {
            Console.WriteLine("*************************************************");
            Console.WriteLine("*          Script Creation v.1                  *");
            Console.WriteLine("*                                               *");
            Console.WriteLine("*                                               *");
            Console.WriteLine("*                                               *");
            Console.WriteLine("*                                               *");
            Console.WriteLine("*                             Created by @GStavr*");
            Console.WriteLine("*************************************************");
            getWindowApplicationListSelection();
            getCommentLine();

        }



        /// <summary>
        //! Window Application List Selection
        /// </summary>
        private static void getWindowApplicationListSelection()
        {
            Console.WriteLine(" Press 1 for Schema file name");
            Console.WriteLine(" Press 2 for Core file name");
            Console.WriteLine(" Press 3 for CustomScript file name");
            Console.WriteLine(" Press 4 for Version Tag name");
            Console.WriteLine(" Press 5 to Automate Procedure");
            Console.WriteLine(" Press any other key to exit");
            ConsoleKeyInfo keyOption = Console.ReadKey();
            Console.WriteLine("");
            int number;
            bool result = Int32.TryParse(keyOption.KeyChar.ToString(), out number);
            if (result)
                swicthCase(number);
            else
                Console.ReadKey();
        }

        /// <summary>
        /// Switch Cases
        /// </summary>
        /// <param name="caseNumber"></param>
        private static void swicthCase(int caseNumber)
        {
            switch (caseNumber)
            {
                case (int)caseSelection.InsertSchemaFile:
                    schemaFileFunction();
                    break;
                case (int)caseSelection.InsertCoreFile:
                    coreFileFunction();
                    break;
                case (int)caseSelection.InsertCustomFile:
                    customFileFunction();
                    break;
                case (int)caseSelection.InsertVersionTagName:
                    customFileFunction();
                    break;
                case (int)caseSelection.AutoateProcedure:
                    automateProcedure();
                    break;
                default:
                    Console.ReadKey();
                    break;
            }
        }

        private static void automateProcedure()
        {
            schemaFileFunction(true);
            coreFileFunction(true);
            customFileFunction(true);
            createScripts();
        }


        private static void createScripts()
        {
            
            Console.WriteLine("Provide Version Tag ex 18.1.3.0");
            string versionTag = Console.ReadLine();

            var array = versionTag.Trim().Split('.');
            string stringFileName = string.Join("", array);

            versionHeaded(versionTag);
            x_App(versionTag);
            
            StringBuilder finalScript = new StringBuilder();
            finalScript.Append(versionHeaderScript);
            finalScript.Append(schemaFile);
            finalScript.Append(coreFile);
            finalScript.Append(customFile);
            finalScript.Append(xAppFile);

            string wanted_path = Path.GetDirectoryName(Path.GetDirectoryName(Directory.GetCurrentDirectory()));
            string exportFile = Directory.GetCurrentDirectory() + $"\\ScriptsFiles\\{stringFileName}.sql";
            Console.WriteLine($"{exportFile} Created" );
            File.WriteAllText(exportFile, finalScript.ToString(), new UTF8Encoding(false));
        }


        private static void versionHeaded(string versionTag)
        {   
            versionHeaderScript = new StringBuilder();
            versionHeaderScript.AppendLine(@"/*");
            versionHeaderScript.AppendLine("You are recommended to back up your database before running this script");
            versionHeaderScript.AppendLine($"Version {versionTag} ");
            versionHeaderScript.AppendLine(string.Format("Date {0}" , DateTime.Now.ToString("dd/MM/yyyy")));
            versionHeaderScript.AppendLine(@"*/");
        }

        private static void x_App( string versionTag)
        {
            xAppFile = new StringBuilder();
            xAppFile.AppendLine("---------------------------------------------X_App -----------------------------------------");
            xAppFile.AppendLine("GO");
            xAppFile.AppendLine($"UPDATE X_App SET VERSION = '{versionTag}'");
            xAppFile.AppendLine($"PRINT 'Update X_App Scripts finished {versionTag} Version'");
        }
        /// <summary>
        /// Shema function
        /// </summary>
        private static void schemaFileFunction(bool automate = false)
        {
            //! Default Path and file Name
            string scriptsFile = getDirectoryPath("schema.txt");

            if (!automate)
            {
                Console.WriteLine("Provide Schema file name e.x schema.txt with UTF-8 Encoding , etc");
                string schemaName = Console.ReadLine();
                Console.WriteLine($"Searching for {schemaName} .......");
                scriptsFile = getDirectoryPath(schemaName);
            }

            getCommentLine();
            
            if (File.Exists(scriptsFile))
            {
                schemaFile = new StringBuilder();
                schemaFile.AppendLine($"-------------------------- Schema Script -----------------------------");

                using (StreamReader sr = File.OpenText(scriptsFile))
                {
                    string s = "";
                    while ((s = sr.ReadLine()) != null)
                        schemaFile.AppendLine(s);
                }
                
                Console.WriteLine("Schema File Created");
            }
            else
            {
                Console.WriteLine("Error! *** Schema file wasn't found!!!");
                getCommentLine(3);
                getWindowApplicationListSelection();
            }

            if (!automate)
                exportFileOption(schemaFile , fileSelectionName.schema);

        }



        private static void exportFileOption(StringBuilder file , fileSelectionName fileSelectionName)
        {
            Console.WriteLine("Press 1 to export the file separately and continue");
            Console.WriteLine("Press 2 to export the file separately and exit");
            Console.WriteLine("Press any other key to continue ");
            ConsoleKeyInfo keyOption = Console.ReadKey();
            Console.WriteLine("");
            int number;
            bool result = Int32.TryParse(keyOption.KeyChar.ToString(), out number);

            switch (number)
            {
                case 1:
                    exportFile(file, fileSelectionName);
                    getWindowApplicationListSelection();
                    break;
                case 2:
                    exportFile(file, fileSelectionName);
                    Console.ReadKey();
                    break;
                case 3:
                    getWindowApplicationListSelection();
                    break;
            }
        }


        /// <summary>
        //! Core Function
        /// </summary>
        private static void coreFileFunction(bool automate = false)
        {
            string scriptsFile = getDirectoryPath("core.txt");
            if (!automate)
            {
                Console.WriteLine("Provide Core file name e.x schema.txt , etc");
                string coreName = Console.ReadLine();
                Console.WriteLine($"Searching for {coreName} .......");
                //! Find Solution Path 
                scriptsFile = getDirectoryPath(coreName);
            }
            
            getCommentLine();
            // Find Scripts Directory
            if (File.Exists(scriptsFile))
            {
                coreFile = new StringBuilder();
                coreFile.AppendLine($"-------------------------- Core Script -----------------------------");

                using (StreamReader sr = File.OpenText(scriptsFile))
                {
                    string s = "";
                    while ((s = sr.ReadLine()) != null)
                    {
                        StringBuilder insertStatement = new StringBuilder();

                        string ifNotExists = string.Empty;
                        if (s.Contains("INSERT"))
                        {
                            //! Find Table Name
                            int startIndex = s.IndexOf('.') + 1;
                            int endIndex = s.IndexOf(']' , startIndex);
                            string tableName = s.Substring(startIndex, (endIndex - startIndex) + 1);
                            int startIndexOfColumnName = s.IndexOf('(');
                            int endIndexOfColumnName = s.IndexOf(']',startIndexOfColumnName);
                            string columnName = s.Substring(startIndexOfColumnName + 1, (endIndexOfColumnName - startIndexOfColumnName));

                            //! Find ID Value
                            int indexOfValueString = s.IndexOf("VALUES");
                            int indexOfFirstSemiCol = s.IndexOf('(', indexOfValueString) + 1;
                            int indexofFirstCommaValue = s.IndexOf(',', indexOfFirstSemiCol);
                            string idValue = s.Substring(indexOfFirstSemiCol, (indexofFirstCommaValue - indexOfFirstSemiCol));
                            
                            if (!tableName.Contains("X_UIControl_Settings") && !tableName.Contains("X_Vars"))
                                insertStatement.AppendLine($"IF NOT EXISTS (select 1 from {tableName} where {columnName} = {idValue})");
                            else
                            {   
                                //! Find ControlID
                                int controlKeyValue = s.IndexOf(",", indexofFirstCommaValue + 1);
                                string ControlID = s.Substring(indexofFirstCommaValue + 1, (controlKeyValue - indexofFirstCommaValue) - 1);
                                //! Find VarKey Value
                                int varControlIDIndex = s.IndexOf(',', controlKeyValue + 1);
                                if (tableName.Contains("X_UIControl_Settings"))
                                {
                                    string varkey = s.Substring(controlKeyValue + 1, (varControlIDIndex - controlKeyValue) - 1);
                                    insertStatement.AppendLine($"IF NOT EXISTS (select 1 from {tableName} where [ControlID] ={ControlID} AND [varKey] = {varkey} )");
                                }   
                                else
                                    insertStatement.AppendLine($"IF NOT EXISTS (select 1 from {tableName} where [varKey] = {ControlID} )");
                            }   
                            insertStatement.AppendLine("BEGIN");
                            insertStatement.AppendLine("\t"+s);
                            insertStatement.AppendLine("END");
                            insertStatement.AppendLine("GO");
                            s = insertStatement.ToString();
                        }
                        if (s.Contains("UPDATE"))
                        {   
                            insertStatement.AppendLine(s.Trim());
                            insertStatement.AppendLine("GO");
                            s = insertStatement.ToString();
                        }
                        coreFile.AppendLine(s.Trim());
                    }
                }
                coreFile.AppendLine($"PRINT 'Core Scripts Update'");
                Console.WriteLine("Core File Created");
            }
            else
            {
                Console.WriteLine("Error! *** Core file wasn't found!!!");
                getCommentLine(1);
            }

            if(!automate)
                exportFileOption(coreFile , fileSelectionName.core);
        }
        /// <summary>
        //! Custom Scripts File
        /// </summary>
        private static void customFileFunction(bool automate = false)
        {
            string scriptsFile = getDirectoryPath("custom.txt");

            if (!automate)
            {
                Console.WriteLine("Provide Custom file name e.x schema.txt , etc");
                string customName = Console.ReadLine();
                Console.WriteLine($"Searching for {customName} .......");
                //! Find Solution Path 
                scriptsFile = getDirectoryPath(customName);
            }
            getCommentLine();
            // Find Scripts Directory
            if (File.Exists(scriptsFile))
            {   
                customFile = new StringBuilder();
                customFile.AppendLine($"-------------------------- Custom Script ---------------------------");

                using (StreamReader sr = File.OpenText(scriptsFile))
                {
                    string s = "";
                    while ((s = sr.ReadLine()) != null)
                    {
                        if (s.Contains("INSERT"))
                            customFile.AppendLine("\t" + s.Trim());
                        else
                            customFile.AppendLine(s.Trim());
                    }
                }
                Console.WriteLine("Custom File Created");
            }
            else
            {
                Console.WriteLine("Error! *** Custom file wasn't found!!!");
                getCommentLine(1);
            }

            if (!automate)
                exportFileOption(customFile , fileSelectionName.custom); 
        }
        

        private static void exportFile(StringBuilder file , fileSelectionName fileName)
        {
            string wanted_path = Path.GetDirectoryName(Path.GetDirectoryName(Directory.GetCurrentDirectory()));
            string exportFile = Directory.GetCurrentDirectory() + $"\\ScriptsFiles\\{fileName.ToString()}.sql";
            File.WriteAllText(exportFile, file.ToString(), new UTF8Encoding(false));
            Console.WriteLine($"File {fileName}.spl has been created");
        }

        //! Helpers Methods
        private static void getCommentLine(int numberOfLines = 1)
        {
            for (int x = 0; x < numberOfLines; x++)
            {
                Console.WriteLine("*************************************************");
            }
        }

        //! Get File from Directory
        private static string getDirectoryPath(string fileName)
        {
            string wanted_path = Path.GetDirectoryName(Path.GetDirectoryName(Directory.GetCurrentDirectory()));
            return Directory.GetCurrentDirectory() + "\\ScriptsFiles\\" + fileName;
        }

        enum caseSelection
        {
            InsertSchemaFile = 1,
            InsertCoreFile,
            InsertCustomFile,
            InsertVersionTagName,
            AutoateProcedure
        }

        enum fileSelectionName
        {
            schema,
            core,
            custom
        }
    }
}
