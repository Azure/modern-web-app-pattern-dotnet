using Azure.LoadTest.Tool.Models.CommandOptions;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.FileProviders.Physical;

namespace Azure.LoadTest.Tool.Providers
{
    public class AzdParametersProvider
    {
        private readonly IConfiguration _configuration;

        public AzdParametersProvider(AzureLoadTestToolOptions options)
        {
            if (string.IsNullOrEmpty(options.EnvironmentName))
            {
                throw new ArgumentNullException(nameof(options.EnvironmentName));
            }

            var pathToConfigDirectory = GetPathToAzdConfigFile(options.EnvironmentName);

            // By default, ini configuration provider does not read files with the extension ".env"
            // So, this behavior is overridden.
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

            DirectoryInfo GetAzdDirectory(DirectoryInfo workingDirectory)
            {
                const string AZD_DIRECTORY = ".azure";
                var azureDirectory = workingDirectory.GetDirectories()
                    .FirstOrDefault(directory => AZD_DIRECTORY.Equals(directory.Name, StringComparison.Ordinal));

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


        /// <summary>
        /// Returns the required AZD configuration value AZURE_RESOURCE_GROUP
        /// </summary>
        /// <exception cref="InvalidOperationException">Thrown when this required configuration has not been set</exception>
        public string GetResourceGroupName()
        {
            const string AZURE_RESOURCE_GROUP = "AZURE_RESOURCE_GROUP";
            return _configuration.GetValue<string>(AZURE_RESOURCE_GROUP)
                   ?? throw new InvalidOperationException($"Missing required configuration {AZURE_RESOURCE_GROUP}");
        }

        /// <summary>
        /// Returns the required AZD configuration value AZURE_SUBSCRIPTION_ID
        /// </summary>
        /// <exception cref="InvalidOperationException">Thrown when this required configuration has not been set</exception>
        public string GetSubscriptionId()
        {
            const string AZURE_SUBSCRIPTION_ID = "AZURE_SUBSCRIPTION_ID";
            return _configuration.GetValue<string>(AZURE_SUBSCRIPTION_ID)
                ?? throw new InvalidOperationException($"Missing required configuration {AZURE_SUBSCRIPTION_ID}");
        }

        /// <summary>
        /// Returns the required AZD configuration value AZURE_LOAD_TEST_NAME
        /// </summary>
        /// <exception cref="InvalidOperationException">Thrown when this required configuration has not been set</exception>
        public string GetAzureLoadTestServiceName()
        {
            const string AZURE_LOAD_TEST_NAME = "AZURE_LOAD_TEST_NAME";
            return _configuration.GetValue<string>(AZURE_LOAD_TEST_NAME)
                ?? throw new InvalidOperationException($"Missing required configuration {AZURE_LOAD_TEST_NAME}");
        }


        /// <summary>
        /// Returns the required AZD configuration value APP_COMPONENTS_RESOURCE_IDS
        /// </summary>
        /// <exception cref="InvalidOperationException">Thrown when this required configuration has not been set</exception>
        public IEnumerable<string> GetAzureLoadTestAppComponentsResourceIds()
        {
            const string RESOURCE_IDS = "APP_COMPONENTS_RESOURCE_IDS";
            var resourceIds = _configuration.GetValue<string>(RESOURCE_IDS)
                ?? throw new InvalidOperationException($"Missing required configuration {RESOURCE_IDS}");

            return resourceIds.Split(',').AsEnumerable();
        }


        /// <summary>
        /// Returns the required AZD configuration value AZURE_LOAD_TEST_FILE
        /// </summary>
        /// <exception cref="InvalidOperationException">Thrown when this required configuration has not been set</exception>
        public string GetPathToJMeterFile()
        {
            const string AZURE_LOAD_TEST_FILE = "AZURE_LOAD_TEST_FILE";
            return _configuration.GetValue<string>(AZURE_LOAD_TEST_FILE)
                ?? throw new InvalidOperationException($"Missing required configuration {AZURE_LOAD_TEST_FILE}");
        }

        /// <summary>
        /// Parses the configuration file and returns a dictionary containing any Azure Load Test Environment parameters encoded as AZD parameters with the prefix `ALT_ENV_PARAM_`
        /// </summary>
        public Dictionary<string, string> GetLoadTestEnvironmentVars()
        {
            const string AZD_ENCODED_AZURE_LOAD_TEST_PARAM = "ALT_ENV_PARAM_";

            // future feature request: make this delimiter configurable
            const string AZD_ENCODED_PARAM_DELIMITER = ",";

            var environmentConfiguration = new Dictionary<string, string>();
            foreach (var keyValuePair in _configuration.AsEnumerable())
            {
                if (string.IsNullOrEmpty(keyValuePair.Value)
                    // when true we found a configuration in the ini file but it isn't one that relates to Azure Load Test environments
                    || !keyValuePair.Key.StartsWith(AZD_ENCODED_AZURE_LOAD_TEST_PARAM, StringComparison.Ordinal)
                    // when true we found a configuration in the ini file but it isn't one that is encoded as key/value pairs for Azure Load Test environments
                    || !keyValuePair.Value.Contains(","))
                {
                    continue;
                }

                var azureLoadTestData = keyValuePair.Value.Split(AZD_ENCODED_PARAM_DELIMITER);
                environmentConfiguration[azureLoadTestData[0]] = azureLoadTestData[1];
            }

            return environmentConfiguration;
        }
    }
}
