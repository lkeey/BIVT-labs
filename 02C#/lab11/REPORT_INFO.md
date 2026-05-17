# Отчет по Лабораторной работе №11: Протокол HTTP. Асинхронное программирование

## Цель работы
Разработка приложения-клиента для взаимодействия с REST API сервиса `restful-booker.herokuapp.com` с использованием протокола HTTP и асинхронного программирования.

## Задачи
1. Реализовать авторизацию (POST `/auth`) для получения токена.
2. Реализовать получение списка ID бронирований (GET `/booking`).
3. Реализовать получение деталей бронирования по ID (GET `/booking/{id}`).
4. Использовать асинхронные методы (`async/await`) для выполнения сетевых запросов.
5. Использовать библиотеку `Newtonsoft.Json` для сериализации и десериализации JSON.
6. **Дополнительное задание (выполнено)**: Реализовать полные CRUD-операции (создание, обновление, удаление) с использованием методов POST, PUT, DELETE и передачей токена авторизации.

## Выбранные технологии
- **UI Framework**: Avalonia UI (кроссплатформенная альтернатива Windows Forms/WPF).
- **Паттерн**: MVVM (CommunityToolkit.Mvvm).
- **HTTP Client**: `System.Net.Http.HttpClient` (один статический экземпляр).
- **JSON**: `Newtonsoft.Json`.

---

## Ответы на контрольные вопросы

### 1. Что такое REST API?
REST (Representational State Transfer) — это архитектурный стиль взаимодействия компонентов распределённого приложения в сети. REST API — это интерфейс программирования приложения (API), который использует HTTP-запросы для получения, добавления, изменения и удаления данных (CRUD-операции). Основные принципы REST:
- Клиент-серверная архитектура.
- Отсутствие состояния (Stateless) — каждый запрос содержит всю необходимую информацию.
- Использование стандартных методов HTTP (GET, POST, PUT, DELETE).
- Представление данных в удобном формате (обычно JSON или XML).

### 2. Какие методы HTTP используются для CRUD-операций?
- **C (Create) - POST**: Создание нового ресурса (например, POST `/booking`).
- **R (Read) - GET**: Получение ресурса или списка ресурсов (например, GET `/booking` или GET `/booking/1`).
- **U (Update) - PUT / PATCH**: Обновление существующего ресурса (PUT обновляет ресурс целиком, PATCH — частично).
- **D (Delete) - DELETE**: Удаление ресурса (например, DELETE `/booking/1`).

### 3. Зачем нужен заголовок `Accept`?
Заголовок `Accept` в HTTP-запросе сообщает серверу, какие форматы данных клиент (наше приложение) способен понять и обработать в ответном сообщении. Например, `Accept: application/json` говорит серверу, что мы ожидаем ответ в формате JSON. Если сервер не может предоставить данные в запрошенном формате, он может вернуть ошибку 406 Not Acceptable (или просто вернуть дефолтный формат, как это иногда делает restful-booker).

### 4. Что такое JSON и зачем он нужен?
JSON (JavaScript Object Notation) — это простой, легковесный текстовый формат обмена данными, основанный на синтаксисе объектов JavaScript. Он легко читается людьми и легко парсится машинами. В веб-разработке и REST API он стал стандартом де-факто для передачи структурированных данных между клиентом и сервером, заменив более громоздкий XML.

### 5. Как в C# десериализовать JSON в объект?
В C# для этого чаще всего используются библиотеки `Newtonsoft.Json` или встроенная `System.Text.Json`. 
Пример с `Newtonsoft.Json`:
```csharp
string jsonString = "{\"firstname\": \"Ivan\", \"lastname\": \"Ivanov\"}";
Booking booking = JsonConvert.DeserializeObject<Booking>(jsonString);
```

### 6. Что такое асинхронное программирование и зачем оно нужно при работе с сетью?
Асинхронное программирование — это подход, при котором выполнение длительных операций (таких как сетевые запросы, чтение файлов) не блокирует основной поток выполнения программы.
В UI-приложениях (Avalonia, WPF, WinForms) все взаимодействия с интерфейсом происходят в одном главном потоке (UI-потоке). Если выполнить синхронный сетевой запрос (например, `Thread.Sleep` или `Task.Wait()`), UI-поток заблокируется, и приложение "зависнет" до получения ответа.
Использование `async` и `await` позволяет освободить UI-поток на время ожидания ответа от сервера, сохраняя отзывчивость интерфейса.

