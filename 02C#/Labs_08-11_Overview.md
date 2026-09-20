# Обзор лабораторных работ 8-11 по C#

## Лабораторная работа №8: RSS Reader с MySQL

### 1. Теория и термины

- **RSS (Really Simple Syndication)** — формат веб-лент для публикации часто обновляемого контента (новости, блоги)
- **XML (eXtensible Markup Language)** — расширяемый язык разметки для структурированных данных
- **HttpWebRequest/HttpWebResponse** — классы .NET для выполнения HTTP-запросов на низком уровне
- **MySQL** — реляционная СУБД с открытым исходным кодом
- **Docker** — платформа для контейнеризации приложений
- **System.Xml** — пространство имен .NET для работы с XML-документами
- **XmlDocument** — класс для загрузки и манипулирования XML в памяти (DOM-модель)
- **Avalonia UI** — кроссплатформенный UI-фреймворк (альтернатива WPF)

### 2. Основная задача и проверяемые навыки

**Задача:** Создать RSS-ридер с графическим интерфейсом, который загружает RSS-ленты, парсит XML и сохраняет данные в MySQL базу данных.

**Проверяемые навыки:**
- Работа с HTTP-запросами через `HttpWebRequest/HttpWebResponse`
- Парсинг XML-документов с использованием `System.Xml`
- Подключение к MySQL через `MySql.Data`
- Выполнение CRUD-операций с БД (CREATE, INSERT, DELETE, SELECT)
- Работа с Docker для развертывания базы данных
- Создание GUI-приложений на Avalonia UI
- Обработка исключений и валидация данных

### 3. Техническая реализация

#### Структура базы данных

```sql
CREATE DATABASE IF NOT EXISTS rss_news;
USE rss_news;

CREATE TABLE news (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(500) NOT NULL,
    description TEXT,
    link VARCHAR(500),
    pub_date DATETIME,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_pub_date (pub_date)
);
```

#### Загрузка RSS через HttpWebRequest

```csharp
public string DownloadRssFeed()
{
    HttpWebRequest request = (HttpWebRequest)WebRequest.Create(rssUrl);
    request.UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)";
    request.Timeout = 30000;

    using (HttpWebResponse response = (HttpWebResponse)request.GetResponse())
    using (Stream stream = response.GetResponseStream())
    using (StreamReader reader = new StreamReader(stream))
    {
        string rssContent = reader.ReadToEnd();
        return rssContent;
    }
}
```

**Ключевые моменты:**
- `HttpWebRequest.Create()` создает запрос к URL
- `UserAgent` имитирует браузер для обхода блокировок
- `GetResponse()` выполняет запрос и получает ответ
- Использование `using` для автоматического освобождения ресурсов

#### Парсинг XML через XmlDocument

```csharp
public List<NewsItem> ParseRss(string xmlContent)
{
    var news = new List<NewsItem>();
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

    return news;
}
```

**Ключевые моменты:**
- `XmlDocument.LoadXml()` загружает XML-строку в DOM-структуру
- `GetElementsByTagName()` находит все элементы по имени тега
- Навигация через индексатор `item["tagName"]`
- Оператор `?.` для безопасного доступа к свойствам (null-conditional)

#### Работа с MySQL

```csharp
using (var connection = new MySqlConnection(connectionString))
{
    connection.Open();

    // Удаление старых записей
    var deleteCmd = new MySqlCommand("DELETE FROM news", connection);
    deleteCmd.ExecuteNonQuery();

    // Вставка новых данных
    foreach (var item in newsItems)
    {
        var insertCmd = new MySqlCommand(
            "INSERT INTO news (title, description, link, pub_date) VALUES (@title, @desc, @link, @date)",
            connection
        );
        insertCmd.Parameters.AddWithValue("@title", item.Title);
        insertCmd.Parameters.AddWithValue("@desc", item.Description);
        insertCmd.Parameters.AddWithValue("@link", item.Link);
        insertCmd.Parameters.AddWithValue("@date", item.PubDate);
        insertCmd.ExecuteNonQuery();
    }
}
```

---

## Лабораторная работа №9: Сетевое программирование (UDP Multicast)

### 1. Теория и термины

