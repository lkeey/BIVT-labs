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
    [NotifyPropertyChangedFor(nameof(CanLoad))]
    [NotifyPropertyChangedFor(nameof(CanAdd))]
    [NotifyPropertyChangedFor(nameof(CanEditOrDelete))]
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
            
            // Создаем новый объект, чтобы Avalonia DataGrid гарантированно заметил изменения и обновил строку
            int idx = Bookings.IndexOf(SelectedBooking);
            if (idx >= 0)
            {
                var updatedItem = new BookingWithId { Id = SelectedBooking.Id, BookingDetails = updatedData };
                Bookings[idx] = updatedItem;
                SelectedBooking = updatedItem;
            }

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