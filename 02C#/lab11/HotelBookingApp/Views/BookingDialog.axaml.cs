using System;
using Avalonia.Controls;
using Avalonia.Interactivity;
using HotelBookingApp.Models;

namespace HotelBookingApp.Views;

public partial class BookingDialog : Window
{
    public BookingDialog()
    {
        InitializeComponent();
    }

    public BookingDialog(Booking? existingBooking) : this()
    {
        if (existingBooking != null)
        {
            FirstNameBox.Text = existingBooking.firstname;
            LastNameBox.Text = existingBooking.lastname;
            PriceBox.Text = existingBooking.totalprice.ToString();
            DepositBox.IsChecked = existingBooking.depositpaid;
            CheckInBox.Text = existingBooking.bookingdates.checkin;
            CheckOutBox.Text = existingBooking.bookingdates.checkout;
            NeedsBox.Text = existingBooking.additionalneeds;
        }
        else
        {
            // Дефолтные значения для нового
            CheckInBox.Text = DateTime.Now.ToString("yyyy-MM-dd");
            CheckOutBox.Text = DateTime.Now.AddDays(1).ToString("yyyy-MM-dd");
        }
    }

    private void Save_Click(object? sender, RoutedEventArgs e)
    {
        // Базовая валидация
        if (string.IsNullOrWhiteSpace(FirstNameBox.Text) ||
            string.IsNullOrWhiteSpace(LastNameBox.Text) ||
            !int.TryParse(PriceBox.Text, out int price))
        {
            // В реальном приложении тут нужно показать ошибку валидации
            return;
        }

        var booking = new Booking
        {
            firstname = FirstNameBox.Text,
            lastname = LastNameBox.Text,
            totalprice = price,
            depositpaid = DepositBox.IsChecked ?? false,
            bookingdates = new BookingDates
            {
                checkin = CheckInBox.Text ?? "",
                checkout = CheckOutBox.Text ?? ""
            },
            additionalneeds = NeedsBox.Text ?? ""
        };

        Close(booking);
    }

    private void Cancel_Click(object? sender, RoutedEventArgs e)
    {
        Close(null);
    }
}