- **UDP (User Datagram Protocol)** — протокол транспортного уровня без установки соединения
- **Multicast** — групповая рассылка пакетов по IP-адресам диапазона 224.0.0.0-239.255.255.255
- **Unicast** — отправка пакета одному конкретному получателю
- **TTL (Time To Live)** — время жизни пакета (количество маршрутизаторов, через которые он может пройти)
- **Порт** — числовой идентификатор (0-65535) процесса на хосте
- **IPEndPoint** — комбинация IP-адреса и порта
- **Socket** — низкоуровневый интерфейс для сетевого взаимодействия
- **ReuseAddress** — опция сокета, позволяющая нескольким процессам слушать один порт
- **Dispatcher.UIThread.Post** — метод для обновления UI из фонового потока (Avalonia)

### 2. Основная задача и проверяемые навыки

**Задача:** Реализовать распределенную доску объявлений с использованием UDP multicast для публичных объявлений и UDP unicast для личных сообщений между пользователями.

**Проверяемые навыки:**
- Работа с UDP через `UdpClient`
- Настройка multicast-группы (`JoinMulticastGroup`)
- Организация фоновых потоков для приема данных (`Task.Run`)
- Синхронизация доступа к UI из фоновых потоков
- Разработка текстового протокола обмена сообщениями
- Корректное завершение работы с сетевыми ресурсами
- Обработка исключений при работе с сокетами

### 3. Техническая реализация

#### Структура протокола

| Тип сообщения | Формат | Транспорт |
|--------------|--------|-----------|
| Объявление | `AD\|имя\|заголовок\|цена\|chatPort` | multicast 235.5.5.1:8001 |
| Системное | `SYS\|текст` | multicast 235.5.5.1:8001 |
| Личное | `MSG\|отправитель\|текст` | unicast (IP + chatPort) |

#### Инициализация multicast-соединения

```csharp
public void Login(string name)
{
    userName = name;

    // Создание сокета с опцией ReuseAddress
    Socket socket = new Socket(AddressFamily.InterNetwork, SocketType.Dgram, ProtocolType.Udp);
    socket.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.ReuseAddress, true);
    socket.Bind(new IPEndPoint(IPAddress.Any, PORT));

    client = new UdpClient { Client = socket };
    client.JoinMulticastGroup(groupAddress, TTL);

    // Второй сокет для личных сообщений (unicast)
    chatClient = new UdpClient(0); // 0 = система выберет свободный порт
    ChatPort = ((IPEndPoint)chatClient.Client.LocalEndPoint!).Port;

    alive = true;
    cts = new CancellationTokenSource();
    receiveTask = Task.Run(ReceiveLoopAsync);
    chatReceiveTask = Task.Run(ChatReceiveLoopAsync);

    SendSystem($"{userName} вошёл на доску объявлений");
}
```

**Ключевые моменты:**
- `ReuseAddress = true` позволяет запустить несколько экземпляров на одной машине
- `JoinMulticastGroup()` подписывает на получение пакетов из multicast-группы
- Два отдельных сокета: один для multicast, другой для unicast
- Фоновые задачи для неблокирующего приема сообщений

#### Отправка multicast-объявления

```csharp
public void PublishAd(string title, string price)
{
    if (!alive || client == null) return;

    string packed = string.Join("|", "AD", userName, title, price, ChatPort.ToString());
    byte[] data = Encoding.Unicode.GetBytes(packed);
    client.Send(data, data.Length, HOST, PORT);
}
```

#### Отправка личного сообщения (unicast)

```csharp
public bool SendPrivateMessage(string sellerName, string text)
{
    if (!sellerContacts.TryGetValue(sellerName, out var contact))
        return false;

    using UdpClient directSender = new UdpClient();
    string packed = string.Join("|", "MSG", userName, text);
    byte[] data = Encoding.Unicode.GetBytes(packed);
    directSender.Send(data, data.Length, contact.Ip.ToString(), contact.Port);
    return true;
}
```

**Ключевые моменты:**
- Словарь `sellerContacts` хранит IP и порт каждого продавца
- IP берется из `remoteEndPoint` при получении AD-сообщения
- Создается новый `UdpClient` для прямой отправки

#### Фоновый прием multicast-сообщений

