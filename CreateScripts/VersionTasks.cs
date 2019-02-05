using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using System.Text;
using System.Xml;


namespace CreateScripts
{
    class VersionTasks
    {
        string connstring = new DataBaseActions().returnConnectionString();

        public VersionTasks()
        {
            this.connectionStringFileCheck();
            this.showConnectionStrings();
        }


        private bool showConnectionStrings()
        {
            bool hasConnectionStrings = false;
            string conFilePath = Path.Combine(Directory.GetCurrentDirectory(), string.Format("connectionString.xml"));
            XmlDocument doc = new XmlDocument();
            doc.Load(conFilePath);

            if (doc.DocumentElement.ChildNodes.Count > 0)
            {
                hasConnectionStrings = true;
                int index = 1;
                Console.WriteLine("=============== Existing Connection Strings ===============");
                foreach (XmlNode node in doc.DocumentElement.ChildNodes)
                {
                    Console.WriteLine($"{index++}: {node.InnerText}");
                }
            }
            else
            {
                Console.WriteLine("No connection string where found");
            }
            return hasConnectionStrings;
        }

        private string getConnectionString(int index)
        {
            string conString = string.Empty;
            string conFilePath = Path.Combine(Directory.GetCurrentDirectory(), string.Format("connectionString.xml"));
            XmlDocument doc = new XmlDocument();
            doc.Load(conFilePath);

            if (doc.DocumentElement.ChildNodes.Count > 0)
                conString = doc.DocumentElement.ChildNodes[index - 1].InnerText;
            //this.connectionString = conString;

            return string.Empty; //this.connectionString;
        }



        /// <summary>
        /// Check if Connection String File exist else Create 
        /// </summary>
        private void connectionStringFileCheck()
        {
            string conFilePath = Path.Combine(Directory.GetCurrentDirectory(), string.Format("connectionString.xml"));
            if (!File.Exists(conFilePath))
            {
                File.WriteAllText(conFilePath, "<?xml version=\"1.0\" encoding=\"UTF - 8\"?>", new UTF8Encoding(false));
                Console.WriteLine($"File {string.Format("connectionString.xml")}.spl has been created and initialized");
            }
        }

        private void RunVersionScript()
        {
            Console.WriteLine("=============== Run Version Script ===============");
            Console.WriteLine(" Press 1 to Run Script to a local Database ");
            Console.WriteLine(" Press 2 to essDB Actions ");
            Console.WriteLine(" Press 3 to ess_r Actions");
            Console.WriteLine(" Press 0 to Go Back");
            ConsoleKeyInfo keyOption = Console.ReadKey();
            Console.WriteLine("");
            int number;
            bool result = Int32.TryParse(keyOption.KeyChar.ToString(), out number);
            if (result)
                Console.WriteLine("Under Construction");
            //swicthCaseVersionScript(number);
            else
            {
                Console.WriteLine("Wrong input !!!!");
                RunVersionScript();
            }

        }

        private void RunDatabaseTasks()
        {
            Console.WriteLine("=============== Run Version Script ===============");
            Console.WriteLine(" Press 1 to Restore local Db ");
            Console.WriteLine(" Press 2 to BackUp local Db ");
            Console.WriteLine(" Press 3 run Version Script to local Db");
            Console.WriteLine(" Press 0 to Go Back");
        }
    }


   
}
