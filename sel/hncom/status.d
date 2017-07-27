﻿/*
 * Copyright (c) 2017 SEL
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
module sel.hncom.status;

import std.json : JSONValue;
import std.socket : Address;
import std.typecons : Tuple;
import std.uuid : UUID;

import sel.hncom.about;
import sel.hncom.io : IO;

/**
 * Used to calculate latency by both the hub and the node.
 * When this packet is received it should be immeditaly sent back to the sender
 * without any change.
 */
@clientbound @serverbound struct Latency {

	enum ubyte ID = 7;

	/**
	 * Id of the ping/pong. Should be unique for the session.
	 */
	uint id;

	mixin IO!(id);

}

/**
 * Notifies the node that the hub's reloadeable settings have been reloaded and that
 * the node should also reload its resources (for example plugin's settings).
 * The fields of the packet may be empty if not updated during the reload.
 */
@clientbound struct Reload {

	enum ubyte ID = 8;

	/**
	 * Display name of the server in the same format as HubInfo's displayName field.
	 */
	string displayName;

	/**
	 * New MOTDs (message of the day) for the supported games.
	 */
	string[ubyte] motds;

	/**
	 * Main language of the server in the same format as HubInfo's language field.
	 */
	string language;

	/**
	 * 
	 */
	string[] acceptedLanguages;

	/**
	 * 
	 */
	JSONValue additionalJSON;

	mixin IO!(displayName, motds, language, acceptedLanguages, additionalJSON);

}

/**
 * Sends a logged message to the hub.
 */
@serverbound struct Log {

	enum ubyte ID = 9;
	
	enum int NO_WORLD = -1;

	/**
	 * Unix time (in milliseconds) that indicates the exact creation time of the
	 * log (for ordering purposes).
	 */
	ulong timestamp;

	/**
	 * Id of the world that has generated the log, if the log comes from a world, -1 otherwise.
	 */
	int worldId = -1;

	/**
	 * Name of the logger thas has generated the log, if the log doesn't come from a world.
	 */
	string logger;

	/**
	 * Logged message. It may contain Minecraft formatting codes.
	 */
	string message;

	/**
	 * Identifier of the command that has generated the log or -1 if the
	 * log wasn't generated by a command.
	 */
	int commandId = -1;

	mixin IO!(timestamp, worldId, logger, message, commandId);

}

/**
 * Notifies the node that another node (that is not the receiver) has connected to the hub.
 */
@clientbound struct AddNode {

	enum ubyte ID = 10;

	/**
	 * Identifier given by the hub to uniquey identify the node.
	 */
	uint hubId;

	/**
	 * Node's name used for displaying and identification purposes.
	 */
	string name;

	/**
	 * Whether the node is a main node.
	 */
	bool main;

	/**
	 * Indicates the games and protocols accepted by the node.
	 */
	uint[][ubyte] acceptedGames;

	mixin IO!(hubId, name, main, acceptedGames);

}

/**
 * Notifies the node that another node, previously added with AddNode,
 * has disconnected from the hub.
 */
@clientbound struct RemoveNode {

	enum ubyte ID = 11;

	/**
	 * Node's id given by the hub.
	 */
	uint hubId;

	mixin IO!(hubId);

}

/**
 * Receives a binary message sent by another node using SendMessage.
 */
@clientbound struct ReceiveMessage {

	enum ubyte ID = 12;

	/**
	 * Id of the node that has sent the message.
	 */
	uint sender;

	/**
	 * Indicates whether the message was broadcasted to every connected node.
	 */
	bool broadcasted;

	/**
	 * Bytes received. It could be serialised data or a plugin-defined packet.
	 */
	ubyte[] payload;

	mixin IO!(sender, payload);

}

/**
 * Sends a binary message to some selected nodes or broadcast it.
 */
@serverbound struct SendMessage {
	
	enum ubyte ID = 13;

	/**
	 * Addressees of the message. If the array is empty the message is
	 * broadcasted to every connected node but the sender.
	 */
	uint[] addressees;

	/**
	 * Bytes to be sent/broadcasted. It may be serialised data or a plugin-defined packet.
	 */
	ubyte[] payload;

	mixin IO!(addressees, payload);
	
}

/**
 * Updates the number of players on the server.
 */
