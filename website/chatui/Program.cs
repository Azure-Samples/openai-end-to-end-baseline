using Microsoft.Extensions.Options;
using Azure.AI.Agents.Persistent;
using Azure.Identity;
using chatui.Configuration;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddOptions<ChatApiOptions>()
    .Bind(builder.Configuration)
    .ValidateDataAnnotations()
    .ValidateOnStart();

builder.Services.AddSingleton((provider) =>
{
    var config = provider.GetRequiredService<IOptions<ChatApiOptions>>().Value;
    PersistentAgentsClient client = new(config.AIProjectEndpoint, new DefaultAzureCredential());

    return client;
});

builder.Services.AddSingleton((provider) =>
{
    var config = provider.GetRequiredService<IOptions<ChatApiOptions>>().Value;

    BingGroundingToolDefinition bingGroundingTool = new(
        new BingGroundingSearchToolParameters(
            [
                new BingGroundingSearchConfiguration(config.BingSearchConnectionId)
                {
                    Count = config.BingSearchResultsCount,
                    Freshness = config.BingSearchResultsTimeRange
                }
            ]
        )
    );

    return bingGroundingTool;
});

builder.Services.AddControllersWithViews();

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAllOrigins",
        builder =>
        {
            builder.AllowAnyOrigin()
                   .AllowAnyMethod()
                   .AllowAnyHeader();
        });
});

var app = builder.Build();

app.UseStaticFiles();

app.UseRouting();

app.MapControllerRoute(
    name: "default",
    pattern: "{controller=Home}/{action=Index}/{id?}");

app.UseCors("AllowAllOrigins");

app.Run();