```csharp
private async Task ReceiveLoopAsync()
{
    UdpClient localClient = client!;
    try
    {
        while (alive)
        {
            var result = await localClient.ReceiveAsync(cts!.Token);
            byte[] data = result.Buffer;
            IPEndPoint remoteIp = result.RemoteEndPoint;
            string packed = Encoding.Unicode.GetString(data);
            string[] parts = packed.Split('|');

            switch (parts[0])
            {
                case "AD":
                    if (parts.Length >= 5)
                    {
                        string seller = parts[1];
                        // Сохраняем контакт продавца
                        if (int.TryParse(parts[4], out int sellerChatPort))
                        {
                            sellerContacts[seller] = (remoteIp.Address, sellerChatPort);
                        }
                        AdReceived?.Invoke(parts[1], parts[2], parts[3], parts[4]);
                    }
                    break;

                case "SYS":
                    SystemReceived?.Invoke(parts[1]);
                    break;
            }
        }
    }
    catch (OperationCanceledException) { }
    catch (ObjectDisposedException) { if (!alive) return; throw; }
}
```

**Ключевые моменты:**
- `ReceiveAsync()` — асинхронный прием данных
- `remoteEndPoint` содержит IP отправителя
- События (`AdReceived`, `SystemReceived`) для передачи данных в UI
- Проверка флага `alive` при `ObjectDisposedException` для штатного завершения

#### Корректное завершение

```csharp
public void Logout()
{
    if (!alive) return;

    SendSystem($"{userName} покинул доску объявлений");

    // ВАЖНО: alive=false ДО закрытия сокетов
    alive = false;
    cts?.Cancel();

    try { client?.DropMulticastGroup(groupAddress); } catch { }

    // Ожидание завершения фоновых задач
    try { receiveTask?.Wait(TimeSpan.FromSeconds(2)); } catch { }
    try { chatReceiveTask?.Wait(TimeSpan.FromSeconds(2)); } catch { }

    // Закрытие сокетов вызовет ObjectDisposedException в ReceiveAsync
    client?.Close();
    chatClient?.Close();

    sellerContacts.Clear();
}
```

**Почему флаг `alive = false` должен быть ДО `Close()`:**
Метод `Close()` синхронно прерывает `ReceiveAsync()` через `ObjectDisposedException`. Фоновый поток проверяет флаг `alive`: если он `false`, значит сокет закрыт намеренно, и поток молча завершается. Если установить флаг после `Close()`, будет race condition.

---

## Лабораторная работа №10: Многопоточное программирование (Задача о рюкзаке)

### 1. Теория и термины

- **TPL (Task Parallel Library)** — библиотека .NET для параллельного программирования
- **Parallel.For** — параллельный цикл с автоматическим распределением итераций
- **Thread-Local Storage (TLS)** — локальные для потока данные
- **ThreadPool** — пул потоков, управляемый runtime .NET
- **Race Condition** — состояние гонки при доступе к общим данным из нескольких потоков
- **lock** — оператор для синхронизации доступа к критической секции
- **MaxDegreeOfParallelism** — максимальное количество одновременно выполняющихся потоков
- **Context Switch** — переключение контекста выполнения между потоками
- **Закон Амдала** — теоретический предел ускорения при распараллеливании

### 2. Основная задача и проверяемые навыки

**Задача:** Решить задачу о рюкзаке методом полного перебора (2^25 комбинаций) с использованием параллельного программирования и провести бенчмарк-анализ масштабируемости.

**Проверяемые навыки:**
- Реализация алгоритмов с использованием `Parallel.For`
- Применение Thread-Local Storage для потокобезопасности
- Работа с низкоуровневым классом `Thread`
- Ручная декомпозиция данных между потоками
- Синхронизация через `lock`
- Измерение производительности и построение графиков
- Анализ масштабируемости параллельных алгоритмов

### 3. Техническая реализация

#### Последовательный алгоритм (базовая линия)

```csharp
public KnapsackResult SolveSequential()
{
    int maxValue = 0;
    int bestCombination = 0;
    int bestWeight = 0;
    int totalCombinations = 1 << items.Length; // 2^25 = 33,554,432

    for (int i = 0; i < totalCombinations; i++)
    {
        int currentWeight = 0;
        int currentValue = 0;

        // Проверяем каждый бит комбинации
        for (int j = 0; j < items.Length; j++)
        {
            if ((i & (1 << j)) != 0)
            {
                currentWeight += items[j].Weight;
                currentValue += items[j].Value;
            }
        }

        if (currentWeight <= maxWeight && currentValue > maxValue)
        {
            maxValue = currentValue;
            bestCombination = i;
            bestWeight = currentWeight;
        }
    }

    return new KnapsackResult { MaxValue = maxValue, BestCombination = bestCombination };
}
```

