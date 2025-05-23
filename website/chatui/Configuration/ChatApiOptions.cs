using System.ComponentModel.DataAnnotations;

namespace chatui.Configuration;

public class ChatApiOptions
{
    [Required]
    public string AIProjectEndpoint { get; init; } = default!;

    [Required]
    public string BingSearchConnectionId { get; init; } = default!;

    [Required]
    public int BingSearchResultsCount { get; init; } = 5;

    [Required]
    public string BingSearchResultsTimeRange { get; init; } = "Week";

    [Required]
    public string DefaultModel { get; init; } = default!;
}