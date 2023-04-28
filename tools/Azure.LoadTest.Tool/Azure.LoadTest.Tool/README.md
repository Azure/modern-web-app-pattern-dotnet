## Set up instructions
The console app uses AZD environment variables as input parameters.

To access those parameters, by environment name, it accepts one
command line parameter.

*Command Line Parameters*
- [environment-name]: Provides the folder name that specifies the azd environment variables that will be used at runtime

These params can be set with `azd env set` after an azd environment
has been created with `azd env new`. Current list of parameters can
be viewed in the Ini file that stores environment variables or
retrieved from command line via `azd env get-values`.

*AZD Parameters*
- [APP_COMPONENTS_RESOURCE_IDS]: a comma delimited list of Azure Resources (specified by resourceId) that specifies server-side metrics to be shown when analyzing load test results
- [Azure_WEBSITE_DOMAIN]: the URL that will be tested during the load test
- [AZURE_LOAD_TEST_NAME]: name of the Azure Load Test Service resource
- [AZURE_LOAD_TEST_NAME]: path to the Azure Load Test JMeter file
- [AZURE_RESOURCE_GROUP]: the resource group where the Azure Load Test Service resource is deployed
- [SUBSCRIPTION_ID]: the subscriptino where the Azure Load Test Service resource is deployed

## Todo
- reuse tokens - extract HttpClient into named clients
- adjust log levels
- refactor and review models