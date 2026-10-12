package lab06

enum class TransactionType { DEPOSIT, WITHDRAWAL }

data class Transaction(
    val accountNumber: String,
    val type: TransactionType,
    val amount: Double,
    val balanceAfter: Double,
)

fun interface TransactionLogger {
    fun record(transaction: Transaction)
}

object NoOpTransactionLogger : TransactionLogger {
    override fun record(transaction: Transaction) = Unit
}

class BankAccount(
    val accountNumber: String,
    initialBalance: Double = 0.0,
    private val logger: TransactionLogger = NoOpTransactionLogger,
) {
    private var currentBalance: Double = initialBalance

    init {
        require(accountNumber.isNotBlank()) { "Номер счёта не должен быть пустым" }
        require(initialBalance.isFinite() && initialBalance >= 0.0) {
            "Начальный баланс должен быть конечным и неотрицательным"
        }
    }

    fun deposit(amount: Double) {
        requireValidAmount(amount)
        currentBalance += amount
        logger.record(Transaction(accountNumber, TransactionType.DEPOSIT, amount, currentBalance))
    }

    fun withdraw(amount: Double) {
        requireValidAmount(amount)
        require(amount <= currentBalance) { "Insufficient funds" }
        currentBalance -= amount
        logger.record(Transaction(accountNumber, TransactionType.WITHDRAWAL, amount, currentBalance))
    }

    fun getBalance(): Double = currentBalance

    private fun requireValidAmount(amount: Double) {
        require(amount.isFinite() && amount > 0.0) { "Сумма должна быть конечной и положительной" }
    }
}