**Ключевые моменты:**
- Битовые операции для представления комбинации: бит 1 = предмет взят
- `(i & (1 << j)) != 0` проверяет j-й бит числа i
- Перебор всех 2^n комбинаций

#### Параллельная реализация через Parallel.For с TLS

```csharp
public KnapsackResult SolveParallelFor(int maxDegreeOfParallelism)
{
    int globalMaxValue = 0;
    int globalBestCombination = 0;
    int globalBestWeight = 0;

    var options = new ParallelOptions { MaxDegreeOfParallelism = maxDegreeOfParallelism };

    Parallel.For(0, totalCombinations, options,
        // localInit: инициализация локальных данных для каждого потока
        () => new KnapsackResult { MaxValue = 0 },

        // body: выполняется для каждой итерации
        (i, state, localResult) =>
        {
            int currentWeight = 0;
            int currentValue = 0;

            for (int j = 0; j < items.Length; j++)
            {
                if ((i & (1 << j)) != 0)
                {
                    currentWeight += items[j].Weight;
                    currentValue += items[j].Value;
                }
            }

            // Обновляем ЛОКАЛЬНЫЙ результат (без синхронизации)
            if (currentWeight <= maxWeight && currentValue > localResult.MaxValue)
            {
                localResult.MaxValue = currentValue;
                localResult.BestCombination = i;
                localResult.TotalWeight = currentWeight;
            }

            return localResult;
        },

        // localFinally: объединение результатов с СИНХРОНИЗАЦИЕЙ
        localResult =>
        {
            lock (this)
            {
                if (localResult.MaxValue > globalMaxValue)
                {
                    globalMaxValue = localResult.MaxValue;
                    globalBestCombination = localResult.BestCombination;
                    globalBestWeight = localResult.TotalWeight;
                }
            }
        });

    return new KnapsackResult { MaxValue = globalMaxValue };
}
```

**Ключевые моменты:**
- **localInit**: создает изолированную структуру данных для каждого потока
- **body**: выполняется параллельно без блокировок (работа с TLS)
- **localFinally**: вызывается один раз на поток для слияния результатов с синхронизацией
- `lock(this)` защищает глобальные переменные от race condition

#### Параллельная реализация через сырые потоки (Thread)

```csharp
public KnapsackResult SolveThreads(int numThreads)
{
    int globalMaxValue = 0;
    int globalBestCombination = 0;
    object locker = new object();

    Thread[] threads = new Thread[numThreads];
    int chunkSize = totalCombinations / numThreads;
    int remainder = totalCombinations % numThreads;

    int startIdx = 0;

    for (int t = 0; t < numThreads; t++)
    {
        int start = startIdx;
        int end = start + chunkSize + (t < remainder ? 1 : 0);
        startIdx = end;

        threads[t] = new Thread(() =>
        {
            int localMaxValue = 0;
            int localBestCombination = 0;

            // Обработка своего диапазона итераций
            for (int i = start; i < end; i++)
            {
                // ... та же логика перебора ...

                if (currentWeight <= maxWeight && currentValue > localMaxValue)
                {
                    localMaxValue = currentValue;
                    localBestCombination = i;
                }
            }

            // Синхронизированное обновление глобального результата
            lock (locker)
            {
                if (localMaxValue > globalMaxValue)
                {
                    globalMaxValue = localMaxValue;
                    globalBestCombination = localBestCombination;
                }
            }
        });

        threads[t].Start();
    }

    // Ожидание завершения всех потоков
    foreach (var thread in threads)
    {
        thread.Join();
    }

    return new KnapsackResult { MaxValue = globalMaxValue };
}
```

**Ключевые моменты:**
- Ручная декомпозиция: диапазон итераций делится поровну между потоками
- Остаток от деления распределяется между первыми потоками
- Каждый поток работает со своим диапазоном без пересечений
- `Thread.Join()` блокирует до завершения потока

#### Контрольные вопросы

**Почему малое число итераций может быть медленнее при параллелизме?**
Создание потоков, распределение задач и синхронизация требуют времени (накладные расходы). Если вычисления занимают меньше времени, чем эти расходы, последовательный код быстрее.

