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
/**
 * Packets related to a player. The first field of every packet is an `hub id`
 * that uniquely identifies a player in the hub and never changes until it disconnects.
 */
module sel.hncom.player;

import std.json : JSONValue;
import std.socket : Address;
import std.typecons : Tuple;
import std.uuid : UUID;

import sel.hncom.about;
static import sel.hncom.io;

mixin template IO(E...) {

	mixin sel.hncom.io.IOImpl!(E);

	ubyte[] encode() {
		ubyte[] buffer;
		sel.hncom.io.encodeType(ID, buffer);
		sel.hncom.io.encodeType(hubId, buffer);
		encodeValues(buffer);
		return buffer;
	}

	void addTo(ref Packets packets) {
		auto packet = typeof(Packets.packets.init[0])(ID, []);
		encodeValues(packet.payload);
		packets.packets ~= packet;
	}

	typeof(this) decode(ubyte[] buffer) {
		size_t index = 0;
		hubId = sel.hncom.io.decodeType!uint(buffer, index);
		decodeValues(buffer, index);
		return this;
	}

	static typeof(this) fromBuffer(ubyte[] buffer) {
		return typeof(this)().decode(buffer);
	}

	static typeof(this) fromBuffer(uint hubId, ubyte[] buffer) {
		size_t index = 0;
		auto ret = typeof(this)(hubId);
		ret.decodeValues(buffer, index);
		return ret;
	}

}

/**
 * Adds a player to the node.
 */
@clientbound struct Add {

	enum ubyte ID = 25;

	alias ServerAddress = Tuple!(string, "ip", ushort, "port");

	alias Skin = Tuple!(string, "name", ubyte[], "data", ubyte[], "cape", string, "geometryName", ubyte[], "geometryData");

	// reason
	enum : ubyte {

		FIRST_JOIN = 0,				/// The player has been automatically put on this node because it's a non-full main node.
		TRANSFERRED = 1,			/// The player has been transferred to this node.
		FORCIBLY_TRANSFERRED = 2,	/// The player was on a node that has wrongly disconnected (probably crashing) and the player has been transferred to the first non-full main node.

	}

	// permission level
	enum : ubyte {

		USER = 0,
		OPERATOR = 2,
		HOST = 3,
		AUTOMATION = 4,
		ADMIN = 5,

	}

	// permissions
	enum : ubyte {
		
		BUILD_AND_MINE = 64,
		USE_DOORS_AND_SWITCHES = 32,
		OPEN_CONTAINERS = 16,
		ATTACK_PLAYERS = 8,
		ATTACK_MOBS = 4,
		//OPERATOR = 2, // same as PermissionLevel.OPERATOR
		USE_TELEPORT = 1,
		
	}

	// input mode
	enum : ubyte {

		KEYBOARD = 0,
		TOUCH = 1,
		CONTROLLER = 2,

	}

	/**
	 * Player's unique id given by the hub.
	 */
	uint hubId;

	/**
	 * Reason for which the player has been added to the node.
	 */
	ubyte reason;

	/**
	 * Game used by the player, which could either be Minecraft: Java Edition or Minecraft (Bedrock Engine).
	 * It should be one of the keys given in NodeInfo's acceptedGames field.
	 */
	ubyte type;

	/**
	 * Version of the protocol used by the client. Should be contained in the list given
	 * to the hub in the NodeInfo's acceptedGames field.
	 */
	uint protocol;

	/**
	 * Version of the game used by the client, usually in the format major.minor[.patch],
	 * calculated by the server or passed by the client during the authentication process.
	 * The node should verify that the version exists and matches the protocol indicated
	 * in the previous field.
	 */
	string version_;

	/**
	 * Client's UUID, given by Mojang's or Microsoft's services if the server is in
	 * online mode or given by the client (and not verified) if the server is in offline mode.
	 */
	UUID uuid;

	/**
	 * Username of the player.
	 */
	string username;

	/**
	 * Display name of the player, which can contain formatting codes. By default it's equals
	 * to the username but it can be updated by the node using the UpdateDisplayName packet.
	 */
	string displayName;

	/**
	 * Player's permission level that indicates its administration power. It's set to USER
	 * by default, which has no particular permission.
	 */
	ubyte permissionLevel;

	/**
	 * Inidicates what a player can and cnnot do on the world (build, mine, teleport, ...).
	 * It's a bitflag.
	 */
	ubyte permissions;

	/**
	 * Dimension in which the player was playing before being transferred in the MCPE format
	 * (0: overworld, 1: nether, 2: end). It shouldn't be considered if the client just joined
	 * the server instead of being transferred.
	 */
	ubyte dimension;

	/**
	 * Client's view distance (or chunk radius).
	 */
	uint viewDistance;

	/**
	 * Remote address of the player.
	 */
	Address clientAddress;

