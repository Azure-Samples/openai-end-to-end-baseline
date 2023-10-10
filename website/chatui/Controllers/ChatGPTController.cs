using chatui.Models;
using Microsoft.AspNetCore.Mvc;
using Newtonsoft.Json;
using System.Net.Http.Headers;
using Newtonsoft.Json.Linq;

namespace chatui.Controllers
{
    [ApiController]

    public class ChatGPTController : ControllerBase
    {
        private readonly IConfiguration _configuration;

        public ChatGPTController(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        [HttpPost]
        [Route("AskChatGPT")]
        public async Task<IActionResult> AskChatGPT([FromBody] string query)
        {
            var apiEndpoint = _configuration["chatApiEndpoint"];
            var apiKey = _configuration["chatApiKey"];

            var chatInputName = _configuration["chatInputName"] ?? "chat_input";
            var chatOutputName = _configuration["chatOutputName"] ?? "chat_output";

            var handler = new HttpClientHandler()
            {
                ClientCertificateOptions = ClientCertificateOption.Manual,
                ServerCertificateCustomValidationCallback =
                        (httpRequestMessage, cert, cetChain, policyErrors) => { return true; }
            };
            using var client = new HttpClient(handler);

            Dictionary<string, string> chatstmt = new Dictionary<string, string>();
            chatstmt.Add(chatInputName, query);
            var requestBody = JsonConvert.SerializeObject(chatstmt);

            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", apiKey);
            client.BaseAddress = new Uri(apiEndpoint);

            var content = new StringContent(requestBody);
            content.Headers.ContentType = new MediaTypeHeaderValue("application/json");

            HttpResponseMessage response = await client.PostAsync("", content);

            if (response.IsSuccessStatusCode)
            {
                string result = await response.Content.ReadAsStringAsync();
                Console.WriteLine("Result: {0}", result);

                HttpChatGPTResponse oHttpResponse = new()
                {
                    Success = true,
                    Data = JsonConvert.DeserializeObject<JObject>(result)[chatOutputName].Value<string>()
                };
                return Ok(oHttpResponse);
            }
            else
            {
                Console.WriteLine(string.Format("The request failed with status code: {0}", response.StatusCode));
                Console.WriteLine(response.Headers.ToString());
                string responseContent = await response.Content.ReadAsStringAsync();
                Console.WriteLine(responseContent);
                return BadRequest(responseContent);
            }
        }
    }
}