**Что произойдет без `lock`?**
Возникнет race condition: несколько потоков одновременно читают и пишут `globalMaxValue`, часть обновлений будет потеряна.

**Закон Амдала:**
Общее ускорение ограничено последовательной частью программы. Если 10% кода нельзя распараллелить, максимальное ускорение ≤ 10x, независимо от количества ядер.

---

## Лабораторная работа №11: Протокол HTTP. Асинхронное программирование

### 1. Теория и термины

- **REST API (Representational State Transfer)** — архитектурный стиль для построения веб-сервисов
- **HTTP методы**: GET (чтение), POST (создание), PUT (обновление), DELETE (удаление)
- **JSON (JavaScript Object Notation)** — текстовый формат обмена данными
- **HttpClient** — класс .NET для отправки HTTP-запросов
- **async/await** — ключевые слова C# для асинхронного программирования
- **Заголовок Accept** — указывает серверу желаемый формат ответа
- **Токен авторизации** — строка для идентификации клиента (обычно передается в Cookie или Authorization)
- **Сериализация/Десериализация** — преобразование объектов в JSON и обратно
- **CRUD** — Create, Read, Update, Delete (базовые операции с данными)

### 2. Основная задача и проверяемые навыки

**Задача:** Разработать клиентское приложение для работы с REST API сервиса бронирования отелей с полной поддержкой CRUD-операций.

**Проверяемые навыки:**
- Работа с HTTP через `HttpClient`
- Формирование HTTP-запросов (методы, заголовки, тело)
- Асинхронное программирование (`async`/`await`)
- Сериализация и десериализация JSON (`Newtonsoft.Json`)
- Реализация авторизации с токеном
- Обработка HTTP-ошибок и статус-кодов
- Паттерн MVVM для разделения логики и UI

### 3. Техническая реализация

#### Модели данных

```csharp
public class AuthRequest
{
    public string username { get; set; }
    public string password { get; set; }
}

public class AuthResponse
{
    public string token { get; set; }
}

public class Booking
{
    public string firstname { get; set; }
    public string lastname { get; set; }
    public int totalprice { get; set; }
    public bool depositpaid { get; set; }
    public BookingDates bookingdates { get; set; }
    public string additionalneeds { get; set; }
}

public class BookingDates
{
    public string checkin { get; set; }
    public string checkout { get; set; }
}
```

#### Инициализация HttpClient (singleton)

```csharp
public class BookingApiService
{
    private const string BASE_URL = "http://restful-booker.herokuapp.com";

    // ВАЖНО: один статический HttpClient на всё приложение (best practice)
    private static readonly HttpClient Http = new HttpClient
    {
        Timeout = TimeSpan.FromSeconds(15)
    };

    private string _token = string.Empty;

    public BookingApiService()
    {
        // Устанавливаем заголовок Accept для всех запросов
        if (!Http.DefaultRequestHeaders.Accept.Contains(
            new MediaTypeWithQualityHeaderValue("application/json")))
        {
            Http.DefaultRequestHeaders.Accept.Add(
                new MediaTypeWithQualityHeaderValue("application/json")
            );
        }
    }
}
```

**Почему статический HttpClient:**
- Создание нового `HttpClient` на каждый запрос приводит к исчерпанию сокетов (socket exhaustion)
- `HttpClient` предназначен для переиспользования
- `static` гарантирует один экземпляр на приложение

#### Авторизация (POST /auth)

```csharp
public async Task<string> AuthenticateAsync(string username, string password)
{
    var reqBody = new AuthRequest { username = username, password = password };
    string jsonBody = JsonConvert.SerializeObject(reqBody);
    var content = new StringContent(jsonBody, Encoding.UTF8, "application/json");

    var response = await Http.PostAsync($"{BASE_URL}/auth", content);
    response.EnsureSuccessStatusCode(); // Бросит исключение если код != 2xx

    string responseStr = await response.Content.ReadAsStringAsync();
    var authObj = JsonConvert.DeserializeObject<AuthResponse>(responseStr);

    if (authObj == null || string.IsNullOrEmpty(authObj.token))
    {
        throw new Exception("Неверный логин или пароль");
    }

    _token = authObj.token;
    return _token;
}
```

