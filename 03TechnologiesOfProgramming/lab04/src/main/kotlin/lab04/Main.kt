package lab04

data class Position(val x: Int, val y: Int)

fun interface MovementStrategy {
    fun next(current: Position, target: Position): Position
}

object DirectMovement : MovementStrategy {
    override fun next(current: Position, target: Position) = Position(
        current.x + (target.x - current.x).sign(),
        current.y + (target.y - current.y).sign(),
    )
}

object CautiousMovement : MovementStrategy {
    override fun next(current: Position, target: Position) = when {
        current.x != target.x -> Position(current.x + (target.x - current.x).sign(), current.y)
        else -> Position(current.x, current.y + (target.y - current.y).sign())
    }
}

private fun Int.sign(): Int = compareTo(0)

data class BattleEvent(val type: String, val amount: Int)

abstract class BattleEventHandler(private val next: BattleEventHandler? = null) {
    fun handle(event: BattleEvent): String = process(event) + (next?.handle(event) ?: "")
    protected abstract fun process(event: BattleEvent): String
}

class ShieldHandler(next: BattleEventHandler? = null) : BattleEventHandler(next) {
    override fun process(event: BattleEvent) =
        if (event.type == "damage") "Щит поглотил ${event.amount / 2}; " else ""
}

class HealthHandler : BattleEventHandler() {
    override fun process(event: BattleEvent) =
        if (event.type == "damage") "остаточный урон обработан: ${event.amount / 2}" else ""
}

data class MapUnit(val name: String, val position: Position)

class MapUnitIterator(private val units: List<MapUnit>) : Iterator<MapUnit> {
    private var index = 0
    override fun hasNext() = index < units.size
    override fun next(): MapUnit {
        if (!hasNext()) throw NoSuchElementException("На карте больше нет юнитов")
        return units[index++]
    }
}

fun main() {
    val start = Position(1, 1)
    val destination = Position(4, 3)
    println("Strategy: следующий ход ${DirectMovement.next(start, destination)}")
    println("Strategy: осторожный ход ${CautiousMovement.next(start, destination)}")

    val chain = ShieldHandler(HealthHandler())
    println("Chain of Responsibility: ${chain.handle(BattleEvent("damage", 20))}")

    val iterator = MapUnitIterator(listOf(MapUnit("Лучник", Position(2, 2)), MapUnit("Страж", Position(4, 1))))
    println("Iterator: ${buildList { while (iterator.hasNext()) add(iterator.next().name) }.joinToString()}")
}
