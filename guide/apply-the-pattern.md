# Modern web app pattern for .NET - Apply the pattern
The reliable web app pattern provides essential implementation guidance for web apps moving to the cloud. It defines how you should update (re-platform) your web app to be successful in the cloud.

There are two articles on the reliable web app pattern for .NET. This article provides code and architecture implementation guidance. The companion article provides [planning guidance](./plan-the-implementation.md). There's a [reference implementation](https://aka.ms/eap/mwa/dotnet) (sample web app) of the pattern that you can deploy.

## Architecture and code

The modern web app pattern situates code changes within the pillars of the Azure Well-Architected Framework to reinforce the close relationship between code and architecture. This guidance uses the reference implementation architecture to illustrate the principles of the modern web app pattern (*see figure 1*). The modern web app pattern is a set of principles with implementation guidance. It's not a specific architecture. It's important that your web app adheres to the principles of the pattern, not this specific architecture.
![Diagram showing the architecture of the reference implementation.](../docs/images/relecloud-solution-diagram.png)
*Figure 1. Target reference implementation architecture. Download a [Visio file](https://arch-center.azureedge.net/reliable-web-app-dotnet.vsdx) of this architecture. For the estimated cost of this architecture, see the [production environment cost](https://azure.com/e/26f1165c5e9344a4bf814cfe6c85ed8d) and [nonproduction environment cost](https://azure.com/e/8a574d4811a74928b55956838db71093).*
