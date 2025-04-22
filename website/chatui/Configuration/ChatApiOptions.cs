using System.ComponentModel.DataAnnotations;

namespace chatui.Configuration;

public class ChatApiOptions
{
    [Url]
    public string ChatApiEndpoint { get; init; } = default!;

    [Required]
    public string ChatApiKey { get; init; } = default!;

    public string ChatInputName { get; init; } = "chat_input";

    public string ChatOutputName { get; init; } = "chat_output";
}