package lab07

import java.io.File
import java.math.BigDecimal
import org.jetbrains.exposed.v1.core.ReferenceOption
import org.jetbrains.exposed.v1.core.Table
import org.jetbrains.exposed.v1.core.eq
import org.jetbrains.exposed.v1.jdbc.Database
import org.jetbrains.exposed.v1.jdbc.SchemaUtils
import org.jetbrains.exposed.v1.jdbc.deleteWhere
import org.jetbrains.exposed.v1.jdbc.insert
import org.jetbrains.exposed.v1.jdbc.selectAll
import org.jetbrains.exposed.v1.jdbc.transactions.transaction
import org.jetbrains.exposed.v1.jdbc.update

object Categories : Table("categories") {
    val id = integer("id").autoIncrement()
    val name = varchar("name", 100).uniqueIndex()
    override val primaryKey = PrimaryKey(id)
}

object Products : Table("products") {
    val id = integer("id").autoIncrement()
    val name = varchar("name", 100)
    val price = decimal("price", precision = 10, scale = 2)
    val categoryId = integer("category_id").references(Categories.id, onDelete = ReferenceOption.CASCADE)
    override val primaryKey = PrimaryKey(id)
}

class ProductRepository(private val database: Database) {
    fun createCategory(name: String): Int = transaction(database) {
        Categories.insert { it[Categories.name] = name }[Categories.id]
    }

    fun createProduct(name: String, price: BigDecimal, categoryId: Int): Int = transaction(database) {
        Products.insert {
            it[Products.name] = name
            it[Products.price] = price
            it[Products.categoryId] = categoryId
        }[Products.id]
    }

    fun productsByCategory(categoryId: Int): List<String> = transaction(database) {
        Products.selectAll().where { Products.categoryId eq categoryId }
            .map { "${it[Products.name]} — ${it[Products.price]} ₽" }
    }

    fun moveProduct(productId: Int, newCategoryId: Int): Int = transaction(database) {
        Products.update({ Products.id eq productId }) {
            it[Products.categoryId] = newCategoryId
        }
    }

    fun deleteCategoryAndProducts(categoryId: Int): Pair<Int, Int> = transaction(database) {
        val productsDeleted = Products.deleteWhere { Products.categoryId eq categoryId }
        val categoriesDeleted = Categories.deleteWhere { Categories.id eq categoryId }
        categoriesDeleted to productsDeleted
    }
}

fun main() {
    File("build").mkdirs()
    val databaseFile = File("build/lab07-demo.db")
    databaseFile.delete()
    val database = Database.connect("jdbc:sqlite:${databaseFile.path}", driver = "org.sqlite.JDBC")
    val repository = ProductRepository(database)

    transaction(database) {
        SchemaUtils.create(Categories, Products)
    }

    val books = repository.createCategory("Книги")
    val games = repository.createCategory("Настольные игры")
    val product = repository.createProduct("Книга о стратегиях", BigDecimal("1200.00"), books)
    repository.createProduct("Шахматы", BigDecimal("2500.00"), games)

    println("Товары категории «Книги»: ${repository.productsByCategory(books)}")
    repository.moveProduct(product, games)
    println("После смены категории «Книги»: ${repository.productsByCategory(books)}")
    println("После смены категории «Настольные игры»: ${repository.productsByCategory(games)}")
    println("Удалено (категорий, товаров): ${repository.deleteCategoryAndProducts(games)}")
}
