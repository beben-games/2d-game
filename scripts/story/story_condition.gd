class_name StoryCondition
extends RefCounted
## A condition of the story format: an event's `when:` or a line's `[condition]`. The grammar,
## loosest first: `or` under `and` under `not` under a comparison (==, !=, <, <=, >, >=) of a
## name with a literal (an integer, true, false, or a bare word) or another name; parentheses
## group; a bare name is its truth (StoryContext.truth). Names may carry dots, so a later
## namespace (`bond.lanista`) is a new lookup in StoryContext, not a parser change.
##
## A bare word on the right of a comparison is a word when it is in the left name's word list
## or names nothing the context knows, and that name's value otherwise. check() decides it once,
## against the names known at load, and keeps the decision in the tree, so a fact handed in at
## play under a word's spelling never turns a word into a name; a condition never checked decides
## at each evaluate (the fallback). An integer is digits with an optional leading '-' and no
## leading zero (INTEGER, the effects' shape too). Pure: every name resolves through the
## StoryContext handed in.

const OPERATORS: Array[String] = ["==", "!=", "<", "<=", ">", ">="]
const ORDERING: Array[String] = ["<", "<=", ">", ">="]
const KEYWORDS: Array[String] = ["and", "or", "not", "true", "false"]
## The one integer shape of the story format (a condition's literal, an effect's value, a flag's
## default, an act): `0`, `3`, `-2`; never `+3`, `03`, or `-0`.
const INTEGER := "^(0|-?[1-9][0-9]*)$"

static var _integer: RegEx = null

## The text it was parsed from, trimmed.
var source := ""
var _tree: Dictionary = {}


## {"condition": StoryCondition, "error": ""} or {"condition": null, "error": what and where}.
static func parse(text: String) -> Dictionary:
	var trimmed := text.strip_edges()
	if trimmed == "":
		return {"condition": null, "error": "an empty condition"}
	var lexed := _tokenize(trimmed)
	if lexed["error"] != "":
		return {"condition": null, "error": lexed["error"]}
	var parser := _Parser.new(lexed["tokens"])
	var tree := parser.parse_or()
	if parser.error == "" and parser.peek()["t"] != "end":
		parser.fail("unexpected %s" % _Parser.describe(parser.peek()))
	if parser.error != "":
		return {"condition": null, "error": parser.error}
	var c := StoryCondition.new()
	c.source = trimmed
	c._tree = tree
	return {"condition": c, "error": ""}


func evaluate(context: StoryContext) -> bool:
	return _eval(_tree, context)


## The names the condition reads (a bare name, the left of a comparison), each once, in order.
## A bare word on the right is left out: whether it is a name is the context's to say.
func names() -> Array[String]:
	var out: Array[String] = []
	_collect(_tree, out)
	return out


## The bare words on the right of a comparison that read a name (`mood == other`: `other`), each
## once, in order: as check() decided, or every bare right word for a condition never checked (the
## caller tells a name from a word then). The Story tab's flag links read names() and these.
func right_names() -> Array[String]:
	var out: Array[String] = []
	_collect_right(_tree, out)
	return out


## The bare words the name is compared with (`last_killer == boss`: `boss`), each once, in order:
## as check() decided (a name on the right is no word), every bare right word for a condition never
## checked. The lint reads it to check an open word's words (last_killer against the enemy ids).
func compared_words(name: String) -> Array[String]:
	var out: Array[String] = []
	_collect_words(_tree, name, out)
	return out


## What is wrong with the condition against the context's names (empty when nothing is): an
## unknown name, a word outside a name's list, a comparison of two kinds, an ordering of a word.
## The catalog runs it at load with a context that knows every name; it also settles each bare
## right-hand word as a word or a name, for every evaluate after.
func check(context: StoryContext) -> Array[String]:
	var out: Array[String] = []
	_check(_tree, context, out)
	return out


static func _eval(node: Dictionary, context: StoryContext) -> bool:
	match node["op"]:
		"or":
			return _eval(node["a"], context) or _eval(node["b"], context)
		"and":
			return _eval(node["a"], context) and _eval(node["b"], context)
		"not":
			return not _eval(node["a"], context)
		"name":
			return StoryContext.truth(context.value(node["name"]))
	var left: Variant = context.value(node["name"])
	var right: Variant = _operand(node, context)
	var op: String = node["cmp"]
	if op in ORDERING:
		if not (left is int and right is int):
			return false
		match op:
			"<":
				return left < right
			"<=":
				return left <= right
			">":
				return left > right
		return left >= right
	var same: bool = typeof(left) == typeof(right) and left == right
	return same if op == "==" else not same


