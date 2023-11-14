
This guide demonstrates how principles from the [Well-Architected Framework](https://docs.microsoft.com/azure/architecture/framework/)
and [Twelve-Factor Applications](https://12factor.net/) can be applied to migrate and modernize a legacy, line-of-business (LOB) web app to the cloud. The following table lists the principles of the modern web app pattern and how to implement those principles in your web app. For more information, see the [Modern web app pattern overview](https://aka.ms/eap/mwa/dotnet/doc).

The following table lists the principles of the modern web app pattern and how to implement those principles in your web app. For more information, see the [Modern web app pattern overview](https://aka.ms/eap/mwa/dotnet/doc).

*Table 1. Pattern principles and how to implement them.*

| Modern web app pattern principles | How to implement the principles |
| --- | --- |
| *Modern web app pattern principles:*<br>▪ Mature dev team practices for modern development<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;▪ Accelerate feature development with vertical slice development <br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;▪ Evolutionary design changes instead of re-write<br>▪ Managed services<br>▪ Focused on vertical slice development to support<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;▪ Non-functional requirements<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;▪ Parallel workstream opportunities<br><br>*Well Architected Framework principles:*<br>▪ Cost optimized<br>▪ Observable<br>▪ Ingress secure<br>▪ Infrastructure as code<br>▪ Identity-centric security|▪ Backends for Frontends pattern <br>▪ Cache-aside pattern <br>▪ Federated Identity pattern<br>▪ Queue-Based Load Leveling pattern<br>▪ Gateway Routing pattern<br>▪ Rate Limiting pattern<br>▪ Strangler Fig pattern <br>▪ Rightsized resources <br>▪ Managed identities <br>▪ Private endpoints <br>▪ Secrets management <br>▪ Bicep deployment <br>▪ Telemetry, logging, monitoring |