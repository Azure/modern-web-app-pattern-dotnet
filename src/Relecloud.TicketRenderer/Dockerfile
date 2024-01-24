## Build Stage
# Build in a separate stage to avoid copying the SDK into the final image
FROM mcr.microsoft.com/dotnet/sdk:8.0-jammy AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src

# Restore packages
COPY ["Relecloud.TicketRenderer/Relecloud.TicketRenderer.csproj", "Relecloud.TicketRenderer/"]
COPY ["Relecloud.Messaging/Relecloud.Messaging.csproj", "Relecloud.Messaging/"]
COPY ["Relecloud.Models/Relecloud.Models.csproj", "Relecloud.Models/"]
RUN dotnet restore "./Relecloud.TicketRenderer/Relecloud.TicketRenderer.csproj"

# Build and publish
COPY . .
WORKDIR "/src/Relecloud.TicketRenderer"
RUN dotnet publish "./Relecloud.TicketRenderer.csproj" -c $BUILD_CONFIGURATION -o /app/publish /p:UseAppHost=false

## Runtime Stage
# Chiseled images contain only the minimal set of packages needed for .NET 8.0
FROM mcr.microsoft.com/dotnet/aspnet:8.0-jammy-chiseled AS final
WORKDIR /app
EXPOSE 8080

# Copy the published app from the build stage
COPY --from=build /app/publish .

# Run as non-root user
USER $APP_UID

ENTRYPOINT ["dotnet", "./Relecloud.TicketRenderer.dll"]
