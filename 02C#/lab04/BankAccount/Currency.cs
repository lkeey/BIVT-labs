namespace BankAccount
{
    public class Currency
    {
        private string code;
        private double exchangeRate;

        public string Code
        {
            get { return code; }
        }

        public double ExchangeRate
        {
            get { return exchangeRate; }
        }

        public Currency(string code, double exchangeRate)
        {
            this.code = code;
            this.exchangeRate = exchangeRate;
        }

        public double ConvertToBase(double amount)
        {
            return amount * exchangeRate;
        }

        public double ConvertFromBase(double amount)
        {
            return amount / exchangeRate;
        }

        public override string ToString()
        {
            return $"{code} (курс: {exchangeRate:F2} RUR)";
        }
    }
}