	/**
	 * Address used by the client to connect to the server. The value of this field is the address
	 * the client has saved in its servers list. For example a client that joins through `localhost`
	 * and a client that joins through `127.0.0.1` will connect to the same server with the same ip
	 * but the field of this value will be different (`localhost` for the first client and
	 * `127.0.0.1` for the latter).
	 */
	ServerAddress serverAddress;

	/**
	 * Client's skin, given by the client or downloaded from Mojang's services in online mode.
	 */
	Skin skin;

	/**
	 * Client's language, in the same format as HubInfo's language field, which should be updated
	 * from the node when the client changes it.
	 */
	string language;

	/**
	 * Client's input mode. May be a controller, a mouse/keyboard set or a touch screen.
	 */
	ubyte inputMode;

	/**
	 * Example:
	 * ---
	 * // bedrock engine
	 * {
	 *    "edu": false,
	 *    "DeviceOS": 1,
	 *    "DeviceModel": "ONEPLUS A0001"
	 * }
	 * ---
	 */
	JSONValue gameData;

	mixin IO!(reason, type, protocol, version_, uuid, username, displayName, permissionLevel, permissions, dimension, viewDistance, clientAddress, serverAddress, skin, language, inputMode, gameData);

}

/**
 * Removes a player from the node.
 * If the player is removed using Kick or Transfer this packet is not sent.
 */
@clientbound struct Remove {

	enum ubyte ID = 26;

	// reason
	enum : ubyte {

		LEFT,			/// The player has closed the connection.
		TIMED_OUT,		/// The hub has closed the connection because didn't had any response from the client for too long.
		KICKED,			/// The player has been manually kicked.
		TRANSFERRED,	/// The player has been transferred by the hub

	}

	/**
	 * Player's unique id given by the hub.
	 */
	uint hubId;

	/**
	 * Reason of the disconnection.
	 */
	ubyte reason;

	mixin IO!(reason);

}

/**
 * Kicks a player from the node and the whole server. When a player is disconnected
 * from the node using this packet the hub will not send the Remove packet.
 */
@serverbound struct Kick {

	enum ubyte ID = 27;

	/**
	 * Player to be kicked.
	 */
	uint hubId;

	/**
	 * Reason of the disconnection that will be displayed in the client's
	 * disconnection screen.
	 */
	string reason;

	/**
	 * Whether the previous string should be translated client-side or not.
	 */
	bool translation;

	/**
	 * Optional parameters for the translation (Only for java clients).
	 */
	string[] parameters;

	mixin IO!(reason, translation, parameters);

}

/**
 * Transfers a player to another node. When a player is transferred from the node the hub
 * will not send the Remove packet and there's no way, for the node, to know whether the
 * player was disconnected or successfully transferred, if not using messages through a
 * user-defined protocol.
 */
@serverbound struct Transfer {

	enum ubyte ID = 28;

	// on fail
	enum : ubyte {

		DISCONNECT,		/// Disconnect with `End of Stream` message.
		AUTO,			/// Connect to the first available node or disconnects if there isn't one.
		RECONNECT,		/// Connect to the same node, but as a new player.

	}

	/**
	 * Player to be transferred.
	 */
	uint hubId;

	/**
	 * Id of the node that player will be transferred to. It should be an id of a
	 * connected node (which can be calculated using AddNode and RemoveNode packets),
	 * otherwise the player will be disconnected or moved to another node (see the following field).
	 */
	uint node;

	/**
	 * Indicates the action to be taken when a transfer fails because the indicated node is
	 * not connected anymore or it cannot accept the given player's game type or protocol.
	 * If the indicated node is full the player will be simply disconnected with the `Server Full` message.
	 */
	ubyte onFail = DISCONNECT;

	mixin IO!(node, onFail);

}

/**
 * Updates the player's display name when it is changed.
 * When this packet is sent by the node a copy is always sent back by the hub.
 */
@clientbound @serverbound struct UpdateDisplayName {

	enum ubyte ID = 29;

	/**
	 * Player's unique id given by the hub.
	 */
	uint hubId;

	/**
	 * Player's display name that can contain formatting codes. Prefixes and suffixes should be avoided.
	 */
	string displayName;

	mixin IO!(displayName);

}

/**
 * Updates the player's world. The player's dimension should be updated by
 * the hub using worldId to identify the world added with AddWorld and
 * removed with RemoveWorld.
 */
@serverbound struct UpdateWorld {

	enum ubyte ID = 30;

	/**
	 * Player's unique id given by the hub.
	 */
	uint hubId;

	/**
	 * World's id, that should have been previously added with the
	 * AddWorld packet.
	 */
	uint worldId;

	mixin IO!(worldId);

}

/**
 * Update the player's permission level.
 * When this packet is sent by the node a copy is always sent back by the hub.
 */
