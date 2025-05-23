using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using Azure;
using Azure.AI.Agents.Persistent;
using chatui.Models;
using chatui.Configuration;

namespace chatui.Controllers;

[ApiController]
[Route("[controller]/[action]")]

public class ChatController(
    PersistentAgentsClient client,
    BingGroundingToolDefinition bingGroundingTool,
    IOptionsMonitor<ChatApiOptions> options,
    ILogger<ChatController> logger) : ControllerBase
{
    private readonly PersistentAgentsClient _client = client;
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
        PersistentAgent agent = await _client.Administration.CreateAgentAsync(
                model: _config.DefaultModel,
                name: "Chatbot Agent",
                instructions: "You are a helpful Chatbot agent.",
                tools: [_bingGroundingTool]);

        PersistentAgentThread thread = await _client.Threads.CreateThreadAsync();

        PersistentThreadMessage message = await _client.Messages.CreateMessageAsync(
            thread.Id,
            MessageRole.User,
            prompt);

        ThreadRun run = await _client.Runs.CreateRunAsync(thread.Id, agent.Id);

        while (run.Status == RunStatus.Queued || run.Status == RunStatus.InProgress || run.Status == RunStatus.RequiresAction)
        {
            await Task.Delay(TimeSpan.FromMilliseconds(500));
            run = (await _client.Runs.GetRunAsync(thread.Id, run.Id)).Value;
        }

        // AsyncPageable<PersistentThreadMessage> messages = await _client.Messages.GetMessagesAsync(threadId: thread.Id, order: ListSortOrder.Ascending);
        Pageable<PersistentThreadMessage>  messages = _client.Messages.GetMessages(
            threadId: thread.Id, order: ListSortOrder.Ascending);

        var fullText = string.Concat(
            messages
                .Where(m => m.Role == MessageRole.Agent)
                .SelectMany(m => m.ContentItems.OfType<MessageTextContent>())
                .Select(c => c.Text)
        );

        return Ok(new HttpChatResponse(true, fullText));
    }
}