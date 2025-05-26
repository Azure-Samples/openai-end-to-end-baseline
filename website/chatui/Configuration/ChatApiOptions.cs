using System.ComponentModel.DataAnnotations;

namespace chatui.Configuration;

public class ChatApiOptions
{
    [Required]
    public string AIProjectConnectionString { get; init; } = default!;

    [Required]
    public string BingSearchConnectionId { get; init; } = default!;

    [Required]
    public string DefaultModel { get; init; } = default!;
}