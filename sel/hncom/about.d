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
 * Copyright: Copyright (c) 2017-2018 sel-project
 * License: MIT
 * Authors: Kripth
 * Source: $(HTTP github.com/sel-project/sel-hncom/sel/hncom/about.d, sel/hncom/about.d)
 */
module sel.hncom.about;

/**
 * Version of the protocol.
 * The hub and the connecting nodes must use the same protocol.
 */
enum uint __PROTOCOL__ = 9;

/// Identifier for Minecraft (Bedrock Engine)
enum ubyte __BEDROCK__ = 0;

/// Identifier for Minecraft: Java Edition
enum ubyte __JAVA__ = 1;

enum clientbound;

enum serverbound;
