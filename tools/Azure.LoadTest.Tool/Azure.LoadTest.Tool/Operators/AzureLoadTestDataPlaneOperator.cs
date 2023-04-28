using Azure.Identity;
using Azure.LoadTest.Tool.Models.AzureLoadTest;
using Microsoft.Extensions.Logging;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;

namespace Azure.LoadTest.Tool.Operators
{
    public class AzureLoadTestDataPlaneOperator
    {
        // represents the resource/audience we target when we retrieve a token for authorization
        private const string AzureLoadTestResourceUri = "https://loadtest.azure-dev.com";

        private readonly ILogger<AzureLoadTestDataPlaneOperator> _logger;

        public AzureLoadTestDataPlaneOperator(
            ILogger<AzureLoadTestDataPlaneOperator> logger)
        {
            _logger = logger;
        }

        public async Task<Guid> CreateLoadTestAsync(string loadTestDataPlaneUri, CancellationToken cancellation)
        {
            var credential = new DefaultAzureCredential();
            var token = await credential.GetTokenAsync(
                new Azure.Core.TokenRequestContext(new[] { AzureLoadTestResourceUri }), cancellation);

            var newTestPlan = CreteNewTestPlan();
            var json = JsonSerializer.Serialize(newTestPlan, new JsonSerializerOptions
            {
                WriteIndented = true,
            });

            _logger.LogInformation($"Request Body: {Environment.NewLine}{json}");

            var url = $"https://{loadTestDataPlaneUri}/tests/{newTestPlan.TestId}?api-version=2022-11-01";
            _logger.LogInformation($"Will patch: {url}");

            using HttpClient client = new HttpClient();
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token.Token);
            client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
            var content = new StringContent(json, Encoding.UTF8, "application/merge-patch+json");

            HttpResponseMessage response = await client.PatchAsync(url, content, cancellation);
            var endpointMessage = await response.Content.ReadAsStringAsync(cancellation);
            if (!response.IsSuccessStatusCode)
            {
                throw new Exception("CreateLoadTestAsync broke: " + endpointMessage);
            }

            return newTestPlan.TestId;

            TestProperties CreteNewTestPlan()
            {
                var hiddenParamDisplayName = $"Relecloud LoadTest Sample {DateTime.Now}";
                var hiddenParamDescription = "Run this test to examine the impact of performance efficiency changes";

                ///TODO - extract hidden parameter
                var hiddenParamDomain = "76tfvbnjua1234a.azurewebsites.net";
                return new TestPlanRequest
                {
                    DisplayName = hiddenParamDisplayName,
                    Description = hiddenParamDescription,
                    EnvironmentVariables = new EnvironmentVariables
                    {
                        Domain = hiddenParamDomain
                    }
                };
            }
        }

        public async Task<string> UploadTestFileAsync(string loadTestDataPlaneUri, Guid testPlanId, string pathToTestFile, CancellationToken cancellation)
        {
            var testFile = new FileInfo(pathToTestFile);
            if (!testFile.Exists)
            {
                throw new ArgumentNullException($"Could not find test file named: {pathToTestFile}");
            }

            var credential = new DefaultAzureCredential();
            var token = await credential.GetTokenAsync(
                new Azure.Core.TokenRequestContext(new[] { AzureLoadTestResourceUri }), cancellation);

            var url = $"https://{loadTestDataPlaneUri}/tests/{testPlanId}/files/{testFile.Name}?api-version=2022-11-01";
            _logger.LogInformation($"Will put: {url}");

            using HttpClient client = new HttpClient();
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token.Token);

            using var content = new StreamContent(testFile.OpenRead());
            content.Headers.ContentDisposition = new ContentDispositionHeaderValue("attachment")
            {
                FileName = testFile.Name
            };
            content.Headers.ContentType = new MediaTypeHeaderValue("application/octet-stream");

            HttpResponseMessage response = await client.PutAsync(url, content, cancellation);
            var endpointMessage = await response.Content.ReadAsStringAsync(cancellation);
            if (!response.IsSuccessStatusCode)
            {
                var errorMessage = string.IsNullOrEmpty(endpointMessage) ? response.ReasonPhrase : endpointMessage;
                throw new Exception("UploadTestFileAsync broke: " + errorMessage);
            }

            var loadTestResponse = JsonSerializer.Deserialize<FileUploadResponse>(endpointMessage);

