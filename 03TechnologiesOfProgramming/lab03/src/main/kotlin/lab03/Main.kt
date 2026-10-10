package lab03

object GameConfig {
    val mapWidth: Int = 20
    val mapHeight: Int = 12
    val startingGold: Int = 250
}

data class GameUnit(val name: String, val attack: Int, val health: Int)

abstract class UnitFactory {
    abstract fun create(name: String): GameUnit
}

class ArcherFactory : UnitFactory() {
    override fun create(name: String) = GameUnit(name, attack = 18, health = 70)
}

class SwordsmanFactory : UnitFactory() {
    override fun create(name: String) = GameUnit(name, attack = 24, health = 110)
}

data class FactionUnit(val faction: String, val name: String)
data class FactionBuilding(val faction: String, val name: String)

interface FactionFactory {
    fun createUnit(name: String): FactionUnit
    fun createBuilding(name: String): FactionBuilding
}

class KingdomFactory : FactionFactory {
    override fun createUnit(name: String) = FactionUnit("Королевство", name)
    override fun createBuilding(name: String) = FactionBuilding("Королевство", name)
}

class OrcFactory : FactionFactory {
    override fun createUnit(name: String) = FactionUnit("Орки", name)
    override fun createBuilding(name: String) = FactionBuilding("Орки", name)
}

data class Scenario(val name: String, val units: List<GameUnit>, val buildings: List<FactionBuilding>)

class ScenarioBuilder {
    private var name: String = "Новая битва"
    private val units = mutableListOf<GameUnit>()
    private val buildings = mutableListOf<FactionBuilding>()

    fun named(name: String) = apply { this.name = name }
    fun addUnit(unit: GameUnit) = apply { units += unit }
    fun addBuilding(building: FactionBuilding) = apply { buildings += building }

    fun build(): Scenario {
        require(units.isNotEmpty()) { "В сценарии должен быть хотя бы один юнит" }
        return Scenario(name, units.toList(), buildings.toList())
    }
}

fun main() {
    val archer = ArcherFactory().create("Эльвин")
    val kingdom = KingdomFactory()
    val scenario = ScenarioBuilder()
        .named("Оборона крепости")
        .addUnit(archer)
        .addBuilding(kingdom.createBuilding("Крепость Серебряный Щит"))
        .build()

    println("Настройки карты: ${GameConfig.mapWidth}×${GameConfig.mapHeight}, золото=${GameConfig.startingGold}")
    println("Factory Method: ${SwordsmanFactory().create("Бран").name}")
    println("Abstract Factory: ${kingdom.createUnit("Страж")}; ${OrcFactory().createBuilding("Логово")}")
    println("Builder: ${scenario.name}, юнитов=${scenario.units.size}, построек=${scenario.buildings.size}")
}
