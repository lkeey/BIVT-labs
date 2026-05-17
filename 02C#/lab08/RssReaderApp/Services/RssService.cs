using System;
using System.IO;
using System.Net;

namespace RssReaderApp.Services
{
    public class RssService
    {
        private string rssUrl = "https://lenta.ru/rss/news";

        public void SetRssUrl(string url)
        {
            rssUrl = url;
        }

        public string DownloadRssFeed()
        {
            HttpWebRequest request = (HttpWebRequest)WebRequest.Create(rssUrl);
            request.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36";
            request.Timeout = 30000;
            
            using (HttpWebResponse response = (HttpWebResponse)request.GetResponse())
            using (Stream stream = response.GetResponseStream())
            using (StreamReader reader = new StreamReader(stream))
            {
                string rssContent = reader.ReadToEnd();
                return rssContent;
            }
        }
    }
}
