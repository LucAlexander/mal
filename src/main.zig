const std = @import("std");
const Buffer = std.ArrayList;
const Map = std.StringHashMap;

const TOKEN = u64;
const TOKEN_EQ = '=';
const TOKEN_SMI = ';';
const TOKEN_OPEN_BLOCK = '{';
const TOKEN_CLOSE_BLOCK = '}';
const TOKEN_OPEN_QUOTE = '(';
const TOKEN_CLOSE_QUOTE = ')';
const TOKEN_REF = '&';
const TOKEN_PTR = '^';
const TOKEN_OPEN_INDEX = '[';
const TOKEN_CLOSE_INDEX = ']';
const TOKEN_ADD = '+';
const TOKEN_SUB = '-';
const TOKEN_MUL = '*';
const TOKEN_DIV = '/';
const TOKEN_MOD = '%';
const TOKEN_LT = '<';
const TOKEN_GT = '>';
const TOKEN_IF = 0;
const TOKEN_FOR = 1;
const TOKEN_IN = 2;
const TOKEN_EQL = 3;
const TOKEN_STR = 4;
const TOKEN_IDEN = 5;
const TOKEN_LE = 6;
const TOKEN_GE = 7;
const TOKEN_ASM = 8;
const TOKEN_ELSE = 9;
const TOKEN_IMPORT = 10;

const Token = struct {
	text: []const u8,
	tag: TOKEN
};

pub fn tokenize(mem: *const std.mem.Allocator, text: []const u8) Buffer(Token) {
	var idenmap = Map(TOKEN).init(mem.*);
	idenmap.put("if", TOKEN_IF ) catch unreachable;
	idenmap.put("for", TOKEN_FOR ) catch unreachable;
	idenmap.put("in", TOKEN_IN ) catch unreachable;
	idenmap.put("==", TOKEN_EQL ) catch unreachable;
	idenmap.put("<=", TOKEN_LE ) catch unreachable;
	idenmap.put(">=", TOKEN_GE ) catch unreachable;
	idenmap.put("asm", TOKEN_ASM ) catch unreachable;
	idenmap.put("else", TOKEN_ELSE ) catch unreachable;
	idenmap.put("import", TOKEN_IMPORT ) catch unreachable;
	var tokens = Buffer(Token).init(mem.*);
	var i: u64 = 0;
	while (i < text.len){
		const c = text[i];
		switch (c) {
			'\t', '\n', ' ', '\r' => {
				i += 1;
				continue;
			},
			TOKEN_EQ, TOKEN_SMI, TOKEN_OPEN_BLOCK, TOKEN_CLOSE_BLOCK, TOKEN_OPEN_QUOTE, TOKEN_CLOSE_QUOTE, TOKEN_REF, TOKEN_PTR, TOKEN_OPEN_INDEX, TOKEN_CLOSE_INDEX, TOKEN_LT, TOKEN_GT, TOKEN_ADD, TOKEN_SUB, TOKEN_MUL, TOKEN_DIV, TOKEN_MOD => {
				tokens.append(Token{
					.text = text[i..i+1],
					.tag = c
				}) catch unreachable;
				i += 1;
				continue;
			},
			'"' => {
				var k = i;
				while (k < text.len){
					if (text[k] == '"'){
						k += 1;
						break;
					}
					k += 1;
				}
				tokens.append(Token{
					.text = text[i..k],
					.tag = TOKEN_STR
				}) catch unreachable;
				i = k;
				continue;
			},
			else => {
				var k = i;
				while (k < text.len){
					const next_c = text[k];
					switch (next_c){
						'\t', '\n', ' ', '\r', TOKEN_EQ, TOKEN_SMI, TOKEN_OPEN_BLOCK, TOKEN_CLOSE_BLOCK, TOKEN_OPEN_QUOTE, TOKEN_CLOSE_QUOTE, TOKEN_REF, TOKEN_PTR, TOKEN_OPEN_INDEX, TOKEN_CLOSE_INDEX, TOKEN_LT, TOKEN_GT, TOKEN_ADD, TOKEN_SUB, TOKEN_MUL, TOKEN_DIV, TOKEN_MOD => {
							break;
						},
						else => {}
					}
					k += 1;
				}
				if (idenmap.get(text[i..k])) |id| {
					tokens.append(Token{
						.text = text[i..k],
						.tag = id
					}) catch unreachable;
					i = k;
					continue;
				}
				tokens.append(Token{
					.text = text[i..k],
					.tag = TOKEN_IDEN
				}) catch unreachable;
				i = k;
				continue;
			}
		}
	}
	return tokens;
}