@clientbound struct UpdatePlayers {

	enum ubyte ID = 14;

	enum int UNLIMITED = -1;

	/**
	 * Players currently online in the whole server (connected to a node).
	 */
	uint online;

	/**
	 * Maximum number of players that can connect to server, which is the sum of
	 * the max players of every connected node.
	 */
	int max;

	mixin IO!(online, max);

}

/**
 * Updates the number of players that can be accepted by the node.
 * If the given number is smaller than the players currently connected
 * to the node no player should be kicked.
 */
@serverbound struct UpdateMaxPlayers {

	enum ubyte ID = 15;

	enum uint UNLIMITED = 0;

	/**
	 * Maximum number of players accepted by node.
	 */
	uint max;

	mixin IO!(max);

}

/**
 * Updates the usage of the system's resources of the node.
 */
@serverbound struct UpdateUsage {

	enum ubyte ID = 16;

	/**
	 * Kibibytes of RAM used by the node.
	 */
	uint ram;

	/**
	 * Percentage of CPU used by the node. It may be higher than 100
	 * if the node has more than 1 CPU
	 */
	float cpu;

	mixin IO!(ram, cpu);

}

/**
 * Executes a command on the node.
 */
@clientbound struct RemoteCommand {

	enum ubyte ID = 17;

	enum : ubyte {

		HUB = 1,
		EXTERNAL_CONSOLE,
		REMOTE_PANEL,
		RCON,

	}

	/**
	 * Origin of the command. It could be the hub itself or an external source.
	 */
	ubyte origin;

	/**
	 * Address of the sender if the command has been sent from an external source.
	 * It's `null` when the hub is the sender.
	 */
	Address sender;

	/**
	 * Commands and arguments that should be executed on the node.
	 * For example `say hello world` or `kill @a`.
	 */
	string command;

	/**
	 * Identifier of the command. It's sent back in Log's commandId field
	 * when the command generates output.
	 */
	uint commandId;

	mixin IO!(origin, sender, command, commandId);

}

/**
 * Notifies the hub that a new world has been created on the node.
 */
@serverbound struct AddWorld {
	
	enum ubyte ID = 18;

	/**
	 * Id of the world. It's unique on the node.
	 */
	uint worldId;

	/**
	 * Name of the world, it doesn't need to be unique.
	 */
	string name;

	/**
	 * World's dimension in the MCPE format (0: overworld, 1: nether, 2: end).
	 */
	ubyte dimension;

	/**
	 * Id of the world's parent or -1 if the world has no parent. This is usually used
	 * for nether/end which are children of an overworld world.
	 */
	int parent = -1;
	
	mixin IO!(worldId, name, dimension, parent);
	
}

/**
 * Notifies the hub that a world has been removed from the node.
 */
@serverbound struct RemoveWorld {
	
	enum ubyte ID = 19;

	/**
	 * Id of the world that has been removed, previosly added using the
	 * AddWorld packet.
	 */
	uint worldId;
	
	mixin IO!(worldId);
	
}

@clientbound struct ListInfo {

	alias EntryUUID = Tuple!(ubyte, "game", UUID, "uuid");

	alias EntryUsername = Tuple!(ubyte, "game", string, "username");

	enum ubyte ID = 20;

	enum : ubyte {

		WHITELIST,
		BLACKLIST

	}

	ubyte list;

	EntryUUID[] entriesByUUID;

	EntryUsername[] entriesByUsername;

	string[] entriesByIp;

	mixin IO!(list, entriesByUUID, entriesByUsername, entriesByIp);

}

@clientbound @serverbound struct UpdateListByUUID {

	enum ubyte ID = 21;

	ubyte list;

	ubyte game;

	UUID uuid;

	mixin IO!(list, game, uuid);

}

@clientbound @serverbound struct UpdateListByUsername {

	enum ubyte ID = 22;

	ubyte list;

	ubyte game;

	string username;

	mixin IO!(list, game, username);

}

@clientbound @serverbound struct UpdateListByIp {

	enum ubyte ID = 23;

	ubyte list;

	string ip;

	mixin IO!(list, ip);

}

@clientbound struct PanelCredentials {

	enum ubyte ID = 24;

	string address;
	ubyte[64] hash;
	uint worldId;

	mixin IO!(address, hash, worldId);

}
