namespace BankAccount
{
    public class Account
    {
        private double balance;

        public Account()
        {
            balance = 0.0;
        }

        public double GetBalance()
        {
            return balance;
        }

        public double GetBalanceInCurrency(Currency currency)
        {
            return currency.ConvertFromBase(balance);
        }

        public bool Deposit(double amount, Currency currency)
        {
            if (amount <= 0)
            {
                return false;
            }

            double amountInBase = currency.ConvertToBase(amount);
            balance += amountInBase;
            return true;
        }

        public bool Withdraw(double amount, Currency currency)
        {
            if (amount <= 0)
            {
                return false;
            }

            double amountInBase = currency.ConvertToBase(amount);

            if (balance < amountInBase)
            {
                return false;
            }

            balance -= amountInBase;
            return true;
        }
    }
}