**Ключевые моменты:**
- `JsonConvert.SerializeObject()` преобразует объект C# в JSON-строку
- `StringContent` оборачивает JSON для HTTP-запроса
- `PostAsync()` выполняет асинхронный POST-запрос
- `EnsureSuccessStatusCode()` проверяет статус ответа
- `JsonConvert.DeserializeObject<T>()` преобразует JSON в объект C#

#### Получение списка бронирований (GET /booking)

```csharp
public async Task<List<int>> GetBookingIdsAsync()
{
    var response = await Http.GetAsync($"{BASE_URL}/booking");
    response.EnsureSuccessStatusCode();

    string json = await response.Content.ReadAsStringAsync();
    var ids = JsonConvert.DeserializeObject<List<BookingIdResponse>>(json);

    return ids.Select(x => x.bookingid).ToList();
}
```

#### Получение деталей бронирования (GET /booking/{id})

```csharp
public async Task<BookingWithId?> GetBookingDetailsAsync(int id)
{
    var response = await Http.GetAsync($"{BASE_URL}/booking/{id}");
    if (!response.IsSuccessStatusCode)
        return null;

    string json = await response.Content.ReadAsStringAsync();

    // Проверка на случай некорректного ответа (XML вместо JSON)
    if (json.TrimStart().StartsWith("<"))
        return null;

    var booking = JsonConvert.DeserializeObject<Booking>(json);
    if (booking == null) return null;

    return new BookingWithId { Id = id, BookingDetails = booking };
}
```

#### Создание бронирования (POST /booking)

```csharp
public async Task<BookingWithId> CreateBookingAsync(Booking booking)
{
    string jsonBody = JsonConvert.SerializeObject(booking);
    var content = new StringContent(jsonBody, Encoding.UTF8, "application/json");

    var req = new HttpRequestMessage(HttpMethod.Post, $"{BASE_URL}/booking")
    {
        Content = content
    };
    req.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

    var response = await Http.SendAsync(req);
    response.EnsureSuccessStatusCode();

    string responseStr = await response.Content.ReadAsStringAsync();
    var createdObj = JsonConvert.DeserializeObject<dynamic>(responseStr);
    int newId = createdObj.bookingid;

    return new BookingWithId { Id = newId, BookingDetails = booking };
}
```

#### Обновление бронирования (PUT /booking/{id}) — требует токен

```csharp
public async Task UpdateBookingAsync(int id, Booking booking)
{
    if (!IsAuthenticated)
        throw new Exception("Необходима авторизация");

    string jsonBody = JsonConvert.SerializeObject(booking);

    var req = new HttpRequestMessage(HttpMethod.Put, $"{BASE_URL}/booking/{id}");
    req.Content = new StringContent(jsonBody, Encoding.UTF8, "application/json");
    req.Headers.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));

    // ВАЖНО: токен передается в Cookie заголовке
    req.Headers.Add("Cookie", $"token={_token}");

    var response = await Http.SendAsync(req);
    response.EnsureSuccessStatusCode();
}
```

**Ключевые моменты:**
- `HttpRequestMessage` для детального контроля запроса
- Токен передается через заголовок `Cookie: token=...`
- API требует токен для операций модификации

#### Удаление бронирования (DELETE /booking/{id}) — требует токен

```csharp
public async Task DeleteBookingAsync(int id)
{
    if (!IsAuthenticated)
        throw new Exception("Необходима авторизация");

    var req = new HttpRequestMessage(HttpMethod.Delete, $"{BASE_URL}/booking/{id}");
    req.Headers.Add("Cookie", $"token={_token}");

    var response = await Http.SendAsync(req);
    if (!response.IsSuccessStatusCode)
    {
        throw new Exception($"Ошибка удаления. Код: {response.StatusCode}");
    }
}
```

#### Асинхронная загрузка в ViewModel

