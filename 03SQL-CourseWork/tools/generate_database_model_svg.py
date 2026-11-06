#!/usr/bin/env python3
"""Render full and product SVGs from the canonical SQL Server CREATE TABLE scripts.

Run from any directory: python3 tools/generate_database_model_svg.py
Only the Python standard library is required. The SVG is a checked-in artifact;
this script lets us regenerate it when the T-SQL schema changes.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from pathlib import Path
from xml.sax.saxutils import escape


ROOT = Path(__file__).resolve().parents[1]
DATABASE = ROOT / "database"
OUTPUT_FULL = ROOT / "architecture" / "database-model.svg"
OUTPUT_PRODUCT = ROOT / "architecture" / "product-model.svg"
DDL_FILES = (
    "01-social-nodes.sql",
    "02-content.sql",
    "03-knowledge-graph.sql",
    "04-social-content-edges.sql",
    "05-assistant-audit.sql",
    "17-auth-and-roles.sql",
)

# Columns are thematic neighborhoods on one canvas; every table appears once.
FULL_LANES = (
    (
        "auth.UserAccount",
        "auth.UserProfile",
        "auth.ExternalIdentity",
        "social.Follows",
        "social.Community",
        "social.MemberOf",
    ),
    (
        "social.ContentItem",
        "social.Authored",
        "social.PublishedIn",
        "social.CommentOn",
        "social.ReactTo",
        "social.PostRevision",
        "social.CommentRevision",
        "social.DocumentDetail",
        "knowledge.DocumentVersion",
    ),
    (
        "knowledge.SourceRevision",
        "knowledge.Chunk",
        "knowledge.ChunkOf",
        "knowledge.KnowledgeEntity",
        "knowledge.Mentions",
        "knowledge.EntityRelation",
        "knowledge.EmbeddingModel",
        "knowledge.ChunkEmbedding",
    ),
    (
        "assistant.RagSession",
        "assistant.RagTurn",
        "assistant.RetrievalRun",
        "assistant.RetrievedChunk",
        "assistant.AnswerCitation",
        "assistant.TurnFeedback",
        "assistant.RecommendationBatch",
        "assistant.RecommendationItem",
        "ops.IndexOutbox",
        "ops.AuditEvent",
    ),
)

# The social network as a product: identity, communities, content, files and feed.
# RAG, indexing, extraction and technical audit tables stay in the full view.
PRODUCT_LANES = (
    (
        "auth.UserAccount",
        "auth.UserProfile",
        "auth.ExternalIdentity",
        "social.Follows",
        "social.Community",
        "social.MemberOf",
        "assistant.RecommendationBatch",
        "assistant.RecommendationItem",
    ),
    (
        "social.ContentItem",
        "social.Authored",
        "social.PublishedIn",
        "social.CommentOn",
        "social.ReactTo",
        "social.PostRevision",
        "social.CommentRevision",
        "social.DocumentDetail",
        "knowledge.DocumentVersion",
    ),
)

CARD_WIDTH = 470
HEADER_HEIGHT = 40
ROW_HEIGHT = 25
BOTTOM_PAD = 9
LANE_GAP = 150
CARD_GAP = 48
LEFT = 55
TOP = 130

GRAPH_ROLES = {
    "social.Follows": ("подписчик", "на кого подписан"),
    "social.MemberOf": ("участник", "сообщество"),
    "social.Authored": ("автор", "материал"),
    "social.PublishedIn": ("материал", "сообщество"),
    "social.CommentOn": ("комментарий", "пост"),
    "social.ReactTo": ("пользователь", "материал"),
    "knowledge.ChunkOf": ("фрагмент", "материал"),
    "knowledge.Mentions": ("фрагмент", "сущность"),
    "knowledge.EntityRelation": ("сущность 1", "сущность 2"),
}


@dataclass
class Column:
    name: str
    sql_type: str
    nullable: bool
    primary: bool = False
    foreign: bool = False
    system: bool = False
    hint: str = ""


@dataclass
class Table:
    name: str
    kind: str
    columns: list[Column] = field(default_factory=list)
    x: float = 0
    y: float = 0
    lane: int = 0

    @property
    def display_columns(self) -> list[Column]:
        """Show Graph endpoints without counting them as declared T-SQL columns."""
        if self.kind == "NODE":
            return [*self.columns, Column("$node_id", "системное", False, system=True)]
        if self.kind == "EDGE":
            from_role, to_role = GRAPH_ROLES[self.name]
            return [
                *self.columns,
                Column("$edge_id", "системное", False, system=True),
                Column("$from_id", "системное", False, system=True, hint=from_role),
                Column("$to_id", "системное", False, system=True, hint=to_role),
            ]
        return self.columns

    @property
    def height(self) -> int:
        if not self.display_columns:
            return HEADER_HEIGHT
        return HEADER_HEIGHT + ROW_HEIGHT * len(self.display_columns) + BOTTOM_PAD

    def column(self, name: str) -> Column:
        return next(col for col in self.columns if col.name == name)

@dataclass(frozen=True)
class ForeignKey:
    source_table: str
    source_columns: tuple[str, ...]
    target_table: str
    target_columns: tuple[str, ...]


@dataclass(frozen=True)
class GraphConnection:
    edge_table: str
    source_table: str
    target_table: str


def unbracket(identifier: str) -> str:
    return identifier.strip().strip("[]")


def names(text: str) -> tuple[str, ...]:
    return tuple(unbracket(part) for part in text.split(","))


def closing_paren(text: str, opening: int) -> int:
    depth = 0
    quoted = False
    pos = opening
    while pos < len(text):
        char = text[pos]
        if char == "'":
            if quoted and pos + 1 < len(text) and text[pos + 1] == "'":
                pos += 2
                continue
            quoted = not quoted
        elif not quoted:
            if char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
                if depth == 0:
                    return pos
        pos += 1
    raise ValueError("Unclosed CREATE TABLE parenthesis")


def split_items(body: str) -> list[str]:
    result: list[str] = []
    start = 0
    depth = 0
    quoted = False
    pos = 0
    while pos < len(body):
        char = body[pos]
        if char == "'":
            if quoted and pos + 1 < len(body) and body[pos + 1] == "'":
                pos += 2
                continue
            quoted = not quoted
        elif not quoted:
            if char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
            elif char == "," and depth == 0:
                result.append(body[start:pos].strip())
                start = pos + 1
        pos += 1
    result.append(body[start:].strip())
    return [item for item in result if item]


def read_model() -> tuple[dict[str, Table], list[ForeignKey], list[GraphConnection]]:
    tables: dict[str, Table] = {}
    fks: list[ForeignKey] = []
    graph: list[GraphConnection] = []
    create_table = re.compile(r"\bCREATE\s+TABLE\s+([A-Za-z_]\w*\.[A-Za-z_]\w*)\s*\(", re.I)
    column_pattern = re.compile(
        r"^(\[[^\]]+\]|[A-Za-z_]\w*)\s+([A-Za-z_]\w*(?:\([^)]*\))?)\s+(.+)$",
        re.I | re.S,
    )
    fk_pattern = re.compile(
        r"\bFOREIGN\s+KEY\s*\(([^)]+)\)\s*REFERENCES\s+"
        r"([A-Za-z_]\w*\.[A-Za-z_]\w*)\s*\(([^)]+)\)",
        re.I | re.S,
    )
    graph_pattern = re.compile(
        r"\bCONNECTION\s*\(\s*([A-Za-z_]\w*\.[A-Za-z_]\w*)\s+TO\s+"
        r"([A-Za-z_]\w*\.[A-Za-z_]\w*)\s*\)",
        re.I | re.S,
    )
    for filename in DDL_FILES:
        source = (DATABASE / filename).read_text(encoding="utf-8")
        for match in create_table.finditer(source):
            name = match.group(1)
            end = closing_paren(source, match.end() - 1)
            kind_match = re.match(r"\s*AS\s+(NODE|EDGE)", source[end + 1 :], re.I)
            kind = kind_match.group(1).upper() if kind_match else "TABLE"
            if name in tables:
                raise ValueError(f"Duplicate CREATE TABLE: {name}")
            table = Table(name=name, kind=kind)
            tables[name] = table
            for item in split_items(source[match.end() : end]):
                if item.upper().startswith("CONSTRAINT "):
                    pk = re.search(r"\bPRIMARY\s+KEY\s*\(([^)]+)\)", item, re.I | re.S)
                    if pk:
                        # Table-level PKs are applied after all columns are read.
                        for column_name in names(pk.group(1)):
                            table.column(column_name).primary = True
                    fk = fk_pattern.search(item)
                    if fk:
                        source_columns = names(fk.group(1))
                        target_columns = names(fk.group(3))
                        if len(source_columns) != len(target_columns):
                            raise ValueError(f"FK arity differs in {name}")
                        fks.append(ForeignKey(name, source_columns, fk.group(2), target_columns))
                    connection = graph_pattern.search(item)
                    if connection:
                        graph.append(GraphConnection(name, connection.group(1), connection.group(2)))
                    continue
                column_match = column_pattern.match(item)
                if not column_match:
                    raise ValueError(f"Unparsed column in {name}: {item[:100]!r}")
                column_name, sql_type, rest = column_match.groups()
                if re.search(r"\bNOT\s+NULL\b", rest, re.I):
                    nullable = False
                elif re.search(r"\bNULL\b", rest, re.I):
                    nullable = True
                else:
                    raise ValueError(f"Missing nullability in {name}.{column_name}")
                table.columns.append(
                    Column(
                        unbracket(column_name),
                        sql_type.upper(),
                        nullable,
                        bool(re.search(r"\bPRIMARY\s+KEY\b", rest, re.I)),
                    )
                )
    for fk in fks:
        for source_column, target_column in zip(fk.source_columns, fk.target_columns):
            tables[fk.source_table].column(source_column).foreign = True
            tables[fk.target_table].column(target_column)
    for link in graph:
        if tables[link.edge_table].kind != "EDGE":
            raise ValueError(f"Graph constraint on non-edge table: {link.edge_table}")
        if tables[link.source_table].kind != "NODE" or tables[link.target_table].kind != "NODE":
            raise ValueError(f"Graph endpoint is not NODE: {link}")
    return tables, fks, graph


def place_tables(tables: dict[str, Table], lanes: tuple[tuple[str, ...], ...]) -> tuple[int, int]:
    ordered = [name for lane in lanes for name in lane]
    if len(ordered) != len(set(ordered)) or set(ordered) != set(tables):
        raise ValueError(f"Layout does not match DDL tables: {set(tables) ^ set(ordered)}")
    bottom = 0
    for lane_no, lane in enumerate(lanes):
        y = TOP
        for name in lane:
            table = tables[name]
            table.lane = lane_no
            table.x = LEFT + lane_no * (CARD_WIDTH + LANE_GAP)
            table.y = y
            y += table.height + CARD_GAP
        bottom = max(bottom, y - CARD_GAP)
    width = LEFT * 2 + len(lanes) * CARD_WIDTH + (len(lanes) - 1) * LANE_GAP
    return width, bottom + 115


def port(table: Table, column: str | None, side: str, offset: int = 0) -> tuple[float, float]:
    x = table.x if side == "left" else table.x + CARD_WIDTH
    if column is None:
        y = table.y + HEADER_HEIGHT / 2
    else:
        index = next(i for i, col in enumerate(table.display_columns) if col.name == column)
        y = table.y + HEADER_HEIGHT + ROW_HEIGHT * (index + 0.5)
    return x, y + offset


def route(source: Table, target: Table, source_field: str | None, target_field: str | None,
          serial: int, height: int, self_edge_part: int = 0) -> str:
    if source.lane == target.lane:
        side = "left" if self_edge_part == 2 else "right"
        sx, sy = port(source, source_field, side, -4 if self_edge_part == 1 else 4 if self_edge_part == 2 else 0)
        tx, ty = port(target, target_field, side, 4 if self_edge_part == 1 else -4 if self_edge_part == 2 else 0)
        bend = sx + (1 if side == "right" else -1) * (38 + (serial % 9) * 8)
        return f"M {sx:.0f} {sy:.1f} C {bend:.0f} {sy:.1f}, {bend:.0f} {ty:.1f}, {tx:.0f} {ty:.1f}"
    toward_right = target.lane > source.lane
    sx, sy = port(source, source_field, "right" if toward_right else "left")
    tx, ty = port(target, target_field, "left" if toward_right else "right")
    if abs(source.lane - target.lane) == 1:
        mid = (sx + tx) / 2 + (serial % 7 - 3) * 5
        return f"M {sx:.0f} {sy:.1f} C {mid:.0f} {sy:.1f}, {mid:.0f} {ty:.1f}, {tx:.0f} {ty:.1f}"
    sign = 1 if toward_right else -1
    sx_bus = sx + sign * (20 + serial % 5 * 5)
    tx_bus = tx - sign * (20 + serial % 5 * 5)
    above = sy + ty < height
    bus_y = (22 + (serial % 14) * 6) if above else (height - 22 - (serial % 14) * 6)
    return (f"M {sx:.0f} {sy:.1f} H {sx_bus:.0f} V {bus_y:.0f} "
            f"H {tx_bus:.0f} V {ty:.1f} H {tx:.0f}")


def svg_text(x: float, y: float, text: str, css_class: str, **attrs: str) -> str:
    attributes = " ".join(f'{key.replace("_", "-")}="{escape(value)}"' for key, value in attrs.items())
    return f'<text class="{css_class}" x="{x:.0f}" y="{y:.1f}" {attributes}>{escape(text)}</text>'


def render(tables: dict[str, Table], fks: list[ForeignKey], graph: list[GraphConnection],
           lanes: tuple[tuple[str, ...], ...], label: str) -> str:
    width, height = place_tables(tables, lanes)
    colors = {
        "auth": ("#eef3ff", "#4870b8"),
        "social": ("#edf8f6", "#25847d"),
        "knowledge": ("#f3f0ff", "#7653aa"),
        "assistant": ("#fff4eb", "#ad6a34"),
        "ops": ("#f0f2f5", "#697586"),
    }
    out = [
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" role="img" aria-label="{escape(label)}">',
        "<defs>",
        '<marker id="fk-arrow" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="7" markerHeight="7" orient="auto"><path d="M 0 0 L 8 4 L 0 8 z" fill="#66789f"/></marker>',
        '<marker id="graph-arrow" viewBox="0 0 8 8" refX="7" refY="4" markerWidth="7" markerHeight="7" orient="auto"><path d="M 0 0 L 8 4 L 0 8 z" fill="#219186"/></marker>',
        "</defs>",
        "<style>",
        '.canvas{fill:#fbfcff}.card{fill:#fff;stroke:#abb5c6;stroke-width:1.4}.header-rule{stroke:#cbd2de;stroke-width:1}',
        '.title{font:700 17px -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;fill:#1f2937;text-anchor:middle}',
        '.field-name{font:500 13px -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;fill:#283342}',
        '.field-type{font:400 12.5px ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;fill:#526277}',
        '.field-flags{font:600 11px ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;fill:#6d59a1}',
        '.field-system{font:400 12px ui-monospace,SFMono-Regular,Menlo,Consolas,monospace;fill:#758295}',
        '.fk-link{fill:none;stroke:#66789f;stroke-width:1.6;stroke-opacity:.43;marker-end:url(#fk-arrow)}',
        '.graph-link{fill:none;stroke:#219186;stroke-width:1.7;stroke-dasharray:6 4;stroke-opacity:.55;marker-end:url(#graph-arrow)}',
        '.fk-link:hover,.graph-link:hover{stroke-width:3;stroke-opacity:1}',
        "</style>",
        f'<rect class="canvas" width="{width}" height="{height}"/>',
        '<g id="connections">',
    ]
    serial = 0
    for fk in fks:
        for source_field, target_field in zip(fk.source_columns, fk.target_columns):
            source, target = tables[fk.source_table], tables[fk.target_table]
            path = route(source, target, source_field, target_field, serial, height)
            title = escape(f"FK: {source.name}.{source_field} → {target.name}.{target_field}")
            out.append(f'<path class="fk-link" d="{path}"><title>{title}</title></path>')
            serial += 1
    for link in graph:
        edge, source, target = tables[link.edge_table], tables[link.source_table], tables[link.target_table]
        same_endpoint = source.name == target.name
        first = route(source, edge, "$node_id", "$from_id", serial, height, 1 if same_endpoint else 0)
        out.append(f'<path class="graph-link" d="{first}"><title>{escape(source.name + ".$node_id → " + edge.name + ".$from_id")}</title></path>')
        serial += 1
        second = route(edge, target, "$to_id", "$node_id", serial, height, 2 if same_endpoint else 0)
        out.append(f'<path class="graph-link" d="{second}"><title>{escape(edge.name + ".$to_id → " + target.name + ".$node_id")}</title></path>')
        serial += 1
    out.append("</g>")
    for lane in lanes:
        for name in lane:
            table = tables[name]
            fill, accent = colors[name.split(".", 1)[0]]
            x, y = table.x, table.y
            out.append(f'<g class="table" id="{name}" data-kind="{table.kind}">')
            out.append(f'<rect class="card" x="{x:.0f}" y="{y:.0f}" width="{CARD_WIDTH}" height="{table.height}" rx="9"/>')
            if table.display_columns:
                out.append(f'<path d="M {x+9:.0f} {y:.0f} H {x+CARD_WIDTH-9:.0f} Q {x+CARD_WIDTH:.0f} {y:.0f} {x+CARD_WIDTH:.0f} {y+9:.0f} V {y+HEADER_HEIGHT:.0f} H {x:.0f} V {y+9:.0f} Q {x:.0f} {y:.0f} {x+9:.0f} {y:.0f} Z" fill="{fill}"/>')
                out.append(f'<path d="M {x+1:.0f} {y+HEADER_HEIGHT:.0f} H {x+CARD_WIDTH-1:.0f}" class="header-rule"/>')
            out.append(f'<rect x="{x:.0f}" y="{y:.0f}" width="4" height="{table.height}" rx="2" fill="{accent}"/>')
            out.append(svg_text(x + CARD_WIDTH / 2, y + 26, name, "title"))
            for index, column in enumerate(table.display_columns):
                baseline = y + HEADER_HEIGHT + ROW_HEIGHT * index + 18
                flags = " ".join(
                    label for label, active in (("PK", column.primary), ("FK", column.foreign), ("NULL", column.nullable))
                    if active
                )
                field_class = "field-system" if column.system else "field-name"
                type_class = "field-system" if column.system else "field-type"
                field_label = column.name + (" · " + column.hint if column.hint else "")
                out.append(svg_text(x + 14, baseline, field_label, field_class))
                out.append(svg_text(x + 216, baseline, column.sql_type, type_class))
                if flags:
                    out.append(svg_text(x + 366, baseline, flags, "field-flags"))
            out.append("</g>")
    out.append("</svg>")
    return "\n".join(out) + "\n"


def main() -> None:
    tables, fks, graph = read_model()
    OUTPUT_FULL.write_text(
        render(tables, fks, graph, FULL_LANES, "Все таблицы SocialNetworkDB, их поля и связи"),
        encoding="utf-8",
    )
    print(f"{OUTPUT_FULL}: {len(tables)} tables, {sum(len(t.columns) for t in tables.values())} columns, "
          f"{len(fks)} FK constraints, {len(graph)} SQL Graph connections")

    product_names = {name for lane in PRODUCT_LANES for name in lane}
    product_tables = {name: table for name, table in tables.items() if name in product_names}
    product_fks = [fk for fk in fks if fk.source_table in product_names and fk.target_table in product_names]
    product_graph = [link for link in graph if {link.edge_table, link.source_table, link.target_table} <= product_names]
    if any(fk.source_table in product_names and fk.target_table not in product_names for fk in fks):
        raise ValueError("Product view cuts a declared foreign key")
    if any(link.edge_table in product_names and link not in product_graph for link in graph):
        raise ValueError("Product view cuts a SQL Graph connection")
    OUTPUT_PRODUCT.write_text(
        render(product_tables, product_fks, product_graph, PRODUCT_LANES,
               "Продуктовые таблицы социальной сети, их поля и связи"),
        encoding="utf-8",
    )
    print(f"{OUTPUT_PRODUCT}: {len(product_tables)} tables, "
          f"{sum(len(t.columns) for t in product_tables.values())} columns, "
          f"{len(product_fks)} FK constraints, {len(product_graph)} SQL Graph connections")


if __name__ == "__main__":
    main()
