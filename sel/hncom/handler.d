﻿/*
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
/**
 * Copyright: 2017-2018 sel-project
 * License: LGPL-3.0
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
