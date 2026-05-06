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

const Token = struct {
	text: []const u8,
	tag: TOKEN
};

pub fn tokenizer(mem: *const std.mem.Allocator, text: []const u8) Buffer(Token) {
	var idenmap = Map(TOKEN).init(mem.*);
	idenmap.put("if", TOKEN_IF ) catch unreachable;
	idenmap.put("for", TOKEN_FOR ) catch unreachable;
	idenmap.put("in", TOKEN_IN ) catch unreachable;
	idenmap.put("==", TOKEN_EQL ) catch unreachable;
	idenmap.put("<=", TOKEN_LE ) catch unreachable;
	idenmap.put(">=", TOKEN_GE ) catch unreachable;
	idenmap.put("asm", TOKEN_ASM ) catch unreachable;
	idenmap.put("else", TOKEN_ELSE ) catch unreachable;
	var tokens = Buffer(Token).init(mem.*);
	var i: u64 = 0;
	while (i < text.len){
		const c = text[i];
		switch (c) {
			'\t', '\n', ' ', '\r' => {
				i += 1;
				continue;
			}
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
						}
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

pub fn main() anyerror!void {
}
