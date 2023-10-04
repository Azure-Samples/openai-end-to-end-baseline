using Microsoft.AspNetCore.Mvc;

namespace chatui.Controllers
{
    public class HomeController : Controller
    {
        public IActionResult Index()
        {
            return View();
        }
    }
}