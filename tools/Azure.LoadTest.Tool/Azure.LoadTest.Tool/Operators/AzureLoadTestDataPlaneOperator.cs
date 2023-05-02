﻿using Azure.Core;
using Azure.Developer.LoadTesting;
using Azure.Identity;
using Azure.LoadTest.Tool.Models.AzureLoadTest.AppComponents;
using Azure.LoadTest.Tool.Models.AzureLoadTest.TestPlans;
using Azure.LoadTest.Tool.Models.AzureLoadTest.TestRuns;
using Azure.LoadTest.Tool.Providers;

namespace Azure.LoadTest.Tool.Operators
{
    public class AzureLoadTestDataPlaneOperator
    {
        private readonly AzdParametersProvider _azdOperator;
        private readonly DefaultAzureCredential _sharedCredentials;

        private readonly Dictionary<string, LoadTestAdministrationClient> _administrationClient = new Dictionary<string, LoadTestAdministrationClient>();
        private readonly Dictionary<string, LoadTestRunClient> _loadTestRunClient = new Dictionary<string, LoadTestRunClient>();

        public AzureLoadTestDataPlaneOperator(
            AzdParametersProvider azdOperator)
        {
            _azdOperator = azdOperator;
            _sharedCredentials = new DefaultAzureCredential();
        }

        private LoadTestAdministrationClient GetAdministrationClient(string dataPlaneUri)
        {
            if (!_administrationClient.ContainsKey(dataPlaneUri))
            {
                _administrationClient[dataPlaneUri] = new LoadTestAdministrationClient(new Uri($"https://{dataPlaneUri}"), _sharedCredentials);
            }

            return _administrationClient[dataPlaneUri];
        }

        private LoadTestRunClient GetLoadTestRunClient(string dataPlaneUri)
        {
            if (!_loadTestRunClient.ContainsKey(dataPlaneUri))
            {
                _loadTestRunClient[dataPlaneUri] = new LoadTestRunClient(new Uri($"https://{dataPlaneUri}"), _sharedCredentials);
            }

            return _loadTestRunClient[dataPlaneUri];
        }

        public async Task<Guid> CreateLoadTestAsync(string loadTestDataPlaneUri)
        {
            var newTestId = Guid.NewGuid();
            var altEnvironmentVariables = _azdOperator.GetLoadTestEnvironmentVars();
            var newTestPlan = CreteNewTestPlan();
            var response = await GetAdministrationClient(loadTestDataPlaneUri).CreateOrUpdateTestAsync(newTestId.ToString(), RequestContent.Create(newTestPlan));
            
            if (response.IsError)
            {
                throw new Exception("CreateLoadTestAsync broke: " + response.ReasonPhrase);
            }

            return newTestPlan.TestId;

            TestPlanRequest CreteNewTestPlan()
            {
                var hiddenParamDisplayName = $"Relecloud LoadTest Sample {DateTime.Now}";
                var hiddenParamDescription = "Run this test to examine the impact of performance efficiency changes";

                return new TestPlanRequest
                {
                    TestId = newTestId,
                    DisplayName = hiddenParamDisplayName,
                    Description = hiddenParamDescription,
                    EnvironmentVariables = altEnvironmentVariables
                };
            }
        }

        public async Task UploadTestFileAsync(string loadTestDataPlaneUri, Guid testPlanId, string pathToTestFile)
        {
            var testFile = new FileInfo(pathToTestFile);
            if (!testFile.Exists)
            {
                throw new ArgumentNullException($"Could not find test file named: {pathToTestFile}");
            }

            var requestContent = RequestContent.Create(await File.ReadAllBytesAsync(testFile.FullName));
            var response = await GetAdministrationClient(loadTestDataPlaneUri).UploadTestFileAsync(WaitUntil.Completed, testPlanId.ToString(), testFile.Name, requestContent);

            if (response.GetRawResponse().IsError)
            {
                throw new Exception("UploadTestFileAsync broke: " + response.GetRawResponse().ReasonPhrase);
            }
        }

        public async Task AssociateAppComponentsAsync(string loadTestDataPlaneUri, Guid existingTestId, IEnumerable<AppComponentInfo> serverSideComponents)
        {
            if (serverSideComponents == null)
            {
                throw new ArgumentNullException(nameof(serverSideComponents));
            }

            var componentsForServerSideMetrics = CreateAppComponents(existingTestId, serverSideComponents);
            var requestContent = RequestContent.Create(componentsForServerSideMetrics);
            var response = await GetAdministrationClient(loadTestDataPlaneUri).CreateOrUpdateAppComponentsAsync(existingTestId.ToString(), requestContent);

            if (response.IsError)
            {
                throw new Exception("AssociateAppComponentsAsync broke: " + response.ReasonPhrase);
            }

            AssociateAppComponentsRequest CreateAppComponents(Guid testPlanId, IEnumerable<AppComponentInfo> serverSideComponents)
            {
                var components = new Dictionary<string, AppComponentInfo>();
                foreach (var serverSideComponent in serverSideComponents)
                {
                    if (!string.IsNullOrEmpty(serverSideComponent.ResourceId))
                    {
                        components.Add(serverSideComponent.ResourceId, serverSideComponent);
                    }
                }

                return new AssociateAppComponentsRequest
                {
                    TestId = testPlanId,
                    Components = components
                };
            }
        }

        public async Task StartLoadTestAsync(string loadTestDataPlaneUri, Guid existingTestPlanId)
        {
            var newTestRunId = Guid.NewGuid().ToString();
            var altEnvironmentVariables = _azdOperator.GetLoadTestEnvironmentVars();
            var data = CreateNewTestRun(existingTestPlanId, altEnvironmentVariables);
            var operation = await GetLoadTestRunClient(loadTestDataPlaneUri).BeginTestRunAsync(WaitUntil.Started, newTestRunId, RequestContent.Create(data));

            if (operation.GetRawResponse().IsError)
            {
                throw new Exception("StartLoadTestAsync broke: " + operation.GetRawResponse().ReasonPhrase);
            }

            TestRunRequest CreateNewTestRun(Guid testPlanId, Dictionary<string, string> altEnvironmentVariables)
            {
                var hiddenParamDisplayName = $"Relecloud LoadTest Run {DateTime.Now}";
                var hiddenParamDescription = "This test run was automatically started";

                return new TestRunRequest(testPlanId)
                {
                    DisplayName = hiddenParamDisplayName,
                    Description = hiddenParamDescription,
                    EnvironmentVariables = altEnvironmentVariables
                };
            }
        }
    }
}
