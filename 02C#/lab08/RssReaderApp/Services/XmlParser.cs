using System;
using System.Collections.Generic;
using System.Globalization;
using System.Xml;
using RssReaderApp.Models;

namespace RssReaderApp.Services
{
    public class XmlParser
    {
        public List<NewsItem> ParseRss(string xmlContent)
        {
            var news = new List<NewsItem>();
            
            try
            {
                XmlDocument doc = new XmlDocument();
                doc.LoadXml(xmlContent);
                
                XmlNodeList items = doc.GetElementsByTagName("item");
                
                foreach (XmlNode item in items)
                {
                    var newsItem = new NewsItem
                    {
                        Title = item["title"]?.InnerText ?? "",
                        Description = item["description"]?.InnerText ?? "",
                        Link = item["link"]?.InnerText ?? "",
                        PubDate = ParsePubDate(item["pubDate"]?.InnerText ?? "")
                    };
                    news.Add(newsItem);
                }
            }
            catch (Exception ex)
            {
                throw new Exception($"Ошибка парсинга XML: {ex.Message}", ex);
            }
            
            return news;
        }
        
        private DateTime ParsePubDate(string pubDate)
        {
            if (string.IsNullOrWhiteSpace(pubDate))
                return DateTime.Now;
            
            // Попытка парсинга RFC822 формата (стандарт RSS)
            if (DateTime.TryParse(pubDate, CultureInfo.InvariantCulture, DateTimeStyles.None, out var date))
                return date;
            
            // Попытка парсинга с учетом RFC1123
            if (DateTime.TryParseExact(pubDate, "ddd, dd MMM yyyy HH:mm:ss zzz", 
                CultureInfo.InvariantCulture, DateTimeStyles.None, out var date2))
                return date2;
            
            return DateTime.Now;
        }
    }
}
