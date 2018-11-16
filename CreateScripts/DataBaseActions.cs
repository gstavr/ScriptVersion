using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Text;

namespace CreateScripts
{
    class DataBaseActions
    {
        private string connectionString = string.Empty;
        public DataBaseActions()
        {
            this.DatabaseActionsMessage();
        }

        public void DatabaseActionsMessage()
        {
            Console.WriteLine("=============== DataBase Actions ===============");
            Console.WriteLine(" Press 1 to Go Back ");
            Console.WriteLine(" Press 2 to BackUp Database ");
            Console.WriteLine(" Press 3 for Restore Database");
            Console.WriteLine(" Press 4 Build Connection String");
            Console.WriteLine(" Press 0 key to exit Application");
            ConsoleKeyInfo keyOption = Console.ReadKey();
            Console.WriteLine();
            int number;
            bool result = Int32.TryParse(keyOption.KeyChar.ToString(), out number);

            if (result && (number > 0 || number < 4))
            {
                switch (number)
                {
                    case 1:
                        Program.getWindowApplicationListSelection();
                        break;
                    case 2:
                        this.DataBases(connectionString);
                        this.BackUpDataBase();
                        break;
                    case 3:
                        //this.restoreDb();
                        break;
                    case 4:
                        buildConnectionString();
                        DatabaseActionsMessage();
                        break;
                    case 0:
                        Environment.Exit(-1);
                        break;
                }
            }
        }


        private void BackUpDataBase()
        {
            Console.WriteLine("Please pick a DataBase");
            ConsoleKeyInfo keyOption = Console.ReadKey();
            Console.WriteLine();
            int number;
            bool result = Int32.TryParse(keyOption.KeyChar.ToString(), out number);

            if (result)
            {


                string t = @"BACKUP DATABASE [ess_bk] TO  DISK = N'C:\newBk.bak' WITH NOFORMAT, INIT,  NAME = N'ess_bk-Full Database Backup', SKIP, NOREWIND, NOUNLOAD,  STATS = 10
                GO
                declare @backupSetId as int
                select @backupSetId = position from msdb..backupset where database_name=N'ess_bk' and backup_set_id=(select max(backup_set_id) from msdb..backupset where database_name=N'ess_bk' )
                if @backupSetId is null begin raiserror(N'Verify failed. Backup information for database ''ess_bk'' not found.', 16, 1) end
                RESTORE VERIFYONLY FROM  DISK = N'C:\newBk.bak' WITH  FILE = @backupSetId,  NOUNLOAD,  NOREWIND
                GO";
            }
        }

        #region DataBases Functions
        private DataTable DataBases(string conString)
        {
            DataTable dataBases = new DataTable();
            if (string.IsNullOrWhiteSpace(conString))
            {
                conString = buildConnectionString();
            }

            if (!string.IsNullOrWhiteSpace(conString))
            {
                dataBases = GetDataBases(conString);
                if (dataBases.Rows.Count > 0)
                    showDataBasesInServer(dataBases);
                else
                {
                    Console.WriteLine("No Databases where found in Server");
                    Program.getWindowApplicationListSelection();
                }
            }
            else
            {
                Console.WriteLine("Connection String is Empty please retry");
                DatabaseActionsMessage();
            }

            return dataBases;
        }


        private void showDataBasesInServer(DataTable dataBases)
        {
            if(dataBases.Rows.Count > 0)
            {
                Console.WriteLine($"DataBases");
                int count = 1;
                foreach(DataRow row in dataBases.Rows)
                {
                    Console.WriteLine($"{count++} : {row["DATABASE_NAME"]}");
                }
            }
        }

        #endregion

