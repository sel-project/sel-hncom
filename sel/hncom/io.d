/*
 * Copyright (c) 2017-2018 sel-project
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 */
/**
 * Copyright: Copyright (c) 2017-2018 sel-project
 * License: MIT
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/sel-hncom/sel/hncom/io.d, sel/hncom/io.d)
 */
module sel.hncom.io;

import std.bitmanip : nativeToBigEndian, bigEndianToNative;
import std.json : JSONValue, parseJSON, JSONException;
import std.socket : Address, InternetAddress, Internet6Address, UnknownAddress;
import std.traits : isArray, isDynamicArray, isAssociativeArray, KeyType, ValueType, isIntegral, isSigned, Unsigned;
import std.typecons : isTuple;
import std.uuid : UUID;

mixin template IO(E...) {

	import sel.hncom.io : IOImpl, encodeType;

	mixin IOImpl!E;

	ubyte[] encode() {
		ubyte[] buffer;
		encodeType(ID, buffer);
		encodeValues(buffer);
		return buffer;
	}

	typeof(this) decode(ubyte[] buffer) {
		size_t index = 0;
		decodeValues(buffer, index);
		return this;
	}

	static typeof(this) fromBuffer(ubyte[] buffer) {
		return typeof(this)().decode(buffer);
	}

}

mixin template IOImpl(E...) {

	import sel.hncom.io : encodeType, decodeType;

	private void encodeValues(ref ubyte[] buffer) {
		foreach(ref value ; E) {
			encodeType(value, buffer);
		}
	}

	private void decodeValues(ubyte[] buffer, ref size_t index) {
		foreach(ref value ; E) {
			value = decodeType!(typeof(value))(buffer, index);
		}
	}

}

void encodeType(T)(T value, ref ubyte[] buffer) {
	static if(isArray!T) {
		static if(isDynamicArray!T) encodeLength(value.length, buffer);
		encodeArray(value, buffer);
	} else static if(isAssociativeArray!T) {
		encodeLength(value.length, buffer);
		foreach(key, v; value) {
			encodeType(key, buffer);
			encodeType(v, buffer);
		}
	} else static if(isTuple!T) {
		foreach(i, name; T.fieldNames) {
			encodeType!(T.Types[i])(mixin("value." ~ name), buffer);
		}
	} else static if(is(T == JSONValue)) {
		encodeType(value.toString(), buffer);
	} else static if(is(T == UUID)) {
		buffer ~= value.data;
	} else static if(is(T == Address)) {
		if(cast(InternetAddress)value) {
			auto v4 = cast(InternetAddress)value;
			buffer ~= ubyte(4);
			encodeAddress(v4.addr, buffer);
			encodeAddress(v4.port, buffer);
		} else if(cast(Internet6Address)value) {
			auto v6 = cast(Internet6Address)value;
			buffer ~= ubyte(6);
			buffer ~= v6.addr;
			encodeAddress(v6.port, buffer);
		} else {
			buffer ~= ubyte(0);
		}
	} else static if(T.sizeof == 1) {
		buffer ~= value;
	} else static if(isIntegral!T) {
		static if(isSigned!T) {
			assert(value >= -1);
			encodeType(cast(Unsigned!T)(value+1), buffer);
		} else {
			while(value > 0b0111_1111) {
				buffer ~= (value & 0b0111_1111) | 0b1000_0000;
				value >>>= 7;
			}
			buffer ~= value & 0b0111_1111;
		}
	} else {
		buffer ~= nativeToBigEndian(value);
	}
}

void encodeLength(size_t _length, ref ubyte[] buffer) {
	static if(is(size_t == uint)) {
		alias length = _length;
	} else {
		uint length = cast(uint)_length;
	}
	encodeType(length, buffer);
}

void encodeArray(T)(T array, ref ubyte[] buffer) if(isArray!T) {
	alias E = typeof(T.init[0]);
	static if(is(typeof(E.sizeof)) && E.sizeof == 1) {
		buffer ~= cast(ubyte[])array;
	} else {
		foreach(element ; array) {
			encodeType(element, buffer);
		}
	}
}

void encodeAddress(T)(T value, ref ubyte[] buffer) if(isIntegral!T) {
	buffer ~= nativeToBigEndian(value);
}

T decodeType(T)(ubyte[] buffer, ref size_t index) {
	static if(isDynamicArray!T) {
		return decodeArray!T(decodeLength(buffer, index), buffer, index);
	} else static if(isArray!T) {
		return decodeArray!T(T.init.length, buffer, index);
	} else static if(isAssociativeArray!T) {
		T ret;
		foreach(i ; 0..decodeLength(buffer, index)) {
			ret[decodeType!(KeyType!T)(buffer, index)] = decodeType!(ValueType!T)(buffer, index);
		}
		return ret;
	} else static if(isTuple!T) {
		T ret;
		foreach(i, name; T.fieldNames) {
			mixin("ret." ~ name) = decodeType!(T.Types[i])(buffer, index);
		}
		return ret;
	} else static if(is(T == JSONValue)) {
		try {
			return parseJSON(decodeType!string(buffer, index));
		} catch(JSONException) {
			return JSONValue.init;
		}
	} else static if(is(T == UUID)) {
		return UUID(decodeType!(ubyte[16])(buffer, index));
	} else static if(is(T == Address)) {
		switch(decodeType!ubyte(buffer, index)) {
			case 4: return new InternetAddress(decodeAddress!uint(buffer, index), decodeAddress!ushort(buffer, index));
			case 6: return new Internet6Address(decodeType!(ubyte[16])(buffer, index), decodeAddress!ushort(buffer, index));
			default: return new UnknownAddress();
		}
	} else static if(T.sizeof == 1) {
		return cast(T)buffer[index++];
	} else static if(isIntegral!T) {
		// short, int, long
		static if(isSigned!T) {
			return cast(T)(decodeType!(Unsigned!T)(buffer, index) - 1);
		} else {
			T ret;
			size_t shift = 0;
			ubyte next;
			do {
				next = buffer[index++];
				ret |= ((next & 0b0111_1111) << shift);
				shift += 7;
			} while(next & 0b1000_0000);
			return ret;
		}
	} else {
		// float, double
		ubyte[T.sizeof] data = buffer[index..index+=T.sizeof];
		return bigEndianToNative!T(data);
	}
}

