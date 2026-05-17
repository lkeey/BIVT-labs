using System;
using System.Collections.Generic;
using MySql.Data.MySqlClient;
using RssReaderApp.Models;

namespace RssReaderApp.Services
{
    public class DatabaseManager
    {
        private const string ConnectionString = 
            "Server=localhost;Port=3306;Database=rss_news;Uid=rss_user;Pwd=rss_pass;";
        
        public void InitializeDatabase()
        {
            using var connection = new MySqlConnection(ConnectionString);
            connection.Open();
            
            string createTableQuery = @"
                CREATE TABLE IF NOT EXISTS news (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    title VARCHAR(500) NOT NULL,
                    description TEXT,
                    link VARCHAR(500),
                    pub_date DATETIME,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    INDEX idx_pub_date (pub_date)
                )";
            
            using var command = new MySqlCommand(createTableQuery, connection);
            command.ExecuteNonQuery();
        }
        
        public void SaveNews(List<NewsItem> newsList)
        {
            using var connection = new MySqlConnection(ConnectionString);
            connection.Open();
            
            // Удаление старых новостей
            using (var deleteCommand = new MySqlCommand("DELETE FROM news", connection))
            {
                deleteCommand.ExecuteNonQuery();
            }
            
            // Вставка новых новостей
            foreach (var news in newsList)
            {
                string insertQuery = @"
                    INSERT INTO news (title, description, link, pub_date)
                    VALUES (@title, @description, @link, @pubDate)";
                
                using var command = new MySqlCommand(insertQuery, connection);
                command.Parameters.AddWithValue("@title", news.Title);
                command.Parameters.AddWithValue("@description", news.Description);
                command.Parameters.AddWithValue("@link", news.Link);
                command.Parameters.AddWithValue("@pubDate", news.PubDate);
                command.ExecuteNonQuery();
            }
        }
        
        public List<NewsItem> LoadAllNews()
        {
            var newsList = new List<NewsItem>();
            
            using var connection = new MySqlConnection(ConnectionString);
            connection.Open();
            
            string selectQuery = "SELECT * FROM news ORDER BY pub_date DESC";
            using var command = new MySqlCommand(selectQuery, connection);
            using var reader = command.ExecuteReader();
            
            while (reader.Read())
            {
                newsList.Add(new NewsItem
                {
                    Id = reader.GetInt32("id"),
                    Title = reader.GetString("title"),
                    Description = reader.IsDBNull(reader.GetOrdinal("description")) 
                        ? "" : reader.GetString("description"),
                    Link = reader.IsDBNull(reader.GetOrdinal("link")) 
                        ? "" : reader.GetString("link"),
                    PubDate = reader.GetDateTime("pub_date"),
                    CreatedAt = reader.GetDateTime("created_at")
                });
            }
            
            return newsList;
        }
        
        public bool TestConnection()
        {
            try
            {
                using var connection = new MySqlConnection(ConnectionString);
                connection.Open();
                return true;
            }
            catch
            {
                return false;
            }
        }
    }
}