        /// <summary>
        /// Build Connection String
        /// </summary>
        /// <returns></returns>
        private string buildConnectionString()
        {
            DataTable dataBases = new DataTable();
            Console.WriteLine("=============== DataBase Actions .2===============");
            Console.WriteLine(" Build Connection String.......");
            Console.WriteLine(" Provide 'Server name' (e.g  DEV2\\EPSILON8");
            Console.WriteLine(" or Press enter to go Back ");
            string server = checkConnectionStringParameters(Console.ReadLine());
            Console.WriteLine(" Press 1 if 'Sql Server Authentication' ");
            Console.WriteLine(" Press 2 if 'Window Authentication' ");
            Console.WriteLine(" Press 3 if 'Default values :D' ");
            ConsoleKeyInfo keyOption = Console.ReadKey();
            Console.WriteLine();
            int number;
            bool isWindowsAuthentication = true;    
            bool result = Int32.TryParse(keyOption.KeyChar.ToString(), out number);
            if (result)
            {
                string catalog = string.Empty;
                string userId = string.Empty;
                string password = string.Empty;

                switch (number)
                {
                    case 1:
                        isWindowsAuthentication = false;
                        Console.WriteLine(" Provide User Id or Press enter to go Back");
                        userId = checkConnectionStringParameters(Console.ReadLine());
                        Console.WriteLine();
                        Console.WriteLine(" Provide Password or Press enter to go Back");
                        password = checkConnectionStringParameters(Console.ReadLine());
                        break;
                    case 2:
                        break;
                    case 3:
                        server = "DEV-STAVROU\\SQLEXPRESS";
                        //catalog = "ess_bak";
                        break;
                }

                connectionString = createConnectionString(server, userId, password, isWindowsAuthentication);
            }


            return connectionString;
        }

        private string checkConnectionStringParameters(string parameters)
        {
            if (string.IsNullOrWhiteSpace(parameters))
                this.DatabaseActionsMessage();

            return parameters;
        }

        private string createConnectionString(string server, string userId, string password , bool isWindowsAuthentication)
        {
            string windowsAuthenticationString = string.Format("Integrated Security=True;MultipleActiveResultSets=true");
            string nowindowsAuthenticationString = string.Format("User Id = {0}; Password = {1};", userId, password);
            //  string.Format("Data Source={0}; Initial Catalog = {1}; {2}", server, catalog, isWindowsAuthentication ? windowsAuthenticationString : nowindowsAuthenticationString);
            return string.Format("Data Source={0}; {1}", server,  isWindowsAuthentication ? windowsAuthenticationString : nowindowsAuthenticationString);
        }


        private DataTable GetDataBases(string connString)
        {
            DataTable dt = new DataTable();
            using (SqlConnection con = new SqlConnection(connString))
            {   
                con.Open();
                SqlCommand cmd = new SqlCommand();
                cmd.Connection = con;
                cmd.CommandText = $"EXEC sys.sp_databases";
                SqlDataReader reader = cmd.ExecuteReader();
                dt.Load(reader);
                con.Close();
            }

            return dt;
        }


        // Extra
        private bool isConnected(string server, string catalog, string userId, string password, bool isWindowsAuthentication)
        {
            string.Format("Data Source=GINOS\\SQLEXPRESS03;Initial Catalog=Odds;Integrated Security=True;MultipleActiveResultSets=true");
            string connString = string.Format("Data Source={0}; Initial Catalog = ess_dev; User Id = sa; Password = epsilonsa;", server);

            string windowsAuthenticationString = string.Format("Integrated Security=True;MultipleActiveResultSets=true");
            string nowindowsAuthenticationString = string.Format("User Id = {0}; Password = {1};", userId, password);


            server = "DEV-STAVROU\\SQLEXPRESS";
            catalog = "ess_bak";

            connString = string.Format("Data Source={0}; Initial Catalog = {1}; {2}", server, catalog, isWindowsAuthentication ? windowsAuthenticationString : nowindowsAuthenticationString);

            return true;
        }

        // DataBase Connections
        private static DataTable CheckCdsToDataBase(List<string> Cds, string filePath)
        {
            DataTable dt = new DataTable();
            using (SqlConnection con = new SqlConnection("Data Source=dev2\\epsilon8; Initial Catalog = ess_dev; User Id = sa; Password = epsilonsa;"))
            {
                con.ConnectionString = "Data Source=dev2\\epsilon8; Initial Catalog = ess_dev; User Id = sa; Password = epsilonsa;";
                con.Open();
                SqlCommand cmd = new SqlCommand();
                cmd.Connection = con;
                string test = string.Format("'{0}'", string.Join(",", Cds.ToArray()).Replace(",", "','"));
                cmd.CommandText = $"SELECT cd FROM X_StaticTranslations_FactoryDefaults WHERE Cd in({test}) GROUP by cd";
                SqlDataReader reader = cmd.ExecuteReader();
                dt.Load(reader);
                con.Close();
            }

            return dt;
        }



    }
}
