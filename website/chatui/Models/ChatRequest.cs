namespace chatui.Models
{
    public class ChatRequest
    {
        public string model { get; set; }
        public Message[] messages { get; set; }
    }

    public class Message
    {
        public string role { get; set; }
        public string content { get; set; }
    }

}