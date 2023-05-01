## Set up instructions
The console app uses AZD environment variables as input parameters.

To access those parameters, by environment name, it accepts one
command line parameter.

**Command Line Parameters**
- [environment-name]: Provides the folder name that specifies the azd environment variables that will be used at runtime

These params can be set with `azd env set` after an azd environment
has been created with `azd env new`. Current list of parameters can
be viewed in the Ini file that stores environment variables or
retrieved from command line via `azd env get-values`.

**AZD Parameters**
- [APP_COMPONENTS_RESOURCE_IDS]: a comma delimited list of Azure Resources (specified by resourceId) that specifies server-side metrics to be shown when analyzing load test results
- [AZURE_LOAD_TEST_NAME]: name of the Azure Load Test Service resource
- [AZURE_LOAD_TEST_FILE]: path to the Azure Load Test JMeter file
- [AZURE_RESOURCE_GROUP]: the resource group where the Azure Load Test Service resource is deployed
- [SUBSCRIPTION_ID]: the subscriptino where the Azure Load Test Service resource is deployed

**AZD Parameters: Load Test Environment Parameters**

Environment paramters are used by JMeter scripts to parameterize the script and develop configurable/reusable scripts.
To support this feature we collect AZD environment parameters following a prefix naming convention and parse their values to assign environment variables to test runs and test definitions in Azure Load Test Service.

E.g.
```
ALT_ENV_PARAM_X1="domain,76tfvbnjua1234a.azurewebsites.net"
```

In this format the prefix is `ALT_ENV_PARAM_` and the tool will attempt to parse all parameters matching this prefix.

In the value component of this example we see
- the name for the environment parameter will be the case-sensitive key of "domain" 
- the value of the environment parameter will be the case-sensitve result of "76tfvbnjua1234a.azurewebsites.net"

> Note the use of comma as a delimiter in this format which cannot be changed in this version of the tool