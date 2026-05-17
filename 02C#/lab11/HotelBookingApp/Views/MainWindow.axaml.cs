using System.Threading.Tasks;
using Avalonia.Controls;
using HotelBookingApp.Models;
using HotelBookingApp.ViewModels;
using MsBox.Avalonia;
using MsBox.Avalonia.Enums;

namespace HotelBookingApp.Views;

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        
        var vm = new MainWindowViewModel();
        DataContext = vm;

        // Подключаем диалоги
        vm.ShowErrorAsync = async (msg) =>
        {
            var box = MessageBoxManager.GetMessageBoxStandard("Ошибка", msg, ButtonEnum.Ok, MsBox.Avalonia.Enums.Icon.Error);
            await box.ShowAsync();
        };

        vm.ShowConfirmDialogAsync = async (msg) =>
        {
            var box = MessageBoxManager.GetMessageBoxStandard("Подтверждение", msg, ButtonEnum.YesNo, MsBox.Avalonia.Enums.Icon.Question);
            var result = await box.ShowAsync();
            return result == ButtonResult.Yes;
        };

        vm.ShowBookingDialogAsync = async (booking) =>
        {
            var dialog = new BookingDialog(booking);
            var result = await dialog.ShowDialog<Booking?>(this);
            return result;
        };
    }
}