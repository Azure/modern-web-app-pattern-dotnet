using Azure.LoadTest.Tool.Models.AzureLoadTest.TestPlans;

namespace Azure.LoadTest.Tool.Models.AzureLoadTest.TestRuns
{
    /// <summary>
    /// API Version 2022-11-01
    /// </summary>
    public class TestRunRequest : TestProperties
    {
        public TestRunRequest(Guid existingTestPlanId)
        {
            TestId = existingTestPlanId;
        }
    }
}
