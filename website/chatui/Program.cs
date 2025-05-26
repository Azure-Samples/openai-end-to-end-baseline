using Microsoft.Extensions.Options;
using Azure.AI.Projects;
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
    var client = new AgentsClient(config.AIProjectConnectionString, new DefaultAzureCredential());

    return client;
});

builder.Services.AddSingleton((provider) =>
{
    var config = provider.GetRequiredService<IOptions<ChatApiOptions>>().Value;

    ToolConnectionList connectionList = new()
    {
        ConnectionList = { new ToolConnection(config.BingSearchConnectionId) }
    };

    BingGroundingToolDefinition bingGroundingTool = new(connectionList);

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