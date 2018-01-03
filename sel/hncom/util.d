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

@clientbound @serverbound struct Uncompressed {

	enum ubyte ID = 5;

	/**
	 * If not 0 the same packet in the next field has the same id.
	 * Otherwise the packet id is the first byte of the packet.
	 */
	ubyte id;
	ubyte[][] packets;

	mixin IO!(id, packets);

	/**
	 * Adds a serialised packet to the array of packets.
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

}

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
	 */
	static Compressed compress(Uncompressed uncompressed, int level=6) {
		ubyte[] buffer = uncompressed.encode()[1..$];
		auto ret = Compressed(buffer.length.to!uint, uncompressed.id);
		Compress compress = new Compress(level, HeaderFormat.deflate);
		ret.payload = cast(ubyte[])compress.compress(buffer);
		ret.payload ~= cast(ubyte[])compress.flush();
		return ret;
	}

	static Compressed compress(ubyte[][] packets) {
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

	Uncompressed uncompress() {
		UnCompress uncompress = new UnCompress(this.length);
		ubyte[] buffer = cast(ubyte[])uncompress.uncompress(this.payload);
		buffer ~= cast(ubyte[])uncompress.flush();
		return Uncompressed.fromBuffer(this.id ~ buffer);
	}

}

unittest {



}
