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
module sel.hncom.login;

import std.json : JSONValue;
import std.typecons : Tuple;

import sel.hncom.about;
import sel.hncom.io : IO;

/**
 * First packet sent by the client after the connection is established.
 * It contains informations used by the hub to check permissions and compatibility.
 */
@serverbound struct ConnectionRequest {

	enum ubyte ID = 1;

	/**
	 * Password, if the hub requires one, or an empty string.
	 */
	string password;

	/**
	 * Name of the node that will be validated by the hub. It should always be
	 * lowercase and only contain letters, numbers, dashes and underscores.
	 */
	string name;

	/**
	 * Indicates whether the node accepts clients when they first connect to the
	 * hub or exclusively when they are transferred.
	 */
	bool main = true;

	/**
	 * Version of the protocol used by the client that must match the hub's one.
	 */
	uint protocol = __PROTOCOL__;

	mixin IO!(password, name, main, protocol);

}

/**
 * Reply to ConnectionRequest sent only when the node's ip is accepted by the hub.
 * It contains the connection status (accepted or an error code) and the hub's protocol.
 */
@clientbound struct ConnectionResponse {

	enum ubyte ID = 2;

	enum : ubyte {

		OK,
		OUTDATED_HUB,				/// The hub uses an old version of hncom
		OUTDATED_NODE,				/// The node uses an old version of hncom
		PASSWORD_REQUIRED,			/// A password is required to connect
		WRONG_PASSWORD,				/// The password doesn't match the hub's one
		INVALID_NAME_LENGTH,		/// The name is too short or too long
		INVALID_NAME_CHARACTERS,	/// The name contains invalid characters
		NAME_ALREADY_USED,			/// There's already a node connected with the same name
		NAME_RESERVED,				/// The name cannot be used because the hub has reserved it for something else
		BLOCKED_BY_PLUGIN,			/// A plugin has blocked the node from connecting

	}

	/**
	 * Indicates the status of connection. If not 0, it indicates an error.
	 */
	ubyte status;

	/**
	 * Indicates the version of the protocol used by the hub when the status
	 * code indicates that the hub or the node is obsolete.
	 */
	uint protocol = __PROTOCOL__;

	mixin IO!(status, protocol);

}

/**
 * Hub's informations.
 */
@clientbound struct HubInfo {

	enum ubyte ID = 3;

	enum int UNLIMITED = -1;
	
	alias GameInfo = Tuple!(string, "motd", uint[], "protocols", bool, "onlineMode", ushort, "port");

	/**
	 * Server's id, either given by a snoop system or randomly generated at runtime.
	 */
	ulong serverId;

	/**
	 * First number of the 4,294,967,296 (2^32) reserved by the hub to create the node's UUIDs.
	 * Every UUID generated by the node is formed by the server's id (most signicant)
	 * and the next reserved uuid (least significant). This way every UUID in the hub
	 * and in the connected nodes is always different.
	 */
	ulong reservedUUIDs;

	/**
	 * Unformatted name of the server as indicated in the hub's configuration file.
	 */
	string displayName;

	/**
	 * Informations about the games supported by the hub.
	 */
	GameInfo[ubyte] gamesInfo;

	/**
	 * Number of players currently online and connected to other nodes.
	 */
	uint online;

	/**
	 * Number of maximum players that can connect to the server (that is the sum
	 * of the max players of the nodes already connected).
	 * The number may change after the current node connects.
	 */
	int max;

	/**
	 * Default server's language in format (language_COUNTRY, e.g. en_GB) and also the
	 * default language for players that don't specify their language or for the ones
	 * which language is not supported by the server.
	 */
	string language;

	/**
	 * Languages accepted by the server in the same format as language.
	 * The list should always contain at least one element (the default language).
	 */
	string[] acceptedLanguages;

	/**
	 * Indicates whether the web admin protocol is active on the hub. If it is the
	 * node should send the port where it will listen for connections in its info packet.
	 */
	bool webAdmin;

	/**
	 * Optional informations about the server's software, social accounts, system and options.
	 * Example:
	 * ---
	 * {
	 *   "software": {
	 *      "name": "selery",
	 *      "version": "0.0.1",
	 *      "stable": true
	 *   },
	 *   "minecraft": {
	 *      "edu": false,
	 *      "realm": true
	 *   },
	 *   "social": {
	 *      "website": "example.com",
	 *      "facebook": "example-official",
	 *      "twitter": "example_tweets",
	 *      "youtube": "examplechannel",
	 *      "instagram": "example",
	 *      "google-plus": "example-plus"
	 *   },
	 *   "system": {
	 *      "os": "Ubuntu 16.04",
	 *      "cpu": "Intel(R) Core(TM) i5-5200U CPU @ 2.20GHz",
	 *      "cores": 2,
	 *      "ram": 2147483648
	 *   }
	 * }
	 * ---
	 */
	JSONValue additionalJSON;

	mixin IO!(serverId, reservedUUIDs, displayName, gamesInfo, online, max, language, acceptedLanguages, webAdmin, additionalJSON);

}

/**
 * Node's informations.
 */
@serverbound struct NodeInfo {

	enum ubyte ID = 4;

	enum uint UNLIMITED = 0;

	alias Plugin = Tuple!(string, "name", string, "version_");

	/**
	 * Informations about the games accepted by the node. There should be at least
	 * one combination of game/protocols that is also accepted by hub as indicated
	 * in HubInfo.gamesInfo, otherwise the node will never receive any player.
	 */
	uint[][ubyte] acceptedGames;
	
	/**
	 * Maximum number of players accepted by node.
	 */
	uint max;

	/**
	 * List of plugins loaded on the node for creating queries on the hub.
	 */
	Plugin[] plugins;

	/**
	 * Port where the node is listening for connections, if the web admin protocol
	 * is active on the hub.
	 */
	ushort webAdminPort;

	/**
	 * Optional informations about the server's software and system,
	 * similar to HubInfo's additionalJson field.
	 * Example:
	 * ---
	 * {
	 *   "software": {
	 *      "name": "selery",
	 *      "version": "0.0.1",
	 *      "stable": true
	 *   },
	 *   "system": {
	 *      "os": "Windows 10",
	 *      "cpu": "Intel(R) Core(TM) i7-5700U CPU @ 3.40GHz",
	 *      "cores": 4,
	 *      "ram": 8589934592
	 *   }
	 * }
	 * ---
	 */
	JSONValue additionalJSON;

	mixin IO!(acceptedGames, max, plugins, webAdminPort, additionalJSON);

}
