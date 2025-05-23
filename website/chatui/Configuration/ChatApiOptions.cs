using System.ComponentModel.DataAnnotations;

namespace chatui.Configuration;

public class ChatApiOptions
{
    [Required]
    public string AIProjectEndpoint { get; init; } = default!;

    [Required]
    public string DefaultModel { get; init; } = default!;
}