## True for the format's integer shape (INTEGER).
static func is_integer(text: String) -> bool:
	if _integer == null:
		_integer = RegEx.create_from_string(INTEGER)
	return _integer.search(text) != null


## The right side's value: a literal, a word, or the value of the name it is (as check() decided,
## or decided now for a condition never checked).
static func _operand(node: Dictionary, context: StoryContext) -> Variant:
	var rhs: Dictionary = node["rhs"]
	if rhs["kind"] != "ident":
		return rhs["value"]
	var is_name: bool = rhs["resolved"] == "name" if rhs.has("resolved") else _is_name(node, context)
	return context.value(rhs["value"]) if is_name else rhs["value"]


## True when the comparison's bare right word is a name, not a word.
static func _is_name(node: Dictionary, context: StoryContext) -> bool:
	var word: String = node["rhs"]["value"]
	return context.knows(word) and not context.words(node["name"]).has(word)


static func _collect(node: Dictionary, out: Array[String]) -> void:
	match node["op"]:
		"or", "and":
			_collect(node["a"], out)
			_collect(node["b"], out)
		"not":
			_collect(node["a"], out)
		_:
			if not out.has(node["name"]):
				out.append(node["name"])


static func _collect_right(node: Dictionary, out: Array[String]) -> void:
	match node["op"]:
		"or", "and":
			_collect_right(node["a"], out)
			_collect_right(node["b"], out)
		"not":
			_collect_right(node["a"], out)
		"cmp":
			var rhs: Dictionary = node["rhs"]
			if rhs["kind"] == "ident" and rhs.get("resolved", "name") == "name" and not out.has(rhs["value"]):
				out.append(rhs["value"])


static func _collect_words(node: Dictionary, name: String, out: Array[String]) -> void:
	match node["op"]:
		"or", "and":
			_collect_words(node["a"], name, out)
			_collect_words(node["b"], name, out)
		"not":
			_collect_words(node["a"], name, out)
		"cmp":
			var rhs: Dictionary = node["rhs"]
			if node["name"] == name and rhs["kind"] == "ident" and rhs.get("resolved", "word") == "word" and not out.has(rhs["value"]):
				out.append(rhs["value"])


static func _check(node: Dictionary, context: StoryContext, out: Array[String]) -> void:
	match node["op"]:
		"or", "and":
			_check(node["a"], context, out)
			_check(node["b"], context, out)
			return
		"not":
			_check(node["a"], context, out)
			return
	var name: String = node["name"]
	if not context.knows(name):
		out.append("unknown name '%s'" % name)
		return
	if node["op"] == "name":
		return
	var kind := context.kind(name)
	var op: String = node["cmp"]
	if op in ORDERING and kind != "int":
		out.append("'%s' compares numbers; '%s' is %s" % [op, name, _a(kind)])
		return
	var rhs: Dictionary = node["rhs"]
	match rhs["kind"]:
		"int", "bool":
			if kind != rhs["kind"]:
				out.append("'%s' is %s, compared with %s" % [name, _a(kind), "a number" if rhs["kind"] == "int" else "a bool"])
		"ident":
			var word: String = rhs["value"]
			rhs["resolved"] = "name" if _is_name(node, context) else "word"
			if rhs["resolved"] == "name":
				var other := context.kind(word)
				if other != kind:
					out.append("'%s' is %s, compared with '%s', %s" % [name, _a(kind), word, _a(other)])
			elif kind != "word":
				out.append("unknown name '%s'" % word)
			else:
				var words := context.words(name)
				if not words.is_empty() and not words.has(word):
					out.append("'%s' is not a word of '%s' (%s)" % [word, name, ", ".join(words)])


static func _a(kind: String) -> String:
	return "an int" if kind == "int" else "a " + kind


