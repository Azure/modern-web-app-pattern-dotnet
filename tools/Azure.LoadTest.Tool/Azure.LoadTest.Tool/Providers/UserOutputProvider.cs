namespace Azure.LoadTest.Tool.Providers
{
    /// <summary>
    /// owns the responsibility for communicating status to someone executing the tool
    /// </summary>
    // separate from ILogger which owns responsibility for communicating messages to a dev that are used for trace/debug behavior
    public class UserOutputProvider
    {
        public void WriteFatalError(string errorMessage)
        {
            Console.ForegroundColor = ConsoleColor.Red;
            Console.Write("FATAL ERROR: ");
            Console.ResetColor();
            Console.WriteLine($"Unable to complete Load Test configuration.");
            Console.WriteLine($"{errorMessage}{Environment.NewLine}");
        }

        public void WriteStatusMessage(string statusMessage)
        {
            Console.WriteLine($"{DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff")} ${statusMessage}");
        }

        public void WriteSuccessMessage()
        {
            Console.ForegroundColor = ConsoleColor.Green;
            Console.Write("SUCCESS: ");
            Console.ResetColor();
            Console.WriteLine($"Completed Load Test configuration and load test was started.{Environment.NewLine}");
        }
    }
}