```csharp
[RelayCommand]
private async Task LoadBookingsAsync()
{
    try
    {
        IsLoading = true;
        Bookings.Clear();
        StatusMessage = "Получение списка ID...";

        var ids = await _api.GetBookingIdsAsync();
        StatusMessage = $"Найдено {ids.Count} ID. Загружаю детали батчами...";

        int loadedCount = 0;
        int batchSize = 20; // Параллельная загрузка батчами

        for (int i = 0; i < ids.Count && loadedCount < 10; i += batchSize)
        {
            var tasks = new List<Task<BookingWithId?>>();

            for (int j = 0; j < batchSize && i + j < ids.Count; j++)
            {
                tasks.Add(_api.GetBookingDetailsAsync(ids[i + j]));
            }

            // Ждем завершения всех запросов в батче ПАРАЛЛЕЛЬНО
            var results = await Task.WhenAll(tasks);

            foreach (var result in results)
            {
                if (result != null && loadedCount < 10)
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
        StatusMessage = $"Ошибка: {ex.Message}";
    }
    finally
    {
        IsLoading = false;
    }
}
```

**Ключевые моменты:**
- `async Task` для асинхронного метода команды
- `await` освобождает UI-поток во время ожидания сетевого ответа
- `Task.WhenAll()` выполняет несколько запросов параллельно
- `try-finally` гарантирует сброс `IsLoading`

#### Контрольные вопросы

**Что такое REST API?**
Архитектурный стиль для распределенных систем, основанный на HTTP и принципах:
- Клиент-серверная архитектура
- Stateless (без сохранения состояния между запросами)
- Стандартные HTTP-методы для CRUD
- Представление данных в JSON/XML

**Зачем заголовок Accept?**
Сообщает серверу, в каком формате клиент хочет получить ответ. `Accept: application/json` означает "ожидаю JSON".

**Зачем async/await при работе с сетью?**
Сетевые запросы занимают время (100-1000 мс). В UI-приложении синхронный запрос заблокирует главный поток, и интерфейс "зависнет". `async/await` освобождает поток на время ожидания, сохраняя отзывчивость UI.

---

## Сравнительная таблица лабораторных работ

| № | Тема | Ключевые технологии | Сложность | Усложненный вариант |
|---|------|---------------------|-----------|---------------------|
| 8 | RSS Reader | HTTP, XML, MySQL, Docker | ⭐⭐⭐ | MySQL вместо SQLite |
| 9 | Сетевое программирование | UDP, Multicast, Unicast | ⭐⭐⭐⭐ | Личные сообщения через unicast |
| 10 | Многопоточность | Parallel.For, Thread, TLS | ⭐⭐⭐⭐ | Сырые потоки + бенчмарк |
| 11 | REST API | HttpClient, JSON, async/await | ⭐⭐⭐ | Полный CRUD (POST, PUT, DELETE) |

---

## Общие паттерны и best practices

### 1. Асинхронное программирование
- Всегда используйте `async/await` для I/O-операций (сеть, файлы, БД)
- Не блокируйте асинхронный код через `.Result` или `.Wait()` — это deadlock
- Именуйте методы с суффиксом `Async` (например, `LoadDataAsync`)

### 2. Работа с сетью
- Используйте один экземпляр `HttpClient` на приложение (лучше `static`)
- Устанавливайте таймауты для предотвращения зависания
- Обрабатывайте ошибки через `try-catch` и проверяйте статус-коды

### 3. Многопоточность
- Используйте `Parallel.For` вместо ручных потоков для CPU-bound задач
- Всегда применяйте синхронизацию (`lock`) при доступе к общим данным
- Для UI обновлений используйте `Dispatcher.UIThread.Post` (Avalonia) или `Invoke` (WinForms)

### 4. Работа с ресурсами
- Используйте `using` для автоматического освобождения (сокеты, соединения, файлы)
- При работе с сокетами корректно устанавливайте флаги завершения ДО закрытия
- Всегда освобождайте ресурсы в `finally` или через `IDisposable`

### 5. Обработка ошибок
- Валидируйте входные данные
- Логируйте исключения для отладки
- Показывайте пользователю понятные сообщения об ошибках

---

## Заключение

Лабораторные работы 8-11 охватывают ключевые аспекты разработки современных приложений на C#:

- **Lab 8**: Интеграция с внешними данными (HTTP, XML) и хранение в БД
- **Lab 9**: Низкоуровневая работа с сетевыми протоколами (UDP, сокеты)
- **Lab 10**: Оптимизация производительности через параллелизм
- **Lab 11**: Взаимодействие с веб-сервисами через REST API

Все работы реализованы с использованием кроссплатформенного UI-фреймворка **Avalonia UI** и современных подходов .NET (async/await, MVVM, dependency injection).