## The tokens of the text: {"tokens": [{"t", "v", "at"}...], "error"}. "t" is "name", "int",
## "op", "(", ")", a keyword, or "end"; "at" the 1-based column.
static func _tokenize(text: String) -> Dictionary:
	var tokens: Array = []
	var i := 0
	while i < text.length():
		var c := text[i]
		if c == " " or c == "\t":
			i += 1
			continue
		if c == "(" or c == ")":
			tokens.append({"t": c, "v": c, "at": i + 1})
			i += 1
			continue
		if c in "=!<>":
			var two := text.substr(i, 2)
			if two in OPERATORS:
				tokens.append({"t": "op", "v": two, "at": i + 1})
				i += 2
				continue
			if c == "<" or c == ">":
				tokens.append({"t": "op", "v": c, "at": i + 1})
				i += 1
				continue
			return {"tokens": [], "error": "unknown operator '%s' at column %d" % [c, i + 1]}
		var start := i
		if _is_digit(c) or (c == "-" and i + 1 < text.length() and _is_digit(text[i + 1])):
			i += 1
			while i < text.length() and _is_digit(text[i]):
				i += 1
			var digits := text.substr(start, i - start)
			if not is_integer(digits):
				return {"tokens": [], "error": "'%s' at column %d is not an integer (no leading zero)" % [digits, start + 1]}
			tokens.append({"t": "int", "v": int(digits), "at": start + 1})
			continue
		if _is_letter(c):
			while i < text.length() and (_is_letter(text[i]) or _is_digit(text[i]) or text[i] == "."):
				i += 1
			var word := text.substr(start, i - start)
			tokens.append({"t": word if word in KEYWORDS else "name", "v": word, "at": start + 1})
			continue
		return {"tokens": [], "error": "unexpected character '%s' at column %d" % [c, i + 1]}
	tokens.append({"t": "end", "v": "", "at": text.length() + 1})
	return {"tokens": tokens, "error": ""}


static func _is_digit(c: String) -> bool:
	return c >= "0" and c <= "9"


static func _is_letter(c: String) -> bool:
	return (c >= "a" and c <= "z") or (c >= "A" and c <= "Z") or c == "_"


## A recursive descent over the tokens; the first error sticks.
class _Parser:
	var tokens: Array
	var at := 0
	var error := ""

	func _init(list: Array) -> void:
		tokens = list

	func peek() -> Dictionary:
		return tokens[at]

	func take() -> Dictionary:
		var token: Dictionary = tokens[at]
		at = mini(at + 1, tokens.size() - 1)
		return token

	func fail(message: String) -> Dictionary:
		if error == "":
			error = message
		return {}

	static func describe(token: Dictionary) -> String:
		if token["t"] == "end":
			return "the end"
		return "'%s' (column %d)" % [str(token["v"]), token["at"]]

	func parse_or() -> Dictionary:
		var left := parse_and()
		while error == "" and peek()["t"] == "or":
			take()
			left = {"op": "or", "a": left, "b": parse_and()}
		return left

	func parse_and() -> Dictionary:
		var left := parse_not()
		while error == "" and peek()["t"] == "and":
			take()
			left = {"op": "and", "a": left, "b": parse_not()}
		return left

	func parse_not() -> Dictionary:
		if peek()["t"] == "not":
			take()
			return {"op": "not", "a": parse_not()}
		return parse_comparison()

	func parse_comparison() -> Dictionary:
		if error != "":
			return {}
		var token := peek()
		if token["t"] == "(":
			take()
			var inner := parse_or()
			if error != "":
				return {}
			if peek()["t"] != ")":
				return fail("expected ')' at %s" % describe(peek()))
			take()
			return inner
		if token["t"] != "name":
			return fail("expected a name at %s" % describe(token))
		take()
		if peek()["t"] != "op":
			return {"op": "name", "name": token["v"]}
		var op: String = take()["v"]
		var rhs := peek()
		match rhs["t"]:
			"int":
				take()
				return {"op": "cmp", "cmp": op, "name": token["v"], "rhs": {"kind": "int", "value": rhs["v"]}}
			"true", "false":
				take()
				return {"op": "cmp", "cmp": op, "name": token["v"], "rhs": {"kind": "bool", "value": rhs["t"] == "true"}}
			"name":
				take()
				return {"op": "cmp", "cmp": op, "name": token["v"], "rhs": {"kind": "ident", "value": rhs["v"]}}
		return fail("expected a value after '%s' at %s" % [op, describe(rhs)])
