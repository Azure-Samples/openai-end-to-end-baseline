using System.Net.Http.Headers;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;
using chatui.Configuration;
using chatui.Models;

namespace chatui.Controllers;

[ApiController]
[Route("[controller]/[action]")]

public class ChatController(
    IHttpClientFactory httpClientFactory,
    IOptionsMonitor<ChatApiOptions> options, 
    ILogger<ChatController> logger) : ControllerBase
{
    private readonly HttpClient _client = httpClientFactory.CreateClient("ChatClient");
    private readonly IOptionsMonitor<ChatApiOptions> _options = options;
    private readonly ILogger<ChatController> _logger = logger;

    [HttpPost]
    public async Task<IActionResult> Completions([FromBody] string prompt)
    {
        if (string.IsNullOrWhiteSpace(prompt))
            throw new ArgumentException("Prompt cannot be null, empty, or whitespace.", nameof(prompt));

        _logger.LogDebug("Prompt received {Prompt}", prompt);

        var _config = _options.CurrentValue;

        var requestBody = JsonSerializer.Serialize(new Dictionary<string, string>
        {
            [_config.ChatInputName] = prompt
        });

        using var request = new HttpRequestMessage(HttpMethod.Post, _config.ChatApiEndpoint)
        {
            Content = new StringContent(requestBody, System.Text.Encoding.UTF8, "application/json"),
        };
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _config.ChatApiKey);

        var response = await _client.SendAsync(request);
        var responseContent = await response.Content.ReadAsStringAsync();

        _logger.LogInformation("HTTP status code: {StatusCode}", response.StatusCode);

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogError("Error response: {Content}", responseContent);

            foreach (var (key, value) in response.Headers)
                _logger.LogDebug("Header {Key}: {Value}", key, string.Join(", ", value));

            foreach (var (key, value) in response.Content.Headers)
                _logger.LogDebug("Content-Header {Key}: {Value}", key, string.Join(", ", value));

            return BadRequest(responseContent);
        }

        _logger.LogInformation("Successful response: {Content}", responseContent);

        var result = JsonSerializer.Deserialize<Dictionary<string, string>>(responseContent);
        var output = result?.GetValueOrDefault(_config.ChatOutputName) ?? string.Empty;

        return Ok(new HttpChatResponse(true, output));
    }
}