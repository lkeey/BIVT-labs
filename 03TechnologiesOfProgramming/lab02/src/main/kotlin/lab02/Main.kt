package lab02

abstract class GameObject(
    val id: Int,
    val name: String,
    x: Int,
    y: Int,
) {
    var x: Int = x
        protected set
    var y: Int = y
        protected set
}

interface Attacker {
    fun attack(target: Unit)
}

interface Moveable {
    fun moveTo(x: Int, y: Int)
}

abstract class Unit(
    id: Int,
    name: String,
    x: Int,
    y: Int,
    initialHp: Double,
) : GameObject(id, name, x, y) {
    var hp: Double = initialHp
        private set

    init {
        require(initialHp > 0.0) { "Здоровье юнита должно быть положительным" }
    }

    fun isAlive(): Boolean = hp > 0.0

    fun receiveDamage(damage: Double) {
        require(damage >= 0.0) { "Урон не может быть отрицательным" }
        hp = (hp - damage).coerceAtLeast(0.0)
    }
}

class Archer(id: Int, name: String, x: Int, y: Int) : Unit(id, name, x, y, initialHp = 70.0), Attacker, Moveable {
    override fun attack(target: Unit) {
        check(isAlive()) { "Мёртвый лучник не может атаковать" }
        target.receiveDamage(18.0)
    }

    override fun moveTo(x: Int, y: Int) {
        check(isAlive()) { "Мёртвый юнит не может перемещаться" }
        this.x = x
        this.y = y
    }
}

abstract class Building(id: Int, name: String, x: Int, y: Int) : GameObject(id, name, x, y) {
    var isBuilt: Boolean = false
        private set

    fun completeConstruction() {
        isBuilt = true
    }
}

class Fort(id: Int, name: String, x: Int, y: Int) : Building(id, name, x, y), Attacker {
    override fun attack(target: Unit) {
        check(isBuilt) { "Крепость ещё не построена" }
        target.receiveDamage(30.0)
    }
}

class MobileHouse(id: Int, name: String, x: Int, y: Int) : Building(id, name, x, y), Moveable {
    override fun moveTo(x: Int, y: Int) {
        check(isBuilt) { "Дом ещё не построен" }
        this.x = x
        this.y = y
    }
}

fun main() {
    val archer = Archer(1, "Лучник", 2, 3)
    val fort = Fort(2, "Северная крепость", 5, 5).apply { completeConstruction() }
    val mobileHouse = MobileHouse(3, "Дом на колёсах", 0, 0).apply {
        completeConstruction()
        moveTo(1, 2)
    }

    fort.attack(archer)
    archer.moveTo(4, 3)

    println("${archer.name}: жив=${archer.isAlive()}, HP=${archer.hp}, позиция=(${archer.x}, ${archer.y})")
    println("${fort.name}: построена=${fort.isBuilt}")
    println("${mobileHouse.name}: позиция=(${mobileHouse.x}, ${mobileHouse.y})")
}