pub fn get_contents(mem: *const std.mem.Allocator, filename: []const u8) ![]u8 {
	var infile = std.fs.cwd().openFile(filename, .{}) catch |err| {
		std.debug.print("File not found: {s}\n", .{filename});
		return err;
	};
	defer infile.close();
	const stat = infile.stat() catch |err| {
		std.debug.print("Errored file stat: {s}\n", .{filename});
		return err;
	};
	const contents = infile.readToEndAlloc(mem.*, stat.size+1) catch |err| {
		std.debug.print("Error reading file: {s}\n", .{filename});
		return err;
	};
	return contents;
}

const Node = struct{
	name: Token,
	args: Buffer(Token),
	value: union(enum){
		block: Block,
		expression: Expression
	}
};

const Block = Buffer(Statement);

const Statement = union(enum){
	if_statement: struct {
		condition: Expression,
		consequent: *Block,
		alternate: ?*Block
	},
	for_statement: struct {
		variable: Token,
		range: Expression,
		consequent: *Block
	},
	definition: *Node,
	asm_statement: *Block,
	stack_statement: Expression
};

const Expression = union(enum){
	composition: Buffer(*Expression),
	quote: *Expression,
	atom: Token,
	access: *Expression
};

const ParseError = error{
	UnexpectedToken,
	UnexpectedEOF
};

pub fn parse(mem: *const std.mem.Allocator, tokens: []Token) ParseError!Buffer(Node) {
	var definitions = Buffer(Node).init(mem.*);
	var i: u64 = 0;
	while (i < tokens.len){
		definitions.append(try parse_definition(mem, &i, tokens)) catch unreachable;
	}
	return definitions;
}

pub fn parse_definition(mem: *const std.mem.Allocator, i: *u64, tokens: []Token) ParseError!*Node {
	const name = tokens[i.*];
	i.* += 1;
	if (name.tag != TOKEN_IDEN){
		return ParseError.UnexpectedToken;
	}
	if (i.* >= tokens.len){
		return ParseError.UnexpectedEOF;
	}
	var args = Buffer(Token).init(mem.*)
	while (i.* < tokens.len and tokens[i.*].tag != TOKEN_EQ){
		if (tokens[i.*].tag == TOKEN_IDEN){
			args.append(tokens[i.*]) catch unreachable;
			i.* += 1;
			continue;
		}
		return ParseError.UnexpectedToken;
	}
	i.* += 1;
	if (i.* >= tokens.len){
		return ParseError.UnexpectedEOF;
	}
	if (tokens[i.*].tag == TOKEN_OPEN_BLOCK){
		const block = try parse_block(mem, i, tokens);
		return Node{
			.name = name,
			.args = args,
			.value = .{
				.block = block
			}
		};
	}
	const expr = try parse_expression(mem, i, tokens, TOKEN_SEMI);
	return Node{
		.name = name,
		.args = args,
		.value = .{
			.expression = expr
		}
	}
}

pub fn parse_block(mem: *const std.mem.Allocator, i: *u64, tokens: []Token) ParseError!Block {
	if (tokens[i.*].tag != TOKEN_OPEN_BLOCK){
		return ParseError.UnexpectedToken;
	}
	i.* += 1;
	var block = Buffer(Statement).init(mem.*);
	while (i.* < tokens.len and tokens[i.*].tag != TOKEN_CLOSE_BLOCK){
		block.append(try parse_statement(mem, i, tokens)) catch unreachable;
	}
	i.* += 1;
	return block;
}

