/*
 * This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not
 * distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/.
 */
module Application.Utility;

import std.conv;
import std.string;

public import Generic.Utility;

/**
 * A few application-specific constants.
 */
immutable string APPLICATION_NAME        = "grestful";
immutable string APPLICATION_VERSION     = "1.1.0";
immutable string APPLICATION_AUTHOR      = "The grestful team";
immutable string APPLICATION_COPYRIGHT   = "Copyright \xc2\xa9 2015 " ~ APPLICATION_AUTHOR;
immutable string APPLICATION_ID          = "grestful.grestful";
immutable string APPLICATION_COMMENTS    = "A simple RESTful API client written in GTK 3.";
immutable string APPLICATION_LICENSE     =  "This Source Code Form is subject to the terms of the Mozilla Public "
    "License, v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at "
    "http://mozilla.org/MPL/2.0/.";

immutable string[] APPLICATION_AUTHORS     = ["The grestful team"];
immutable string[] APPLICATION_ARTISTS     = [];
immutable string[] APPLICATION_DOCUMENTERS = [""];
immutable string APPLICATION_TRANSLATORS   = "";

immutable string APPLICATION_RESOURCE_DIR;
immutable string APPLICATION_DESIGN_DIR;

/**
 * The minimum required GTK version.
 */
immutable uint GTK_VERSION_MAJOR = 3;
immutable uint GTK_VERSION_MINOR = 16;
immutable uint GTK_VERSION_PATCH = 0;

/**
 * Static constructor to initialize some constants.
 */
static this()
{
    APPLICATION_RESOURCE_DIR = "/usr/share/" ~ APPLICATION_NAME.toLower() ~ "/";

    debug
    {
        APPLICATION_RESOURCE_DIR = "public/";
    }

    APPLICATION_DESIGN_DIR = APPLICATION_RESOURCE_DIR ~ "design/";
}
