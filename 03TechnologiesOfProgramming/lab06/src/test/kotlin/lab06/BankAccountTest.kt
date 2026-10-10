package lab06

import org.junit.jupiter.api.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class BankAccountTest {
    private class MockTransactionLogger : TransactionLogger {
        val recorded = mutableListOf<Transaction>()
        override fun record(transaction: Transaction) {
            recorded += transaction
        }
    }

    @Test
    fun `creates account with default and supplied balance`() {
        assertEquals(0.0, BankAccount("A-1").getBalance())
        assertEquals(125.5, BankAccount("A-2", 125.5).getBalance())
    }

    @Test
    fun `rejects negative initial balance and blank account number`() {
        assertFailsWith<IllegalArgumentException> { BankAccount("A-1", -1.0) }
        assertFailsWith<IllegalArgumentException> { BankAccount(" ") }
    }

    @Test
    fun `deposit changes balance and records transaction in mock`() {
        val mockLogger = MockTransactionLogger()
        val account = BankAccount("A-1", logger = mockLogger)

        account.deposit(125.0)

        assertEquals(125.0, account.getBalance())
        assertEquals(listOf(Transaction("A-1", TransactionType.DEPOSIT, 125.0, 125.0)), mockLogger.recorded)
    }

    @Test
    fun `rejects zero negative and non-finite deposit`() {
        val account = BankAccount("A-1")
        for (amount in listOf(0.0, -1.0, Double.NaN, Double.POSITIVE_INFINITY)) {
            assertFailsWith<IllegalArgumentException> { account.deposit(amount) }
        }
        assertEquals(0.0, account.getBalance())
    }

    @Test
    fun `withdraws available amount and records transaction`() {
        val mockLogger = MockTransactionLogger()
        val account = BankAccount("A-1", 200.0, mockLogger)

        account.withdraw(75.0)

        assertEquals(125.0, account.getBalance())
        assertEquals(TransactionType.WITHDRAWAL, mockLogger.recorded.single().type)
    }

    @Test
    fun `rejects withdrawal greater than balance without logging`() {
        val mockLogger = MockTransactionLogger()
        val account = BankAccount("A-1", 25.0, mockLogger)

        val error = assertFailsWith<IllegalArgumentException> { account.withdraw(26.0) }

        assertEquals("Insufficient funds", error.message)
        assertEquals(25.0, account.getBalance())
        assertEquals(0, mockLogger.recorded.size)
    }

    @Test
    fun `rejects zero and negative withdrawal`() {
        val account = BankAccount("A-1", 25.0)
        for (amount in listOf(0.0, -2.0)) {
            assertFailsWith<IllegalArgumentException> { account.withdraw(amount) }
        }
        assertEquals(25.0, account.getBalance())
    }
}
