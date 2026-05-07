const std = @import("std");
const Buffer = std.ArrayList;
const Map = std.StringHashMap;

const TOKEN = u64;
const TOKEN_EQ = '=';
const TOKEN_SEMI = ';';
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
const TOKEN_IMPORT = 10; // TODO file import

const Token = struct {
	text: []const u8,
	tag: TOKEN,

	pub fn show(self: *Token) void {
		std.debug.print("{s} ", .{self.text});
	}
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
		if (c == '/'){
			if (i+1 < text.len){
				if (text[i+1] == '/'){
					while (i < text.len and text[i] != '\n'){
						i += 1;
					}
					continue;
				}
			}
		}
		if (c == '='){
			if (i+1 < text.len){
				if (text[i+1] == '='){
					tokens.append(Token{
						.text = text[i..i+2],
						.tag = TOKEN_EQL
					}) catch unreachable;
					i += 2;
					continue;
				}
			}
		}
		if (c == '>'){
			if (i+1 < text.len){
				if (text[i+1] == '='){
					tokens.append(Token{
						.text = text[i..i+2],
						.tag = TOKEN_GE
					}) catch unreachable;
					i += 2;
					continue;
				}
			}
		}
		if (c == '<'){
			if (i+1 < text.len){
				if (text[i+1] == '='){
					tokens.append(Token{
						.text = text[i..i+2],
						.tag = TOKEN_LE
					}) catch unreachable;
					i += 2;
					continue;
				}
			}
		}
		switch (c) {
			'\t', '\n', ' ', '\r' => {
				i += 1;
				continue;
			},
			TOKEN_EQ, TOKEN_SEMI, TOKEN_OPEN_BLOCK, TOKEN_CLOSE_BLOCK, TOKEN_OPEN_QUOTE, TOKEN_CLOSE_QUOTE, TOKEN_REF, TOKEN_PTR, TOKEN_OPEN_INDEX, TOKEN_CLOSE_INDEX, TOKEN_LT, TOKEN_GT, TOKEN_ADD, TOKEN_SUB, TOKEN_MUL, TOKEN_DIV, TOKEN_MOD => {
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
						'\t', '\n', ' ', '\r', TOKEN_EQ, TOKEN_SEMI, TOKEN_OPEN_BLOCK, TOKEN_CLOSE_BLOCK, TOKEN_OPEN_QUOTE, TOKEN_CLOSE_QUOTE, TOKEN_REF, TOKEN_PTR, TOKEN_OPEN_INDEX, TOKEN_CLOSE_INDEX, TOKEN_LT, TOKEN_GT, TOKEN_ADD, TOKEN_SUB, TOKEN_MUL, TOKEN_DIV, TOKEN_MOD => {
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
	},
	
	pub fn show(self: *Node) void {
		self.name.show();
		for (self.args.items) |*arg| {
			arg.show();
		}
		std.debug.print("= ", .{});
		switch(self.value){
			.block => {
				show_block(&self.value.block);
			},
			.expression => {
				self.value.expression.show();
				std.debug.print("\n", .{});
			}
		}
	}
};

const Block = Buffer(Statement);

pub fn show_block(self: *Block) void {
	std.debug.print("<\n", .{});
	for (self.items) |*line| {
		line.show();
		std.debug.print("\n", .{});
	}
	std.debug.print(">\n", .{});
}

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
	assignment: struct{
		left: Expression,
		right: Expression
	},
	asm_statement: *Block,
	stack_statement: Expression,
	
	pub fn show(self: *Statement) void {
		switch (self.*){
			.if_statement => {
				std.debug.print("if ", .{});
				self.if_statement.condition.show();
				show_block(self.if_statement.consequent);
				if (self.if_statement.alternate) |alt| {
					std.debug.print("else ", .{});
					show_block(alt);
				}
			},
			.for_statement => {
				std.debug.print("for ", .{});
				self.for_statement.variable.show();
				std.debug.print("in ", .{});
				self.for_statement.range.show();
				show_block(self.for_statement.consequent);
			},
			.definition => {
				self.definition.show();
			},
			.assignment => {
				self.assignment.left.show();
				std.debug.print("<- ", .{});
				self.assignment.right.show();
			},
			.asm_statement => {
				std.debug.print("asm ", .{});
				show_block(self.asm_statement);
			},
			.stack_statement => {
				self.stack_statement.show();
			}
		}
	}
};

const Expression = union(enum){
	composition: Buffer(*Expression),
	quote: *Expression,
	atom: Token,
	access: *Expression,

	pub fn show(self: *Expression) void {
		switch(self.*) {
			.composition => {
				for (self.composition.items) |atom| {
					atom.show();
					std.debug.print(" ", .{});
				}
			},
			.quote => {
				std.debug.print("(", .{});
				self.quote.show();
				std.debug.print(")", .{});
			},
			.atom => {
				self.atom.show();
			},
			.access => {
				std.debug.print("[", .{});
				self.access.show();
				std.debug.print("]", .{});
			}
		}
	}
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

pub fn parse_definition(mem: *const std.mem.Allocator, i: *u64, tokens: []Token) ParseError!Node {
	const name = tokens[i.*];
	i.* += 1;
	if (name.tag != TOKEN_IDEN){
		return ParseError.UnexpectedToken;
	}
	if (i.* >= tokens.len){
		return ParseError.UnexpectedEOF;
	}
	var args = Buffer(Token).init(mem.*);
	while (i.* < tokens.len and tokens[i.*].tag != TOKEN_EQ){
		if (tokens[i.*].tag == TOKEN_IDEN){
			args.append(tokens[i.*]) catch unreachable;
			i.* += 1;
			continue;
		}
		std.debug.print("Unexpected token: {s}\n", .{tokens[i.*].text});
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
	};
}

pub fn parse_block(mem: *const std.mem.Allocator, i: *u64, tokens: []Token) ParseError!Block {
	if (tokens[i.*].tag != TOKEN_OPEN_BLOCK){
		std.debug.print("Unexpected token: {s}\n", .{tokens[i.*].text});
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
		var alternate: ?*Block = null;
		if (i.* >= tokens.len){
			return ParseError.UnexpectedEOF;
		}
		if (tokens[i.*].tag == TOKEN_ELSE){
			i.* += 1;
			if (i.* >= tokens.len){
				return ParseError.UnexpectedEOF;
			}
			alternate = mem.create(Block) catch unreachable;
			alternate.?.* = try parse_block(mem, i, tokens);
		}
		return Statement{
			.if_statement = .{
				.condition = condition,
				.consequent = consequent,
				.alternate = alternate
			}
		};
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
		const range = try parse_expression(mem, i, tokens, TOKEN_OPEN_BLOCK);
		i.* -= 1;
		const consequent = mem.create(Block) catch unreachable;
		consequent.* = try parse_block(mem, i, tokens);
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
		if (i.* >= tokens.len){
			return ParseError.UnexpectedEOF;
		}
		if (tokens[i.*].tag != TOKEN_OPEN_BLOCK){
			return ParseError.UnexpectedToken;
		}
		const loc = mem.create(Block) catch unreachable;
		loc.* = try parse_block(mem, i, tokens);
		return Statement{
			.asm_statement = loc
		};
	}
	else {
		var k = i.*;
		var not_iden: bool = false;
		while (k < tokens.len){
			if (tokens[k].tag != TOKEN_IDEN and tokens[k].tag != TOKEN_EQ){
				not_iden = true;
			}
			if (tokens[k].tag == TOKEN_EQ){
				if (not_iden){
					if (tokens[k+1].tag == TOKEN_OPEN_BLOCK){
						const loc = mem.create(Node) catch unreachable;
						loc.* = try parse_definition(mem, i, tokens);
						return Statement{
							.definition = loc
						};
					}
					const left = try parse_expression(mem, i, tokens, TOKEN_EQ);
					const right = try parse_expression(mem, i, tokens, TOKEN_SEMI);
					return Statement{
						.assignment = .{
							.left = left,
							.right = right
						}
					};
				}
				else{
					const loc = mem.create(Node) catch unreachable;
					loc.* = try parse_definition(mem, i, tokens);
					return Statement{
						.definition = loc
					};
				}
			}
			else if (tokens[k].tag == TOKEN_SEMI){
				const expr = try parse_expression(mem, i, tokens, TOKEN_SEMI);
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
	var expr = Expression{
		.composition = Buffer(*Expression).init(mem.*)
	};
	while (i.* < tokens.len and tokens[i.*].tag != end_token){
		if (tokens[i.*].tag == TOKEN_OPEN_QUOTE){
			i.* += 1;
			const loc = mem.create(Expression) catch unreachable;
			loc.* = Expression{
				.quote = mem.create(Expression) catch unreachable
			};
			loc.quote.* = try parse_expression(mem, i, tokens, TOKEN_CLOSE_QUOTE);
			expr.composition.append(loc) catch unreachable;
		}
		else if (tokens[i.*].tag == TOKEN_OPEN_INDEX){
			i.* += 1;
			const loc = mem.create(Expression) catch unreachable;
			loc.* = Expression{
				.access = mem.create(Expression) catch unreachable
			};
			loc.access.* = try parse_expression(mem, i, tokens, TOKEN_CLOSE_INDEX);
			expr.composition.append(loc) catch unreachable;
		}
		else{
			if (!is_intrinsic(tokens[i.*].tag) and tokens[i.*].tag != TOKEN_IDEN){
				std.debug.print("Unexpected token: {s}\n", .{tokens[i.*].text});
				return ParseError.UnexpectedToken;
			}
			const loc = mem.create(Expression) catch unreachable;
			loc.* = Expression{
				.atom = tokens[i.*]
			};
			expr.composition.append(loc) catch unreachable;
			i.* += 1;
		}
	}
	if (tokens[i.*].tag != end_token){
		return ParseError.UnexpectedEOF;
	}
	i.* += 1;
	return expr;
}

pub fn is_intrinsic(id: TOKEN) bool {
	switch (id){
		TOKEN_REF, TOKEN_PTR, TOKEN_ADD , TOKEN_STR , TOKEN_LE , TOKEN_GE , TOKEN_EQL , TOKEN_SUB , TOKEN_MUL , TOKEN_DIV , TOKEN_MOD , TOKEN_LT , TOKEN_GT  => {
			return true;
		},
		else => {
			return false;
		}
	}
}

pub fn main() anyerror!void {
	const heap = std.heap.page_allocator;
	const main_buffer = heap.alloc(u8, 0x1000000) catch unreachable;
	const temp_buffer = heap.alloc(u8, 0x10000) catch unreachable;
	var main_mem_fixed = std.heap.FixedBufferAllocator.init(main_buffer);
	var temp_mem_fixed = std.heap.FixedBufferAllocator.init(temp_buffer);
	var main_mem = main_mem_fixed.allocator();
	_ = temp_mem_fixed.allocator();
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
	const ast = try parse(&main_mem, tokens.items);
	var i: u64 = 0;
	while (i < ast.items.len){
		ast.items[i].show();
		i += 1;
	}
}