@clientbound @serverbound struct UpdatePermissionLevel {
	
	// permission level
	enum : ubyte {
		
		USER = 0,
		OPERATOR = 2,
		HOST = 3,
		AUTOMATION = 4,
		ADMIN = 5,
		
	}

	enum ubyte ID = 31;

	/**
	 * Player's unique id given by the hub.
	 */
	uint hubId;

	ubyte permissionLevel;

	mixin IO!(permissionLevel);

}

/**
 * Update the player's permissions.
 * When this packet is sent by the node a copy is always sent back by the hub.
 */
@clientbound @serverbound struct UpdatePermissions {

	enum ubyte ID = 32;

	// permissions
	enum : ubyte {

		BUILD_AND_MINE = 64,
		USE_DOORS_AND_SWITCHES = 32,
		OPEN_CONTAINERS = 16,
		ATTACK_PLAYERS = 8,
		ATTACK_MOBS = 4,
		OPERATOR = 2,
		USE_TELEPORT = 1,

	}

	/**
	 * Player's unique id given by the hub.
	 */
	uint hubId;

	/**
	 * Indicates which permissions are currently being updated.
	 */
	ubyte updated;

	/**
	 * Indicates the values of the updated permissions.
	 */
	ubyte permissions;
	
	mixin IO!(updated, permissions);

}

/**
 * Notifies the node that the player's view distance has been updated client-side.
 * The node may decide to not accept the new view distance and not send the required chunks.
 */
@clientbound struct UpdateViewDistance {

	enum ubyte ID = 33;

	/**
	 * Player's unique id given by the hub.
	 */
	uint hubId;

	/**
	 * Player's new view distance as indicated by the client.
	 */
	uint viewDistance;

	mixin IO!(viewDistance);

}

/**
 * Updates the player's language when the client changes it.
 */
@clientbound struct UpdateLanguage {

	enum ubyte ID = 34;

	/**
	 * Player's unique id given by the hub.
	 */
	uint hubId;

	/**
	 * Player's language in the same format as HubInfo's language field.
	 */
	string language;

	mixin IO!(language);

}

/**
 * Updates the latency between the player and the hub.
 */
@clientbound struct UpdateLatency {

	enum ubyte ID = 35;

	/**
	 * Player's unique id given by the hub.
	 */
	uint hubId;

	/**
	 * Player's latency in milliseconds. The latency between the client and the
	 * node is then calculated adding the latency between the node and the hub
	 * to this field's value.
	 */
	uint latency;

	mixin IO!(latency);

}

/**
 * Updates the packet loss between the player and the hub.
 */
@clientbound struct UpdatePacketLoss {

	enum ubyte ID = 36;

	/**
	 * Player's unique id given by the hub.
	 */
	uint hubId;

	/**
	 * Percentage of lost packets, from 0% (no packet lost) to 100% (every
	 * packet lost).
	 */
	float packetLoss;

	mixin IO!(packetLoss);

}

@clientbound @serverbound struct GamePacket {
	
	enum ubyte ID = 37;

	/**
	 * Player's unique id given by the hub.
	 */
	uint hubId;
	ubyte[] payload;
	
	mixin IO!(payload);
	
}

@serverbound struct SerializedGamePacket {

	enum ubyte ID = 38;

	/**
	 * Player's unique id given by the hub.
	 */
	uint hubId;
	ubyte[] payload;

	mixin IO!(payload);

}

@serverbound struct OrderedGamePacket {

	enum ubyte ID = 39;

	/**
	 * Player's unique id given by the hub.
	 */
	uint hubId;
	uint order;
	ubyte[] payload;

	mixin IO!(order, payload);

}

@clientbound @serverbound struct Packets {

	enum ubyte ID = 40;

	/**
	 * Player's unique id given by the hub.
	 */
	uint hubId;
	Tuple!(ubyte, "id", ubyte[], "payload")[] packets;

	mixin IO!(packets);

}

unittest {

	auto packets = Packets(42);
	UpdateDisplayName(42, "Steve").addTo(packets);
	UpdateViewDistance(42, 16).addTo(packets);
	import std.conv;
	assert(packets.encode() == [Packets.ID, 42, 2, UpdateDisplayName.ID, 6, 5, 'S', 't', 'e', 'v', 'e', UpdateViewDistance.ID, 1, 16]);

	packets = Packets.fromBuffer([100, 3, UpdateLatency.ID, 1, 1, UpdateLatency.ID, 1, 2, UpdateLatency.ID, 2, 130, 1]);
	assert(packets.hubId == 100);
	foreach(packet ; packets.packets) {
		assert(packet.id == UpdateLatency.ID);
		assert(UpdateLatency.fromBuffer(packets.hubId, packet.payload).latency >= 1);
	}

}