---

## Основные фрагменты кода

<details>
<summary><b>1. Модели данных (BookingModels.cs)</b></summary>

```csharp
using System;

namespace HotelBookingApp.Models;

public class AuthRequest
{
    public string username { get; set; } = string.Empty;
    public string password { get; set; } = string.Empty;
}

public class AuthResponse
{
    public string token { get; set; } = string.Empty;
}

public class BookingIdResponse
{
    public int bookingid { get; set; }
}

public class BookingDates
{
    public string checkin { get; set; } = string.Empty;
    public string checkout { get; set; } = string.Empty;
}

public class Booking
{
    public string firstname { get; set; } = string.Empty;
    public string lastname { get; set; } = string.Empty;
    public int totalprice { get; set; }
    public bool depositpaid { get; set; }
    public BookingDates bookingdates { get; set; } = new BookingDates();
    public string additionalneeds { get; set; } = string.Empty;
}

public class BookingWithId
{
    public int Id { get; set; }
    public Booking BookingDetails { get; set; } = new Booking();

    // Свойства для удобного биндинга в DataGrid
    public string FirstName => BookingDetails.firstname;
    public string LastName => BookingDetails.lastname;
    public string TotalPrice => $"{BookingDetails.totalprice} руб.";
    public string DepositPaid => BookingDetails.depositpaid ? "Да" : "Нет";
    public string CheckIn => BookingDetails.bookingdates.checkin;
    public string CheckOut => BookingDetails.bookingdates.checkout;
    public string AdditionalNeeds => BookingDetails.additionalneeds;
}
```
</details>

<details>
<summary><b>2. Сетевой сервис (BookingApiService.cs)</b></summary>

```csharp
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
```
</details>

<details>
<summary><b>3. ViewModel (MainWindowViewModel.cs)</b></summary>

