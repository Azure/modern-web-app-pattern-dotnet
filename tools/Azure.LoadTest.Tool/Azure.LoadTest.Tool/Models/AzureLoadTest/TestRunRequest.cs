namespace Azure.LoadTest.Tool.Models.AzureLoadTest
{
    public class TestRunRequest : TestProperties
    {
        public TestRunRequest(Guid existingTestPlanId)
        {
            TestId = existingTestPlanId;
        }
    }
}
