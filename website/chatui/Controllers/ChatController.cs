using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Azure.AI.Projects;
using chatui.Models;
using chatui.Configuration;

namespace chatui.Controllers;

[ApiController]
[Route("[controller]/[action]")]

public class ChatController(
    AgentsClient client,
    BingGroundingToolDefinition bingGroundingTool,
    IOptionsMonitor<ChatApiOptions> options,
    ILogger<ChatController> logger) : ControllerBase
{
    private readonly AgentsClient _client = client;
    private readonly BingGroundingToolDefinition _bingGroundingTool = bingGroundingTool;
    private readonly IOptionsMonitor<ChatApiOptions> _options = options;
    private readonly ILogger<ChatController> _logger = logger;

    [HttpPost]
    public async Task<IActionResult> Completions([FromBody] string prompt)
    {
        if (string.IsNullOrWhiteSpace(prompt))
            throw new ArgumentException("Prompt cannot be null, empty, or whitespace.", nameof(prompt));

        _logger.LogDebug("Prompt received {Prompt}", prompt);
        var _config = _options.CurrentValue;
        Agent agent = (await _client.CreateAgentAsync(
                model: _config.DefaultModel,
                name: "Chatbot Agent",
                instructions: "You are a helpful Chatbot agent.",
                tools: [_bingGroundingTool])).Value;

        var thread = (await _client.CreateThreadAsync()).Value;

        ThreadMessage message = (await _client.CreateMessageAsync(
            thread.Id,
            MessageRole.User,
            prompt)).Value;

        ThreadRun run = (await _client.CreateRunAsync(thread.Id, agent.Id)).Value;

        while (run.Status == RunStatus.Queued || run.Status == RunStatus.InProgress)
        {
            await Task.Delay(TimeSpan.FromMilliseconds(500));
            run = (await _client.GetRunAsync(thread.Id, run.Id)).Value;
        }

        IReadOnlyList<ThreadMessage> messages = (await _client.GetMessagesAsync(thread.Id)).Value.Data;

        var fullText = string.Concat(
            messages
                .Where(m => m.Role == MessageRole.Agent)
                .SelectMany(m => m.ContentItems.OfType<MessageTextContent>())
                .Select(c => c.Text)
        );

        return Ok(new HttpChatResponse(true, fullText));
    }
}