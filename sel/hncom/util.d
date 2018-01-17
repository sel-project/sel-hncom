/*
 * Copyright (c) 2017-2018 SEL
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU Lesser General Public License for more details.
 * 
 */
module sel.hncom.util;

import std.conv : to;
import std.zlib : Compress, UnCompress, HeaderFormat;

import sel.hncom.about;
import sel.hncom.io : IO;

/**
 * Group of packets.
 */
@clientbound @serverbound struct Uncompressed {

	enum ubyte ID = 5;

	/**
	 * If not 0 the same packet in the next field has the same id.
	 * Otherwise the packet id is the first byte of the packet.
	 */
	ubyte id;

	/**
	 * List of the encoded packets (with the ID if the id field is 0,
	 * without the ID otherwise.
	 */
	ubyte[][] packets;

	mixin IO!(id, packets);

	/**
	 * Adds a serialised packet to the array of packets.
	 * Example:
	 * ---
	 * // same packet
	 * auto uc = Uncompressed(RemoveWorld.ID);
	 * uc.add(RemoveWorld(12).encode());
	 * uc.add(RemoveWorld(13));
	 * 
	 * // different packets
	 * auto uc = Uncompressed(0);
	 * uc.add(AddWorld(23, "test", 0));
	 * uc.add(RemoveWorld(20));
	 * ---
	 */
	typeof(this) add(ubyte[] packet) {
		if(this.id == 0) {
			this.packets ~= packet;
		} else {
			assert(packet[0] == this.id);
			this.packets ~= packet[1..$];
		}
		return this;
	}

	/// ditto
	typeof(this) add(T)(T packet) if(is(typeof(T.encode))) {
		return this.add(packet.encode());
	}

	/**
	 * Creates a packet and start to add packets.
	 */
	static Uncompressed fromPackets(ubyte[][] packets...) {
		auto ret = Uncompressed(0);
		foreach(packet ; packets) {
			ret.add(packet);
		}
		return ret;
	}

	/**
	 * Creates an Uncompress packet from a list of packets
	 * of the same type.
	 * Example:
	 * ---
	 * Uncompress.fromPackets(RemoveWorld(3), RemoveWorld(4), RemoveWorld(5));
	 * Uncompress.fromPackets([RemoveWorld(1), RemoveWorld(44)]);
	 * ---
	 */
	static Uncompressed fromPackets(T)(T[] packets...) if(is(typeof(T.encode))) {
		auto ret = Uncompressed(T.ID);
		foreach(packet ; packets) {
			ret.packets ~= packet.encode()[1..$]; // remove ID
		}
		return ret;
	}

}

/**
 * Compressed packets.
 */
@clientbound @serverbound struct Compressed {

	enum ubyte ID = 6;

	/**
	 * Length of the uncompressed buffer.
	 */
	uint length;

	/**
	 * Same as Uncompressed's id field.
	 */
	ubyte id;

	/**
	 * Compressed data.
	 */
	ubyte[] payload;

	mixin IO!(length, id, payload);

	/**
	 * Creates a Compressed from an Uncompressed packet.
	 * The Uncompressed packet is encoded and the data is compressed using
	 * zlib's deflate algorithm.
	 * Example:
	 * ---
	 * Compress.compress(Uncompress.fromPackets(RemoveWorld(1), RemoveWorld(2)));
	 * ---
	 */
	static Compressed compress(Uncompressed uncompressed, int level=6) {
		ubyte[] buffer = uncompressed.encode()[1..$];
		auto ret = Compressed(buffer.length.to!uint, uncompressed.id);
		Compress compress = new Compress(level, HeaderFormat.deflate);
		ret.payload = cast(ubyte[])compress.compress(buffer);
		ret.payload ~= cast(ubyte[])compress.flush();
		return ret;
	}

	/**
	 * Creates a Compressed from a list of encoded packets.
	 */
	static Compressed compress(ubyte[][] packets...) {
		assert(packets.length);
		ubyte id = packets[0][0];
		foreach(packet ; packets[1..$]) {
			if(packet[0] != id) {
				id = 0;
				break;
			}
		}
		if(id != 0) {
			// remove ids
			foreach(ref packet ; packets) {
				packet = packet[1..$];
			}
		}
		return compress(Uncompressed(id, packets));
	}

	/**
	 * Uncompresses the data and returns an Uncompressed packet.
	 * Example:
	 * ---
	 * auto c = Compressed.fromBuffer(buffer);
	 * Uncompressed uc = c.uncompress();
	 * ---
	 */
	Uncompressed uncompress() {
		UnCompress uncompress = new UnCompress(this.length);
		ubyte[] buffer = cast(ubyte[])uncompress.uncompress(this.payload);
		buffer ~= cast(ubyte[])uncompress.flush();
		return Uncompressed.fromBuffer(buffer);
	}

}

unittest {

	import sel.hncom.status;

	Uncompressed uc;

	uc.add(RemoveNode(44));
	uc.add(RemoveWorld(12).encode());
	assert(uc.encode() == [Uncompressed.ID, 0, 2, 2, RemoveNode.ID, 44, 2, RemoveWorld.ID, 12]);

	uc = Uncompressed(RemoveNode.ID);
	uc.add(RemoveNode(4));
	assert(uc.encode() == [Uncompressed.ID, RemoveNode.ID, 1, 1, 4]);

	uc = Uncompressed.fromPackets(RemoveWorld(13).encode(), RemoveWorld(2).encode(), RemoveNode(55).encode());
	assert(uc.encode() == [Uncompressed.ID, 0, 3, 2, RemoveWorld.ID, 13, 2, RemoveWorld.ID, 2, 2, RemoveNode.ID, 55]);

	uc = Uncompressed.fromPackets(RemoveWorld(1), RemoveWorld(2));
	assert(uc.encode() == [Uncompressed.ID, RemoveWorld.ID, 2, 1, 1, 1, 2]);

	Compressed c;

	c = Compressed.compress(RemoveWorld(1).encode(), RemoveWorld(50).encode());
	assert(c.encode() == [Compressed.ID, 6, 21, 14, 120, 156, 19, 101, 98, 100, 100, 52, 2, 0, 0, 201, 0, 77]);

	c = Compressed.compress(uc);
	assert(c.encode() == [Compressed.ID, 6, RemoveWorld.ID, 14, 120, 156, 19, 101, 98, 100, 100, 100, 2, 0, 0, 153, 0, 29]);

	auto ucc = Compressed.fromBuffer(cast(ubyte[])[6, RemoveWorld.ID, 14, 120, 156, 19, 101, 98, 100, 100, 100, 2, 0, 0, 153, 0, 29]).uncompress();
	assert(ucc.id == RemoveWorld.ID);
	assert(ucc.packets == [[1], [2]]);

}