size_t decodeLength(ubyte[] buffer, ref size_t index) {
	return decodeType!uint(buffer, index);
}

T decodeArray(T)(size_t length, ubyte[] buffer, ref size_t index) if(isArray!T) {
	alias E = typeof(T.init[0]);
	static if(is(typeof(E.sizeof)) && E.sizeof == 1) {
		T ret = cast(E[])buffer[index..index+=length];
		return ret;
	} else {
		static if(isDynamicArray!T) auto ret = new E[length];
		else T ret;
		foreach(ref element ; ret) {
			element = decodeType!E(buffer, index);
		}
		return ret;
	}
}

T decodeAddress(T)(ubyte[] buffer, ref size_t index) if(isIntegral!T) {
	ubyte[T.sizeof] data = buffer[index..index+=T.sizeof];
	return bigEndianToNative!T(data);
}

unittest {

	import std.conv;

	ubyte[] encode(T)(T value) {
		ubyte[] buffer;
		encodeType(value, buffer);
		return buffer;
	}

	T decode(T)(ubyte[] buffer) {
		size_t index = 0;
		return decodeType!T(buffer, index);
	}

	// numbers

	assert(encode(true) == [1]);
	assert(encode(ubyte(3)) == [3]);
	assert(encode(ushort(5)) == [5]);
	assert(encode(130u) == [130, 1]);
	assert(encode(12) == [13]);
	assert(encode(-1L) == [0]);
	assert(encode(2f) == [64, 0, 0, 0]);

	assert(decode!bool([0]) == false);
	assert(decode!byte([255]) == -1);
	assert(decode!short([0]) == -1);
	assert(decode!uint([132, 1]) == 132);
	assert(decode!float([64, 64, 0, 0]) == 3);

	// uuid

	import std.uuid : randomUUID;
	auto uuid = randomUUID();
	assert(encode(uuid) == uuid.data);
	assert(decode!UUID(uuid.data) == uuid);

	// json

	import std.json : JSON_TYPE;
	assert(encode(JSONValue((JSONValue[string]).init)) == [2, '{', '}']);
	assert(decode!JSONValue([2, '{', '}']).type == JSON_TYPE.OBJECT);
	assert(decode!JSONValue([8, '[', '1', ',', '2', ',', ' ', '3', ']']) == JSONValue([1, 2, 3]));
	assert(decode!JSONValue([3, '{', '{', '}']).isNull);

	// addresses

	assert(encode(cast(Address)new InternetAddress("127.0.0.1", 0)) == [4, 127, 0, 0, 1, 0, 0]);
	assert(encode(cast(Address)new Internet6Address("::1", 80)) == [6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 80]);
	assert(encode(Address.init) == [0]);

	assert(cast(UnknownAddress)decode!Address([0]));
	assert(decode!Address([4, 192, 168, 1, 1, 0, 80]) == new InternetAddress("192.168.1.1", 80));
	assert(decode!Address([6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]).toString() == "[::]:0");

	// dynamic arrays

	assert(encode([1, 2, 3]) == [3, 2, 3, 4]);
	assert(encode(cast(ubyte[])[1, 2, 3]) == [3, 1, 2, 3]);
	assert(encode(["this", "is", "a", "string"]) == [4, 4, 't', 'h', 'i', 's', 2, 'i', 's', 1, 'a', 6, 's', 't', 'r', 'i', 'n', 'g']);

	assert(decode!(bool[])([2, 0, 1]) == [false, true]);
	assert(decode!(uint[])([3, 0, 1, 2]) == [0, 1, 2]);

	// static arrays

	int[4] int_;
	string[2] string_;
	string_[1] = "$";

	assert(encode(int_) == [1, 1, 1, 1]);
	assert(encode(string_) == [0, 1, '$']);

	// associative arrays

	assert(encode([0: 12u]) == [1, 1, 12]);
	assert(decode!(string[bool])([2, 1, 4, 't', 'r', 'u', 'e', 0, 5, 'f', 'a', 'l', 's', 'e']) == [true: "true", false: "false"]);

	// tuples

	import std.typecons : Tuple;

	alias Test = Tuple!(Address, "address", int, "number");

	assert(encode(Test.init) == [0, 1]);
	assert(decode!Test([4, 0, 0, 0, 0, 0, 80, 0]) == Test(new InternetAddress("0.0.0.0", 80), -1));

}