pub fn parse_statement(mem: *const std.mem.Allocator, i: *u64, tokens: []Token) ParseError!Statement {
	if (tokens[i.*].tag == TOKEN_IF){
		i.* += 1;
		if (i.* >= tokens.len){
			return ParseError.UnexpectedEOF;
		}
		const condition = try parse_expression(mem, i, tokens, TOKEN_OPEN_BLOCK);
		i.* -= 1;
		const consequent = mem.create(Block) catch unreachable;
		consequent.* = try parse_block(mem, i, tokens);
		const alternate: ?*Block = null;
		if (i.* >= tokens.len){
			return ParseError.UnexpectedEOF;
		}
		if (tokens[i.*].tag == TOKEN_ELSE){
			i.* += 1;
			if (i.* >= tokens.len){
				return ParseError.UnexpectedEOF;
			}
			alternate = mem.create(Block) catch unreachable;
			alternate.* = try parse_block(me,, i, tokens);
		}
		return Statement(
			.if_statement = .{
				.condition = condition,
				.consequent = consequent,
				.alternate = alternate
			}
		);
	}
	else if (tokens[i.*].tag == TOKEN_FOR){
		i.* += 1;
		if (i.* >= tokens.len){
			return ParseError.UnexpectedEOF;
		}
		if (tokens[i.*].tag != TOKEN_IDEN){
			return ParseError.UnexpectedToken;
		}
		const variable = tokens[i.*];
		i.* += 1;
		if (i.* >= tokens.len){
			return ParseError.UnexpectedEOF;
		}
		if (tokens[i.*].tag != TOKEN_IN){
			return ParseError.UnexpectedToken;
		}
		i.* += 1;
		if (i.* >= tokens.len){
			return ParseError.UnexpectedEOF;
		}
		const range = mem.create(Expression) catch unreachable;
		range.* = try parse_expression(mem, i, token, TOKEN_OPEN_BLOCK);
		const consequent = mem.create(Block) catch unreachable;
		consequent.* = parse_block(mem, i, tokens);
		return Statement{
			.for_statement = .{
				.variable = variable,
				.range = range,
				.consequent = consequent
			}
		};
	}
	else if (tokens[i.*].tag == TOKEN_ASM){
		i.* += 1;
		if (i >= tokens.len){
			return ParseError.UnexpectedEOF;
		}
		if (tokens[i.*] != TOKEN_OPEN_BLOCK){
			return ParseError.UnexpectedToken;
		}
		const loc = mem.create(Block) catch unreachable;
		loc.* = try parse_block(mem, i, tokens);
		return Statement{
			.asm_statement = loc;
		};
	}
	else {
		var k = i.*;
		while (k < tokens.len){
			if (tokens[k].tag == TOKEN_EQ){
				const loc = mem.create(Node) catch unreachable;
				loc.* = try parse_definition(mem, i, tokens);
				return Statement{
					.definition = loc
				};
			}
			else if (tokens[k].tag == TOKEN_SEMI){
				const expr = try parse_expression(mem, i, TOKEN_SEMI);
				return Statement{
					.stack_statement = expr
				};
			}
			k += 1;
		}
		return ParseError.UnexpectedEOF;
	}
}

pub fn parse_expression(mem: *const std.mem.Allocator, i: *u64, tokens: []Token, end_token: TOKEN) ParseError!Expression {
	var expr = Expr{
		.composition = Buffer(*Expression).init(mem.*)
	};
	while (i.* < tokens.len and tokens[i.*].tag != end_token){
		if (tokens[i.*].tag == TOKEN_OPEN_QUOTE){
			i.* += 1;
			const loc = mem.create(Expression) catch unreachable;
			loc.* = try parse_expression(mem, i, tokens, TOKEN_CLOSE_QUOTE);
			expr.composition.append(loc) catch unreachable;
		}
		else if (tokens[i.*].tag == TOKEN_OPEN_INDEX){
			i.* += 1;
			const loc = mem.create(Expression) catch unreachable;
			loc.* = try parse_expression(mem, i, tokens, TOKEN_CLOSE_INDEX);
			expr.composition.append(loc) catch unreachable;
		}
		else{
			if (tokens[i.*].tag != TOKEN_IDEN){
				return ParseError.UnexpectedToken;
			}
			const loc = mem.create(Expression) catch unreachable;
			loc.* = Expression{
				.atom = tokens[i.*];
			};
			expr.composition.append() catch unreachable;
		}
	}
	if (tokens[i.*].tag != end_token){
		return ParseError.UnexpectedEOF;
	}
	i.* += 1;
	return expr;
}

pub fn main() anyerror!void {
	const heap = std.heap.page_allocator;
	const main_buffer = heap.alloc(u8, 0x1000000) catch unreachable;
	const temp_buffer = heap.alloc(u8, 0x10000) catch unreachable;
	var main_mem_fixed = std.heap.FixedBufferAllocator.init(main_buffer);
	var temp_mem_fixed = std.heap.FixedBufferAllocator.init(temp_buffer);
	var main_mem = main_mem_fixed.allocator();
	var temp_mem = temp_mem_fixed.allocator();
	const args = try std.process.argsAlloc(main_mem);
	if (args.len == 1){
		std.debug.print("-h for help\n", .{});
		return;
	}
	if (std.mem.eql(u8, args[1], "-h")){
		std.debug.print("Help Menu\n", .{});
		std.debug.print("   -h : Show this message\n", .{});
		std.debug.print("   [filename] : compile file\n", .{});
		return;
	}
	const filename = args[1];
	const contents = try get_contents(&main_mem, filename);
	const tokens = tokenize(&main_mem, contents);
}
