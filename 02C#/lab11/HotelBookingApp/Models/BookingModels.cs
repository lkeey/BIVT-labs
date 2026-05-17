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