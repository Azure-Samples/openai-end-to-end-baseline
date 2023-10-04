namespace chatui.Models
{
    public class HttpChatGPTResponse
    {
        public bool Success { get; set; }
        public string Data { get; set; }
        public string Error { get; set; }
    }

    public class ChatResponse
    {
        public string id { get; set; }
        public string _object { get; set; }
        public int created { get; set; }
        public Choice[] choices { get; set; }
        public Usage usage { get; set; }
    }

    public class Usage
    {
        public int prompt_tokens { get; set; }
        public int completion_tokens { get; set; }
        public int total_tokens { get; set; }
    }

    public class Choice
    {
        public int index { get; set; }
        public Message message { get; set; }
        public string finish_reason { get; set; }
    }

}