```csharp
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Threading.Tasks;
using Avalonia.Threading;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;
using HotelBookingApp.Models;
using HotelBookingApp.Services;

namespace HotelBookingApp.ViewModels;

public partial class MainWindowViewModel : ObservableObject
{
    private readonly BookingApiService _api = new();

    [ObservableProperty]
    private string _username = "admin";

    [ObservableProperty]
    private string _password = "password123";

    [ObservableProperty]
    private string _statusMessage = "Ожидание авторизации...";

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(CanLoad))]
    [NotifyPropertyChangedFor(nameof(CanAdd))]
    private bool _isAuthenticated = false;

    [ObservableProperty]
    private bool _isLoading = false;

    public bool CanLoad => IsAuthenticated && !IsLoading;
    public bool CanAdd => IsAuthenticated && !IsLoading;

    [ObservableProperty]
    [NotifyPropertyChangedFor(nameof(CanEditOrDelete))]
    private BookingWithId? _selectedBooking;

    public bool CanEditOrDelete => SelectedBooking != null && !IsLoading;

    public ObservableCollection<BookingWithId> Bookings { get; } = new();

    // События для вызова диалоговых окон из View
    public Func<Booking?, Task<Booking?>>? ShowBookingDialogAsync;
    public Func<string, Task<bool>>? ShowConfirmDialogAsync;
    public Action<string>? ShowErrorAsync;

    [RelayCommand]
    private async Task LoginAsync()
    {
        try
        {
            IsLoading = true;
            StatusMessage = "Авторизация...";
            
            string token = await _api.AuthenticateAsync(Username, Password);
            
            IsAuthenticated = true;
            StatusMessage = $"Авторизован. Токен: {token}";
        }
        catch (Exception ex)
        {
            StatusMessage = $"Ошибка: {ex.Message}";
            ShowErrorAsync?.Invoke(ex.Message);
        }
        finally
        {
            IsLoading = false;
        }
    }

    [RelayCommand]
    private async Task LoadBookingsAsync()
    {
        try
        {
            IsLoading = true;
            Bookings.Clear();
            StatusMessage = "Получение списка ID...";

            var ids = await _api.GetBookingIdsAsync();
            StatusMessage = $"Найдено {ids.Count} ID. Загружаю детали (батчами)...";

            int loadedCount = 0;
            int targetCount = 10; // По заданию нужно 10 успешных
            int batchSize = 20;

            for (int i = 0; i < ids.Count && loadedCount < targetCount; i += batchSize)
            {
                var tasks = new List<Task<BookingWithId?>>();
                int currentBatchSize = Math.Min(batchSize, ids.Count - i);

                for (int j = 0; j < currentBatchSize; j++)
                {
                    tasks.Add(_api.GetBookingDetailsAsync(ids[i + j]));
                }

                // Ждем завершения всех запросов в батче параллельно
                var results = await Task.WhenAll(tasks);

                foreach (var result in results)
                {
                    if (result != null && loadedCount < targetCount)
                    {
                        Bookings.Add(result);
                        loadedCount++;
                    }
                }
            }

            StatusMessage = $"Готово. Показано {loadedCount} бронирований.";
        }
        catch (Exception ex)
        {
            StatusMessage = $"Ошибка загрузки: {ex.Message}";
        }
        finally
        {
            IsLoading = false;
        }
    }

    [RelayCommand]
    private async Task AddBookingAsync()
    {
        if (ShowBookingDialogAsync == null) return;

        var newBookingData = await ShowBookingDialogAsync(null);
        if (newBookingData == null) return; // Отмена

        try
        {
            IsLoading = true;
            StatusMessage = "Создание бронирования...";
            
            var created = await _api.CreateBookingAsync(newBookingData);
            
            // Добавляем в начало списка
            Bookings.Insert(0, created);
            SelectedBooking = created;
            StatusMessage = $"Бронирование #{created.Id} успешно создано.";
        }
        catch (Exception ex)
        {
            StatusMessage = "Ошибка создания";
            ShowErrorAsync?.Invoke(ex.Message);
        }
        finally
        {
            IsLoading = false;
        }
    }

    [RelayCommand]
    private async Task EditBookingAsync()
    {
        if (SelectedBooking == null || ShowBookingDialogAsync == null) return;

        var currentData = SelectedBooking.BookingDetails;
        var updatedData = await ShowBookingDialogAsync(currentData);
        if (updatedData == null) return; // Отмена

        try
        {
            IsLoading = true;
            StatusMessage = $"Обновление бронирования #{SelectedBooking.Id}...";
            
            await _api.UpdateBookingAsync(SelectedBooking.Id, updatedData);
            
            // Обновляем данные в UI
            SelectedBooking.BookingDetails = updatedData;
            
            // Трюк для обновления DataGrid: переприсваиваем элемент
            int idx = Bookings.IndexOf(SelectedBooking);
            var temp = SelectedBooking;
            Bookings[idx] = temp;
            SelectedBooking = temp;

            StatusMessage = $"Бронирование #{SelectedBooking.Id} успешно обновлено.";
        }
        catch (Exception ex)
        {
            StatusMessage = "Ошибка обновления";
            ShowErrorAsync?.Invoke(ex.Message);
        }
        finally
        {
            IsLoading = false;
        }
    }

    [RelayCommand]
    private async Task DeleteBookingAsync()
    {
        if (SelectedBooking == null || ShowConfirmDialogAsync == null) return;

        bool confirm = await ShowConfirmDialogAsync($"Вы действительно хотите удалить бронирование #{SelectedBooking.Id} ({SelectedBooking.FirstName} {SelectedBooking.LastName})?");
        if (!confirm) return;

        try
        {
            IsLoading = true;
            StatusMessage = $"Удаление бронирования #{SelectedBooking.Id}...";
            
            await _api.DeleteBookingAsync(SelectedBooking.Id);
            
            Bookings.Remove(SelectedBooking);
            SelectedBooking = null;
            
            StatusMessage = "Бронирование успешно удалено.";
        }
        catch (Exception ex)
        {
            StatusMessage = "Ошибка удаления";
            ShowErrorAsync?.Invoke(ex.Message);
        }
        finally
        {
            IsLoading = false;
        }
    }
}
```
</details>