            return loadTestResponse?.Url ?? throw new InvalidOperationException("JMX file was not uploaded successfully");
        }

        public async Task<string> AssociateAppComponentsAsync(string loadTestDataPlaneUri, Guid testPlanId, IEnumerable<ComponentInfo> serverSideComponents, CancellationToken cancellation)
        {
            if (serverSideComponents == null)
            {
                throw new ArgumentNullException(nameof(serverSideComponents));
            }

            // make an API call that requests details
            var credential = new DefaultAzureCredential();
            var token = await credential.GetTokenAsync(
                new Azure.Core.TokenRequestContext(new[] { AzureLoadTestResourceUri }), cancellation);

            var newTestRun = CreateAppComponents(testPlanId, serverSideComponents);
            var json = JsonSerializer.Serialize(newTestRun, new JsonSerializerOptions
            {
                WriteIndented = true,
            });

            _logger.LogInformation($"Request Body: {Environment.NewLine}{json}");

            var url = $"https://{loadTestDataPlaneUri}/tests/{testPlanId}/app-components?api-version=2022-11-01";
            _logger.LogInformation($"Will patch: {url}");

            using HttpClient client = new HttpClient();
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token.Token);
            client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
            var content = new StringContent(json, Encoding.UTF8, "application/merge-patch+json");

            HttpResponseMessage response = await client.PatchAsync(url, content, cancellation);
            var endpointMessage = await response.Content.ReadAsStringAsync(cancellation);
            if (!response.IsSuccessStatusCode)
            {
                var errorMessage = string.IsNullOrEmpty(endpointMessage) ? response.ReasonPhrase : endpointMessage;
                throw new Exception("AssociateAppComponentsAsync broke: " + errorMessage);
            }

            var appCompAssociateResponse = JsonSerializer.Deserialize<AssociateAppComponentsResponse>(endpointMessage);

            return appCompAssociateResponse?.LastModifiedBy ?? throw new InvalidOperationException("Server-side metrics were not associated successfully");

            AssociateAppComponentsRequest CreateAppComponents(Guid testPlanId, IEnumerable<ComponentInfo> serverSideComponents)
            {
                var components = new Dictionary<string, ComponentInfo>();
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

        public async Task<string> StartLoadTestAsync(string loadTestDataPlaneUri, Guid existingTestPlanId, CancellationToken cancellation)
        {
            var credential = new DefaultAzureCredential();
            var token = await credential.GetTokenAsync(
                new Azure.Core.TokenRequestContext(new[] { AzureLoadTestResourceUri }), cancellation);

            var newTestRun = CreateNewTestRun(existingTestPlanId);
            var json = JsonSerializer.Serialize(newTestRun, new JsonSerializerOptions
            {
                WriteIndented = true,
            });

            _logger.LogInformation($"Request Body: {Environment.NewLine}{json}");

            var newTestRunId = Guid.NewGuid();
            var url = $"https://{loadTestDataPlaneUri}/test-runs/{newTestRunId}?api-version=2022-11-01";
            _logger.LogInformation($"Will patch: {url}");

            using HttpClient client = new HttpClient();
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token.Token);
            client.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
            var content = new StringContent(json, Encoding.UTF8, "application/merge-patch+json");

            HttpResponseMessage response = await client.PatchAsync(url, content, cancellation);
            var endpointMessage = await response.Content.ReadAsStringAsync(cancellation);
            if (!response.IsSuccessStatusCode)
            {
                var errorMessage = string.IsNullOrEmpty(endpointMessage) ? response.ReasonPhrase : endpointMessage;
                throw new Exception("StartLoadTestAsync broke: " + errorMessage);
            }

            var loadTestResponse = JsonSerializer.Deserialize<TestRunResponse>(endpointMessage);

            return loadTestResponse?.TestRunId ?? throw new InvalidOperationException("Load test was not started successfully");

            TestRunRequest CreateNewTestRun(Guid testPlanId)
            {
                ///TODO - extract hidden parameters
                var hiddenParamDisplayName = $"Relecloud LoadTest Run {DateTime.Now}";
                var hiddenParamDescription = "This test run was automatically started";
                var hiddenParamDomain = "76tfvbnjua1234a.azurewebsites.net";
                return new TestRunRequest(testPlanId)
                {
                    DisplayName = hiddenParamDisplayName,
                    Description = hiddenParamDescription,
                    EnvironmentVariables = new EnvironmentVariables
                    {
                        Domain = hiddenParamDomain
                    }
                };
            }
        }
    }
}
