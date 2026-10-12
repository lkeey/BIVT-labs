package lab06

fun main() {
    val account = BankAccount("40817810000000000001", initialBalance = 1000.0)
    account.deposit(500.0)
    account.withdraw(250.0)
    println("Счёт ${account.accountNumber}: баланс=${"%.2f".format(account.getBalance())}")
}
