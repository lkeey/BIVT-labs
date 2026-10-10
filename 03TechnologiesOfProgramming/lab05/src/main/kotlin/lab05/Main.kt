package lab05

data class UnitView(val id: Int, val name: String, val x: Int, val y: Int)

interface MapView {
    fun visibleUnits(): List<UnitView>
}

class RealMap(private val units: List<UnitView>) : MapView {
    override fun visibleUnits() = units
}

class FogOfWarProxy(private val realMap: MapView, private val visibleIds: Set<Int>) : MapView {
    override fun visibleUnits() = realMap.visibleUnits().filter { it.id in visibleIds }
}

interface MapRenderer {
    fun render(units: List<UnitView>): String
}

class TextRenderer : MapRenderer {
    override fun render(units: List<UnitView>) = units.joinToString("\n") {
        "${it.name} (${it.x}, ${it.y})"
    }
}

class CompactRenderer : MapRenderer {
    override fun render(units: List<UnitView>) = units.joinToString(" | ") { "${it.name}@${it.x}:${it.y}" }
}

class GameMap(private val renderer: MapRenderer) {
    fun draw(view: MapView) = renderer.render(view.visibleUnits())
}

interface Attacker {
    fun attack(target: UnitView)
}

class LegacyCannon {
    fun fireAt(x: Int, y: Int) = println("Старое орудие стреляет по координатам ($x, $y)")
}

class CannonAdapter(private val cannon: LegacyCannon) : Attacker {
    override fun attack(target: UnitView) = cannon.fireAt(target.x, target.y)
}

fun main() {
    val units = listOf(UnitView(1, "Лучник", 2, 3), UnitView(2, "Орк", 7, 4))
    val restrictedView = FogOfWarProxy(RealMap(units), visibleIds = setOf(1))

    println("Proxy (туман войны):")
    println(GameMap(TextRenderer()).draw(restrictedView))
    println("Bridge с компактным рендерером: ${GameMap(CompactRenderer()).draw(restrictedView)}")
    println("Adapter:")
    CannonAdapter(LegacyCannon()).attack(units.last())
}
