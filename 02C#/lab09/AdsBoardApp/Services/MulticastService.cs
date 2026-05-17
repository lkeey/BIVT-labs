using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace AdsBoardApp.Services;

public class MulticastService
{
    private const string HOST = "235.5.5.1";
    private const int PORT = 8001;
    private const int TTL = 20;

    private readonly IPAddress groupAddress = IPAddress.Parse(HOST);
    private readonly ConcurrentDictionary<string, (IPAddress Ip, int Port)> sellerContacts = new();

    private UdpClient? client;
    private UdpClient? chatClient;
    private Task? receiveTask;
    private Task? chatReceiveTask;
    private CancellationTokenSource? cts;
    private volatile bool alive;
    private string userName = string.Empty;

    public int ChatPort { get; private set; }
    public bool IsOnline => alive;
    public string UserName => userName;

    public event Action<string, string, string, string>? AdReceived;
    public event Action<string>? SystemReceived;
    public event Action<string, string>? PrivateMessageReceived;

    public void Login(string name)
    {
        if (alive) return;

        userName = name;

        Socket socket = new Socket(AddressFamily.InterNetwork, SocketType.Dgram, ProtocolType.Udp);
        socket.SetSocketOption(SocketOptionLevel.Socket, SocketOptionName.ReuseAddress, true);
        socket.Bind(new IPEndPoint(IPAddress.Any, PORT));
        client = new UdpClient { Client = socket };
        client.JoinMulticastGroup(groupAddress, TTL);

        chatClient = new UdpClient(0);
        ChatPort = ((IPEndPoint)chatClient.Client.LocalEndPoint!).Port;

        alive = true;
        cts = new CancellationTokenSource();
        receiveTask = Task.Run(ReceiveLoopAsync);
        chatReceiveTask = Task.Run(ChatReceiveLoopAsync);

        SendSystem($"{userName} вошёл на доску объявлений");
    }

    public void Logout()
    {
        if (!alive) return;

        SendSystem($"{userName} покинул доску объявлений");

        // alive=false ДО закрытия сокетов, чтобы фоновые потоки
        // распознали штатное завершение и не пробросили исключение.
        alive = false;
        cts?.Cancel();

        try { client?.DropMulticastGroup(groupAddress); } catch { }

        // Дожидаемся фактического завершения фоновых потоков, иначе при
        // быстром повторном входе старые циклы продолжают читать порт
        // и UI зависает.
        try { receiveTask?.Wait(TimeSpan.FromSeconds(2)); } catch { }
        try { chatReceiveTask?.Wait(TimeSpan.FromSeconds(2)); } catch { }

        // Close() будит блокирующий Receive() через ObjectDisposedException.
        // Сокеты закрываем ДО зануления полей, иначе поток может
        // обратиться к уже null-ссылке.
        client?.Close();
        chatClient?.Close();

        client = null;
        chatClient = null;
        receiveTask = null;
        chatReceiveTask = null;
        cts?.Dispose();
        cts = null;
        sellerContacts.Clear();
    }

    public void PublishAd(string title, string price)
    {
        if (!alive || client == null) return;

        string packed = string.Join("|", "AD", userName, title, price, ChatPort.ToString());
        byte[] data = Encoding.Unicode.GetBytes(packed);
        client.Send(data, data.Length, HOST, PORT);
    }

    public bool SendPrivateMessage(string sellerName, string text)
    {
        if (!sellerContacts.TryGetValue(sellerName, out var contact)) return false;

        using UdpClient directSender = new UdpClient();
        string packed = string.Join("|", "MSG", userName, text);
        byte[] data = Encoding.Unicode.GetBytes(packed);
        directSender.Send(data, data.Length, contact.Ip.ToString(), contact.Port);
        return true;
    }

    private void SendSystem(string text)
    {
        if (client == null) return;
        string packed = string.Join("|", "SYS", text);
        byte[] data = Encoding.Unicode.GetBytes(packed);
        client.Send(data, data.Length, HOST, PORT);
    }

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
                if (parts.Length == 0) continue;

                switch (parts[0])
                {
                    case "AD":
                        if (parts.Length >= 5)
                        {
                            string seller = parts[1];
                            string title = parts[2];
                            string price = parts[3];
                            if (int.TryParse(parts[4], out int sellerChatPort) && remoteIp != null)
                            {
                                sellerContacts[seller] = (remoteIp.Address, sellerChatPort);
                            }
                            string time = DateTime.Now.ToString("HH:mm");
                            AdReceived?.Invoke(time, seller, title, price);
                        }
                        break;

                    case "SYS":
                        if (parts.Length >= 2)
                        {
                            SystemReceived?.Invoke(parts[1]);
                        }
                        break;
                }
            }
        }
        catch (OperationCanceledException)
        {
            // Expected when cts.Cancel() is called
        }
        catch (ObjectDisposedException)
        {
            if (!alive) return;
            throw;
        }
        catch (SocketException)
        {
            if (!alive) return;
            throw;
        }
    }

    private async Task ChatReceiveLoopAsync()
    {
        UdpClient localChatClient = chatClient!;
        try
        {
            while (alive)
            {
                var result = await localChatClient.ReceiveAsync(cts!.Token);
                byte[] data = result.Buffer;
                string packed = Encoding.Unicode.GetString(data);
                string[] parts = packed.Split('|');

                if (parts.Length >= 3 && parts[0] == "MSG")
                {
                    PrivateMessageReceived?.Invoke(parts[1], parts[2]);
                }
            }
        }
        catch (OperationCanceledException)
        {
            // Expected when cts.Cancel() is called
        }
        catch (ObjectDisposedException)
        {
            if (!alive) return;
            throw;
        }
        catch (SocketException)
        {
            if (!alive) return;
            throw;
        }
    }
}
