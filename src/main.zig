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
const TOKEN_IF = 0;
const TOKEN_FOR = 1;
const TOKEN_IN = 2;
const TOKEN_EQL = 3;
const TOKEN_LT = 4;
const TOKEN_GT = 5;
const TOKEN_LE = 6;
const TOKEN_GE = 7;
const TOKEN_ASM = 8;
const TOKEN_ELSE = 9;
const TOKEN_STR = 10;
const TOKEN_IDEN = 11;

pub fn tokenizer(mem: *const std.mem.Allocator, text: []const u8) Buffer(Token) {
	
}

pub fn main() anyerror!void {
}
