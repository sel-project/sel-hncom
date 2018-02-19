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
 * Source: $(HTTP github.com/sel-project/sel-hncom/sel/hncom/handler.d, sel/hncom/handler.d)
 */
module sel.hncom.handler;

import std.string : capitalize;
import std.traits : hasUDA;
import std.typetuple : TypeTuple;

import sel.hncom.about;

static import sel.hncom.util;
static import sel.hncom.status;
static import sel.hncom.player;

interface HncomHandler(alias type) if(is(type == clientbound )|| is(type == serverbound)) {
	
	mixin((){
		string ret;
		foreach(section ; TypeTuple!("util", "status", "player")) {
			foreach(member ; __traits(allMembers, mixin("sel.hncom." ~ section))) {
				static if(member != "Packets" && hasUDA!(__traits(getMember, mixin("sel.hncom." ~ section), member), type)) {
					ret ~= "protected void handle" ~ capitalize(section) ~ member ~ "(sel.hncom." ~ section ~ "." ~ member ~ " packet);";
				}
			}
		}
		return ret;
	}());

	public final void handleHncom(ubyte[] buffer) {
		assert(buffer.length);
		switch(buffer[0]) {
			foreach(section ; TypeTuple!("util", "status", "player")) {
				foreach(member ; __traits(allMembers, mixin("sel.hncom." ~ section))) {
					static if(hasUDA!(__traits(getMember, mixin("sel.hncom." ~ section), member), type)) {
						mixin("alias T = sel.hncom." ~ section ~ "." ~ member ~ ";");
						case T.ID: return mixin("this.handle" ~ capitalize(section) ~ member)(T.fromBuffer(buffer[1..$]));
					}
				}
			}
			default: break;
		}
	}

	protected final void handlePlayerPackets(sel.hncom.player.Packets packets) {
		foreach(packet ; packets.packets) {
			this.handlePlayerPacketsImpl(packets.hubId, packet.id, packet.payload);
		}
	}

	private final void handlePlayerPacketsImpl(uint hubId, ubyte id, ubyte[] payload) {
		switch(id) {
			foreach(member ; __traits(allMembers, sel.hncom.player)) {
				static if(member != "Packets" && hasUDA!(__traits(getMember, sel.hncom.player, member), type)) {
					mixin("alias T = sel.hncom.player." ~ member ~ ";");
					case T.ID: return mixin("this.handlePlayer" ~ member)(T.fromBuffer(hubId, payload));
				}
			}
			default: return;
		}
	}

}

unittest {

	abstract class TestClientbound : HncomHandler!clientbound {}

	abstract class TestServerbound : HncomHandler!serverbound {}

}
