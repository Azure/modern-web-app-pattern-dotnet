using Azure.LoadTest.Tool.Models.CommandOptions;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.FileProviders.Physical;

namespace Azure.LoadTest.Tool.Operators
{
    public class AzdOperator
    {
        private readonly IConfiguration _configuration;

        public AzdOperator(AzureLoadTestToolOptions options)
        {
            if (string.IsNullOrEmpty(options.EnvironmentName))
            {
                throw new ArgumentNullException(nameof(options.EnvironmentName));
            }

            var pathToConfigDirectory = GetPathToAzdConfigFile(options.EnvironmentName);

            // by default ini configuration provider does not read files with the extension ".env"
            // so this behavior is overridden
            var dotnetConfigurationProvider = new PhysicalFileProvider(pathToConfigDirectory, ExclusionFilters.None);

            _configuration = new ConfigurationBuilder()
                .AddIniFile(provider: dotnetConfigurationProvider, path: ".env", optional: false, reloadOnChange: false)
                .Build();
        }


        /// AZD uses a special directory to store configuration files
        /// the well-known name for this directory is the ".azure" directory
        /// in this folder variables are stored in folders named by environment
        private string GetPathToAzdConfigFile(string environmentName)
        {
            var azdDirectory = GetAzdDirectory(new DirectoryInfo(Directory.GetCurrentDirectory()));

            return Path.Combine(azdDirectory.FullName, environmentName);

            /// this operation will recurse upward and locate our azure directory
            DirectoryInfo GetAzdDirectory(DirectoryInfo workingDirectory)
            {
                const string AZD_DIRECTORY = ".azure";

                var azureDirectory = workingDirectory.GetDirectories().FirstOrDefault(directory => AZD_DIRECTORY.Equals(directory.Name, StringComparison.Ordinal));

                if (azureDirectory != null)
                {
                    return azureDirectory;
                }

                if (workingDirectory.Parent is null)
                {
                    throw new InvalidOperationException("Could not find AZD environment");
                }

                return GetAzdDirectory(workingDirectory.Parent);
            }
        }

        public string GetResourceGroupName()
        {
            const string AZURE_RESOURCE_GROUP = "AZURE_RESOURCE_GROUP";
            return _configuration.GetValue<string>(AZURE_RESOURCE_GROUP) ?? throw new InvalidOperationException($"Missing required configuration {AZURE_RESOURCE_GROUP}");
        }

        internal string GetSubscriptionId()
        {
            const string SUBSCRIPTION_ID = "SUBSCRIPTION_ID";
            return _configuration.GetValue<string>(SUBSCRIPTION_ID) ?? throw new InvalidOperationException($"Missing required configuration {SUBSCRIPTION_ID}");
        }

        internal string GetAzureLoadTestServiceName()
        {
            const string AZURE_LOAD_TEST_NAME = "AZURE_LOAD_TEST_NAME";
            return _configuration.GetValue<string>(AZURE_LOAD_TEST_NAME) ?? throw new InvalidOperationException($"Missing required configuration {AZURE_LOAD_TEST_NAME}");
        }

        internal IEnumerable<string> GetAzureLoadTestAppComponentsResourceIds()
        {
            const string RESOURCE_IDS = "APP_COMPONENTS_RESOURCE_IDS";
            var resourceIds = _configuration.GetValue<string>(RESOURCE_IDS) ?? throw new InvalidOperationException($"Missing required configuration {RESOURCE_IDS}");

            return resourceIds.Split(',').AsEnumerable();
        }

        internal string GetPathToJMeterFile()
        {
            const string AZURE_LOAD_TEST_FILE = "AZURE_LOAD_TEST_FILE";
            return _configuration.GetValue<string>(AZURE_LOAD_TEST_FILE) ?? throw new InvalidOperationException($"Missing required configuration {AZURE_LOAD_TEST_FILE}");
        }

        /// <summary>
        /// When the load test runs it will use Environment variables to configure the JMX
        /// This AZD var specifies the domain that was parameterized when the JMX was created
        /// so that that load test can be reused for multiple environments
        /// </summary>
        /// <returns></returns>
        /// <exception cref="NotImplementedException"></exception>
        internal string GetEnvironmentVarDomainName()
        {
            const string AZURE_WEBSITE_DOMAIN = "AZURE_WEBSITE_DOMAIN";
            return _configuration.GetValue<string>(AZURE_WEBSITE_DOMAIN) ?? throw new InvalidOperationException($"Missing required configuration {AZURE_WEBSITE_DOMAIN}");
        }
    }
}
