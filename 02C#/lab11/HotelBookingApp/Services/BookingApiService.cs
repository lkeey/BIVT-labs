using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Threading.Tasks;
using HotelBookingApp.Models;
using Newtonsoft.Json;

namespace HotelBookingApp.Services;

public class BookingApiService
{
    private const string BASE_URL = "http://restful-booker.herokuapp.com";
    
    // Один статический экземпляр HttpClient на всё приложение (best practice)
    private static readonly HttpClient Http = new HttpClient
    {
        Timeout = TimeSpan.FromSeconds(15)
    };

    private string _token = string.Empty;
    public bool IsAuthenticated => !string.IsNullOrEmpty(_token);

    public BookingApiService()
    {
        // Устанавливаем глобальный заголовок Accept, чтобы всегда получать JSON
        if (!Http.DefaultRequestHeaders.Accept.Contains(new MediaTypeWithQualityHeaderValue("application/json")))
        {
            Http.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        }
    }

    /// <summary>
    /// Авторизация и получение токена
    /// </summary>
    public async Task<string> AuthenticateAsync(string username, string password)
    {
        var reqBody = new AuthRequest { username = username, password = password };
        string jsonBody = JsonConvert.SerializeObject(reqBody);
        var content = new StringContent(jsonBody, Encoding.UTF8, "application/json");

        var response = await Http.PostAsync($"{BASE_URL}/auth", content);
        response.EnsureSuccessStatusCode();

        string responseStr = await response.Content.ReadAsStringAsync();
        var authObj = JsonConvert.DeserializeObject<AuthResponse>(responseStr);

        if (authObj == null || string.IsNullOrEmpty(authObj.token) || authObj.token == "Bad credentials")
        {
            throw new Exception("Неверный логин или пароль");
        }

        _token = authObj.token;
        return _token;
    }

    /// <summary>
    /// Получение списка всех ID бронирований
    /// </summary>
    public async Task<List<int>> GetBookingIdsAsync()
    {
        var response = await Http.GetAsync($"{BASE_URL}/booking");
        response.EnsureSuccessStatusCode();

        string json = await response.Content.ReadAsStringAsync();
        var ids = JsonConvert.DeserializeObject<List<BookingIdResponse>>(json);
        
        var result = new List<int>();
        if (ids != null)
        {
            foreach (var item in ids)
            {
                result.Add(item.bookingid);
            }
        }
        return result;
    }

    /// <summary>
    /// Получение деталей конкретного бронирования
    /// </summary>
    public async Task<BookingWithId?> GetBookingDetailsAsync(int id)
    {
        var response = await Http.GetAsync($"{BASE_URL}/booking/{id}");
        if (!response.IsSuccessStatusCode)
            return null;

        string json = await response.Content.ReadAsStringAsync();
        // Проверка на случай, если сервер вернул XML или HTML (например, 418 I'm a teapot)
        if (json.TrimStart().StartsWith("<"))
            return null;

        var booking = JsonConvert.DeserializeObject<Booking>(json);
        if (booking == null) return null;

        return new BookingWithId { Id = id, BookingDetails = booking };
    }

    /// <summary>
    /// Создание нового бронирования (POST) - не требует токена
    /// </summary>
    public async Task<BookingWithId> CreateBookingAsync(Booking booking)
    {
        string jsonBody = JsonConvert.SerializeObject(booking);
        var content = new StringContent(jsonBody, Encoding.UTF8, "application/json");

        // Для POST /booking также нужно добавить Accept заголовок явно на всякий случай
        var req = new HttpRequestMessage(HttpMethod.Post, $"{BASE_URL}/booking")
        {
            Content = content
        };
        req.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

        var response = await Http.SendAsync(req);
        response.EnsureSuccessStatusCode();

        string responseStr = await response.Content.ReadAsStringAsync();
        
        // Ответ при создании содержит и ID, и само бронирование
        // Формат: {"bookingid": 123, "booking": { ... }}
        var createdObj = JsonConvert.DeserializeObject<dynamic>(responseStr);
        int newId = createdObj!.bookingid;
        
        return new BookingWithId { Id = newId, BookingDetails = booking };
    }

    /// <summary>
    /// Обновление бронирования (PUT) - ТРЕБУЕТ ТОКЕН
    /// </summary>
    public async Task UpdateBookingAsync(int id, Booking booking)
    {
        if (!IsAuthenticated) throw new Exception("Необходима авторизация");

        string jsonBody = JsonConvert.SerializeObject(booking);
        
        var req = new HttpRequestMessage(HttpMethod.Put, $"{BASE_URL}/booking/{id}");
        req.Content = new StringContent(jsonBody, Encoding.UTF8, "application/json");
        req.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        req.Headers.Add("Cookie", $"token={_token}");

        var response = await Http.SendAsync(req);
        response.EnsureSuccessStatusCode();
    }

    /// <summary>
    /// Удаление бронирования (DELETE) - ТРЕБУЕТ ТОКЕН
    /// </summary>
    public async Task DeleteBookingAsync(int id)
    {
        if (!IsAuthenticated) throw new Exception("Необходима авторизация");

        var req = new HttpRequestMessage(HttpMethod.Delete, $"{BASE_URL}/booking/{id}");
        req.Headers.Add("Cookie", $"token={_token}");

        var response = await Http.SendAsync(req);
        // Сервер restful-booker возвращает 201 Created при успешном удалении
        if (!response.IsSuccessStatusCode)
        {
            throw new Exception($"Ошибка удаления. Код: {response.StatusCode}");
        }
    }
}